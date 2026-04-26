#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENSSL_VERSION="1.0.1f"
ARCHIVE="openssl-${OPENSSL_VERSION}.tar.gz"
SRC_DIR="${ROOT_DIR}/openssl-${OPENSSL_VERSION}"
# Matches official OpenSSL_1_0_1f release tarball (e.g. GitHub release asset).
# Override if you mirror the archive: OPENSSL_TARBALL_SHA256=...
OPENSSL_TARBALL_SHA256="${OPENSSL_TARBALL_SHA256:-6cc2a80b17d64de6b7bac985745fdaba971d54ffd7d38d3556f998d7c0c9cb5a}"
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
  downloaded=""
  for url in "${URLS[@]}"; do
    if curl -fL "${url}" -o "${ARCHIVE}"; then
      downloaded="1"
      break
    fi
  done
  if [[ -z "${downloaded}" ]]; then
    echo "ERROR: could not download ${ARCHIVE} from any configured URL." >&2
    exit 1
  fi
fi

if [[ ! -s "${ARCHIVE}" ]]; then
  echo "ERROR: ${ARCHIVE} is missing or empty." >&2
  exit 1
fi

tar tf "${ARCHIVE}" >/dev/null

if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
else
  actual_sha256="$(shasum -a 256 "${ARCHIVE}" | awk '{print $1}')"
fi
if [[ "${actual_sha256}" != "${OPENSSL_TARBALL_SHA256}" ]]; then
  echo "ERROR: SHA256 mismatch for ${ARCHIVE} (wrong or corrupt file)." >&2
  echo "  expected: ${OPENSSL_TARBALL_SHA256}" >&2
  echo "  actual:   ${actual_sha256}" >&2
  rm -f "${ARCHIVE}"
  exit 1
fi

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
