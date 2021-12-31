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

ARG ARCH=x86_64
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]

# SUPPLY_CHAIN_NOTE: apt-get update means we always get latest, but also doesn't fix versions

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
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
        procps \
        python \
        python-crypto \
        python-pip \
        python-setuptools \
        rsync \
        sqlite3 \
        unzip \
        uuid-dev \
        wget \
        xxd \
        zlib1g-dev && \
    pip install -U setuptools pip && \
    pip install pycryptodome && \
    pip cache purge && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

    # update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1
    # update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

ARG protobuf_version=3.12.4
ARG protobuf_dir=/usr/local/protobuf
ENV PATH "${protobuf_dir}/bin:${PATH}"
RUN protobuf_url=https://github.com/protocolbuffers/protobuf/releases/download ; \
    if [ ${ARCH} = aarch64 ] ; then p_arch=aarch_64 ; else p_arch=${ARCH} ; fi ; \
    protobuf_temp=/tmp/protobuf-${p_arch}.zip ; \
    curl -o ${protobuf_temp} -L ${protobuf_url}/v${protobuf_version}/protoc-${protobuf_version}-linux-${p_arch}.zip \
    && unzip ${protobuf_temp} -d ${protobuf_dir} \
    && rm ${protobuf_temp} \
    && chmod --recursive a+rwx ${protobuf_dir}

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.56.1

RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='3dc5ef50861ee18657f9db2eeb7392f9c2a6c95c90ab41e45ab4ca71476b4338' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='32a1532f7cef072a667bac53f1a5542c99666c4071af0c9549795bbdb2069ec1' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.24.3/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    rustup target add wasm32-wasi ; \
    cargo install diesel_cli --no-default-features --features sqlite ; \
    rm -rf /usr/local/cargo/registry/*/github.com-* ; \
    chmod -R a+rw ${CARGO_HOME} ${RUSTUP_HOME} ; \
    find ${RUSTUP_HOME} ${CARGO_HOME} -type d | xargs -n 1000 chmod a+x
