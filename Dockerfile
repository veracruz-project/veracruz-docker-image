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
ARG TEE

FROM ubuntu:18.04 AS build_sgx

ARG USER
ARG UID
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
    libcurl4-openssl-dev libprotobuf-dev python cmake git libsqlite3-dev \ 
    libssl-dev build-essential libtool libclang-dev llvm-dev \
    wget make curl unzip ca-certificates autoconf automake clang xxd python python-crypto python-pip pkg-config sqlite3; \ 
    pip install pycryptodome; \
    apt-get autoremove -y && apt-get clean; \
    rm -rf /tmp/* /var/tmp/*; \
# Work around "Unsupported platform - neither systemctl nor initctl is found" raised by sgx psw
    mkdir /etc/init -p

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
    if [ "$USER" != "root" ] ; then useradd -u $UID -m -p deadbeef -s /bin/bash $USER ; fi; \
    chown -R $USER /work
# explictly specify the sgx libraries path and mbed-crypto path
ENV C_INCLUDE_PATH /work/sgxsdk/include

ARG protobuf_version=3.12.4
ARG protobuf_dir=/usr/local/protobuf
ARG protobuf_temp=/tmp/protobuf.zip
ENV PATH "${protobuf_dir}/bin:${PATH}"
RUN curl --location https://github.com/protocolbuffers/protobuf/releases/download/v${protobuf_version}/protoc-${protobuf_version}-linux-x86_64.zip > ${protobuf_temp} \
    && unzip ${protobuf_temp} -d ${protobuf_dir} \
    && rm ${protobuf_temp} \
    && chmod --recursive a+rwx ${protobuf_dir}

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.48.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        wget \
        ; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='49c96f3f74be82f4752b8bffcf81961dea5e6e94ce1ccba94435f12e871c3bdb' ;; \
        armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='5a2be2919319e8778698fa9998002d1ec720efe7cb4f6ee4affb006b5e73f1be' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='d93ef6f91dab8299f46eef26a56c2d97c66271cea60bf004f2f088a86a697078' ;; \
        i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='e3d0ae3cfce5c6941f74fed61ca83e53d4cd2deb431b906cbd0687f246efede4' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.22.1/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup component add rust-src; \
    cargo install xargo --force; \
    cargo install diesel_cli --no-default-features --features sqlite; \
    chown -R $USER $RUSTUP_HOME; \
    chown -R $USER $CARGO_HOME; 

# Link the user's toolchain to the global toolchain directory
USER $USER
RUN if [ "$USER" != "root" ] ; then mkdir /home/$USER/.rustup; fi;
WORKDIR /home/$USER/.rustup/
RUN ln -s /usr/local/rustup/toolchains

#TZ
FROM build_sgx AS build_tz_base

ARG USER
ARG UID
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]

# add the arm64 source
COPY patch/sources.list /etc/apt/ 
COPY cleanup.sh /cleanup.sh
RUN dpkg --add-architecture arm64

RUN apt-get update && apt-get install --no-install-recommends -y \
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
            python3 \
            python3-pip \ 
            python3-pyelftools \ 
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
            zlib1g-dev; \
    apt-get autoremove -y && apt-get clean; \
    rm -rf /tmp/* /var/tmp/*; \
    pip install pycryptodome; \
    pip3 install pycryptodome; \
    # Use the latest version of repo
    curl https://storage.googleapis.com/git-repo-downloads/repo > /bin/repo; \
    chmod a+x /bin/repo;
# Add a user
# Since build_tz_base use build_sgx, the following is commented out. However, we keep the record in case it is needed in the future.
    #if [ "$USER" != "root" ] ; then useradd -u $UID -m -p deadbeef -s /bin/bash $USER ; fi

# Fetch and install trustzone optee
WORKDIR /work
RUN chown -R $USER /work
USER $USER
RUN git clone --depth 1 --branch veracruz https://github.com/veracruz-project/rust-optee-trustzone-sdk.git \
    && cd rust-optee-trustzone-sdk \ 
    && git submodule update --init \
# remove unnecessary submodule    
    && rm -rf rust

# These two patches surprise debug 
COPY patch/bget.c /work/rust-optee-trustzone-sdk/optee/optee_os/lib/libutils/isoc/
COPY patch/mempool.c /work/rust-optee-trustzone-sdk/optee/optee_os/lib/libutils/ext/

FROM build_tz_base AS build_optee
# Install the optee
WORKDIR /work/rust-optee-trustzone-sdk
RUN make toolchains; \
    make -j 12 optee; \
    source environment;

FROM build_tz_base AS build_qemu 
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
    && repo sync -c --no-tags --no-clone-bundle \
    && cd /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build \
## Fetch openssl and remove the tar
    && wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2s.tar.gz \
    && tar -xvf openssl-1.0.2s.tar.gz \
    && rm openssl-1.0.2s.tar.gz

# patch optee qemu
COPY patch/platform_def.h /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/trusted-firmware-a/plat/qemu/include/
COPY patch/conf.mk /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/plat-vexpress/
COPY patch/core_mmu_lpae.c /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/mm/
COPY patch/build_optee.sh patch/qemu_v8.mk /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/
COPY patch/environment /work/rust-optee-trustzone-sdk/
COPY patch/pgt_cache.h /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/include/mm/
COPY patch/***REMOVED*** /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/qemu/hw/arm/

RUN make -j4 toolchains

FROM build_qemu AS build_tz
WORKDIR /work/rust-optee-trustzone-sdk/optee
COPY --from=build_optee /work/rust-optee-trustzone-sdk/optee .
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
RUN echo "set print array on\nset print pretty on\n\ndefine optee\n\thandle SIGTRAP noprint nostop pass\n\tsymbol-file /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/out/arm/core/tee.elf\n\ttarget remote localhost:1234\nend\ndocument optee\n\tLoads and setup the binary (tee.elf) for OP-TEE and also connects to the QEMU\nremote.\n end" > ~/.gdbinit
COPY build_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build
COPY run_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build

USER $USER
# set the cross-compiling binary path
ENV CC_aarch64_unknown_optee_trustzone /work/rust-optee-trustzone-sdk/optee/toolchains/aarch64/bin/aarch64-linux-gnu-gcc

USER root
RUN chown -R $USER /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/build_optee.sh \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/run_optee.sh \
                   /work/rust-optee-trustzone-sdk/environment \ 
                   /work/rust-optee-trustzone-sdk/optee/optee_os/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/trusted-firmware-a/
WORKDIR /
RUN ./cleanup.sh

FROM build_${TEE} as final

WORKDIR /work
COPY --chown=$USER start_aesm.sh .
# NOTE: The image used in CI should run start_aesm.sh in the gitlab-ci script.
# Otherwise the gitlab runner may complaint.
ENTRYPOINT ["bash", "start_aesm.sh"]
