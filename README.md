# Building Veracruz

<img src = "https://confidentialcomputing.io/wp-content/uploads/sites/85/2019/08/cc_consortium-color.svg" width=192>

This is the repository for the Docker container used for developing Veracruz.
Veracruz is an open-source runtime for collaborative privacy-preserving compute.
The main Veracruz repository can be found [here](https://github.com/veracruz-project/veracruz).

Veracruz is an adopted project of the Confidential Compute Consortium (CCC).

## Supported platforms

- AWS Nitro Enclaves
- Linux (no TEE technology used)

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

- ### Build Instructions for AWS Nitro Enclaves
    ```
    make nitro-base
    ```

- ### Build Instructions for Linux
    ```
    make linux-base
    ```

- ### Starting the veracruz container
    For AWS Nitro Enclaves:
    ```
    make nitro-run
    ```

    Or, for Linux:
    ```
    make linux-run
    ```

There should be a Docker container running called "veracruz_<PLATFORM>_<USERNAME>". To verify that it's running, run: 
    ```
    docker ps
    ```
    
You can now start a shell in the newly created container:
    For Nitro:
```
    make nitro-exec
```

    For Linux:
```
    make linux-exec
```

## Test Instructions for AWS Nitro Enclaves

Once inside the container, set up your local environment.

Now, to build the binaries:
```
cd workspaces/
make nitro
```

and to run the tests:

```
cd workspaces/nitro-host/
make test-server
make veracruz-test
```

## Test Instructions for Linux

Once inside the container, build the binaries:
```
cd workspaces/
make linux
```

and to run the tests:

```
cd workspaces/linux-host/
make test-server
make veracruz-test
```

# Cleaning a build

The Veracruz Makefile exposes a build target, `clean`, which recursively
invokes `cargo clean` for each major subcomponent of the project.  However,
sometimes this is not enough to fix a broken build environment (note that this
is common when using `xargo` to build e.g. the examples, or the rest of the
SDK).  In that case, it is useful to also delete the contents of the
`~/.xargo` directory, in addition to the standard clean build process described
above.

# Generating the certificates

Cryptographic certificates can be generated by using the following `openssl`
invocation:

```
openssl req -new -x509 -key <key filename> -sha256 -nodes -days 3650 -out <certificate filename> -config cert.conf 
```
