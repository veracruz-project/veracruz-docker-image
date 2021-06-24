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

FROM veracruz/tz-base:latest AS build_qemu 
ARG USER=root
ARG UID=0
ENV DEBIAN_FRONTEND noninteractive
# Use bash as the default
SHELL ["/bin/bash", "-c"]
USER root
# Install qemu toolchains and openssl
RUN mkdir /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build -p
RUN chown -R $USER /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0
USER $USER
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0
RUN repo init -q -u https://github.com/veracruz-project/OPTEE-manifest.git -m qemu_v8.xml -b veracruz \
# Use the updated repo, as suggested.
# repo sync, we only sync the current branch with ``-c'' flag.
    && repo sync -c --no-tags --no-clone-bundle \
    && cd /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build \
## Fetch openssl and remove the tar
    && wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2s.tar.gz \
    && tar -xvf openssl-1.0.2s.tar.gz \
    && rm openssl-1.0.2s.tar.gz

# patch optee qemu
COPY patch/platform_def.h /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/trusted-firmware-a/plat/qemu/include/
COPY patch/conf.mk /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/plat-vexpress/
COPY patch/core_mmu_lpae.c /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/mm/
COPY patch/build_optee.sh patch/qemu_v8.mk /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/
COPY patch/environment /work/rust-optee-trustzone-sdk/
COPY patch/pgt_cache.h /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/core/arch/arm/include/mm/

WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build

WORKDIR /work/rust-optee-trustzone-sdk/optee
# COPY --from=build_optee /work/rust-optee-trustzone-sdk/optee .
# Install openssl for compiling trustzone
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/openssl-1.0.2s
RUN ./Configure -fPIC linux-aarch64 \
    && make -j`nproc` CC=/work/rust-optee-trustzone-sdk/optee/toolchains/aarch64/bin/aarch64-linux-gnu-gcc \
    && mkdir lib/ \
    && cp libssl.a lib/ \
    && cp libcrypto.a lib/ 

# Install qemu: set up the environments and then run
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/
RUN mkdir -p out/ \
    && mkdir -p out/bin \
    && export ROOT=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/ \
    && export OPENSSL_DIR=/work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/openssl-1.0.2s/ \
    && export CC=/work/rust-optee-trustzone-sdk/optee/toolchains/aarch64/bin/aarch64-linux-gnu-gcc \
    && export PATH=/work/rust-optee-trustzone-sdk/optee/toolchains/aarch64/bin:$PATH 
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/qemu
COPY patch/virt-secure-mem.patch /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/qemu
RUN patch -p1 < virt-secure-mem.patch
WORKDIR /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build
RUN sed -i 's/%TOP_DIR%\/toolchains/\/work\/rust-optee-trustzone-sdk\/optee\/toolchains/g' br-ext/configs/toolchain-aarch*
RUN sed -i 's/BR2_TOOLCHAIN_EXTERNAL_HEADERS_4_19=y/BR2_TOOLCHAIN_EXTERNAL_HEADERS_4_18=y/g' br-ext/configs/toolchain-aarch64
RUN make QEMU_VIRTFS_ENABLE=y CFG_TEE_RAM_VA_SIZE=0x00300000 -j`nproc` TOOLCHAIN_ROOT=/work/rust-optee-trustzone-sdk/optee/toolchains all

# set back the work dir 
WORKDIR /work
RUN echo "set print array on\nset print pretty on\n\ndefine optee\n\thandle SIGTRAP noprint nostop pass\n\tsymbol-file /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/out/arm/core/tee.elf\n\ttarget remote localhost:1234\nend\ndocument optee\n\tLoads and setup the binary (tee.elf) for OP-TEE and also connects to the QEMU\nremote.\n end" > ~/.gdbinit
COPY build_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build
COPY run_optee.sh /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build

USER $USER
# set the cross-compiling binary path
ENV CC_aarch64_unknown_optee_trustzone /work/rust-optee-trustzone-sdk/optee/toolchains/aarch64/bin/aarch64-linux-gnu-gcc

USER root
RUN chown -R $USER /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/build_optee.sh \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/run_optee.sh \
                   /work/rust-optee-trustzone-sdk/environment \ 
                   /work/rust-optee-trustzone-sdk/optee/optee_os/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/optee_os/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/ \
                   /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/trusted-firmware-a/
WORKDIR /
COPY cleanup.sh /cleanup.sh
RUN ./cleanup.sh
WORKDIR /work

FROM veracruz/tz-base as final
COPY --from=build_qemu /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/out-br/images/* /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/outbr/images/
COPY --from=build_qemu /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/out/bin/* /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/out/bin/
COPY --from=build_qemu /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/qemu/aarch64-softmmu/qemu-* /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/qemu/aarch64-softmmu/
COPY --from=build_qemu /work/rust-optee-trustzone-sdk/environment /work/rust-optee-trustzone-sdk/environment
COPY --from=build_qemu /work/rust-optee-trustzone-sdk/optee-qemuv8-3.7.0/build/openssl-1.0.2s/lib/* /usr/lib/aarch64-linux-gnu 

WORKDIR /work
