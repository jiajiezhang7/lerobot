#!/usr/bin/env bash
set -euo pipefail

POLICY_PATH="${1:?usage: $0 /abs/path/to/pretrained_model}"
SOURCE_HOST="${SOURCE_HOST:?set SOURCE_HOST, e.g. johnny@10.19.131.221}"
ORIN_MODEL_DIR="${ORIN_MODEL_DIR:?set ORIN_MODEL_DIR, e.g. /home/agx-orin-mars01/lerobot_ws/models}"
TOKENIZER_SOURCE="${TOKENIZER_SOURCE:?set TOKENIZER_SOURCE, e.g. /home/johnny/self_learn_ws/lerobot/models/google_paligemma_3b_pt_224_tokenizer}"

echo "Run these commands on Orin:"
echo
echo "mkdir -p ${ORIN_MODEL_DIR}"
echo "scp -r ${SOURCE_HOST}:${POLICY_PATH} ${ORIN_MODEL_DIR}/"
echo "scp -r ${SOURCE_HOST}:${TOKENIZER_SOURCE} ${ORIN_MODEL_DIR}/"
echo
echo "# After transfer, patch the checkpoint preprocessor on Orin:"
echo "sed -i 's#google/paligemma-3b-pt-224#${ORIN_MODEL_DIR}/google_paligemma_3b_pt_224_tokenizer#g' \\"
echo "  ${ORIN_MODEL_DIR}/$(basename "${POLICY_PATH}")/policy_preprocessor.json"
