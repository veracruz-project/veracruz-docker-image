VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= ..
USER ?= $(shell id -un)
UID ?= $(shell id -u)
OS_NAME := $(shell uname -s | tr A-Z a-z)
AWS_NITRO_CLI_REVISION = v1.1.0
NIX_VOLUME = veracruz-icecap-nix-root

ifeq ($(OS_NAME),darwin)
LOCALIP = $(shell "(ifconfig en0 ; ifconfig en1) | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}'")
DOCKER_GROUP_ID=$(shell stat -f "%g" $(shell realpath /var/run/docker.sock))
else
LOCALIP = $(shell ip -4 address show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
DOCKER_GROUP_ID=$(shell stat --format "%g" $(shell realpath /var/run/docker.sock))
endif

ifeq ($(shell uname -m),aarch64)
ARCH = aarch64
else
ARCH = x86_64
endif

BUILD_ARCH = --build-arg ARCH=$(ARCH)

DOCKER_RUN_PARAMS = \
		-v $(abspath $(VERACRUZ_ROOT)):/work/veracruz \
		-v $(HOME)/.cargo/registry/:/usr/local/cargo/registry/

.PHONY:
default:


#####################################################################
# Shared targets

.PHONY:
base: base/Dockerfile
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/base -f $< .

.PHONY:
%-build: Dockerfile %-base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) \
		--build-arg USER=$(USER) --build-arg UID=$(UID) --build-arg TEE=$* \
		--build-arg DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) \
		-t $(VERACRUZ_DOCKER_IMAGE)_$*:$(USER) -f $< .

.PHONY:
all-base: base linux-base nitro-base
	echo 'All base docker images re-built from scratch'

.PHONY:
pull-base:
	docker pull veracruz/base
	docker pull veracruz/linux
	docker pull veracruz/nitro

#####################################################################
# CI-related targets
#
.PHONY:
ci-run: ci-build
	docker run --privileged --rm -d \
		-v /work/cache:/cache \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(abspath $(VERACRUZ_ROOT)):/work/veracruz \
		--name $(VERACRUZ_CONTAINER)_ci_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_ci:$(USER) sleep inf

.PHONY:
ci-exec:
	docker exec -u root -i -t $(VERACRUZ_CONTAINER)_ci_$(USER) /bin/bash || true

.PHONY:
ci-base: ci/Dockerfile nitro-base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) \
		--build-arg USER=root --build-arg UID=0 \
		--build-arg ICECAP_REV=$(shell GIT_DIR=../icecap/icecap/.git git rev-parse HEAD) \
		--build-arg TEE=ci -t veracruz/ci -f $< .

# "local" is similar to "ci" but uses "icecap/hacking" with local volume
# to cache nix store.
.PHONY:
localci-run: localci-build icecap-initialize-volume
	docker run --privileged --rm -d $(DOCKER_RUN_PARAMS) \
		-v /work/cache:/cache \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--mount type=volume,src=$(NIX_VOLUME),dst=/nix \
		--name $(VERACRUZ_CONTAINER)_localci_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_localci:$(USER) sleep inf

.PHONY:
localci-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_localci_$(USER) /bin/bash || true

.PHONY:
localci-base: localci/Dockerfile nitro-base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) \
		--build-arg TEE=ci -t veracruz/localci -f $< .


#####################################################################
# IceCap-related targets

.PHONY:
icecap-initialize-volume: icecap-build
	if [ -z "$$(docker volume ls -q -f "name=$(NIX_VOLUME)")" ]; then \
		docker volume create --label $(VERACRUZ_CONTAINER)_icecap_$(USER) \
			$(NIX_VOLUME) && \
		docker run --privileged --rm -u root --label $(VERACRUZ_CONTAINER)_icecap_$(USER) \
			-w /work --mount type=volume,src=$(NIX_VOLUME),dst=/nix \
			$(VERACRUZ_DOCKER_IMAGE)_icecap:$(USER) flock /nix/.installed.lock bash /work/setup.sh $(USER); \
	fi

.PHONY:
icecap-run: icecap-build icecap-initialize-volume
	docker run --privileged -d $(DOCKER_RUN_PARAMS) \
		--mount type=volume,src=$(NIX_VOLUME),dst=/nix \
		--name $(VERACRUZ_CONTAINER)_icecap_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_icecap:$(USER) sleep inf

.PHONY:
icecap-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_icecap_$(USER) /bin/bash || true

.PHONY:
icecap-base: icecap/hacking/Dockerfile base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/icecap -f $< .

.PHONY: icecap-clean
icecap-clean:
	for volume in $$(docker volume ls -q -f "name=$(NIX_VOLUME)"); do \
		docker volume rm $$volume; \
	done

#####################################################################
# Linux-related targets

.PHONY:
linux-run: linux-build
	docker run --privileged -d $(DOCKER_RUN_PARAMS) \
		--name $(VERACRUZ_CONTAINER)_linux_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_linux:$(USER) sleep inf

.PHONY:
linux-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_linux_$(USER) /bin/bash || true

.PHONY:
linux-base: linux/Dockerfile base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/linux -f $< .


#####################################################################
# Nitro-related targets

.PHONY:
nitro-run: nitro-build
	# This container must be started on a "Nitro Enclave"-capable AWS instance
	docker run --privileged -d $(DOCKER_RUN_PARAMS) \
		-v /usr/bin:/host/bin \
		-v /usr/share/nitro_enclaves:/usr/share/nitro_enclaves \
		-v /run/nitro_enclaves:/run/nitro_enclaves \
		-v /etc/nitro_enclaves:/etc/nitro_enclaves \
		--device=/dev/vsock:/dev/vsock \
		--device=/dev/nitro_enclaves:/dev/nitro_enclaves \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--env TABASCO_IP_ADDRESS=$(LOCALIP) -p $(LOCALIP):3010:3010/tcp \
		--name $(VERACRUZ_CONTAINER)_nitro_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) sleep inf

.PHONY:
nitro-run-build: nitro-build
	# This container does not need to be run in AWS, it can build but not start enclaves
	docker run --privileged -d $(DOCKER_RUN_PARAMS) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--env TABASCO_IP_ADDRESS=$(LOCALIP) -p $(LOCALIP):3010:3010/tcp \
		--name $(VERACRUZ_CONTAINER)_nitro_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) sleep inf

.PHONY:
nitro-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_nitro_$(USER) /bin/bash || true

.PHONY:
nitro-base: nitro/Dockerfile base
ifeq (,$(wildcard aws-nitro-enclaves-cli))
	git clone https://github.com/aws/aws-nitro-enclaves-cli.git
endif
	cd "aws-nitro-enclaves-cli" && git checkout $(AWS_NITRO_CLI_REVISION) || \
		(git fetch ; git checkout $(AWS_NITRO_CLI_REVISION))
	perl -i -pe 's/readlink -f/realpath/' aws-nitro-enclaves-cli/Makefile # Work-around to build on Mac
	make -C aws-nitro-enclaves-cli nitro-cli
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/nitro -f $< .
