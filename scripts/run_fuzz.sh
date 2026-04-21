#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUZZER="${ROOT_DIR}/build/heartbleed_fuzz"
CORPUS_DIR="${ROOT_DIR}/fuzz/corpus"
CRASH_DIR="${FUZZ_CRASH_DIR:-${ROOT_DIR}/fuzz/crashes}"
DICT="${ROOT_DIR}/fuzz/heartbleed.dict"

mkdir -p "${CRASH_DIR}"

exec "${FUZZER}" \
  -artifact_prefix="${CRASH_DIR}/" \
  -dict="${DICT}" \
  -max_total_time="${MAX_TOTAL_TIME:-120}" \
  -print_final_stats=1 \
  "${CORPUS_DIR}"
