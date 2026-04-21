---
marp: true
title: Rediscovering Heartbleed with libFuzzer
paginate: true
---

# Rediscovering Heartbleed with libFuzzer

Secure System Developing project

- Target: `CVE-2014-0160`
- Library: `OpenSSL 1.0.1f`
- Tool: `libFuzzer + ASan`
- Environment: Docker

---

# Problem

Goal:

- deploy a fuzzing tool
- run it on a real target
- rediscover a known CVE
- provide reproducible artifacts

---

# CVE-2014-0160

Heartbleed:

- flaw in TLS heartbeat handling
- attacker controls claimed payload length
- OpenSSL trusts that length
- result: out-of-bounds read and memory disclosure

Fixed in:

- `OpenSSL 1.0.1g`

---

# Why libFuzzer

- built into clang
- fast in-process execution
- easy ASan integration
- small custom harness
- good fit for parser and protocol targets

---

# Test Architecture

```mermaid
flowchart LR
  fuzzer[libFuzzerInput] --> harness[heartbleed_fuzz.cc]
  harness --> bioIn[MemoryBIOIn]
  bioIn --> openssl[OpenSSL1_0_1f]
  openssl --> heartbeat[tls1_process_heartbeat]
  heartbeat --> asan[ASanCrashReport]
```

---

# Harness

Core idea:

- create server-side `SSL*`
- load local test certificate
- feed fuzz bytes through memory BIO
- call `SSL_do_handshake`
- drain records with `SSL_read`

---

# Build

OpenSSL build flags:

```bash
./config no-shared no-asm -fno-omit-frame-pointer -g -O1
make build_libs CC=clang CFLAG="-g -O1 -fsanitize=address,fuzzer-no-link"
```

Harness link:

```bash
clang++ -fsanitize=address,fuzzer ...
```

---

# Corpus Strategy

- seed 1: heartbeat-like TLS record
- seed 2: ClientHello-style record
- dictionary: TLS versions, heartbeat type, handshake prefix

Why:

- reduce search space
- reach heartbeat parser faster

---

# Run

```bash
make docker-fuzz
```

Observed:

- crash artifact written to `artifacts/`
- ASan heap-buffer-overflow
- stack trace into `tls1_process_heartbeat`

---

# Root Cause

Vulnerable pattern:

```c
n2s(p, payload);
pl = p;
memcpy(bp, pl, payload);
```

Missing:

- check that the record actually contains `payload` bytes

---

# Fix

Commit:

- `96db9023b881d7cd9f379b0c154650d6c108e9a3`

Added:

- header size validation
- payload bounds validation
- silent discard of malformed heartbeat messages

---

# Deliverables

- source code repository / ZIP
- report in Markdown for PDF export
- slide deck in Markdown for PDF/PPT export
- demo script for video recording

---

# Takeaways

- fuzzing finds old protocol bugs fast
- sanitizers make read bugs visible
- reproducible Docker setup helps grading
- small harness, large security impact
