# docker image for developing and testing Veracruz on TrustZone
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
ARG TEE=tz

FROM veracruz/base:latest

ARG USER=root
ARG UID=0
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]
USER root
# add the arm64 source
COPY patch/sources.list /etc/apt/ 
RUN dpkg --add-architecture arm64

RUN apt-get update && apt-get install --no-install-recommends -y \
            ack \ 
            alien \ 
            android-tools-adb \ 
            android-tools-fastboot \ 
            apt-transport-https \ 
            bison \ 
            cpio \ 
            cscope \ 
            device-tree-compiler \ 
            expect \ 
            flex \ 
            ftp-upload \ 
            g++-multilib \ 
            gdb \ 
            gdisk \ 
            iasl \ 
            keychain \
            kmod \ 
            libaio-dev \ 
            libattr1-dev \ 
            libbluetooth-dev \ 
            libboost-all-dev \ 
            libbrlapi-dev \ 
            libc6-dev \ 
            libc6-dev-i386 \ 
            libcap-dev \ 
            libfdt-dev \ 
            libftdi-dev \ 
            libglib2.0-dev \ 
            libhidapi-dev \ 
            libjsoncpp-dev \ 
            liblog4cpp5-dev \ 
            libncurses5-dev \ 
            libpixman-1-dev \ 
            libprotobuf-c0-dev \ 
            libsqlite3-dev:arm64 \
            libssl-dev:arm64 \
            libsystemd-dev \ 
            libxml2-dev \ 
            mtools \ 
            netcat \ 
            patch \ 
            pkg-config \ 
            protobuf-c-compiler \ 
            protobuf-compiler \ 
            python-serial \ 
            python-wand \ 
            python3 \
            python3-pip \ 
            python3-pyelftools \ 
            rsync \ 
            screen \ 
            sudo \ 
            systemd \ 
            systemd-sysv \ 
            uuid-dev \ 
            xdg-utils \ 
            xterm \ 
            xz-utils \ 
            zlib1g-dev; \
    apt-get autoremove -y && apt-get clean; \
    rm -rf /tmp/* /var/tmp/*; \
    pip3 install pycryptodome; \
    # Use the latest version of repo
    curl https://storage.googleapis.com/git-repo-downloads/repo > /bin/repo; \
    chmod a+x /bin/repo;
# Add a user
RUN if [ "$USER" != "root" ] ; then useradd -u $UID -m -p deadbeef -s /bin/bash $USER ; fi

# Fetch and install trustzone optee
WORKDIR /work
RUN chown -R $USER /work
USER $USER
RUN git clone --depth 1 --branch veracruz https://github.com/veracruz-project/rust-optee-trustzone-sdk.git \
    && cd rust-optee-trustzone-sdk \ 
    && git rm -rf rust \
    && git submodule update --init; \
    rm -rf rust-optee-trustzone-sdk/.git; \
    rm -rf rust-optee-trustzone-sdk/*/.git;

# These two patches surprise debug 
COPY patch/bget.c /work/rust-optee-trustzone-sdk/optee/optee_os/lib/libutils/isoc/
COPY patch/mempool.c /work/rust-optee-trustzone-sdk/optee/optee_os/lib/libutils/ext/

# Install the optee
WORKDIR /work/rust-optee-trustzone-sdk
RUN make toolchains; \
    rm -f /work/rust-optee-trustzone-sdk/optee/toolchains/*.tar.xz; \
    cd optee/toolchains; find . -type f \( -perm -0100 \) -print | xargs -rl strip -s 2> /dev/null;cd ../..;

RUN make -j`nproc` optee; \
    source environment;

WORKDIR /work
