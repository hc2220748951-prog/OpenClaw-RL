#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_CONFIG_DIR="${SCRIPT_DIR}/config"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/data/matt/workspace}"
APP_ROOT="${APP_ROOT:-${WORKSPACE_ROOT}/netproxy/mihomo}"
BIN_DIR="${APP_ROOT}/bin"
CONFIG_DIR="${APP_ROOT}/config"
PROVIDERS_DIR="${APP_ROOT}/providers"
LOG_DIR="${APP_ROOT}/logs"
RUN_DIR="${APP_ROOT}/run"
TMP_DIR="${APP_ROOT}/tmp"

mkdir -p "${BIN_DIR}" "${CONFIG_DIR}" "${PROVIDERS_DIR}" "${LOG_DIR}" "${RUN_DIR}" "${TMP_DIR}"

REPO_API_BASE="https://api.github.com/repos/MetaCubeX/mihomo/releases"
MIHOMO_VERSION="${MIHOMO_VERSION:-latest}"
ARCH_RAW="$(uname -m)"
CPU_LEVEL="${CPU_LEVEL:-v1}"

case "${ARCH_RAW}" in
  x86_64|amd64)
    ASSET_PATTERN="mihomo-linux-amd64-${CPU_LEVEL}-"
    ;;
  aarch64|arm64)
    ASSET_PATTERN="mihomo-linux-arm64-v8-"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH_RAW}" >&2
    exit 1
    ;;
esac

if [ "${MIHOMO_VERSION}" = "latest" ]; then
  RELEASE_API_URL="${REPO_API_BASE}/latest"
else
  RELEASE_API_URL="${REPO_API_BASE}/tags/${MIHOMO_VERSION}"
fi

PY_RESULT="$(
python3 - <<'PY' "${RELEASE_API_URL}" "${ASSET_PATTERN}"
import json
import sys
import urllib.request

api_url = sys.argv[1]
pattern = sys.argv[2]

with urllib.request.urlopen(api_url, timeout=30) as resp:
    data = json.load(resp)

assets = data.get("assets", [])
for asset in assets:
    name = asset.get("name", "")
    if pattern in name and name.endswith(".gz"):
        print(data.get("tag_name", ""))
        print(name)
        print(asset.get("browser_download_url", ""))
        raise SystemExit(0)

raise SystemExit(f"No matching asset found for pattern: {pattern}")
PY
)"

MIHOMO_TAG="$(printf '%s\n' "${PY_RESULT}" | sed -n '1p')"
ASSET_NAME="$(printf '%s\n' "${PY_RESULT}" | sed -n '2p')"
ASSET_URL="$(printf '%s\n' "${PY_RESULT}" | sed -n '3p')"

TMP_GZ="${TMP_DIR}/${ASSET_NAME}"
TMP_BIN="${TMP_DIR}/mihomo"
FINAL_BIN="${BIN_DIR}/mihomo"

echo "Downloading ${ASSET_NAME}"
curl -fL --retry 3 --retry-delay 2 "${ASSET_URL}" -o "${TMP_GZ}"

python3 - <<'PY' "${TMP_GZ}" "${TMP_BIN}"
import gzip
import shutil
import sys

src = sys.argv[1]
dst = sys.argv[2]

with gzip.open(src, "rb") as fsrc, open(dst, "wb") as fdst:
    shutil.copyfileobj(fsrc, fdst)
PY

chmod +x "${TMP_BIN}"
mv "${TMP_BIN}" "${FINAL_BIN}"

printf '%s\n' "${MIHOMO_TAG}" > "${APP_ROOT}/VERSION"

cat > "${APP_ROOT}/env_proxy_on.sh" <<'EOF'
#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "Please source this file instead of executing it." >&2
  echo "Example: source /data/matt/workspace/netproxy/mihomo/env_proxy_on.sh" >&2
  exit 1
fi

export PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
export PROXY_PORT="${PROXY_PORT:-17890}"

export HTTP_PROXY="http://${PROXY_HOST}:${PROXY_PORT}"
export HTTPS_PROXY="${HTTP_PROXY}"
export ALL_PROXY="socks5h://${PROXY_HOST}:${PROXY_PORT}"
export http_proxy="${HTTP_PROXY}"
export https_proxy="${HTTPS_PROXY}"
export all_proxy="${ALL_PROXY}"
export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost,::1}"
export no_proxy="${NO_PROXY}"

echo "Proxy enabled for this shell:"
echo "  HTTP_PROXY=${HTTP_PROXY}"
echo "  HTTPS_PROXY=${HTTPS_PROXY}"
echo "  ALL_PROXY=${ALL_PROXY}"
EOF

cat > "${APP_ROOT}/env_proxy_off.sh" <<'EOF'
#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "Please source this file instead of executing it." >&2
  echo "Example: source /data/matt/workspace/netproxy/mihomo/env_proxy_off.sh" >&2
  exit 1
fi

unset PROXY_HOST PROXY_PORT
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
unset http_proxy https_proxy all_proxy
unset NO_PROXY no_proxy

echo "Proxy disabled for this shell."
EOF

chmod +x "${APP_ROOT}/env_proxy_on.sh" "${APP_ROOT}/env_proxy_off.sh"

cp -f "${REPO_CONFIG_DIR}/mihomo.subscription.template.yaml" "${CONFIG_DIR}/mihomo.subscription.template.yaml"
cp -f "${REPO_CONFIG_DIR}/mihomo.file-provider.template.yaml" "${CONFIG_DIR}/mihomo.file-provider.template.yaml"

echo "Installed mihomo to: ${FINAL_BIN}"
echo "Version: ${MIHOMO_TAG}"
echo "Workspace root: ${APP_ROOT}"
