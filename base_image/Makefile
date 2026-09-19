PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
IMAGE := registry.gitlab.com/buildroot.org/buildroot/base:20260708.2311
OUTPUT_VOLUME := nerves-by-hand-output-$(shell printf '%s' "$(PROJECT_DIR)" | cksum | cut -d ' ' -f1)

CONTAINER_RUN = docker run --rm \
	--env HOME=/tmp \
	--volume "$(PROJECT_DIR):/work" \
	--volume "$(OUTPUT_VOLUME):/work/output" \
	--volume "$(PROJECT_DIR)/output:/export" \
	--workdir /work

.PHONY: all build shell clean submodule output-volume

all: build

build: submodule output-volume
	$(CONTAINER_RUN) --user root $(IMAGE) \
		./container-entrypoint.sh ./build-in-container.sh

release: build
	cd .. && tar cfz prebuilt_base_image.tgz base_image/output

shell: submodule output-volume
	$(CONTAINER_RUN) --interactive --tty --user root $(IMAGE) \
		./container-entrypoint.sh /bin/bash

clean:
	rm -rf "$(PROJECT_DIR)/output"
	@if docker volume inspect "$(OUTPUT_VOLUME)" >/dev/null 2>&1; then \
		echo "Deleting Docker volume $(OUTPUT_VOLUME)"; \
		docker volume rm "$(OUTPUT_VOLUME)"; \
	fi

submodule:
	git -C "$(PROJECT_DIR)" submodule update --init --depth 1 buildroot

output-volume:
	@mkdir -p "$(PROJECT_DIR)/output"
	@if ! docker volume inspect "$(OUTPUT_VOLUME)" >/dev/null 2>&1; then \
		echo "Creating Docker volume $(OUTPUT_VOLUME)"; \
		docker volume create "$(OUTPUT_VOLUME)"; \
	fi
