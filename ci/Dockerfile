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

WORKDIR /work
