#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/jay-scripts/pi0/env_pi0.sh"

if [[ ! -f "${PI0_TOKENIZER_DIR}/tokenizer.model" ]]; then
  echo "Tokenizer missing at ${PI0_TOKENIZER_DIR}."
  echo "Run jay-scripts/pi0/bootstrap_pi0_assets.sh after accepting the PaliGemma license."
  exit 1
fi

"${LEROBOT_PYTHON}" "${ROOT_DIR}/jay-scripts/pi0/patch_pi0_tokenizer_path.py" \
  --policy-dir "${PI0_MODEL_DIR}" \
  --tokenizer-dir "${PI0_TOKENIZER_DIR}"

export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
export TRANSFORMERS_OFFLINE="${TRANSFORMERS_OFFLINE:-1}"
export HF_DATASETS_OFFLINE="${HF_DATASETS_OFFLINE:-1}"

"${LEROBOT_PYTHON}" -m lerobot.scripts.lerobot_train \
  --policy.path="${PI0_MODEL_DIR}" \
  --dataset.repo_id="${GRABFRUIT_DATASET_REPO_ID}" \
  --dataset.root="${GRABFRUIT_DATASET_ROOT}" \
  --rename_map='{"observation.images.front":"observation.images.base_0_rgb","observation.images.side":"observation.images.left_wrist_0_rgb"}' \
  --policy.push_to_hub=false \
  --policy.device="${POLICY_DEVICE:-cuda}" \
  --policy.dtype="${POLICY_DTYPE:-bfloat16}" \
  --policy.gradient_checkpointing=true \
  --policy.compile_model=false \
  --wandb.enable=false \
  --batch_size="${BATCH_SIZE:-1}" \
  --steps="${STEPS:-10000}" \
  --num_workers="${NUM_WORKERS:-2}" \
  --output_dir="${OUTPUT_DIR:-${ROOT_DIR}/outputs/train/pi0_grabfruit_lora}" \
  --job_name="${JOB_NAME:-pi0_grabfruit_lora}" \
  --peft.method=LORA \
  --peft.r="${PEFT_R:-16}" \
  "$@"
