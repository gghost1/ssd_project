# Rediscovering Heartbleed with libFuzzer

## 1. Executive summary

This project reproduces **CVE-2014-0160 (Heartbleed)** by fuzzing **OpenSSL 1.0.1f** with **libFuzzer** and **AddressSanitizer** inside Docker. The target crashes with a heap out-of-bounds read in `tls1_process_heartbeat`, matching the known vulnerability class and code path.

## 2. Background

Heartbleed affected OpenSSL heartbeat processing in the TLS and DTLS implementations. A malicious peer could claim a large heartbeat payload length while sending only a tiny message. OpenSSL trusted the advertised length and copied extra bytes from process memory into the reply buffer.

Affected range:

- OpenSSL `1.0.1` through `1.0.1f`
- Fixed in `1.0.1g`

Impact:

- Private key leakage
- Session data leakage
- User credential leakage
- Cross-request memory disclosure

## 3. Why libFuzzer

`libFuzzer` was chosen because it is:

- in-process, so iteration speed is high
- bundled with modern clang
- easy to combine with AddressSanitizer
- good for parser / protocol state machines with a small custom harness

Compared with AFL++, setup is smaller for this project because the instrumentation, executor, and minimization flow are already integrated into clang.

## 4. Setup

Environment:

- Docker
- Ubuntu 22.04
- clang
- OpenSSL `1.0.1f`
- AddressSanitizer

Build flow:

1. Download `openssl-1.0.1f.tar.gz`
2. Build static OpenSSL libraries with `-fsanitize=address,fuzzer-no-link`
3. Compile a custom harness with `-fsanitize=address,fuzzer`
4. Run the fuzzer on a small TLS heartbeat-oriented corpus

Main build command:

```bash
clang++ -g -O1 -std=c++17 -fsanitize=address,fuzzer \
  -Iopenssl-1.0.1f/include \
  fuzz/heartbleed_fuzz.cc \
  openssl-1.0.1f/libssl.a openssl-1.0.1f/libcrypto.a \
  -ldl -lpthread -o build/heartbleed_fuzz
```

## 5. Harness design

The harness creates a TLS server context, loads a test certificate and key, feeds arbitrary bytes into an in-memory BIO, and lets OpenSSL parse them during handshake / record processing.

High-level logic:

1. `LLVMFuzzerInitialize` stores the executable directory
2. `Environment` initializes OpenSSL and loads `server.pem` + `server.key`
3. `LLVMFuzzerTestOneInput`:
   - creates a fresh `SSL*`
   - attaches memory BIOs
   - writes fuzz input into the inbound BIO
   - calls `SSL_do_handshake`
   - drains records with `SSL_read`

This structure is enough to reach `tls1_process_heartbeat` when a mutated input becomes a heartbeat record after or during handshake parsing.

## 6. Corpus and dictionary

The project uses two starter seeds:

- a minimal heartbeat-like TLS record
- a larger ClientHello-style record

The dictionary includes useful protocol bytes:

- heartbeat content type `0x18`
- TLS versions `0x0301`, `0x0302`, `0x0303`
- generic handshake prefix `0x16 0x03`

This reduces time-to-crash compared with a totally empty corpus.

## 7. Fuzzing run

Run command:

```bash
make docker-fuzz
```

Observed result:

- libFuzzer starts from the generated corpus
- mutations quickly reach malformed heartbeat messages
- AddressSanitizer reports `heap-buffer-overflow`
- stack trace reaches `tls1_process_heartbeat` in `ssl/t1_lib.c:2586`
- crash artifact is persisted to `artifacts/`

Observed run details from a verified execution:

- `829` executed inputs before crash
- peak RSS about `86 MB`
- saved artifact: `artifacts/crash-5ad3eb0e25edc75a2f72f4962dc655c709fb1ba9`
- replay with `make docker-reproduce` reproduces the same ASan failure

The fuzzing command exits non-zero by design because ASan aborts the process after detecting the bug.

## 8. Crash analysis

Vulnerable logic lives in `ssl/t1_lib.c` in `tls1_process_heartbeat`. The record payload length from the packet is trusted without verifying that the full payload is actually present in the received record buffer.

Simplified vulnerable pattern:

```c
hbtype = *p++;
n2s(p, payload);
pl = p;
buffer = OPENSSL_malloc(1 + 2 + payload + padding);
memcpy(bp, pl, payload);
```

If `payload` is much larger than the real remaining bytes, the `memcpy` reads beyond the received record and leaks heap memory.

In the verified run, the crash mapped to:

- `tls1_process_heartbeat`
- a read overflow near `memcpy`
- OpenSSL heartbeat handling code in `ssl/t1_lib.c`
- harness entry at `LLVMFuzzerTestOneInput`

## 9. Patch reference

OpenSSL fixed the issue in commit `96db9023b881d7cd9f379b0c154650d6c108e9a3`.

The fix adds bounds checks before copying the claimed heartbeat payload:

- validate that the record contains the heartbeat header
- validate that `1 + 2 + payload + 16 <= record_length`
- silently discard malformed heartbeat messages as required by RFC 6520

## 10. Lessons learned

- Small harnesses can expose protocol bugs quickly.
- Sanitizers make memory disclosure bugs visible even when the original issue is a read, not a write.
- Seed corpora and dictionaries matter for protocol formats.
- Docker improves grading reproducibility.

## References

1. CVE-2014-0160 advisory
2. OpenSSL security advisory dated 2014-04-07
3. OpenSSL fix commit `96db9023b881d7cd9f379b0c154650d6c108e9a3`
4. Google ClusterFuzz Heartbleed example
