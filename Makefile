VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= $(HOME)/git/veracruz
USER := $(shell id -un)
UID := $(shell id -u)
IP := $(shell ifconfig en0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $1}' )
OS_NAME := $(shell uname -s | tr A-Z a-z)

.PHONY:
# Assume an linux machine with sgx enable
run: build
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif
	docker run --privileged --cap-add=ALL -e IAS_TOKEN=${IAS_TOKEN} -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/home/$$USER/.cargo/registry/ --device /dev/isgx --device /dev/mei0 --name $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)

sgx: run

# This is a container for development, which allows compilation.
.PHONY:
development: build
ifndef IAS_TOKEN
	$(error IAS_TOKEN is not defined)
endif
	docker run --privileged --cap-add=ALL -e IAS_TOKEN=${IAS_TOKEN} -v /lib/modules:/lib/modules -d -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/home/$$USER/.cargo/registry/ --name  $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)

# This macos is used for run test on trustzone either on MacOS or Linux. Please install XQuartz on MacOS or xhost on Linux. 
.PHONY:
tz: build
ifeq ($(OS_NAME),darwin)
	xhost + $(IP)
	docker run --privileged -e DISPLAY=$(IP):0 -d -v /tmp/.X11-unix:/tmp/.X11-unix -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/home/$$USER/.cargo/registry/ --name  $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)
else # otherwise linux
	xhost +local:$(USER)
	docker run --privileged -e DISPLAY=${DISPLAY} -d -v /tmp/.X11-unix:/tmp/.X11-unix -v $(abspath $(VERACRUZ_ROOT)):/work/veracruz -v $(HOME)/.cargo/registry/:/home/$$USER/.cargo/registry/ --name  $(VERACRUZ_CONTAINER) $(VERACRUZ_DOCKER_IMAGE)
endif

.PHONY:
build: Dockerfile
	docker build --build-arg USER=$(USER) --build-arg UID=$(UID) -t $(VERACRUZ_DOCKER_IMAGE) -f $< .

.PHONY:
ci: Dockerfile.ci
	docker build --build-arg USER=root --build-arg UID=0 -t $(VERACRUZ_DOCKER_IMAGE) -f $<  .

Dockerfile.ci: Dockerfile
	sed '/ENTRYPOINT/d' $< | tee $@
