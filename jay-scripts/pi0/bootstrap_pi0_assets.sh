#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/jay-scripts/pi0/env_pi0.sh"

resolve_hfd() {
  local candidate
  for candidate in \
    "${HFD_SCRIPT:-}" \
    "${HOME}/tts_ws/hfd.sh" \
    "${HOME}/action_ws/hfd.sh"
  do
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  echo "Could not find hfd.sh. Set HFD_SCRIPT=/abs/path/to/hfd.sh and rerun." >&2
  return 1
}

ensure_sentencepiece() {
  if "${LEROBOT_PYTHON}" - <<'PY' >/dev/null 2>&1; then
import sentencepiece
PY
    echo "sentencepiece already importable."
    return 0
  fi

  if "${LEROBOT_PYTHON}" - <<'PY' >/dev/null 2>&1; then
import sys
sys.path.insert(0, ".vendor/pi0_pydeps")
import sentencepiece
PY
    echo "sentencepiece already available through ${ROOT_DIR}/.vendor/pi0_pydeps."
    return 0
  fi

  echo "Installing sentencepiece into ${ROOT_DIR}/.vendor/pi0_pydeps ..."
  "${LEROBOT_PYTHON}" -m pip install sentencepiece -t "${ROOT_DIR}/.vendor/pi0_pydeps"
}

download_pi0_base() {
  if [[ -f "${PI0_MODEL_DIR}/model.safetensors" ]]; then
    echo "pi0_base already present at ${PI0_MODEL_DIR}"
    return 0
  fi

  local hfd
  hfd="$(resolve_hfd)"
  echo "Downloading lerobot/pi0_base into ${PI0_MODEL_DIR}"
  HF_ENDPOINT="${HF_ENDPOINT}" bash "${hfd}" \
    lerobot/pi0_base \
    --local-dir "${PI0_MODEL_DIR}"
}

download_tokenizer_if_possible() {
  if [[ -f "${PI0_TOKENIZER_DIR}/tokenizer.model" && -f "${PI0_TOKENIZER_DIR}/tokenizer_config.json" ]]; then
    echo "PaliGemma tokenizer already present at ${PI0_TOKENIZER_DIR}"
    return 0
  fi

  if [[ -z "${HF_TOKEN:-}" ]]; then
    echo "Skipping tokenizer download: HF_TOKEN is not set."
    echo "You must first accept the Google Gemma/PaliGemma license on Hugging Face."
    return 0
  fi

  local repo="google/paligemma-3b-pt-224"
  local files=(
    "config.json"
    "special_tokens_map.json"
    "tokenizer.json"
    "tokenizer.model"
    "tokenizer_config.json"
  )

  mkdir -p "${PI0_TOKENIZER_DIR}"

  echo "Downloading google/paligemma-3b-pt-224 tokenizer into ${PI0_TOKENIZER_DIR}"
  for file in "${files[@]}"; do
    local url="${HF_ENDPOINT}/${repo}/resolve/main/${file}"
    echo "  - ${file}"
    curl -L --fail --retry 3 \
      -H "Authorization: Bearer ${HF_TOKEN}" \
      -o "${PI0_TOKENIZER_DIR}/${file}" \
      "${url}"
  done
}

patch_preprocessor_if_tokenizer_exists() {
  if [[ -f "${PI0_TOKENIZER_DIR}/tokenizer.model" && -f "${PI0_TOKENIZER_DIR}/tokenizer_config.json" ]]; then
    "${LEROBOT_PYTHON}" "${ROOT_DIR}/jay-scripts/pi0/patch_pi0_tokenizer_path.py" \
      --policy-dir "${PI0_MODEL_DIR}" \
      --tokenizer-dir "${PI0_TOKENIZER_DIR}"
  else
    echo "Tokenizer files are still missing. policy_preprocessor.json remains unpatched."
  fi
}

ensure_sentencepiece
download_pi0_base
download_tokenizer_if_possible
patch_preprocessor_if_tokenizer_exists

echo
echo "Bootstrap finished."
echo "PI0 model dir: ${PI0_MODEL_DIR}"
echo "Tokenizer dir: ${PI0_TOKENIZER_DIR}"
