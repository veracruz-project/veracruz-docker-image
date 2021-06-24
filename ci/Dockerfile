# docker image for CI.
# It combines TZ and SGX.
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

# import the tz image
FROM veracruz/tz:latest as tz

# use sgx as based and copy in the tz artifact
FROM veracruz/sgx:latest as final
COPY --from=tz / /

WORKDIR /work
