#!/usr/bin/env bash

set -euo pipefail

echo "== Proxy environment =="
env | grep -i proxy || true
echo

echo "== Pip config =="
python -m pip config list -v || true
echo

echo "== Endpoint checks =="
for url in \
  "https://github.com" \
  "https://huggingface.co" \
  "https://download.pytorch.org" \
  "https://flashinfer.ai" \
  "https://hf.co/cli/install.sh"
do
  echo "-- $url"
  curl -I --max-time "${CURL_TIMEOUT:-15}" "$url" || true
  echo
done

echo "== DNS checks =="
python - <<'PY'
import socket
hosts = [
    "github.com",
    "huggingface.co",
    "download.pytorch.org",
    "flashinfer.ai",
    "hf.co",
]
for host in hosts:
    try:
        print(f"{host}\t{socket.gethostbyname(host)}")
    except Exception as exc:
        print(f"{host}\tDNS_FAIL\t{exc}")
PY

echo
echo "== Summary hints =="
cat <<'EOF'
- If GitHub is reachable but Hugging Face times out, model download is the first external blocker.
- If Hugging Face is blocked, prefer either:
  1. an approved session-level proxy, or
  2. copying a pre-downloaded local model directory to the server.
- Do not write proxy settings into ~/.bashrc until the route is confirmed.
EOF
