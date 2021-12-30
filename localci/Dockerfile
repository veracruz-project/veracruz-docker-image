# docker image for local CI.
# It currently uses nitro image (which is a superset of linux image) and adds icecap hacking
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

ENV PATH="/nix/env/bin:${PATH}"
ENV MANPATH="/nix/env/share/man:${MANPATH}"
ENV NIX_SSL_CERT_FILE=/nix/env/etc/ssl/certs/ca-bundle.crt
ENV NIX_BUILD_SHELL bash

# HACK for persistent git cache.
ENV XDG_CACHE_HOME=/nix/cache

COPY icecap/install-nix.sh /work
COPY icecap/hacking/setup.sh /work
COPY icecap/hacking/nix.conf /etc/nix/

WORKDIR /work
