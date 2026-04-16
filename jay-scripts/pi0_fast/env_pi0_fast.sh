#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export PYTHONPATH="${ROOT_DIR}/.vendor/pi0_fast_pydeps${PYTHONPATH:+:${PYTHONPATH}}"
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_HOME="${HF_HOME:-${HOME}/.cache/huggingface}"
export HF_DATASETS_CACHE="${HF_DATASETS_CACHE:-/tmp/hf_datasets_cache}"
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"

export PI0_FAST_MODEL_DIR="${PI0_FAST_MODEL_DIR:-${ROOT_DIR}/models/lerobot_pi0_fast_base}"
export PI0_FAST_TEXT_TOKENIZER_DIR="${PI0_FAST_TEXT_TOKENIZER_DIR:-${ROOT_DIR}/models/google_paligemma_3b_pt_224_tokenizer}"
export PI0_FAST_ACTION_TOKENIZER_DIR="${PI0_FAST_ACTION_TOKENIZER_DIR:-${ROOT_DIR}/models/lerobot_fast_action_tokenizer}"
export GRABFRUIT_DATASET_ROOT="${GRABFRUIT_DATASET_ROOT:-${HOME}/.cache/huggingface/lerobot/grabfruit/test}"
export GRABFRUIT_DATASET_REPO_ID="${GRABFRUIT_DATASET_REPO_ID:-grabfruit/test}"

if [[ "${CONDA_DEFAULT_ENV:-}" == "lerobot" && -n "${CONDA_PREFIX:-}" && -x "${CONDA_PREFIX}/bin/python" ]]; then
  _DEFAULT_LEROBOT_PYTHON="${CONDA_PREFIX}/bin/python"
elif [[ -x "${HOME}/anaconda3/envs/lerobot/bin/python" ]]; then
  _DEFAULT_LEROBOT_PYTHON="${HOME}/anaconda3/envs/lerobot/bin/python"
else
  _DEFAULT_LEROBOT_PYTHON="$(command -v python)"
fi

export LEROBOT_PYTHON="${LEROBOT_PYTHON:-${_DEFAULT_LEROBOT_PYTHON}}"
