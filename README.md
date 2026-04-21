# Heartbleed fuzzing project

Rediscover **CVE-2014-0160 (Heartbleed)** by fuzzing **OpenSSL 1.0.1f** with **libFuzzer** and **AddressSanitizer** in Docker.

## Contents

- `fuzz/heartbleed_fuzz.cc` - fuzz target
- `scripts/build_openssl.sh` - vulnerable OpenSSL build
- `scripts/run_fuzz.sh` - fuzzing launcher
- `scripts/reproduce.sh` - deterministic replay
- `report/report.md` - report source
- `slides/slides.md` - presentation source
- `demo/demo.md` - video/demo script

## Quick start

```bash
make docker-fuzz
```

The command ends with a non-zero status on success because ASan aborts after the crash is found.

Replay the first saved crash:

```bash
make docker-reproduce
```

Crash artifacts are stored in host `artifacts/`.

## Local run without Docker

Docker is the recommended path. Local execution requires a clang toolchain that ships the libFuzzer runtime.

```bash
chmod +x scripts/*.sh
./scripts/build_openssl.sh
make fuzz-build
make fuzz
```

## Apple Silicon note

If Docker uses ARM by default, build and run with:

```bash
make build DOCKER_PLATFORM=--platform=linux/amd64
make docker-fuzz DOCKER_PLATFORM=--platform=linux/amd64
```

## Deliverables

- report source: `report/report.md`
- slides source: `slides/slides.md`
- demo script: `demo/demo.md`
- source code: this project directory can be zipped or pushed to a public repository

## Expected result

The fuzzer should trigger an `AddressSanitizer: heap-buffer-overflow` in the OpenSSL heartbeat parser, consistent with Heartbleed.

Verified run:

- crash in `tls1_process_heartbeat`
- persisted artifact in `artifacts/crash-5ad3eb0e25edc75a2f72f4962dc655c709fb1ba9`
- deterministic replay with `make docker-reproduce`

## References

- OpenSSL archive: <https://www.openssl.org/source/old/1.0.1/>
- ClusterFuzz Heartbleed example: <https://google.github.io/clusterfuzz/setting-up-fuzzing/heartbleed-example/>
- Fix commit: <https://github.com/openssl/openssl/commit/96db9023b881d7cd9f379b0c154650d6c108e9a3>
