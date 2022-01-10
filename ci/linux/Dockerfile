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
ARG USER=root
ARG UID=0

FROM veracruz/base:latest as final

RUN apt update && \
    apt install --no-install-recommends -y software-properties-common && \
    add-apt-repository -y ppa:git-core/ppa && \
    apt update && \
    apt install --no-install-recommends -y git && \
    apt remove -y software-properties-common && \
    apt autoremove -y && apt clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

WORKDIR /work
