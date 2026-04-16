#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/jay-scripts/pi0_fast/env_pi0_fast.sh"

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
sys.path.insert(0, ".vendor/pi0_fast_pydeps")
import sentencepiece
PY
    echo "sentencepiece already available through ${ROOT_DIR}/.vendor/pi0_fast_pydeps."
    return 0
  fi

  echo "Installing sentencepiece into ${ROOT_DIR}/.vendor/pi0_fast_pydeps ..."
  "${LEROBOT_PYTHON}" -m pip install sentencepiece -t "${ROOT_DIR}/.vendor/pi0_fast_pydeps"
}

download_snapshot_with_fallback() {
  local target_dir="$1"
  shift
  local hfd
  hfd="$(resolve_hfd)"

  if [[ -f "${target_dir}/config.json" || -f "${target_dir}/tokenizer_config.json" ]]; then
    echo "Assets already present at ${target_dir}"
    return 0
  fi

  local repo
  local tmp_dir
  for repo in "$@"; do
    tmp_dir="$(mktemp -d "${ROOT_DIR}/models/.tmp_$(basename "${target_dir}").XXXXXX")"
    echo "Downloading ${repo} into temporary dir ${tmp_dir}"
    if HF_ENDPOINT="${HF_ENDPOINT}" bash "${hfd}" "${repo}" --local-dir "${tmp_dir}"; then
      rm -rf "${target_dir}"
      mv "${tmp_dir}" "${target_dir}"
      echo "Downloaded ${repo} into ${target_dir}"
      return 0
    fi
    rm -rf "${tmp_dir}"
    echo "Download failed for ${repo}, trying next candidate..."
  done

  echo "All download candidates failed for ${target_dir}" >&2
  return 1
}

download_pi0_fast_base() {
  download_snapshot_with_fallback \
    "${PI0_FAST_MODEL_DIR}" \
    "lerobot/pi0fast-base" \
    "lerobot/pi0fast_base"
}

download_fast_action_tokenizer() {
  download_snapshot_with_fallback \
    "${PI0_FAST_ACTION_TOKENIZER_DIR}" \
    "lerobot/fast-action-tokenizer"
}

download_text_tokenizer_if_possible() {
  if [[ -f "${PI0_FAST_TEXT_TOKENIZER_DIR}/tokenizer.model" && -f "${PI0_FAST_TEXT_TOKENIZER_DIR}/tokenizer_config.json" ]]; then
    echo "PaliGemma tokenizer already present at ${PI0_FAST_TEXT_TOKENIZER_DIR}"
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

  mkdir -p "${PI0_FAST_TEXT_TOKENIZER_DIR}"

  echo "Downloading google/paligemma-3b-pt-224 tokenizer into ${PI0_FAST_TEXT_TOKENIZER_DIR}"
  for file in "${files[@]}"; do
    local url="${HF_ENDPOINT}/${repo}/resolve/main/${file}"
    echo "  - ${file}"
    curl -L --fail --retry 3 \
      -H "Authorization: Bearer ${HF_TOKEN}" \
      -o "${PI0_FAST_TEXT_TOKENIZER_DIR}/${file}" \
      "${url}"
  done
}

patch_assets_if_ready() {
  if [[ -f "${PI0_FAST_MODEL_DIR}/config.json" && -f "${PI0_FAST_MODEL_DIR}/policy_preprocessor.json" && -f "${PI0_FAST_TEXT_TOKENIZER_DIR}/tokenizer.model" && -f "${PI0_FAST_ACTION_TOKENIZER_DIR}/tokenizer_config.json" ]]; then
    "${LEROBOT_PYTHON}" "${ROOT_DIR}/jay-scripts/pi0_fast/patch_pi0_fast_local_paths.py" \
      --policy-dir "${PI0_FAST_MODEL_DIR}" \
      --text-tokenizer-dir "${PI0_FAST_TEXT_TOKENIZER_DIR}" \
      --action-tokenizer-dir "${PI0_FAST_ACTION_TOKENIZER_DIR}"
  else
    echo "Some Pi0-Fast assets are still missing. Skipping local path patch."
  fi
}

ensure_sentencepiece
download_pi0_fast_base
download_fast_action_tokenizer
download_text_tokenizer_if_possible
patch_assets_if_ready

echo
echo "Bootstrap finished."
echo "PI0-Fast model dir: ${PI0_FAST_MODEL_DIR}"
echo "Text tokenizer dir: ${PI0_FAST_TEXT_TOKENIZER_DIR}"
echo "Action tokenizer dir: ${PI0_FAST_ACTION_TOKENIZER_DIR}"
