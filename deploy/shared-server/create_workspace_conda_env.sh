#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/data/matt/workspace}"
ENV_PREFIX="${ENV_PREFIX:-${WORKSPACE_ROOT}/.conda/envs/openclaw-rl-py312}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found in PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "${ENV_PREFIX}")"

if [ -d "${ENV_PREFIX}" ]; then
  echo "Environment already exists: ${ENV_PREFIX}"
else
  conda create -p "${ENV_PREFIX}" "python=${PYTHON_VERSION}" -y
fi

echo
echo "Activate it with:"
echo "  conda activate ${ENV_PREFIX}"
echo
echo "Then verify:"
echo "  python --version"
echo "  which python"
