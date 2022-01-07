# docker image for CI.
# It currently uses nitro image (which is a superset of linux image).
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
ARG TEE=ci

ARG USER=root
ARG UID=0

FROM veracruz/nitro:latest as final

ARG ICECAP_REV

COPY icecap/install-nix.sh .
COPY icecap/ci/nix.conf /etc/nix/
COPY icecap/ci/populate populate/

ENV PATH="/nix/env/bin:${PATH}" \
    MANPATH="/nix/env/share/man:${MANPATH}" \
    NIX_SSL_CERT_FILE=/nix/env/etc/ssl/certs/ca-bundle.crt \
    NIX_BUILD_SHELL=bash

RUN \
    mkdir -m 0755 /nix ; \
    groupadd -r nixbld && useradd -rMN -g nixbld -G nixbld -d /var/empty -s /bin/false nixbld ; \
    bash install-nix.sh ; \
    rm install-nix.sh ; \
    ICECAP_REV=${ICECAP_REV} bash populate/run.sh ; \
    rm -r populate ; \
    rm -rf /root/.cache/nix ; \
    chgrp -R nixbld /nix ; \
    chmod -R g+rw /nix

RUN add-apt-repository ppa:git-core/ppa && \
    apt update && \
    apt install -y git

WORKDIR /work
