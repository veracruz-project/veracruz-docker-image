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
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y \
    python-setuptools \
    python3-setuptools \
    python3 \
    python3-pip \
    musl-tools \
    ca-certificates \
    curl \
    lxc \
    iptables \
    jq \
    iproute2 \
    apt-transport-https \
    gnupg \
    lsb-release \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb https://download.docker.com/linux/ubuntu bionic stable"
RUN apt-get update && apt-get install --no-install-recommends -y docker-ce-cli

COPY aws-nitro-enclaves-cli/build/nitro_cli/${ARCH}-unknown-linux-musl/release/nitro-cli /usr/bin/

RUN pip install -U setuptools && \
    pip install awscli

WORKDIR /work/
RUN wget https://github.com/openssl/openssl/archive/OpenSSL_1_1_1f.tar.gz && \
    tar zxvf OpenSSL_1_1_1f.tar.gz &&\
    cd openssl-OpenSSL_1_1_1f && \
    CC="musl-gcc -fPIE -pie -static -idirafter /usr/include/ -idirafter /usr/include/${ARCH}-linux-gnu/" ./Configure no-shared no-async --prefix=/work/veracruz-nitro-root-enclave/musl --openssldir=/work/veracruz/nitro-root-enclave/musl/ssl linux-${ARCH} -DOPENSSL_NO_SECURE_MEMORY && \
    make -j 2

ENV AARCH64_UNKNOWN_LINUX_MUSL_OPENSSL_LIB_DIR=/work/openssl-OpenSSL_1_1_1f/
ENV X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_LIB_DIR=/work/openssl-OpenSSL_1_1_1f/
ENV AARCH64_UNKNOWN_LINUX_MUSL_OPENSSL_INCLUDE_DIR=/work/openssl-OpenSSL_1_1_1f/include/
ENV X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_INCLUDE_DIR=/work/openssl-OpenSSL_1_1_1f/include/

RUN mkdir -p /var/log/nitro_enclaves/
RUN touch /var/log/nitro_enclaves/nitro_enclaves.log

RUN mkdir -p /usr/share/nitro_enclaves/blobs/
COPY aws-nitro-enclaves-cli/blobs/${ARCH}/* /usr/share/nitro_enclaves/blobs

# Define additional metadata for our image.
VOLUME /var/lib/docker
# Nitro

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip" \
	&& unzip awscliv2.zip \
	&& ./aws/install

RUN rustup target add ${ARCH}-unknown-linux-musl
