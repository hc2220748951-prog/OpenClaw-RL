#!/usr/bin/env bash

set -euo pipefail

if [ -z "${HTTP_PROXY:-}" ] && [ -z "${http_proxy:-}" ]; then
  echo "Proxy environment is not enabled in this shell." >&2
  echo "Run: source /data/matt/workspace/netproxy/mihomo/env_proxy_on.sh" >&2
  exit 1
fi

for url in \
  "https://github.com" \
  "https://huggingface.co" \
  "https://download.pytorch.org" \
  "https://flashinfer.ai"
do
  echo "-- ${url}"
  curl -I --max-time 20 "${url}" || true
  echo
done
