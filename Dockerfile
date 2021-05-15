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
ENV DEBIAN_FRONTEND noninteractive

# If you want to use a local cache, you should bind in a local cache directory to /cache
ENV XARGO_HOME=/cache/xargo \
    SCCACHE_DIR=/cache/sccache \
    SCCACHE_CACHE_SIZE=10G \
    PATH=/cache/cargo/bin:$PATH \
    RUST_VERSION=1.48.0

# Use bash as the default
SHELL ["/bin/bash", "-c"]

# add a user
    RUN \
        mkdir -p /work; \
        if [ "$USER" != "root" ] ; then useradd -u $UID -m -p `openssl rand -base64 32` -s /bin/bash $USER ; fi; \
        chown -R $USER /work;chown -Rf $USER /usr/local/rustup;chown -Rf $USER /usr/local/cargo

# Link the user's toolchain to the global toolchain directory
USER $USER
RUN if [ "$USER" != "root" ] ; then mkdir /home/$USER/.rustup; fi;
WORKDIR /home/$USER/.rustup/
RUN ln -s /usr/local/rustup/toolchains

USER root
WORKDIR /
RUN chown -R $USER /work
WORKDIR /work
USER $USER
