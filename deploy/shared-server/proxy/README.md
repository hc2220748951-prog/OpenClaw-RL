# Workspace-Local Proxy Toolkit

This toolkit is designed for a shared Linux server where you want proxy access without polluting the global environment.

## Design goals

- everything lives under `/data/matt/workspace`
- no writes to `/etc`
- no writes to `~/.bashrc`
- no systemd service
- no TUN, iptables, or global routing changes
- proxy only applies when you explicitly `source` the env script

## Recommended approach

Use a userspace local proxy client instead of a full system VPN.

For your use case, that is enough because the main targets are:

- `huggingface.co`
- `github.com`
- `download.pytorch.org`
- `flashinfer.ai`

This toolkit uses `mihomo` in local mixed-port mode:

- local listen address: `127.0.0.1`
- local mixed port: `17890`
- controller port: `19090`

Then your shell opts in by sourcing:

- `env_proxy_on.sh`

And opts out by sourcing:

- `env_proxy_off.sh`

## Directory layout on the server

All files are intended to live under:

- `/data/matt/workspace/netproxy/mihomo`

Expected subdirectories:

- `bin/`
- `config/`
- `providers/`
- `logs/`
- `run/`

## Supported config inputs

### Option 1

You have a Clash/Mihomo subscription URL.

Use:

- `configure_subscription.sh`
- `config/mihomo.subscription.template.yaml`

### Option 2

You already have a provider file or a list of proxy URIs.

Use:

- `config/mihomo.file-provider.template.yaml`
- `providers/manual_provider.yaml`

The provider file can be one of the formats documented by Mihomo:

- YAML with `proxies:`
- URI lines
- base64-encoded URI content

## Install and start

```bash
cd /data/matt/workspace/OpenClaw-RL
bash deploy/shared-server/proxy/install_mihomo.sh
```

If you have a subscription URL:

```bash
cd /data/matt/workspace/OpenClaw-RL
SUBSCRIPTION_URL='REPLACE_WITH_YOUR_URL' \
bash deploy/shared-server/proxy/configure_subscription.sh
```

Then start the client:

```bash
cd /data/matt/workspace/OpenClaw-RL
bash deploy/shared-server/proxy/start_mihomo.sh
```

Enable proxy in the current shell only:

```bash
source /data/matt/workspace/netproxy/mihomo/env_proxy_on.sh
```

Test:

```bash
curl -I --max-time 20 https://huggingface.co
curl -I --max-time 20 https://github.com
```

Turn the proxy off in the current shell:

```bash
source /data/matt/workspace/netproxy/mihomo/env_proxy_off.sh
```

Stop the background client:

```bash
cd /data/matt/workspace/OpenClaw-RL
bash deploy/shared-server/proxy/stop_mihomo.sh
```

## Important note

This is intentionally a proxy-mode setup, not a full-VPN/TUN setup.

That is deliberate because a TUN-based VPN usually means more system-level impact:

- extra privileges
- route changes
- possible interference with other users

If your provider only gives WireGuard/OpenVPN config and no Clash/Mihomo-compatible format, tell me what format you have and I will adapt the plan.
