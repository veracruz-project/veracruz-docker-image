VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= ..
USER := $(shell id -un)
UID := $(shell id -u)
IP := $(firstword $(shell ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $1}' ))
OS_NAME := $(shell uname -s | tr A-Z a-z)

NIX_ROOT ?= ../icecap/nix-root

.PHONY:
# Assume an linux machine with sgx enable
run: build
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif

	docker run --privileged --cap-add=ALL -e IAS_TOKEN=${IAS_TOKEN} -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --device /dev/isgx --device /dev/mei0 --name $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)_sgx


sgx: run

# This is a container for development, which allows compilation.
.PHONY:
development: build
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif

	docker run --privileged --cap-add=ALL -e IAS_TOKEN=${IAS_TOKEN} -v /lib/modules:/lib/modules -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --name  $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)_sgx


# This macos is used for run test on trustzone either on MacOS or Linux. Please install XQuartz on MacOS or xhost on Linux. 
.PHONY:
tz: build
ifeq ($(OS_NAME),darwin)
	docker run --privileged -e DISPLAY=$(IP):0 -d -v /tmp/.X11-unix:/tmp/.X11-unix -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --name  $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)_tz
else # otherwise linux
	docker run --privileged -e DISPLAY=${DISPLAY} -d -v /tmp/.X11-unix:/tmp/.X11-unix -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz --name  $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)_tz
endif

.PHONY:
icecap: build
	mkdir -p $(NIX_ROOT)
	docker run --privileged -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(abspath $(NIX_ROOT)):/nix --name $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)_icecap

.PHONY:
build: Dockerfile
	DOCKER_BUILDKIT=1 docker build --squash --build-arg USER=$(USER) --build-arg UID=$(UID) --build-arg TEE=$(TEE) -t $(VERACRUZ_DOCKER_IMAGE)_$(TEE) -f $< .

.PHONY:
ci: Dockerfile.ci
	DOCKER_BUILDKIT=1 docker build --squash --build-arg USER=root --build-arg UID=0 --build-arg TEE=sgx -t $(VERACRUZ_DOCKER_IMAGE)_sgx -f $<  .
	DOCKER_BUILDKIT=1 docker build --squash --build-arg USER=root --build-arg UID=0 --build-arg TEE=tz -t $(VERACRUZ_DOCKER_IMAGE)_tz -f $<  .

Dockerfile.ci: Dockerfile
	sed '/ENTRYPOINT/d' $< | tee $@
