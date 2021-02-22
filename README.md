# Veracruz Docker image

## Requirements

The tests are done on a linux machine. [To enable docker experimental features on another OS.](https://docs.docker.com/engine/reference/commandline/checkpoint_create/)

We use `squash` docker experimental feature to help reduce docker image size, to enable this feature:
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

## Build instructions

Veracruz docker image can be built for both `SGX` and `TrustZone`:
- for `SGX`:
```sh
make build TEE=sgx
```
- for `TrustZone`:
```sh
make build TEE=tz
```

To run Veracruz: [instructions](https://github.com/veracruz-project/veracruz/blob/main/BUILD_INSTRUCTIONS.markdown).