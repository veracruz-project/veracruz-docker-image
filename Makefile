VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= ..
USER ?= $(shell id -un)
UID ?= $(shell id -u)
OS_NAME := $(shell uname -s | tr A-Z a-z)
AWS_NITRO_CLI_REVISION = v1.1.0

ifeq ($(OS_NAME),darwin)
LOCALIP = $(shell "(ifconfig en0 ; ifconfig en1) | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}'")
else
LOCALIP = $(shell ip -4 address show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
endif

ifeq ($(shell uname -m),aarch64)
ARCH = aarch64
else
ARCH = x86_64
endif

BUILD_ARCH = --build-arg ARCH=$(ARCH)

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
nitro-run: nitro-base
	# This container must be started on a "Nitro Enclave"-capable AWS instance
	docker run --privileged -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/usr/local/cargo/registry/ \
		-v /usr/bin:/host/bin -v /usr/share/nitro_enclaves:/usr/share/nitro_enclaves -v /run/nitro_enclaves:/run/nitro_enclaves \
		-v /etc/nitro_enclaves:/etc/nitro_enclaves --device=/dev/vsock:/dev/vsock --device=/dev/nitro_enclaves:/dev/nitro_enclaves \
		-v /var/run/docker.sock:/var/run/docker.sock --env TABASCO_IP_ADDRESS=$(LOCALIP) -p $(LOCALIP):3010:3010/tcp \
		--name $(VERACRUZ_CONTAINER)_nitro_$(USER) $(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) sleep inf

.PHONY:
nitro-run-build: nitro-base
	# This container does not need to be run in AWS it can build but not start enclaves
	docker run --privileged -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/usr/local/cargo/registry/ \
	-v /var/run/docker.sock:/var/run/docker.sock --env TABASCO_IP_ADDRESS=$(LOCALIP) -p $(LOCALIP):3010:3010/tcp \
	--name $(VERACRUZ_CONTAINER)_nitro_$(USER) $(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) sleep inf

.PHONY:
nitro-exec:
	docker exec -u root -i -t $(VERACRUZ_CONTAINER)_nitro_$(USER) /bin/bash

.PHONY:
build: Dockerfile
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) --build-arg USER=$(USER) --build-arg UID=$(UID) --build-arg TEE=$(TEE) -t $(VERACRUZ_DOCKER_IMAGE)_$(TEE):$(USER) -f $< .

.PHONY:
base: base/Dockerfile
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) -t veracruz/base -f $< .

.PHONY:
nitro-base: nitro/Dockerfile base
ifeq (,$(wildcard aws-nitro-enclaves-cli))
	git clone https://github.com/aws/aws-nitro-enclaves-cli.git
endif
	cd "aws-nitro-enclaves-cli" && git checkout $(AWS_NITRO_CLI_REVISION)
	perl -i -pe 's/readlink -f/realpath/' aws-nitro-enclaves-cli/Makefile # Work-around to build on Mac
	make -C aws-nitro-enclaves-cli nitro-cli
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) --build-arg USER=root --build-arg UID=0 --build-arg TEE=nitro -t $(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) -f $< .

.PHONY:
all-base: base nitro-base
	echo 'All base docker images re-built from scratch'

.PHONY:
ci-base: ci/Dockerfile
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) --build-arg USER=root --build-arg UID=0 --build-arg TEE=ci -t veracruz/ci -f $< .

.PHONY:
linux-base: linux/Dockerfile base
	DOCKER_BUILDKIT=1 docker build $(BUILD_ARCH) --build-arg -t $(VERACRUZ_DOCKER_IMAGE)_linux -f $< .

.PHONY:
pull-base:
	docker pull veracruz/base
	docker pull veracruz/linux
	docker pull veracruz/nitro
