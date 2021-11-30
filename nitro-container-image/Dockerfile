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

FROM ubuntu:18.04

ARG USER=root
ARG UID=0
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y \
    curl && \
    apt-get clean 
#    python-setuptools \
#    python3-setuptools \
#    python3 \
#    python3-pip \
#    musl-tools \
#    ca-certificates \
#    lxc \
#    iptables \
#    jq \
#    iproute2
#
COPY nitro-container-image/nitro-cli /usr/bin/


COPY nitro-container-image/proxy-attestation-server /work/proxy-attestation-server/proxy-attestation-server
COPY nitro-container-image/proxy-attestation-server.db /work/proxy-attestation-server/proxy-attestation-server.db
COPY nitro-container-image/proxy-attestation-server /work/proxy-attestation-server/proxy-attestation-server
COPY nitro-container-image/veracruz-server /work/veracruz-server/veracruz-server
COPY nitro-container-image/veracruz-client /work/veracruz-client/veracruz-client
COPY nitro-container-image/runtime_manager.eif /work/runtime-manager/runtime_manager.eif
COPY nitro-container-image/hash /work/veracruz-client/hash

RUN mkdir /work/proxy-config-files /work/veracruz-server-policy

WORKDIR /work/veracruz-server

ENV IAS_TOKEN="deadbeefdeadbeefdeadbeefeadbeef"

