#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/jay-scripts/pi0/env_pi0.sh"

POLICY_PATH="${POLICY_PATH:-${ROOT_DIR}/outputs/train/pi0_grabfruit_lora/checkpoints/010000/pretrained_model}"
ROBOT_TYPE="${ROBOT_TYPE:-so101_follower}"
ROBOT_PORT="${ROBOT_PORT:?set ROBOT_PORT, e.g. /dev/ttyACM0}"
ROBOT_ID="${ROBOT_ID:?set ROBOT_ID, e.g. my_blue_follower_arm}"
TASK="${TASK:?set TASK, e.g. 'fruit grab wax apple'}"
DURATION="${DURATION:-120}"
DEVICE="${DEVICE:-cuda}"
POLICY_DEVICE="${POLICY_DEVICE:-${DEVICE}}"
RTC_EXECUTION_HORIZON="${RTC_EXECUTION_HORIZON:-20}"
RTC_MAX_GUIDANCE_WEIGHT="${RTC_MAX_GUIDANCE_WEIGHT:-5.0}"
RTC_PREFIX_ATTENTION_SCHEDULE="${RTC_PREFIX_ATTENTION_SCHEDULE:-LINEAR}"

ROBOT_CAMERAS="${ROBOT_CAMERAS:-{ base_0_rgb: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30, fourcc: \"MJPG\"}, left_wrist_0_rgb: {type: opencv, index_or_path: 2, width: 640, height: 480, fps: 30, fourcc: \"MJPG\"} }}"

"${LEROBOT_PYTHON}" examples/rtc/eval_with_real_robot.py \
  --policy.path="${POLICY_PATH}" \
  --policy.device="${POLICY_DEVICE}" \
  --robot.type="${ROBOT_TYPE}" \
  --robot.port="${ROBOT_PORT}" \
  --robot.id="${ROBOT_ID}" \
  --robot.cameras="${ROBOT_CAMERAS}" \
  --task="${TASK}" \
  --duration="${DURATION}" \
  --device="${DEVICE}" \
  --rtc.enabled=true \
  --rtc.execution_horizon="${RTC_EXECUTION_HORIZON}" \
  --rtc.max_guidance_weight="${RTC_MAX_GUIDANCE_WEIGHT}" \
  --rtc.prefix_attention_schedule="${RTC_PREFIX_ATTENTION_SCHEDULE}" \
  "$@"
