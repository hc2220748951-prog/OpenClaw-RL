#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/data/matt/workspace}"
APP_ROOT="${APP_ROOT:-${WORKSPACE_ROOT}/netproxy/mihomo}"
PID_FILE="${APP_ROOT}/run/mihomo.pid"

if [ ! -f "${PID_FILE}" ]; then
  echo "No PID file found: ${PID_FILE}"
  exit 0
fi

PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
if [ -z "${PID}" ]; then
  echo "PID file is empty."
  rm -f "${PID_FILE}"
  exit 0
fi

if kill -0 "${PID}" 2>/dev/null; then
  kill "${PID}"
  sleep 2
  if kill -0 "${PID}" 2>/dev/null; then
    echo "Process still alive, sending SIGKILL."
    kill -9 "${PID}"
  fi
fi

rm -f "${PID_FILE}"
echo "mihomo stopped."
