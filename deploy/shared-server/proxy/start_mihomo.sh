#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/data/matt/workspace}"
APP_ROOT="${APP_ROOT:-${WORKSPACE_ROOT}/netproxy/mihomo}"
BIN="${APP_ROOT}/bin/mihomo"
CONFIG="${CONFIG:-${APP_ROOT}/config/mihomo.yaml}"
LOG_FILE="${APP_ROOT}/logs/mihomo.log"
PID_FILE="${APP_ROOT}/run/mihomo.pid"

if [ ! -x "${BIN}" ]; then
  echo "mihomo binary not found: ${BIN}" >&2
  echo "Run install_mihomo.sh first." >&2
  exit 1
fi

if [ ! -f "${CONFIG}" ]; then
  echo "Config not found: ${CONFIG}" >&2
  exit 1
fi

if [ -f "${PID_FILE}" ]; then
  OLD_PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [ -n "${OLD_PID}" ] && kill -0 "${OLD_PID}" 2>/dev/null; then
    echo "mihomo is already running with PID ${OLD_PID}" >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "${LOG_FILE}")" "$(dirname "${PID_FILE}")"

nohup "${BIN}" -d "${APP_ROOT}" -f "${CONFIG}" > "${LOG_FILE}" 2>&1 &
PID=$!
printf '%s\n' "${PID}" > "${PID_FILE}"

sleep 2

if kill -0 "${PID}" 2>/dev/null; then
  echo "mihomo started in background."
  echo "PID: ${PID}"
  echo "Log: ${LOG_FILE}"
else
  echo "mihomo failed to start. Check log: ${LOG_FILE}" >&2
  exit 1
fi
