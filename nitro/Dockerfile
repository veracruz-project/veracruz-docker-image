# docker image for developing and testing Veracruz on AWS Nitro Enclaves
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

FROM veracruz/base:latest
ARG ARCH=x86_64
ARG NE_GID=""
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        apt-transport-https \
        ca-certificates \
        gnupg \
        iproute2 \
        iptables \
        jq \
        lsb-release \
        lxc \
        musl-tools \
        python3 \
        python3-pip \
        python3-setuptools \
        software-properties-common ; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - ; \
    add-apt-repository "deb https://download.docker.com/linux/ubuntu bionic stable" ; \
    apt-get update && apt-get install --no-install-recommends -y docker-ce-cli ; \
    apt-get autoremove -y && apt-get clean ; \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

COPY aws-nitro-enclaves-cli/build/nitro_cli/${ARCH}-unknown-linux-musl/release/nitro-cli /usr/bin/

RUN pip install --no-cache-dir awscli

WORKDIR /work/
RUN wget https://github.com/openssl/openssl/archive/OpenSSL_1_1_1f.tar.gz && \
    tar zxvf OpenSSL_1_1_1f.tar.gz &&\
    cd openssl-OpenSSL_1_1_1f && \
    CC="musl-gcc -fPIE -pie -static -idirafter /usr/include/ -idirafter /usr/include/${ARCH}-linux-gnu/" \
        ./Configure no-shared no-async -DOPENSSL_NO_SECURE_MEMORY \
        --prefix=/work/veracruz-nitro-root-enclave/musl \
        --openssldir=/work/veracruz/nitro-root-enclave/musl/ssl linux-${ARCH} && \
    make -j 2 && \
    make install && \
    cd .. && \
    rm -rf openssl-OpenSSL_1_1_1f

ENV \
    AARCH64_UNKNOWN_LINUX_MUSL_OPENSSL_LIB_DIR=/work/veracruz-nitro-root-enclave/musl/lib \
    X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_LIB_DIR=/work/veracruz-nitro-root-enclave/musl/lib \
    AARCH64_UNKNOWN_LINUX_MUSL_OPENSSL_INCLUDE_DIR=/work/veracruz-nitro-root-enclave/musl/include \
    X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_INCLUDE_DIR=/work/veracruz-nitro-root-enclave/musl/include

RUN mkdir -p /var/log/nitro_enclaves ; \
    touch /var/log/nitro_enclaves/nitro_enclaves.log ; \
    chmod -R a+rw /var/log/nitro_enclaves ; \
    chmod a+x /var/log/nitro_enclaves ; \
    mkdir -p /usr/share/nitro_enclaves/blobs/
COPY aws-nitro-enclaves-cli/blobs/${ARCH}/* /usr/share/nitro_enclaves/blobs

RUN NE_GID=${NE_GID} ; \
    if [ -z "$NE_GID" ] ; then \
    else \
        groupadd -g ${NE_GID} ne ; \
    fi

# Define additional metadata for our image.
VOLUME /var/lib/docker
# Nitro

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip" \
	&& unzip awscliv2.zip \
	&& ./aws/install \
    && rm -rf awscliv2.zip aws

RUN rustup target add ${ARCH}-unknown-linux-musl
