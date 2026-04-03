#!/usr/bin/env bash

set -euo pipefail

export PYTHONUNBUFFERED=1
export PYTHONFAULTHANDLER=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../slime" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

GPU_LIST="${GPU_LIST:-0,1,2,3}"
if [ -z "${CUDA_VISIBLE_DEVICES:-}" ]; then
  export CUDA_VISIBLE_DEVICES="${GPU_LIST}"
fi

IFS=',' read -r -a GPU_ARRAY <<< "${CUDA_VISIBLE_DEVICES}"
NUM_GPUS="${NUM_GPUS:-${#GPU_ARRAY[@]}}"

ACTOR_GPUS="${ACTOR_GPUS:-2}"
ROLLOUT_GPUS="${ROLLOUT_GPUS:-1}"
PRM_GPUS="${PRM_GPUS:-1}"

if (( ACTOR_GPUS + ROLLOUT_GPUS + PRM_GPUS > NUM_GPUS )); then
  echo "ACTOR_GPUS + ROLLOUT_GPUS + PRM_GPUS must be <= NUM_GPUS" >&2
  echo "ACTOR_GPUS=${ACTOR_GPUS} ROLLOUT_GPUS=${ROLLOUT_GPUS} PRM_GPUS=${PRM_GPUS} NUM_GPUS=${NUM_GPUS}" >&2
  exit 1
fi

RUN_NAME="${RUN_NAME:-qwen3-4b-openclaw-rl-lora-safe}"
RUN_ROOT="${RUN_ROOT:-${REPO_ROOT}/runs/${RUN_NAME}}"
mkdir -p "${RUN_ROOT}"

HF_CKPT="${HF_CKPT:-${REPO_ROOT}/models/Qwen3-4B}"
REF_LOAD="${REF_LOAD:-${HF_CKPT}}"
SAVE_CKPT="${SAVE_CKPT:-${REPO_ROOT}/ckpt/qwen3-4b-openclaw-rl-lora-safe}"
PRM_MODEL_PATH="${PRM_MODEL_PATH:-${HF_CKPT}}"

if [ ! -d "${HF_CKPT}" ]; then
  echo "Model directory not found: ${HF_CKPT}" >&2
  echo "Prepare it first with deploy/shared-server/download_qwen_model.sh" >&2
  exit 1
fi

PORT="${PORT:-30000}"
RAY_PORT="${RAY_PORT:-16379}"
DASHBOARD_PORT="${DASHBOARD_PORT:-18265}"
MASTER_ADDR="${MASTER_ADDR:-127.0.0.1}"

for check_port in "${PORT}" "${RAY_PORT}" "${DASHBOARD_PORT}"; do
  if ss -ltn "( sport = :${check_port} )" | grep -q ":${check_port}"; then
    echo "Port already in use: ${check_port}" >&2
    exit 1
  fi
done

export RAY_health_check_failure_threshold="${RAY_health_check_failure_threshold:-20}"
export RAY_health_check_period_ms="${RAY_health_check_period_ms:-5000}"
export RAY_health_check_timeout_ms="${RAY_health_check_timeout_ms:-30000}"
export RAY_num_heartbeats_timeout="${RAY_num_heartbeats_timeout:-60}"

export SGLANG_API_KEY="${SGLANG_API_KEY:-}"
export SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3-4b}"
export HOST="${HOST:-127.0.0.1}"
export OPENCLAW_RECORD_ENABLED="${OPENCLAW_RECORD_ENABLED:-1}"
export OPENCLAW_RECORD_FILE="${OPENCLAW_RECORD_FILE:-${RUN_ROOT}/qwen3_4b_lora_record.jsonl}"
export TP="${TP:-1}"
export CONTEXT_LENGTH="${CONTEXT_LENGTH:-32768}"
export MEM_FRACTION_STATIC="${MEM_FRACTION_STATIC:-0.80}"
export REASONING_PARSER="${REASONING_PARSER:-qwen3}"
export TOOL_CALL_PARSER="${TOOL_CALL_PARSER:-qwen25}"
export PRM_M="${PRM_M:-3}"

CKPT_ARGS=(
  --hf-checkpoint "${HF_CKPT}"
  --ref-load "${REF_LOAD}"
  --save "${SAVE_CKPT}"
  --save-interval "${SAVE_INTERVAL:-1}"
)

ROLLOUT_ARGS=(
  --disable-rollout-global-dataset
  --rollout-function-path openclaw_rollout.generate_rollout_openclaw
  --num-rollout "${NUM_ROLLOUT:-100000000}"
  --rollout-batch-size "${ROLLOUT_BATCH_SIZE:-8}"
  --n-samples-per-prompt "${N_SAMPLES_PER_PROMPT:-1}"
  --rollout-max-response-len "${ROLLOUT_MAX_RESPONSE_LEN:-4096}"
  --rollout-max-context-len "${ROLLOUT_MAX_CONTEXT_LEN:-32768}"
  --rollout-temperature "${ROLLOUT_TEMPERATURE:-0.6}"
  --reward-key score
  --num-steps-per-rollout "${NUM_STEPS_PER_ROLLOUT:-1}"
)

PERF_ARGS=(
  --use-dynamic-batch-size
  --max-tokens-per-gpu "${MAX_TOKENS_PER_GPU:-4096}"
  --gradient-checkpointing
)

GRPO_ARGS=(
  --advantage-estimator grpo
  --disable-rewards-normalization
  --use-kl-loss
  --kl-loss-coef "${KL_LOSS_COEF:-0.0}"
  --kl-loss-type low_var_kl
  --entropy-coef "${ENTROPY_COEF:-0.00}"
  --eps-clip "${EPS_CLIP:-0.2}"
  --eps-clip-high "${EPS_CLIP_HIGH:-0.28}"
)

OPTIMIZER_ARGS=(
  --optimizer adam
  --lr "${LR:-1e-5}"
  --lr-decay-style constant
  --weight-decay "${WEIGHT_DECAY:-0.1}"
  --adam-beta1 0.9
  --adam-beta2 0.98
)

LORA_ARGS=(
  --use-lora
  --lora-rank "${LORA_RANK:-16}"
  --lora-alpha "${LORA_ALPHA:-32}"
  --lora-target-modules "q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj"
)

SGLANG_ARGS=(
  --rollout-num-gpus-per-engine "${TP}"
  --sglang-tool-call-parser "${TOOL_CALL_PARSER}"
  --sglang-mem-fraction-static "${MEM_FRACTION_STATIC}"
  --sglang-context-length "${CONTEXT_LENGTH}"
  --sglang-reasoning-parser "${REASONING_PARSER}"
)

PRM_ARGS=(
  --prm-enable
  --prm-num-gpus "${PRM_GPUS}"
  --prm-num-gpus-per-engine "${PRM_TP:-${TP}}"
  --prm-model-path "${PRM_MODEL_PATH}"
  --prm-m "${PRM_M}"
  --prm-temperature "${PRM_TEMPERATURE:-0.6}"
  --prm-max-new-tokens "${PRM_MAX_NEW_TOKENS:-2048}"
)

CUSTOM_ARGS=(
  --custom-generate-function-path openclaw_api_server.generate
  --custom-rm-path openclaw_api_server.reward_func
)

USE_WANDB="${USE_WANDB:-0}"
WANDB_PROJECT="${WANDB_PROJECT:-openclaw_rl}"
WANDB_KEY_VALUE="${WANDB_KEY:-${WANDB_API_KEY:-}}"
if [ "${USE_WANDB}" = "1" ] && [ -n "${WANDB_KEY_VALUE}" ]; then
  WANDB_ARGS=(
    --use-wandb
    --wandb-project "${WANDB_PROJECT}"
    --wandb-group qwen3-4b-openclaw-rl-lora-safe
    --wandb-key "${WANDB_KEY_VALUE}"
  )
else
  WANDB_ARGS=()
fi

RUNTIME_ENV_JSON="$(cat <<EOF
{
  "env_vars": {
    "PYTHONPATH": "${SCRIPT_DIR}:${SLIME_ROOT}",
    "CUDA_DEVICE_MAX_CONNECTIONS": "1",
    "SGLANG_API_KEY": "${SGLANG_API_KEY}",
    "HOST": "${HOST}",
    "PORT": "${PORT}",
    "SERVED_MODEL_NAME": "${SERVED_MODEL_NAME}",
    "OPENCLAW_RECORD_ENABLED": "${OPENCLAW_RECORD_ENABLED}",
    "OPENCLAW_RECORD_FILE": "${OPENCLAW_RECORD_FILE}",
    "PRM_M": "${PRM_M}"
  }
}
EOF
)"

echo "Starting safe launcher with:"
echo "  CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"
echo "  NUM_GPUS=${NUM_GPUS}"
echo "  RUN_ROOT=${RUN_ROOT}"
echo "  PORT=${PORT} RAY_PORT=${RAY_PORT} DASHBOARD_PORT=${DASHBOARD_PORT}"

ray start \
  --head \
  --node-ip-address "${MASTER_ADDR}" \
  --port "${RAY_PORT}" \
  --num-gpus "${NUM_GPUS}" \
  --disable-usage-stats \
  --dashboard-host 127.0.0.1 \
  --dashboard-port "${DASHBOARD_PORT}" \
  --temp-dir "${RUN_ROOT}/ray_tmp"

ray job submit --address="http://127.0.0.1:${DASHBOARD_PORT}" \
  --runtime-env-json="${RUNTIME_ENV_JSON}" \
  -- python3 "${SLIME_ROOT}/train_async.py" \
  --train-backend fsdp \
  --actor-num-nodes 1 \
  --actor-num-gpus-per-node "${ACTOR_GPUS}" \
  --rollout-num-gpus "${ROLLOUT_GPUS}" \
  --num-gpus-per-node "${NUM_GPUS}" \
  "${CKPT_ARGS[@]}" \
  "${ROLLOUT_ARGS[@]}" \
  "${OPTIMIZER_ARGS[@]}" \
  "${GRPO_ARGS[@]}" \
  "${PERF_ARGS[@]}" \
  "${SGLANG_ARGS[@]}" \
  "${WANDB_ARGS[@]}" \
  "${CUSTOM_ARGS[@]}" \
  "${PRM_ARGS[@]}" \
  "${LORA_ARGS[@]}"
