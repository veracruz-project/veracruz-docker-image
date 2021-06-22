VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= ..
USER ?= $(shell id -un)
UID ?= $(shell id -u)
IP := $(firstword $(shell ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $1}' ))
OS_NAME := $(shell uname -s | tr A-Z a-z)
LOCALIP=$(shell ip -4 address show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

.PHONY:
# Assume an linux machine with sgx enable
sgx-run:
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif
	docker run --rm --privileged --cap-add=ALL -e IAS_TOKEN=${IAS_TOKEN} -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --device /dev/isgx --device /dev/mei0 --name $(VERACRUZ_CONTAINER)_sgx_$(USER) $(VERACRUZ_DOCKER_IMAGE)_sgx:$(USER) /bin/bash /work/start_aesm.sh

# This is a container for development, which allows compilation.
.PHONY:
sgx-dev:
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif
	docker run --rm --privileged --cap-add=ALL -e IAS_TOKEN=${IAS_TOKEN} -v /lib/modules:/lib/modules -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --name  $(VERACRUZ_CONTAINER)_sgx_$(USER) $(VERACRUZ_DOCKER_IMAGE)_sgx:$(USER) /bin/bash /work/start_aesm.sh

.PHONY:
sgx-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_sgx_$(USER) /bin/bash

# This macos is used for run test on trustzone either on MacOS or Linux. Please install XQuartz on MacOS or xhost on Linux. 
.PHONY:
tz-run:
	docker run --rm --privileged -u $(UID) -d -v /work/cache:/cache -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --name  $(VERACRUZ_CONTAINER)_tz_$(USER) $(VERACRUZ_DOCKER_IMAGE)_tz:$(USER) sleep inf

.PHONY:
tz-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_tz_$(USER) /bin/bash

# Check if the CI image is good enough locally.
.PHONY:
ci-run:
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif
	docker run --rm --privileged -u $(UID) -d -v /work/cache:/cache -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz  --device /dev/isgx --device /dev/mei0 --name $(VERACRUZ_CONTAINER)_ci_$(USER) $(VERACRUZ_DOCKER_IMAGE)_ci:$(USER) /bin/bash /work/start_aesm.sh

.PHONY:
ci-exec:
	docker exec -i -t $(VERACRUZ_CONTAINER)_ci_$(USER) /bin/bash

.PHONY:
nitro-run: nitro-base
	docker run --privileged -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/usr/local/cargo/registry/ -v /usr/bin:/host/bin -v /usr/share/nitro_enclaves:/usr/share/nitro_enclaves -v /run/nitro_enclaves:/run/nitro_enclaves -v /etc/nitro_enclaves:/etc/nitro_enclaves --device=/dev/vsock:/dev/vsock -v /var/run/docker.sock:/var/run/docker.sock --device=/dev/nitro_enclaves:/dev/nitro_enclaves --env TABASCO_IP_ADDRESS=$(LOCALIP) -p $(LOCALIP):3010:3010/tcp --name $(VERACRUZ_CONTAINER)_nitro_$(USER) $(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) sleep inf

.PHONY:
nitro-exec:
	docker exec -u root -i -t $(VERACRUZ_CONTAINER)_nitro_$(USER) /bin/bash

.PHONY:
build: Dockerfile
	DOCKER_BUILDKIT=1 docker build --build-arg USER=$(USER) --build-arg UID=$(UID) --build-arg TEE=$(TEE) -t $(VERACRUZ_DOCKER_IMAGE)_$(TEE):$(USER) -f $< .

.PHONY:
base: base/Dockerfile
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 -t veracruz/base -f $< .

.PHONY:
sgx-base: sgx/Dockerfile base
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 --build-arg TEE=sgx -t $(VERACRUZ_DOCKER_IMAGE)_sgx:$(USER) -f $< .

.PHONY:
tz-base: tz/Dockerfile base
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 --build-arg TEE=tz -t veracruz/tz-base -f $< .

.PHONY:
nitro-base: nitro/Dockerfile base
ifneq (,$(wildcard aws-nitro-enclaves-cli))
	cd "aws-nitro-enclaves-cli"
	git pull origin main
else
	git clone https://github.com/aws/aws-nitro-enclaves-cli.git
endif
	make -C aws-nitro-enclaves-cli nitro-cli
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 --build-arg TEE=nitro -t $(VERACRUZ_DOCKER_IMAGE)_nitro:$(USER) -f $< .


.PHONY:
qemu-base: qemu/Dockerfile
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 --build-arg TEE=tz -t veracruz/tz -f $< .

.PHONY:
all-base: base sgx-base tz-base qemu-base
	echo 'All base docker images re-built from scratch'

.PHONY:
ci-base: ci/Dockerfile
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 --build-arg TEE=ci -t veracruz/ci -f $< .

.PHONY:
pull-base:
	docker pull veracruz/sgx
	docker pull veracruz/tz
