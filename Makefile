VERACRUZ_DOCKER_IMAGE ?= veracruz_image
VERACRUZ_CONTAINER ?= veracruz
VERACRUZ_ROOT ?= ..
USER ?= $(shell id -un)
UID ?= $(shell id -u)
IP := $(firstword $(shell ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $1}' ))
OS_NAME := $(shell uname -s | tr A-Z a-z)
LOCALIP=$(shell ip -4 address show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
#AWS_NITRO_CLI_REVISION = dff9102783959412dcf5d515e641c2c3ad0d443b
AWS_NITRO_CLI_REVISION = main

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
nitro-container-image/created: nitro-container-image/Dockerfile ../proxy-attestation-server/target/debug/proxy-attestation-server ../veracruz-server/target/debug/veracruz-server ../veracruz-client/target/debug/veracruz-client ../runtime-manager/runtime_manager.eif ../test-collateral/proxy-attestation-server.db ../runtime-manager/PCR0
	CONTAINERID=$(shell docker create veracruz_image_nitro:$(USER)); \
        docker cp $$CONTAINERID:/usr/bin/nitro-cli nitro-container-image; \
        docker rm $$CONTAINERID
	cp -u ../proxy-attestation-server/target/debug/proxy-attestation-server ../veracruz-server/target/debug/veracruz-server ../veracruz-client/target/debug/veracruz-client ../runtime-manager/runtime_manager.eif ../test-collateral/proxy-attestation-server.db nitro-container-image 
	cut -c 1-64 < ../runtime-manager/PCR0 > nitro-container-image/hash
	DOCKER_BUILDKIT=1 docker build --build-arg USER=root --build-arg UID=0 --build-arg TEE=nitro -t veracruz_container_nitro:$(USER)  -f $< .
	touch nitro-container-image/created

.PHONY:
nitro-container-image: nitro-container-image/created

.PHONY:
nitro-container-image-run: nitro-container-image
	docker run --rm -d --device=/dev/vsock:/dev/vsock --device=/dev/nitro_enclaves:/dev/nitro_enclaves -p $(LOCALIP):3010:3010/tcp --name veracruz_container_nitro_$(USER) veracruz_container_nitro:$(USER) sleep inf

.PHONY:
nitro-container-image-exec:
	docker exec -u root -i -t veracruz_container_nitro_$(USER) /bin/bash

.PHONY:
nitro-container-image-run-server: nitro-container-image ../test-collateral/dual_policy.json
	sed -e 's/^\(.*proxy_attestation_server_url.*\)127.0.0.1\(.*\)$$/\1veracruz_container_nitro_proxy_$(USER)\2/' \
		-e 's/^\(.*veracruz_server_url.*\)127.0.0.1\(.*\)$$/\1veracruz_container_nitro_server_$(USER)\2/' \
		../test-collateral/dual_policy.json > dual_policy.json
	docker run --rm -d \
		-v ${PWD}/dual_policy.json:/work/veracruz-server-policy/dual_policy.json \
		-v /run/nitro_enclaves:/run/nitro_enclaves \
		-v /var/log/nitro_enclaves:/var/log/nitro_enclaves \
		--device=/dev/vsock:/dev/vsock \
		--device=/dev/nitro_enclaves:/dev/nitro_enclaves \
		--name veracruz_container_nitro_server_$(USER) \
		--hostname veracruz_container_nitro_server_$(USER)\
		--add-host="veracruz_container_nitro_proxy_$(USER):$(shell docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' veracruz_container_nitro_proxy_$(USER))"  \
		veracruz_container_nitro:$(USER) \
		/work/veracruz-server/veracruz-server /work/veracruz-server-policy/dual_policy.json

.PHONY:
nitro-container-image-run-server-exec: 
	docker exec -u root -i -t veracruz_container_nitro_server_$(USER) /bin/bash

.PHONY:
nitro-container-image-run-proxy: nitro-container-image ../test-collateral/CACert.pem ..//test-collateral/CAKey.pem
	docker run --rm -d \
		-v ${PWD}/../test-collateral/CAKey.pem:/work/proxy-config-files/CAKey.pem \
		-v ${PWD}/../test-collateral/CACert.pem:/work/proxy-config-files/CACert.pem \
		--name veracruz_container_nitro_proxy_$(USER) \
		--hostname veracruz_container_nitro_proxy_$(USER)\
		veracruz_container_nitro:$(USER) \
		/work/proxy-attestation-server/proxy-attestation-server 0.0.0.0:3010 --ca-cert /work/proxy-config-files/CACert.pem --ca-key /work/proxy-config-files/CAKey.pem --database-url /work/proxy-attestation-server/proxy-attestation-server.db

.PHONY:
nitro-container-image-run-proxy-exec: 
	docker exec -u root -i -t veracruz_container_nitro_proxy_$(USER) /bin/bash

.PHONY:
nitro-container-image-run-client: nitro-container-image ../test-collateral/dual_policy.json ../test-collateral/client_rsa_key.pem ../test-collateral/client_rsa_cert.pem ../test-collateral/data_client_key.pem ../test-collateral/data_client_cert.pem ../test-collateral/expired_key.pem ../test-collateral/expired_cert.pem ../test-collateral/never_used_key.pem ../test-collateral/never_used_cert.pem ../test-collateral/program_client_key.pem ../test-collateral/program_client_cert.pem ../test-collateral/result_client_key.pem ../test-collateral/result_client_cert.pem ../test-collateral/server_rsa_key.pem ../test-collateral/server_rsa_cert.pem ../test-collateral/linear-regression.wasm ../test-collateral/linear-regression.dat
	sed -e 's/^\(.*proxy_attestation_server_url.*\)127.0.0.1\(.*\)$$/\1veracruz_container_nitro_proxy_$(USER)\2/' \
		-e 's/^\(.*veracruz_server_url.*\)127.0.0.1\(.*\)$$/\1veracruz_container_nitro_server_$(USER)\2/' \
		../test-collateral/dual_policy.json > dual_policy.json
	echo "#!/bin/bash\n" \
		"../veracruz-client/veracruz-client dual_policy.json -p linear-regression.wasm  --identity program_client_cert.pem --key program_client_key.pem\n" \
		"../veracruz-client/veracruz-client dual_policy.json --data input-0=linear-regression.dat --identity data_client_cert.pem --key data_client_key.pem\n" \
   		"../veracruz-client/veracruz-client dual_policy.json --results linear-regression.wasm=output --identity data_client_cert.pem --key data_client_key.pem\n" > execute-veracruz-client.sh
	chmod u+x execute-veracruz-client.sh
	docker run --rm -d \
		-v ${PWD}/execute-veracruz-client.sh:/work/veracruz-server-policy/execute-veracruz-client.sh \
		-v ${PWD}/dual_policy.json:/work/veracruz-server-policy/dual_policy.json \
		-v ${PWD}/../test-collateral/client_rsa_key.pem:/work/veracruz-server-policy/client_rsa_key.pem \
		-v ${PWD}/../test-collateral/data_client_key.pem:/work/veracruz-server-policy/data_client_key.pem \
		-v ${PWD}/../test-collateral/expired_key.pem:/work/veracruz-server-policy/expired_key.pem \
		-v ${PWD}/../test-collateral/never_used_key.pem:/work/veracruz-server-policy/never_used_key.pem \
		-v ${PWD}/../test-collateral/program_client_key.pem:/work/veracruz-server-policy/program_client_key.pem \
		-v ${PWD}/../test-collateral/result_client_key.pem:/work/veracruz-server-policy/result_client_key.pem \
		-v ${PWD}/../test-collateral/server_rsa_key.pem:/work/veracruz-server-policy/server_rsa_key.pem \
		-v ${PWD}/../test-collateral/client_rsa_cert.pem:/work/veracruz-server-policy/client_rsa_cert.pem \
		-v ${PWD}/../test-collateral/data_client_cert.pem:/work/veracruz-server-policy/data_client_cert.pem \
		-v ${PWD}/../test-collateral/expired_cert.pem:/work/veracruz-server-policy/expired_cert.pem \
		-v ${PWD}/../test-collateral/never_used_cert.pem:/work/veracruz-server-policy/never_used_cert.pem \
		-v ${PWD}/../test-collateral/program_client_cert.pem:/work/veracruz-server-policy/program_client_cert.pem \
		-v ${PWD}/../test-collateral/result_client_cert.pem:/work/veracruz-server-policy/result_client_cert.pem \
		-v ${PWD}/../test-collateral/server_rsa_cert.pem:/work/veracruz-server-policy/server_rsa_cert.pem \
		-v ${PWD}/../test-collateral/linear-regression.wasm:/work/veracruz-server-policy/linear-regression.wasm \
		-v ${PWD}/../test-collateral/linear-regression.dat:/work/veracruz-server-policy/linear-regression.dat \
		--name veracruz_container_nitro_client_$(USER) \
		--hostname veracruz_container_nitro_client_$(USER)\
		--add-host="veracruz_container_nitro_server_$(USER):$(shell docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' veracruz_container_nitro_server_$(USER))"  \
		veracruz_container_nitro:$(USER) \
		sleep inf

	#	/work/veracruz-server/veracruz-server /work/veracruz-server-policy/dual_policy.json

.PHONY:
nitro-container-image-run-client-exec: 
	docker exec -u root -i -t veracruz_container_nitro_client_$(USER) /bin/bash

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
ifeq (,$(wildcard aws-nitro-enclaves-cli))
	git clone https://github.com/aws/aws-nitro-enclaves-cli.git
endif
	cd "aws-nitro-enclaves-cli" && git checkout $(AWS_NITRO_CLI_REVISION)
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
