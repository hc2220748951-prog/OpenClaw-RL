#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"

MODEL_NAME="${MODEL_NAME:-Qwen3-4B}"
MODEL_SOURCE="${MODEL_SOURCE:-local}"
TARGET_ROOT="${TARGET_ROOT:-${REPO_ROOT}/models}"
HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-60}"

case "${MODEL_NAME}" in
  Qwen3-4B)
    TARGET_DIR="${TARGET_ROOT}/Qwen3-4B"
    HF_REPO_ID="${HF_REPO_ID:-Qwen/Qwen3-4B}"
    ;;
  Qwen3-0.6B)
    TARGET_DIR="${TARGET_ROOT}/Qwen3-0.6B"
    HF_REPO_ID="${HF_REPO_ID:-Qwen/Qwen3-0.6B}"
    ;;
  *)
    echo "Unsupported MODEL_NAME: ${MODEL_NAME}" >&2
    exit 1
    ;;
esac

mkdir -p "${TARGET_ROOT}"

if [ -e "${TARGET_DIR}" ] && [ -n "$(ls -A "${TARGET_DIR}" 2>/dev/null || true)" ]; then
  echo "Target already exists and is not empty: ${TARGET_DIR}"
  echo "Nothing changed."
  exit 0
fi

case "${MODEL_SOURCE}" in
  local)
    SOURCE_PATH="${SOURCE_PATH:-}"
    if [ -z "${SOURCE_PATH}" ]; then
      echo "MODEL_SOURCE=local requires SOURCE_PATH." >&2
      exit 1
    fi
    if [ ! -d "${SOURCE_PATH}" ]; then
      echo "SOURCE_PATH does not exist: ${SOURCE_PATH}" >&2
      exit 1
    fi
    mkdir -p "$(dirname "${TARGET_DIR}")"
    ln -s "${SOURCE_PATH}" "${TARGET_DIR}"
    echo "Linked ${TARGET_DIR} -> ${SOURCE_PATH}"
    ;;
  hf)
    if ! command -v hf >/dev/null 2>&1; then
      echo "hf CLI not found. Installing huggingface_hub into the current environment."
      python -m pip install -U "huggingface_hub"
    fi
    export HF_HUB_DOWNLOAD_TIMEOUT
    HF_ARGS=()
    if [ -n "${HF_TOKEN:-}" ]; then
      HF_ARGS+=(--token "${HF_TOKEN}")
    fi
    hf download "${HF_REPO_ID}" --local-dir "${TARGET_DIR}" "${HF_ARGS[@]}"
    ;;
  copy)
    SOURCE_PATH="${SOURCE_PATH:-}"
    if [ -z "${SOURCE_PATH}" ]; then
      echo "MODEL_SOURCE=copy requires SOURCE_PATH." >&2
      exit 1
    fi
    if [ ! -d "${SOURCE_PATH}" ]; then
      echo "SOURCE_PATH does not exist: ${SOURCE_PATH}" >&2
      exit 1
    fi
    mkdir -p "${TARGET_DIR}"
    rsync -aH --info=progress2 "${SOURCE_PATH}/" "${TARGET_DIR}/"
    ;;
  *)
    echo "Unsupported MODEL_SOURCE: ${MODEL_SOURCE}" >&2
    echo "Use one of: local, hf, copy" >&2
    exit 1
    ;;
esac

echo "Model directory ready: ${TARGET_DIR}"
