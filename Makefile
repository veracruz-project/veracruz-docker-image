VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= ..
USER ?= $(shell id -un)
UID ?= $(shell id -u)
OS_NAME := $(shell uname -s | tr A-Z a-z)
AWS_NITRO_CLI_REVISION = v1.1.0

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

# Check if the CI image is good enough locally.
.PHONY:
ci-run:
	docker run --rm --privileged -u $(UID) -d \
		-v /work/cache:/cache \
		-v $(abspath $(VERACRUZ_ROOT)):/work/veracruz \
		--name $(VERACRUZ_CONTAINER)_ci_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_ci:$(USER) sleep inf

.PHONY:
ci-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_ci_$(USER) /bin/bash

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
	docker exec -i -t $(VERACRUZ_CONTAINER)_nitro_$(USER) /bin/bash

.PHONY:
linux-run: linux-build
	docker run --privileged -d $(DOCKER_RUN_PARAMS) \
		--name $(VERACRUZ_CONTAINER)_linux_$(USER) \
		$(VERACRUZ_DOCKER_IMAGE)_linux:$(USER) sleep inf

.PHONY:
linux-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_linux_$(USER) /bin/bash

.PHONY:
%-build: Dockerfile %-base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) \
		--build-arg USER=$(USER) --build-arg UID=$(UID) --build-arg TEE=$* \
		--build-arg DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) \
		-t $(VERACRUZ_DOCKER_IMAGE)_$*:$(USER) -f $< .

.PHONY:
base: base/Dockerfile
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/base -f $< .

.PHONY:
linux-base: linux/Dockerfile base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/linux -f $< .

.PHONY:
nitro-base: nitro/Dockerfile base
ifeq (,$(wildcard aws-nitro-enclaves-cli))
	git clone https://github.com/aws/aws-nitro-enclaves-cli.git
endif
	cd "aws-nitro-enclaves-cli" && git fetch && git checkout $(AWS_NITRO_CLI_REVISION)
	perl -i -pe 's/readlink -f/realpath/' aws-nitro-enclaves-cli/Makefile # Work-around to build on Mac
	make -C aws-nitro-enclaves-cli nitro-cli
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/nitro -f $< .

.PHONY:
ci-base: ci/Dockerfile
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) --build-arg USER=root --build-arg UID=0 --build-arg TEE=ci -t veracruz/ci -f $< .

.PHONY:
all-base: base linux-base nitro-base
	echo 'All base docker images re-built from scratch'

.PHONY:
pull-base:
	docker pull veracruz/base
	docker pull veracruz/linux
	docker pull veracruz/nitro
