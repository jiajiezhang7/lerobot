#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/jay-scripts/pi0/env_pi0.sh"

export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
export TRANSFORMERS_OFFLINE="${TRANSFORMERS_OFFLINE:-1}"
export HF_DATASETS_OFFLINE="${HF_DATASETS_OFFLINE:-1}"

"${LEROBOT_PYTHON}" -m lerobot.scripts.lerobot_edit_dataset \
  --repo_id "${GRABFRUIT_DATASET_REPO_ID}" \
  --root "${GRABFRUIT_DATASET_ROOT}" \
  --operation.type recompute_stats \
  --operation.relative_action true \
  --operation.chunk_size "${CHUNK_SIZE:-50}" \
  --operation.relative_exclude_joints '["gripper"]' \
  --operation.num_workers "${NUM_WORKERS:-0}" \
  --push_to_hub false \
  "$@"
