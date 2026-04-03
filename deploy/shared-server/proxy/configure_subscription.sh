#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/data/matt/workspace}"
APP_ROOT="${APP_ROOT:-${WORKSPACE_ROOT}/netproxy/mihomo}"
CONFIG_DIR="${APP_ROOT}/config"
TARGET_CONFIG="${CONFIG_DIR}/mihomo.yaml"
TEMPLATE="${CONFIG_DIR}/mihomo.subscription.template.yaml"

SUBSCRIPTION_URL="${SUBSCRIPTION_URL:-}"
if [ -z "${SUBSCRIPTION_URL}" ]; then
  echo "SUBSCRIPTION_URL is required." >&2
  exit 1
fi

if [ ! -f "${TEMPLATE}" ]; then
  echo "Template not found: ${TEMPLATE}" >&2
  echo "Run install_mihomo.sh first." >&2
  exit 1
fi

mkdir -p "${CONFIG_DIR}"

if [ -f "${TARGET_CONFIG}" ]; then
  cp -p "${TARGET_CONFIG}" "${TARGET_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
fi

python3 - <<'PY' "${TEMPLATE}" "${TARGET_CONFIG}" "${SUBSCRIPTION_URL}"
import pathlib
import sys

template = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
target = pathlib.Path(sys.argv[2])
subscription_url = sys.argv[3]

target.write_text(template.replace("__SUBSCRIPTION_URL__", subscription_url), encoding="utf-8")
PY

echo "Wrote config: ${TARGET_CONFIG}"
