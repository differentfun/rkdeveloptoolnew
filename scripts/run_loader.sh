#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RKD_TOOL="${ROOT_DIR}/rkdeveloptool-new"
DEFAULT_LOADER="${ROOT_DIR}/loaders/rk3328_loader_v1.21.250.bin"

if [[ ! -x "${RKD_TOOL}" ]]; then
  echo "rkdeveloptool binary not found at ${RKD_TOOL}" >&2
  exit 1
fi

LOADER_PATH="${1:-${DEFAULT_LOADER}}"

if [[ ! -f "${LOADER_PATH}" ]]; then
  echo "Loader not found: ${LOADER_PATH}" >&2
  exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
  exec pkexec "$0" "$@"
fi

echo "Using loader: ${LOADER_PATH}"
"${RKD_TOOL}" db "${LOADER_PATH}"
