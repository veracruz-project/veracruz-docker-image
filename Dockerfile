# docker image for developing and testing Veracruz.
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
ARG TEE

FROM veracruz/${TEE}:latest
ARG USER=root
ARG UID=0
ARG DOCKER_GROUP_ID=0
ENV DEBIAN_FRONTEND noninteractive

# If you want to use a local cache, you should bind in a local cache directory to /cache
ENV XARGO_HOME=/cache/xargo \
    SCCACHE_DIR=/cache/sccache \
    SCCACHE_CACHE_SIZE=10G \
    PATH=/cache/cargo/bin:$PATH

# Use bash as the default
SHELL ["/bin/bash", "-c"]

# add a user
RUN \
    mkdir -p /work; \
    if [ "$USER" != "root" ] ; then \
        useradd -u $UID -m -p `openssl rand -base64 32` -s /bin/bash $USER ; \
        mkdir /home/$USER/.rustup ; \
        ln -s /usr/local/rustup/toolchains /home/$USER/.rustup/ ; \
        if [ "$DOCKER_GROUP_ID" != "0" ] ; then \
            groupadd -g ${DOCKER_GROUP_ID} docker ; \
            usermod -a -G docker $USER ; \
        fi ; \
        if getent group nixbld &>/dev/null ; then \
            usermod -a -G nixbld $USER ; \
        fi ; \
    fi

WORKDIR /work/veracruz
USER $USER
