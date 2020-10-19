# docker image for developing and testing Veracruz.
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
FROM ubuntu:18.04

ARG USER
ARG UID

# Set noninteractive for apt-get install and a user
ENV DEBIAN_FRONTEND noninteractive

# In root, install dependencies and set up local user
USER root

# Use bash as the default
SHELL ["/bin/bash", "-c"]

# add the arm64 source
RUN ls /etc/apt/
RUN cat /etc/apt/sources.list
COPY patch/sources.list /etc/apt/ 
RUN dpkg --add-architecture arm64

# TODO: there might be unnecessary packages.
RUN apt-get update && apt-get install -y \
            ack \ 
            alien \ 
            android-tools-adb \ 
            android-tools-fastboot \ 
            apt-transport-https \ 
            autoconf \ 
            automake \ 
            bc \ 
            bison \ 
            build-essential \ 
            clang \
            cmake \ 
            cpio \ 
            cscope \ 
            curl \ 
            device-tree-compiler \ 
            expect \ 
            flex \ 
            ftp-upload \ 
            g++-multilib \ 
            gdb \ 
            gdisk \ 
            git \ 
            iasl \ 
            keychain \
            kmod \ 
            libaio-dev \ 
            libattr1-dev \ 
            libbluetooth-dev \ 
            libboost-all-dev \ 
            libbrlapi-dev \ 
            libc6-dev \ 
            libc6-dev-i386 \ 
            libcap-dev \ 
            libclang-dev \
            libcurl4-openssl-dev \ 
            libfdt-dev \ 
            libftdi-dev \ 
            libglib2.0-dev \ 
            libhidapi-dev \ 
            libjsoncpp-dev \ 
            liblog4cpp5-dev \ 
            libncurses5-dev \ 
            libpixman-1-dev \ 
            libprotobuf-c0-dev \ 
            libprotobuf-dev \ 
            libsqlite3-dev \ 
            libsqlite3-dev:arm64 \
            libssl-dev \ 
            libssl-dev \ 
            libsystemd-dev \ 
            libtool \ 
            libxml2-dev \ 
            llvm-dev \
            make \ 
            mtools \ 
            netcat \ 
            patch \ 
            pkg-config \ 
            protobuf-c-compiler \ 
            protobuf-compiler \ 
            python \ 
            python-crypto \ 
            python-pip \ 
            python-serial \ 
            python-wand \ 
            python3-pip \ 
            python3-pyelftools \ 
            repo \
            rsync \ 
            screen \ 
            sqlite3 \ 
            sudo \ 
            systemd \ 
            systemd-sysv \ 
            unzip \ 
            uuid-dev \ 
            wget \ 
            xdg-utils \ 
            xterm \ 
            xxd \ 
            xz-utils \ 
            zlib1g-dev 

RUN pip install pycryptodome
RUN pip3 install pycryptodome

# add a user
RUN if [ "$USER" != "root" ] ; then useradd -u $UID -m -p deadbeef -s /bin/bash $USER ; fi

# Work around "Unsupported platform - neither systemctl nor initctl is found" raised by sgx psw
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
    && rm libsgx-enclave-common-dev_2.5.101.50123-bionic1_amd64.deb 

# Install PSW debug symbols
RUN wget https://download.01.org/intel-sgx/linux-2.5/ubuntu18.04-server/libsgx-enclave-common-dbgsym_2.5.101.50123-bionic1_amd64.ddeb \
    && dpkg -i libsgx-enclave-common-dbgsym_2.5.101.50123-bionic1_amd64.ddeb \
    && rm libsgx-enclave-common-dbgsym_2.5.101.50123-bionic1_amd64.ddeb 

## fetch and build the SDK
WORKDIR /work
RUN wget https://download.01.org/intel-sgx/sgx-linux/2.9.1/distro/ubuntu18.04-server/sgx_linux_x64_sdk_2.9.101.2.bin \
    && chmod a+x ./sgx_linux_x64_sdk_2.9.101.2.bin \
    && echo "yes" | ./sgx_linux_x64_sdk_2.9.101.2.bin \
    && rm sgx_linux_x64_sdk_2.9.101.2.bin \
# add into path
    && source /work/sgxsdk/environment \
    && cat /work/sgxsdk/environment >> /etc/profile 

# Install protocol buffer 
USER root
WORKDIR /work
RUN git clone --depth 1 --recurse-submodules -b master https://github.com/protocolbuffers/protobuf.git -b v3.12.4 \
    && cd protobuf \
    && ./autogen.sh \
    && ./configure \
    && make -j 4 \
    && make check \
    && make install \
# refresh shared library cache.
    && ldconfig \
    && cd .. \
    && rm -rf protobuf
#RUN git submodule update --init --recursive
#WORKDIR /work/protobuf

RUN chown -R $USER /work

# Install Rust
USER $USER
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
# Install the dependencies for rust,
# seting up for cross-compiling for aarch64 and trustzone
RUN if [ "$USER" != "root" ] ; then . /home/$USER/.cargo/env ; else . /root/.cargo/env; fi \
    && rustup component add rust-src \
    && cargo install xargo --force \
    && cargo install diesel_cli --no-default-features --features sqlite

# Fetch and install trustzone optee
USER $USER
WORKDIR /work
RUN git clone --depth 1 --branch veracruz https://github.com/veracruz-project/rust-optee-trustzone-sdk.git \
    && cd rust-optee-trustzone-sdk \ 
    && git submodule update --init \
    && cd rust/compiler-builtins \
    && git submodule update --init libm \
    && cd ../rust \
    && git submodule update --init src/stdarch src/llvm-project 

# These two patches surprise debug 
COPY patch/bget.c /work/rust-optee-trustzone-sdk/optee/optee_os/lib/libutils/isoc/
COPY patch/mempool.c /work/rust-optee-trustzone-sdk/optee/optee_os/lib/libutils/ext/
# Install the optee
WORKDIR /work/rust-optee-trustzone-sdk
RUN make toolchains
RUN make -j 12 optee \
    && source environment 

USER $USER
# Install qemu toolchains and openssl
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build

USER root
RUN chown -R $USER /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0
USER $USER
RUN mkdir /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0 -p \
    && cd /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0 \
    && repo init -q -u https://github.com/veracruz-project/OPTEE-manifest.git -m qemu_v8.xml -b veracruz  \
# Use the updated repo, as suggested.
# repo sync, we only sync the current branch with ``-c'' flag.
    && .repo/repo/repo sync -c --no-tags --no-clone-bundle \
    && cd /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build \
## Fetch openssl and remove the tar
    && wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2s.tar.gz \
    && tar -xvf openssl-1.0.2s.tar.gz \
    && rm openssl-1.0.2s.tar.gz

# patch optee qemu
COPY patch/platform_def.h /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/trusted-firmware-a/plat/qemu/include/
COPY patch/conf.mk /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/plat-vexpress/
COPY patch/core_mmu_lpae.c /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/mm/
COPY patch/build_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/
COPY patch/environment /work/rust-optee-trustzone-sdk/
COPY patch/qemu_v8.mk /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/
# NOTE: this two patches are no longer copied in, instead, moved to the repo directly
#COPY patch/rem_pio2_large.rs /work/rust-optee-trustzone-sdk/rust/compiler-builtins/libm/src/math/
#COPY patch/mod.rs /work/rust-optee-trustzone-sdk/rust/rust/src/libcore/slice/
COPY patch/pgt_cache.h /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/include/mm/
COPY patch/***REMOVED*** /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/qemu/hw/arm/

RUN make -j4 toolchains

# Install openssl for compiling trustzone
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/openssl-1.0.2s
RUN ./Configure -fPIC linux-aarch64 \
    && make -j 12 CC=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/toolchains/aarch64/bin/aarch64-linux-gnu-gcc \
    && mkdir lib/ \
    && cp libssl.a lib/ \
    && cp libcrypto.a lib/ 

# Install qemu: set up the environments and then run
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/
RUN mkdir -p out/ \
    && mkdir -p out/bin \
    && export ROOT=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/ \
    && export OPENSSL_DIR=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/openssl-1.0.2s/ \
    && export CC=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/toolchains/aarch64/bin/aarch64-linux-gnu-gcc \
    && export PATH=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/toolchains/aarch64/bin:$PATH 
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build
RUN make QEMU_VIRTFS_ENABLE=y CFG_TEE_RAM_VA_SIZE=0x00300000 -j 12

# set back the work dir 
WORKDIR /work
COPY start_aesm.sh .

RUN echo "set print array on\nset print pretty on\n\ndefine optee\n\thandle SIGTRAP noprint nostop pass\n\tsymbol-file /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/out/arm/core/tee.elf\n\ttarget remote localhost:1234\nend\ndocument optee\n\tLoads and setup the binary (tee.elf) for OP-TEE and also connects to the QEMU\nremote.\n end" > ~/.gdbinit
COPY build_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build
COPY run_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build

#################### ENV #####################
USER $USER
# explictly specify the sgx libraries path and mbed-crypto path
ENV C_INCLUDE_PATH /work/sgxsdk/include

# set the cross-compiling binary path
ENV CC_aarch64_unknown_optee_trustzone /work/rust-optee-trustzone-sdk/optee/toolchains/aarch64/bin/aarch64-linux-gnu-gcc

# Set rust environment. Note that the user might be root for the image used by CI.
ENV PATH /home/$USER/.cargo/bin:/root/.cargo/bin:$PATH

USER root
RUN chown -R $USER /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/build_optee.sh \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/run_optee.sh \
                   /work/rust-optee-trustzone-sdk/environment \ 
                   /work/rust-optee-trustzone-sdk/optee/optee_os/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/trusted-firmware-a/

# NOTE: The image used in CI should run start_aesm.sh in the gitlab-ci script.
# Otherwise the gitlab runner may complaint.
USER root
ENTRYPOINT ["bash", "start_aesm.sh"]
