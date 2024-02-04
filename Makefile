SPARROW_VERSION := 1.8.2
SPARROW_DEBVERSION := 1.8.2-1
SPARROW_PGP_SIG := E94618334C674B40

PKG_ID := $(shell yq e ".id" manifest.yaml)
PKG_VERSION := $(shell yq e ".version" manifest.yaml)
TS_FILES := $(shell find ./ -name \*.ts)
ROOT_FILES := $(shell find ./root)

.DELETE_ON_ERROR:

all: verify

arm:
	@rm -f docker-images/x86_64.tar
	@ARCH=aarch64 $(MAKE)

x86:
	@rm -f docker-images/aarch64.tar
	@ARCH=x86_64 $(MAKE)

verify: $(PKG_ID).s9pk
	@start-sdk verify s9pk $(PKG_ID).s9pk
	@echo " Done!"
	@echo "   Filesize: $(shell du -h $(PKG_ID).s9pk) is ready"

install:
ifeq (,$(wildcard ~/.embassy/config.yaml))
	@echo; echo "You must define \"host: http://server-name.local\" in ~/.embassy/config.yaml config file first"; echo
else
	start-cli package install $(PKG_ID).s9pk
endif

clean:
	rm -rf docker-images
	rm -f $(PKG_ID).s9pk
	rm -f scripts/*.js

scripts/embassy.js: $(TS_FILES)
	deno bundle scripts/embassy.ts scripts/embassy.js

docker-images/aarch64.tar: Dockerfile.aarch64 docker_entrypoint.sh $(ROOT_FILES)
ifeq ($(ARCH),x86_64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) \
		--build-arg ARCH=aarch64 \
		--build-arg PLATFORM=arm64 \
		--build-arg SPARROW_VERSION=$(SPARROW_VERSION) \
		--build-arg SPARROW_DEBVERSION=$(SPARROW_DEBVERSION) \
		--build-arg SPARROW_PGP_SIG=$(SPARROW_PGP_SIG) \
		--platform=linux/arm64 -o type=docker,dest=docker-images/aarch64.tar -f Dockerfile.aarch64 .
endif

docker-images/x86_64.tar: Dockerfile docker_entrypoint.sh $(ROOT_FILES)
ifeq ($(ARCH),aarch64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) \
		--build-arg ARCH=x86_64 \
		--build-arg PLATFORM=amd64 \
		--build-arg SPARROW_VERSION=$(SPARROW_VERSION) \
		--build-arg SPARROW_DEBVERSION=$(SPARROW_DEBVERSION) \
		--build-arg SPARROW_PGP_SIG=$(SPARROW_PGP_SIG) \
		--platform=linux/amd64 -o type=docker,dest=docker-images/x86_64.tar .
endif

$(PKG_ID).s9pk: manifest.yaml instructions.md icon.png LICENSE scripts/embassy.js docker-images/aarch64.tar docker-images/x86_64.tar
ifeq ($(ARCH),aarch64)
	@echo "start-sdk: Preparing aarch64 package ..."
else ifeq ($(ARCH),x86_64)
	@echo "start-sdk: Preparing x86_64 package ..."
else
	@echo "start-sdk: Preparing Universal Package ..."
endif
	@start-sdk pack
