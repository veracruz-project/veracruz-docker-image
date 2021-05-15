# base docker image for developing and testing Veracruz
#
# This builds a common Ubuntu base image with the right pre-installed tools
# to build custom versions of tools, install rust, and build veracruz itself
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

ARG USER=root
ARG UID=0
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]

# SUPPLY_CHAIN_NOTE: apt-get update means we always get latest, but also doesn't fix versions

RUN apt-get update && apt-get install --no-install-recommends -y \
    autoconf \
    automake \
    bc \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    curl \
    git \
    libaio-dev \ 
    libbluetooth-dev \ 
    libcap-dev \     
    libclang-dev \
    libcurl4-openssl-dev \
    libfdt-dev \ 
    libglib2.0-dev \ 
    libpixman-1-dev \
    libprotobuf-dev \
    libsqlite3-dev \ 
    libssl-dev \
    libtool \
    llvm-dev \
    make \
    pkg-config \
    python \
    python \
    python-crypto \
    python-pip \
    sqlite3 \ 
    unzip \
    uuid-dev \
    wget \
    xxd \
    zlib1g-dev; \
    pip install pycryptodome; \
    apt-get autoremove -y && apt-get clean; \
    rm -rf /tmp/* /var/tmp/*

# add a user
    RUN \
        mkdir -p /work; \
        if [ "$USER" != "root" ] ; then useradd -u $UID -m -p `openssl rand -base64 32` -s /bin/bash $USER ; fi; \
        chown -R $USER /work

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
    RUST_VERSION=1.48.0 \
    USER=${USER}

RUN set -eux; \
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
    chown -R ${USER} $RUSTUP_HOME; \
    chown -R ${USER} $CARGO_HOME; 