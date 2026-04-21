#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUZZER="${ROOT_DIR}/build/heartbleed_fuzz"
CRASH_DIR="${FUZZ_CRASH_DIR:-${ROOT_DIR}/fuzz/crashes}"

CRASH_FILE="${1:-}"

if [[ -z "${CRASH_FILE}" ]]; then
  CRASH_FILE="$(ls -1 "${CRASH_DIR}"/crash-* 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${CRASH_FILE}" || ! -f "${CRASH_FILE}" ]]; then
  echo "No crash file found in ${CRASH_DIR}" >&2
  exit 1
fi

exec "${FUZZER}" "${CRASH_FILE}"
