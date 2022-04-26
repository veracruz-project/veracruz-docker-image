# Building Veracruz

<img src = "https://confidentialcomputing.io/wp-content/uploads/sites/85/2019/08/cc_consortium-color.svg" width=192>

This is the repository for the Docker container used for developing Veracruz.
Veracruz is an open-source runtime for collaborative privacy-preserving compute.
The main Veracruz repository can be found [here](https://github.com/veracruz-project/veracruz).

Veracruz is an adopted project of the Confidential Compute Consortium (CCC).

## Supported platforms

- Intel SGX
- Arm TrustZone

## Requirements

- **Docker:** 
We use Docker to provide a consistent build environment.  Follow this guide to [install Docker](https://docs.docker.com/engine/install/) if necessary.
- **Enable Docker squash experimental feature:** *The tests are done on a linux machine. [To enable docker experimental features on another OS.](https://docs.docker.com/engine/reference/commandline/checkpoint_create/)*
We use the `squash` docker experimental feature to help reduce the Veracruz docker image size, to enable this feature:
    - run: 
        ```sh 
        sudo service docker stop
        ```
    - copy the following in `/etc/docker/daemon.json `
        ```sh
        {
            "experimental": true
        }
        ```
    - run:
        ```sh 
        sudo service docker start
        ```

- **Intel Attestation Service access token (IAS_Token)** *Only if building on an Intel platform:* 
You can get this token by following these steps: 
    - Create an account [here](https://api.portal.trustedservices.intel.com/EPID-attestation)
    - Once Signed in, under `Development Access`, select either `Subscribe (linkable)` or `Subscribe (unlinkable)` then `subscribe`.
    - Two keys will be generated, Primary and Secondary key, either of these keys can be used as your `IAS_Token`.


## Local build setup

Once all the necessary requirements are available, run the following commands:
- Clone the Veracruz repository: This will pull the docker submodule

    ```
    git clone --recursive https://github.com/veracruz-project/veracruz.git 
    export VERACRUZ_ROOT=$PWD/veracruz
    ```
- Once you have a local copy of the Veracruz source:

    ```
    cd veracruz/docker
    ```

The following instructions depend on the platform you're building for. (SGX, Arm TZ)

Note that building the Docker image will take a long time (we appreciate any suggestions on how this can be sped up!)

- ### Build Instructions for SGX
    ```
    make build TEE=sgx 
    ```
- ### Build Instructions for Arm TrustZone
    ```
    make build TEE=tz
    ```

- ### Build Instructions for AWS Nitro Enclaves
    ```
    make build TEE=nitro
    ```

- ### Starting the veracruz container
    ```
    make sgx-run IAS_TOKEN=<your Intel Attestation Service token>
    ```
    or (for trustzone):
    ```
    make tz-run
    ```
    or (for AWS Nitro Enclaves):
    ```
    make nitro-run
    ```

There should be a Docker container running called "veracruz". To verify that it's running, run: 
    ```
    docker ps
    ```
    
You can now start a shell in the newly created container:
    
   For SGX:

```
docker exec -u <your username> -it 'veracruz_sgx_<your username>' bash
```
    
   For trustzone:

```
docker exec -u <your username> -it 'veracruz_tz_<your username>' bash
```

## Test Instructions for SGX

You can manually build Veracruz by running:

```
source /work/veracruz/sgx_env.sh

cd /work/veracruz
make sgx
```

With that, all major sub-components of Veracruz (including the SDK) will be built for SGX.

Now, to run the Veracruz server tests.  Simply run:

```
cd /work/veracruz
make sgx-veracruz-server-test
```

You should see that all (_7_) tests pass.  Now, to run the full system
integration tests:

```
make sgx-veracruz-test
```

All (_8_) tests should pass.

## Test Instructions for TrustZone

Once inside the container, setup your local environment using the `tz_env.sh` shell script in the Veracruz repository root directory:

```
source tz_env.sh
```

Following that, the enclave binary may be built by executing the `trustzone` build target, again in the root directory of Veracruz:

```
make trustzone
```

Everything is now built for TrustZone, and the Veracruz server and Veracruz integration tests can now be run:

```
make trustzone-veracruz-server-test
```

and

```
make trustzone-veracruz-test
```

will execute both of these testsuites.  You, again, should see _7_ and _8_ tests executing and passing, respectively.

## Test Instructions for AWS Nitro Enclaves

Once inside the container, set up your local environment.

You need to configure your AWS credentials by running:
```
aws configure
```
and entering the appropriate values at the prompt.

Veracruz needs the ability to start another EC2 instance from your initial EC2 instance. The following instructions set up this ability.

You need to get the subnet that your initial EC2 instance is on.

The id of this subnet should be set in the environment varialbe AWS_SUBNET.

You need to create a security group that allows ports 3010, 9090 for private IP addresses within the subnet.

You probably also want to allow port 22 form all IPs to enable you to SSH into the instance (if you think you'll want to)

The name of this security group should be set in the environment variable AWS_SECURITY_GROUP_ID

You also need to set up an AWSK public/private key pair. You need the private key in a file on your initial EC2 instance. The path to this private key should be set in the environment variable AWS_PRIVATE_KEY_FILENAME.

The name of this key pair (as known by AWS) should be set in the environment variable AWS_KEY_NAME.

The AWS region that you are running on should be set in the environment variable AWS_REGION.

To do this, it is recommended to set the variables in a file called nitro.env as follows:
```bash
export AWS_KEY_NAME="<VALUE>"
export AWS_PRIVATE_KEY_FILENAME="<VALUE>"
export AWS_SUBNET="<VALUE>"
export AWS_REGION="<VALUE>"
export AWS_SECURITY_GROUP_ID="<VALUE>"
```
Now, to run the tests:
```
make trustzone-veracruz-server-test
```

and

```
make trustzone-veracruz-test
```

***IMPORTANT***
After the tests have run, you should make sure any extra EC2 instances have been
shut down by running:
```
./veracruz-server-test/nitro-ec2-terminate-root.sh
```
or you might end up with some surprising AWS bills.

# Cleaning a build

The Veracruz Makefile exposes a build target, `clean`, which recursively
invokes `cargo clean` for each major subcomponent of the project.  However,
sometimes this is not enough to fix a broken build environment (note that this
is common when using `xargo` to build e.g. the examples, or the rest of the
SDK).  In that case, it is useful to also delete the contents of the
`~/.xargo` directory, in addition to the standard clean build process described
above.

# What to do when your kernel version changes

Note: All of the commands below need to be run on the host operating system,
not inside a Docker container.

When your Linux kernel gets updated, it does not update the SGX kernel module
with it, and therefore this needs to be rebuilt and reinstalled.  You can tell
when this has happened by running:

```
sudo lsmod | grep sgx
```

If you get no results, you need to reinstall the SGX kernel module.

Following the directions for installing the module for your new kernel from
here: https://github.com/intel/linux-sgx-driver.

Rebuild the linux-sgx-driver by running make, then:

```
sudo mkdir -p "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
sudo cp isgx.ko "/lib/modules/"`uname -r`"/kernel/drivers/intel/sgx"
sudo /sbin/depmod
sudo /sbin/modprobe isgx
```

# Generating the certificates

Cryptographic certificates can be generated by using the following `openssl`
invocation:

```
openssl req -new -x509 -key <key filename> -sha256 -nodes -days 3650 -out <certificate filename> -config cert.conf 
```
