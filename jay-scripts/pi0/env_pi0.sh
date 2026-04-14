#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export PYTHONPATH="${ROOT_DIR}/.vendor/pi0_pydeps${PYTHONPATH:+:${PYTHONPATH}}"
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_HOME="${HF_HOME:-${HOME}/.cache/huggingface}"
export HF_DATASETS_CACHE="${HF_DATASETS_CACHE:-/tmp/hf_datasets_cache}"
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"

export PI0_MODEL_DIR="${PI0_MODEL_DIR:-${ROOT_DIR}/models/lerobot_pi0_base}"
export PI0_TOKENIZER_DIR="${PI0_TOKENIZER_DIR:-${ROOT_DIR}/models/google_paligemma_3b_pt_224_tokenizer}"
export GRABFRUIT_DATASET_ROOT="${GRABFRUIT_DATASET_ROOT:-${HOME}/.cache/huggingface/lerobot/grabfruit/test}"
export GRABFRUIT_DATASET_REPO_ID="${GRABFRUIT_DATASET_REPO_ID:-grabfruit/test}"

export LEROBOT_PYTHON="${LEROBOT_PYTHON:-$(command -v python)}"
