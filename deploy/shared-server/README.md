# Shared Server Deployment Notes

This folder contains shared-server-safe helpers for bringing up `OpenClaw-RL` without using the stock launchers directly.

## Why these files exist

The stock launchers under `openclaw-rl/` and `openclaw-combine/` begin with global cleanup commands such as:

```bash
pkill -9 python
pkill -9 ray
pkill -9 sglang
ray stop --force
```

That is unsafe on a shared machine.

These helpers avoid global process cleanup and instead:

- let you choose a dedicated GPU subset
- let you choose per-run ports
- write outputs into a run-specific directory
- fail fast if a port or model path is missing

## Files

- `diagnose_model_network.sh`
  - quick check for GitHub, Hugging Face, PyTorch wheels, FlashInfer, and optional session proxy vars
- `download_qwen_model.sh`
  - prepare `models/Qwen3-4B` or `models/Qwen3-0.6B` from either a local path or Hugging Face

## Launcher files

- `openclaw-rl/run_qwen3_4b_openclaw_rl_lora_safe.sh`
  - recommended first training path
- `openclaw-rl/run_qwen3_0p6b_openclaw_rl_lora_safe.sh`
  - smaller experimental smoke-test path

## Recommended order

1. Run network diagnostics.
2. Decide model source:
   - existing local directory
   - official Hugging Face access
   - copy from another machine
3. Prepare the model directory under `OpenClaw-RL/models/`.
4. Start with the 4B LoRA safe launcher.
5. Use the 0.6B launcher only when you want a cheaper smoke test.

## Example

```bash
cd /data/openclaw/OpenClaw-RL
bash deploy/shared-server/diagnose_model_network.sh
```

```bash
cd /data/openclaw/OpenClaw-RL
MODEL_SOURCE=local \
MODEL_NAME=Qwen3-4B \
SOURCE_PATH=/data/models/Qwen3-4B \
bash deploy/shared-server/download_qwen_model.sh
```

```bash
cd /data/openclaw/OpenClaw-RL
GPU_LIST=0,1,2,3 \
PORT=31000 \
RAY_PORT=16379 \
DASHBOARD_PORT=18265 \
bash openclaw-rl/run_qwen3_4b_openclaw_rl_lora_safe.sh
```

## Notes on Hugging Face access

If `huggingface.co` is blocked:

- first prefer a session-level proxy that is approved in your environment
- otherwise copy an already-downloaded model directory onto the server and use `MODEL_SOURCE=local`

Do not hardcode proxy settings into shell startup files until you have confirmed the approved route.

## Fastest path if your local machine already has VPN

If your local machine already has stable VPN access, that is usually the fastest and safest route.

Recommended flow:

1. On your local machine:
   - pull this repo
   - download `Qwen3-4B` or `Qwen3-0.6B`
   - commit your helper scripts
   - push to GitHub
2. On the server:
   - pull the repo into `/data/matt/workspace/OpenClaw-RL`
   - create a workspace-local conda env
   - copy or sync the model directory into `OpenClaw-RL/models/`
3. When GPUs are free:
   - activate the workspace-local env
   - run the safe launcher

Why this is preferred:

- your server stays clean
- your VPN stays on your local machine
- no need to debug server-side VPN first
- model download failure is removed from the critical path

Suggested model target paths on the server:

- `/data/matt/workspace/OpenClaw-RL/models/Qwen3-4B`
- `/data/matt/workspace/OpenClaw-RL/models/Qwen3-0.6B`

Suggested env path on the server:

- `/data/matt/workspace/.conda/envs/openclaw-rl-py312`
