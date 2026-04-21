#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENSSL_VERSION="1.0.1f"
ARCHIVE="openssl-${OPENSSL_VERSION}.tar.gz"
SRC_DIR="${ROOT_DIR}/openssl-${OPENSSL_VERSION}"
URLS=(
  "https://github.com/openssl/openssl/releases/download/OpenSSL_1_0_1f/${ARCHIVE}"
  "https://www.openssl.org/source/old/1.0.1/${ARCHIVE}"
  "https://openssl.org/source/old/1.0.1/${ARCHIVE}"
)

cd "${ROOT_DIR}"

if [[ -f "${ARCHIVE}" ]] && ! tar tf "${ARCHIVE}" >/dev/null 2>&1; then
  rm -f "${ARCHIVE}"
fi

if [[ ! -f "${ARCHIVE}" ]]; then
  for url in "${URLS[@]}"; do
    if curl -fL "${url}" -o "${ARCHIVE}"; then
      break
    fi
  done
fi

tar tf "${ARCHIVE}" >/dev/null

rm -rf "${SRC_DIR}"
tar xf "${ARCHIVE}"

cd "${SRC_DIR}"

make clean >/dev/null 2>&1 || true

export CC=clang
export CXX=clang++
export CFLAGS="-g -O1 -fno-omit-frame-pointer -fsanitize=address,fuzzer-no-link"
export CXXFLAGS="${CFLAGS}"

./config no-shared no-asm -fno-omit-frame-pointer -g -O1
make build_libs \
  CC="${CC}" \
  CFLAG="${CFLAGS}" \
  CXX="${CXX}" \
  MAKEDEPPROG="${CC}" \
  -j"$(getconf _NPROCESSORS_ONLN || echo 4)"
