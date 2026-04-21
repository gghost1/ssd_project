# Demo script

Target length: 3-5 minutes.

## 1. Show project files

```bash
pwd
ls
```

Say:

`This project rediscovers Heartbleed, CVE-2014-0160, by fuzzing OpenSSL 1.0.1f with libFuzzer inside Docker.`

## 2. Build container

```bash
make build
```

Say:

`The container installs clang, builds vulnerable OpenSSL 1.0.1f with AddressSanitizer instrumentation, then links the custom fuzz target.`

## 3. Run fuzzing

```bash
make docker-fuzz
```

Show:

- corpus initialization
- mutation counters
- crash artifact path in `artifacts/`
- `AddressSanitizer: heap-buffer-overflow`
- non-zero exit code after ASan abort

Say:

`The crash lands in tls1_process_heartbeat, which is the vulnerable Heartbleed code path.`

## 4. Reproduce deterministically

```bash
make docker-reproduce
```

Show:

- same artifact replayed
- same ASan crash

Say:

`This proves the crash is stable and directly tied to the saved input.`

## 5. Point at root cause

Open:

- `fuzz/heartbleed_fuzz.cc`
- `report/report.md`

Say:

`The bug exists because OpenSSL trusts the heartbeat payload length and copies more bytes than are actually present in the record buffer.`

## 6. Point at the fix

Mention:

- fixed in `OpenSSL 1.0.1g`
- commit `96db9023b881d7cd9f379b0c154650d6c108e9a3`

Say:

`The patch adds explicit bounds checks before processing the heartbeat payload.`

## 7. Close

Say:

`The deliverables include the source, report, slides, and this demo flow.`
