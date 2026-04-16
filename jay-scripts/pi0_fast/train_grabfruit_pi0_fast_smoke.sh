#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/jay-scripts/pi0_fast/env_pi0_fast.sh"

if [[ ! -f "${PI0_FAST_TEXT_TOKENIZER_DIR}/tokenizer.model" ]]; then
  echo "Text tokenizer missing at ${PI0_FAST_TEXT_TOKENIZER_DIR}."
  echo "Run jay-scripts/pi0_fast/bootstrap_pi0_fast_assets.sh after accepting the PaliGemma license."
  exit 1
fi

if [[ ! -f "${PI0_FAST_ACTION_TOKENIZER_DIR}/tokenizer_config.json" ]]; then
  echo "FAST action tokenizer missing at ${PI0_FAST_ACTION_TOKENIZER_DIR}."
  echo "Run jay-scripts/pi0_fast/bootstrap_pi0_fast_assets.sh first."
  exit 1
fi

"${LEROBOT_PYTHON}" "${ROOT_DIR}/jay-scripts/pi0_fast/patch_pi0_fast_local_paths.py" \
  --policy-dir "${PI0_FAST_MODEL_DIR}" \
  --text-tokenizer-dir "${PI0_FAST_TEXT_TOKENIZER_DIR}" \
  --action-tokenizer-dir "${PI0_FAST_ACTION_TOKENIZER_DIR}"

export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
export TRANSFORMERS_OFFLINE="${TRANSFORMERS_OFFLINE:-1}"
export HF_DATASETS_OFFLINE="${HF_DATASETS_OFFLINE:-1}"

"${LEROBOT_PYTHON}" -m lerobot.scripts.lerobot_train \
  --policy.path="${PI0_FAST_MODEL_DIR}" \
  --dataset.repo_id="${GRABFRUIT_DATASET_REPO_ID}" \
  --dataset.root="${GRABFRUIT_DATASET_ROOT}" \
  --rename_map='{"observation.images.front":"observation.images.base_0_rgb","observation.images.side":"observation.images.left_wrist_0_rgb"}' \
  --policy.push_to_hub=false \
  --policy.device="${POLICY_DEVICE:-cuda}" \
  --policy.dtype="${POLICY_DTYPE:-bfloat16}" \
  --policy.text_tokenizer_name="${PI0_FAST_TEXT_TOKENIZER_DIR}" \
  --policy.action_tokenizer_name="${PI0_FAST_ACTION_TOKENIZER_DIR}" \
  --policy.gradient_checkpointing=true \
  --policy.compile_model=false \
  --policy.chunk_size="${POLICY_CHUNK_SIZE:-10}" \
  --policy.n_action_steps="${POLICY_N_ACTION_STEPS:-10}" \
  --policy.max_action_tokens="${POLICY_MAX_ACTION_TOKENS:-256}" \
  --wandb.enable=false \
  --batch_size="${BATCH_SIZE:-1}" \
  --steps="${STEPS:-20}" \
  --num_workers="${NUM_WORKERS:-0}" \
  --output_dir="${OUTPUT_DIR:-${ROOT_DIR}/outputs/train/pi0_fast_grabfruit_smoke}" \
  --job_name="${JOB_NAME:-pi0_fast_grabfruit_smoke}" \
  --peft.method_type=LORA \
  --peft.r="${PEFT_R:-16}" \
  --peft.target_modules="${PEFT_TARGET_MODULES:-.*language_model\\.layers\\..*\\.self_attn\\.(q|v)_proj}" \
  "$@"
