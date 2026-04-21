IMAGE ?= heartbleed-fuzz
DOCKER_PLATFORM ?=
ARTIFACTS_DIR ?= $(PWD)/artifacts
DOCKER_BUILD = docker build $(DOCKER_PLATFORM) -t $(IMAGE) .
DOCKER_RUN = docker run --rm $(DOCKER_PLATFORM) $(IMAGE)
DOCKER_RUN_ARTIFACTS = docker run --rm $(DOCKER_PLATFORM) -v "$(ARTIFACTS_DIR):/artifacts" -e FUZZ_CRASH_DIR=/artifacts $(IMAGE)

OPENSSL_DIR := openssl-1.0.1f
BUILD_DIR := build
FUZZER := $(BUILD_DIR)/heartbleed_fuzz
CORPUS_DIR := fuzz/corpus
DICT := fuzz/heartbleed.dict
CRASH_DIR := fuzz/crashes

.PHONY: build openssl fuzz-build fuzz reproduce docker-fuzz docker-reproduce clean shell

build:
	$(DOCKER_BUILD)

openssl:
	./scripts/build_openssl.sh

fuzz-build: $(FUZZER)

$(FUZZER): fuzz/heartbleed_fuzz.cc fuzz/server.pem fuzz/server.key $(OPENSSL_DIR)/libssl.a $(OPENSSL_DIR)/libcrypto.a
	mkdir -p $(BUILD_DIR) $(CRASH_DIR)
	python3 scripts/generate_corpus.py
	clang++ -g -O1 -std=c++17 \
		-fsanitize=address,fuzzer \
		-I$(OPENSSL_DIR)/include \
		fuzz/heartbleed_fuzz.cc \
		$(OPENSSL_DIR)/libssl.a \
		$(OPENSSL_DIR)/libcrypto.a \
		-ldl -lpthread -o $(FUZZER)
	cp fuzz/server.pem $(BUILD_DIR)/server.pem
	cp fuzz/server.key $(BUILD_DIR)/server.key

fuzz: fuzz-build
	./scripts/run_fuzz.sh

reproduce: fuzz-build
	./scripts/reproduce.sh

docker-fuzz: build
	mkdir -p "$(ARTIFACTS_DIR)"
	$(DOCKER_RUN_ARTIFACTS) make fuzz

docker-reproduce: build
	mkdir -p "$(ARTIFACTS_DIR)"
	$(DOCKER_RUN_ARTIFACTS) make reproduce

shell:
	$(DOCKER_RUN) /bin/bash

clean:
	rm -rf $(BUILD_DIR) $(OPENSSL_DIR) openssl-1.0.1f.tar.gz
