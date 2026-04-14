# Pi0 on SO101: Grabfruit Runbook

## Current State

- `lerobot/pi0_base` has been downloaded to:
  - `/home/johnny/self_learn_ws/lerobot/models/lerobot_pi0_base`
- A local Python dependency overlay now exists at:
  - `/home/johnny/self_learn_ws/lerobot/.vendor/pi0_pydeps`
- `sentencepiece` is installed into that overlay.
- The remaining external blocker is the gated tokenizer repo:
  - `google/paligemma-3b-pt-224`

## Why The Tokenizer Is Still Pending

`google/paligemma-3b-pt-224` is gated by Google's Gemma/PaliGemma license. The mirror metadata is reachable, but the actual files return `403` unless a Hugging Face token with accepted license terms is provided.

This means:

- Pi0 base weights are local already.
- Training and inference still need the tokenizer files.
- After you accept the license on Hugging Face and export `HF_TOKEN`, the bootstrap script can finish the tokenizer download and patch the local Pi0 preprocessor to use the local tokenizer path.

## One-Time Bootstrap

Run this in the `lerobot` repo root:

```bash
bash jay-scripts/pi0/bootstrap_pi0_assets.sh
```

If you have already accepted the Gemma/PaliGemma license on Hugging Face, export your token first:

```bash
export HF_TOKEN=hf_xxx
bash jay-scripts/pi0/bootstrap_pi0_assets.sh
```

## Local Verification

```bash
source jay-scripts/pi0/env_pi0.sh
"${LEROBOT_PYTHON}" jay-scripts/pi0/verify_pi0_setup.py
```

## Smoke Training

```bash
bash jay-scripts/pi0/train_grabfruit_pi0_smoke.sh
```

Default behavior:

- local `pi0_base`
- dataset `grabfruit/test`
- `front -> base_0_rgb`
- `side -> left_wrist_0_rgb`
- missing `right_wrist_0_rgb` is auto-padded by Pi0
- LoRA rank `4`
- `steps=1`
- `batch_size=1`
- `num_workers=0`

You can override the main knobs inline:

```bash
POLICY_DEVICE=cuda POLICY_DTYPE=bfloat16 BATCH_SIZE=1 STEPS=20 \
bash jay-scripts/pi0/train_grabfruit_pi0_smoke.sh
```

## Full First Run

```bash
bash jay-scripts/pi0/train_grabfruit_pi0_full.sh
```

Suggested first pass on a single card:

```bash
POLICY_DEVICE=cuda POLICY_DTYPE=bfloat16 BATCH_SIZE=1 NUM_WORKERS=2 STEPS=10000 \
bash jay-scripts/pi0/train_grabfruit_pi0_full.sh
```

## Validated On This Machine

Validated on `2026-04-14` with the local RTX 3090:

- GPU load test passed:
  - local `pi0_base` loads on `cuda` in about `5.6s`
  - steady GPU allocation after load is about `8.5 GiB`
- GPU smoke train passed:
  - `1 step`, `batch_size=1`, `num_workers=0`, `LoRA r=4`
  - output:
    `/home/johnny/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_smoke_gpu_1step_clean_v1`
- Short stability smoke passed:
  - `20 steps`, `batch_size=1`, `num_workers=0`, `LoRA r=4`
  - output:
    `/home/johnny/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_smoke_gpu_20step_clean_v1`
  - observed throughput:
    about `2.5 step/s`
  - final checkpoint:
    `/home/johnny/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_smoke_gpu_20step_clean_v1/checkpoints/000020/pretrained_model`

The trained LoRA checkpoint was also reloaded successfully with the same `rename_map`.

Important correction:

- do not add `--policy.empty_cameras=1` for `pi0_base`
- `pi0_base` already expects:
  - `observation.images.base_0_rgb`
  - `observation.images.left_wrist_0_rgb`
  - `observation.images.right_wrist_0_rgb`
- with your two-camera setup, only the missing `right_wrist_0_rgb` slot should be padded

## Second Pass: Relative Actions

Recompute stats first:

```bash
bash jay-scripts/pi0/recompute_relative_stats.sh
```

Then rerun training by adding these flags to the training shell script command if needed:

```bash
--policy.use_relative_actions=true \
--policy.relative_exclude_joints='["gripper"]'
```

The current helper scripts intentionally keep the first run in absolute-action mode. If you decide to switch to relative actions, either duplicate the full script or append those flags manually.

## Orin Deployment Notes

For Pi0 on Orin, use `examples/rtc/eval_with_real_robot.py`, not `lerobot-record`, as the first deployment entrypoint.

Camera naming should match Pi0 target keys directly on the robot side:

- main view: `base_0_rgb`
- second view: `left_wrist_0_rgb`

After training succeeds and the tokenizer is available locally, patch the trained checkpoint preprocessor before moving it to Orin:

```bash
source jay-scripts/pi0/env_pi0.sh
"${LEROBOT_PYTHON}" jay-scripts/pi0/patch_pi0_tokenizer_path.py \
  --policy-dir /home/johnny/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_lora/checkpoints/010000/pretrained_model \
  --tokenizer-dir "${PI0_TOKENIZER_DIR}"
```

On Orin, patch again to the Orin-local tokenizer path after transfer.

Example:

```bash
sed -i 's#google/paligemma-3b-pt-224#/home/agx-orin-mars01/lerobot_ws/models/google_paligemma_3b_pt_224_tokenizer#g' \
  /home/agx-orin-mars01/lerobot_ws/models/pretrained_model/policy_preprocessor.json
```

RTC evaluation shell template:

```bash
ROBOT_PORT=/dev/ttyACM0 \
ROBOT_ID=my_blue_follower_arm \
TASK='fruit grab wax apple' \
bash jay-scripts/pi0/eval_pi0_rtc_so101.sh
```

Reverse `scp` command printer:

```bash
bash jay-scripts/pi0/print_orin_pull_commands.sh \
  /home/johnny/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_lora/checkpoints/010000/pretrained_model
```

## Files Added For This Workflow

- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/env_pi0.sh`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/bootstrap_pi0_assets.sh`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/patch_pi0_tokenizer_path.py`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/verify_pi0_setup.py`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/train_grabfruit_pi0_smoke.sh`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/train_grabfruit_pi0_full.sh`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/recompute_relative_stats.sh`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/eval_pi0_rtc_so101.sh`
- `/home/johnny/self_learn_ws/lerobot/jay-scripts/pi0/print_orin_pull_commands.sh`
