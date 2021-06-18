# docker image for developing and testing Veracruz on SGX.
#
# AUTHORS
#
# The Veracruz Development Team.
#
# COPYRIGHT
#
# See the `LICENSE.markdown` file in the Veracruz root directory for licensing
# and copyright information.
#
# NOTE: We try to follow the guide in https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
#       Each RUN contains a bundle of steps, which reduces the cache.
ARG TEE=sgx

FROM veracruz/base:latest

ARG USER=root
ARG UID=0
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]
USER root
RUN mkdir /etc/init -p

# Install PSW
WORKDIR /tmp
RUN wget https://download.01.org/intel-sgx/linux-2.5/ubuntu18.04-server/libsgx-enclave-common_2.5.101.50123-bionic1_amd64.deb \
    && dpkg -i libsgx-enclave-common_2.5.101.50123-bionic1_amd64.deb \
    && rm libsgx-enclave-common_2.5.101.50123-bionic1_amd64.deb  

# Install PSW-dev
WORKDIR /work
RUN wget https://download.01.org/intel-sgx/linux-2.5/ubuntu18.04-server/libsgx-enclave-common-dev_2.5.101.50123-bionic1_amd64.deb \
    && dpkg -i libsgx-enclave-common-dev_2.5.101.50123-bionic1_amd64.deb \
    && rm libsgx-enclave-common-dev_2.5.101.50123-bionic1_amd64.deb;\ 
# Install PSW debug symbols
    wget https://download.01.org/intel-sgx/linux-2.5/ubuntu18.04-server/libsgx-enclave-common-dbgsym_2.5.101.50123-bionic1_amd64.ddeb \
    && dpkg -i libsgx-enclave-common-dbgsym_2.5.101.50123-bionic1_amd64.ddeb \
    && rm libsgx-enclave-common-dbgsym_2.5.101.50123-bionic1_amd64.ddeb; \
## fetch and build the SDK
    wget https://download.01.org/intel-sgx/sgx-linux/2.9.1/distro/ubuntu18.04-server/sgx_linux_x64_sdk_2.9.101.2.bin \
    && chmod a+x ./sgx_linux_x64_sdk_2.9.101.2.bin \
    && echo "yes" | ./sgx_linux_x64_sdk_2.9.101.2.bin \
    && rm sgx_linux_x64_sdk_2.9.101.2.bin \
    && source /work/sgxsdk/environment \
    && cat /work/sgxsdk/environment >> /etc/profile; \
# add a user
    if [ "$USER" != "root" ] ; then useradd -u $UID -m -p `openssl rand -base64 32` -s /bin/bash $USER ; fi; \
    chown -R $USER /work
# explictly specify the sgx libraries path and mbed-crypto path
ENV C_INCLUDE_PATH /work/sgxsdk/include

WORKDIR /work
COPY --chown=$USER start_aesm.sh .
