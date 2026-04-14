# NVIDIA GPU 服务器训练总手册

## 目标

这份文档用于在一台全新的、搭载 NVIDIA GPU 的 Linux 服务器上，从零开始复现当前这套 LeRobot 微调流程。

覆盖范围：

- 创建 `conda` 环境
- 安装当前仓库版本的 `lerobot`
- 使用 `hf-mirror + hfd` 下载模型
- 准备 LeRobot v3 数据集
- 微调 `SmolVLA`
- 微调 `Pi0`
- 记录输出、恢复训练、排错

这份手册默认你要训练的是当前已经验证过的这一套：

- 数据集：`grabfruit/test`
- 本地数据根目录：`~/.cache/huggingface/lerobot/grabfruit/test`
- SmolVLA 本地模型：
  - `models/lerobot_smolvla_base`
  - `models/HuggingFaceTB_SmolVLM2-500M-Video-Instruct`
- Pi0 本地模型：
  - `models/lerobot_pi0_base`
  - `models/google_paligemma_3b_pt_224_tokenizer`

## 重要前提

这份文档假设你使用的是当前这个仓库版本，而不是一份干净的上游发行版。

原因：

- 当前仓库已经包含了 Pi0 的本地优化与修复：
  - `src/lerobot/policies/pi0/modeling_pi0.py`
- 当前仓库已经包含 Pi0 训练脚本：
  - `jay-scripts/pi0/`
- 当前仓库现在还新增了 SmolVLA 的本地路径修补脚本：
  - `jay-scripts/smolvla/patch_smolvla_local_paths.py`

如果你要在新服务器复现，最稳妥的方法不是重新手敲一遍，而是直接把当前整个仓库目录复制过去，再按本文档执行。

## 标准目录布局

建议在新服务器统一放在同一个工作区，例如：

```bash
~/self_learn_ws/lerobot
```

仓库内部最终建议保持如下结构：

```text
lerobot/
├── models/
│   ├── lerobot_smolvla_base/
│   ├── HuggingFaceTB_SmolVLM2-500M-Video-Instruct/
│   ├── lerobot_pi0_base/
│   └── google_paligemma_3b_pt_224_tokenizer/
├── outputs/
│   └── train/
├── outputs/train_logs/
├── jay-docs/
├── jay-scripts/
└── src/
```

## 0. 服务器最低检查

先确保这些条件成立：

- 系统是 Linux
- `nvidia-smi` 正常
- GPU 显存至少 `24 GiB` 更舒服
- 磁盘至少预留 `100 GiB`
- 已安装 `conda`
- 当前用户对工作目录有读写权限

建议先执行：

```bash
nvidia-smi
python3 --version
conda --version
df -h
free -h
```

如果 `nvidia-smi` 不通，不要继续安装训练环境，先修驱动。

## 1. 系统依赖

进入新服务器后先装基础依赖：

```bash
sudo apt update
sudo apt install -y git git-lfs curl wget aria2 ffmpeg build-essential
git lfs install
```

`hfd.sh` 依赖 `aria2`，所以这一步不要漏。

## 2. 获取当前仓库

最稳妥方案：

1. 在旧机器上把当前整个仓库打包或 `rsync/scp`
2. 在新服务器放到目标位置

如果你只是从 Git 重新拉代码，也至少要确认这些本地文件存在：

- `jay-scripts/pi0/bootstrap_pi0_assets.sh`
- `jay-scripts/pi0/train_grabfruit_pi0_smoke.sh`
- `jay-scripts/pi0/train_grabfruit_pi0_full.sh`
- `jay-scripts/smolvla/patch_smolvla_local_paths.py`
- `src/lerobot/policies/pi0/modeling_pi0.py`

## 3. 创建 conda 环境

当前仓库 `pyproject.toml` 要求 Python `>=3.12`，因此直接用 `3.12`：

```bash
conda create -n lerobot python=3.12 -y
conda activate lerobot
```

建议升级基础工具：

```bash
python -m pip install --upgrade pip setuptools wheel
```

## 4. 安装 GPU 版 PyTorch

优先安装你服务器对应 CUDA 的 GPU 版 PyTorch。  
如果你不确定，先去 PyTorch 官方安装页选当前系统和 CUDA 版本。

一个常用例子是 CUDA 12.8：

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

安装后立刻验证：

```bash
python - <<'PY'
import torch
print("cuda_available =", torch.cuda.is_available())
print("device_count =", torch.cuda.device_count())
if torch.cuda.is_available():
    print("device_name =", torch.cuda.get_device_name(0))
PY
```

如果这里不通，不要继续。

## 5. 安装当前仓库版本的 LeRobot

进入仓库根目录：

```bash
cd ~/self_learn_ws/lerobot
```

安装训练所需 extras：

```bash
pip install -e ".[smolvla,pi,peft]"
pip install sentencepiece
```

说明：

- `smolvla`：SmolVLA 相关依赖
- `pi`：Pi0 相关依赖
- `peft`：LoRA 相关依赖
- `sentencepiece`：Pi0 tokenizer 额外必需，本仓库 extras 里没有自动带上

验证 CLI：

```bash
lerobot-train --help >/dev/null
```

如果 `lerobot-train` 不在 PATH，可以统一改用：

```bash
python -m lerobot.scripts.lerobot_train --help >/dev/null
```

## 6. 配置 hf-mirror 和 hfd

### 6.1 准备 hfd

如果新服务器还没有 `hfd.sh`，先下载一份，例如放到：

```bash
~/tts_ws/hfd.sh
```

然后：

```bash
chmod +x ~/tts_ws/hfd.sh
```

后面统一用：

```bash
export HFD_SCRIPT=~/tts_ws/hfd.sh
export HF_ENDPOINT=https://hf-mirror.com
```

### 6.2 Hugging Face Token

Pi0 需要下载 gated 的 `google/paligemma-3b-pt-224` tokenizer。  
因此你需要：

1. 在 Hugging Face 网页上先接受 Gemma / PaliGemma 的 license
2. 准备自己的 `HF_TOKEN`

然后在 shell 中设置：

```bash
export HF_TOKEN=你的_TOKEN
```

不要把 token 写进文档、脚本或仓库。

## 7. 准备数据集

### 7.1 标准位置

当前流程默认数据集放在：

```bash
~/.cache/huggingface/lerobot/grabfruit/test
```

### 7.2 从旧机器复制

如果数据集已经在旧机器上，直接复制整个目录：

```bash
mkdir -p ~/.cache/huggingface/lerobot/grabfruit
scp -r OLD_HOST:~/.cache/huggingface/lerobot/grabfruit/test \
  ~/.cache/huggingface/lerobot/grabfruit/
```

### 7.3 检查数据集

```bash
python - <<'PY'
import json
from pathlib import Path
info = Path.home() / ".cache/huggingface/lerobot/grabfruit/test/meta/info.json"
obj = json.loads(info.read_text())
print("episodes =", obj["total_episodes"])
print("frames   =", obj["total_frames"])
print("fps      =", obj["fps"])
print("robot    =", obj["robot_type"])
PY
```

如果这里都读不到，训练不要开始。

## 8. 下载与本地化 SmolVLA

SmolVLA 训练时真正需要两套东西：

- `lerobot/smolvla_base`
- `HuggingFaceTB/SmolVLM2-500M-Video-Instruct`

只下第一套不够，第二套不本地化，训练时会联网。

### 8.1 下载模型

```bash
cd ~/self_learn_ws/lerobot
export HFD_SCRIPT=~/tts_ws/hfd.sh
export HF_ENDPOINT=https://hf-mirror.com

bash "${HFD_SCRIPT}" lerobot/smolvla_base \
  --local-dir ./models/lerobot_smolvla_base

bash "${HFD_SCRIPT}" HuggingFaceTB/SmolVLM2-500M-Video-Instruct \
  --local-dir ./models/HuggingFaceTB_SmolVLM2-500M-Video-Instruct
```

### 8.2 修补本地路径

下载完成后，把 `smolvla_base` 的配置改到本地路径：

```bash
python ./jay-scripts/smolvla/patch_smolvla_local_paths.py \
  --policy-dir ./models/lerobot_smolvla_base \
  --vlm-dir ./models/HuggingFaceTB_SmolVLM2-500M-Video-Instruct
```

这个步骤会同时修补：

- `models/lerobot_smolvla_base/config.json`
- `models/lerobot_smolvla_base/policy_preprocessor.json`

### 8.3 检查

```bash
python - <<'PY'
import json
from pathlib import Path
cfg = json.loads(Path("models/lerobot_smolvla_base/config.json").read_text())
print("vlm_model_name =", cfg["vlm_model_name"])
PY
```

## 9. 下载与本地化 Pi0

Pi0 已经有现成脚本，直接用。

```bash
cd ~/self_learn_ws/lerobot
export HFD_SCRIPT=~/tts_ws/hfd.sh
export HF_ENDPOINT=https://hf-mirror.com
export HF_TOKEN=你的_TOKEN

bash jay-scripts/pi0/bootstrap_pi0_assets.sh
```

脚本会完成：

- 安装 `sentencepiece` 检查
- 下载 `lerobot/pi0_base`
- 下载 `google/paligemma-3b-pt-224` tokenizer 必需文件
- 修补 `policy_preprocessor.json` 到本地 tokenizer 路径

验证：

```bash
source jay-scripts/pi0/env_pi0.sh
"${LEROBOT_PYTHON}" jay-scripts/pi0/verify_pi0_setup.py
```

## 10. 当前数据集的相机映射

当前 `grabfruit/test` 数据集原始相机键名是：

- `observation.images.front`
- `observation.images.side`

### 10.1 SmolVLA

当前这套数据集已经实际训练成功的映射是：

```text
front -> observation.images.camera1
side  -> observation.images.camera3
```

因此命令里用：

```bash
--rename_map='{"observation.images.front":"observation.images.camera1","observation.images.side":"observation.images.camera3"}'
```

### 10.2 Pi0

当前这套数据集已经实际训练成功的映射是：

```text
front -> observation.images.base_0_rgb
side  -> observation.images.left_wrist_0_rgb
```

因此命令里用：

```bash
--rename_map='{"observation.images.front":"observation.images.base_0_rgb","observation.images.side":"observation.images.left_wrist_0_rgb"}'
```

重要说明：

- `pi0_base` 已经自带三路视觉槽位：
  - `base_0_rgb`
  - `left_wrist_0_rgb`
  - `right_wrist_0_rgb`
- 不要再额外传 `--policy.empty_cameras=1`
- 缺失的 `right_wrist_0_rgb` 会在 Pi0 预处理里自动补空图

## 11. SmolVLA 训练

### 11.1 当前已验证配置

当前已经训练成功的 SmolVLA 任务参数是：

- 模型：`models/lerobot_smolvla_base`
- 数据集：`grabfruit/test`
- batch size：`32`
- steps：`20000`
- 设备：`cuda`
- 输出目录：`outputs/train/fruit_smolvla`

### 11.2 训练命令

```bash
cd ~/self_learn_ws/lerobot

python -m lerobot.scripts.lerobot_train \
  --policy.path=/home/$USER/self_learn_ws/lerobot/models/lerobot_smolvla_base \
  --dataset.repo_id=grabfruit/test \
  --dataset.root=/home/$USER/.cache/huggingface/lerobot/grabfruit/test \
  --rename_map='{"observation.images.front":"observation.images.camera1","observation.images.side":"observation.images.camera3"}' \
  --batch_size=32 \
  --steps=20000 \
  --output_dir=/home/$USER/self_learn_ws/lerobot/outputs/train/fruit_smolvla \
  --job_name=my_smolvla_training \
  --policy.device=cuda \
  --wandb.enable=false \
  --policy.push_to_hub=false
```

### 11.3 训练结果目录

最终 checkpoint 示例：

```text
outputs/train/fruit_smolvla/checkpoints/020000/pretrained_model
```

## 12. Pi0 训练

### 12.1 先做 smoke train

先跑一个极小 smoke，验证环境：

```bash
cd ~/self_learn_ws/lerobot
POLICY_DEVICE=cuda POLICY_DTYPE=bfloat16 BATCH_SIZE=1 STEPS=20 NUM_WORKERS=0 PEFT_R=4 \
bash jay-scripts/pi0/train_grabfruit_pi0_smoke.sh --save_freq=20 --log_freq=5
```

### 12.2 当前已验证的正式训练配置

当前已经验证通过的 Pi0 正式训练基线是：

- `batch_size=1`
- `num_workers=0`
- `steps=10000`
- `LoRA r=16`
- `bfloat16`

已完成结果示例：

```text
outputs/train/pi0_grabfruit_lora_10k_run1/checkpoints/010000/pretrained_model
```

### 12.3 启动 10k 训练

```bash
cd ~/self_learn_ws/lerobot

POLICY_DEVICE=cuda \
POLICY_DTYPE=bfloat16 \
BATCH_SIZE=1 \
NUM_WORKERS=0 \
STEPS=10000 \
PEFT_R=16 \
OUTPUT_DIR=/home/$USER/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_lora_10k_run1 \
JOB_NAME=pi0_grabfruit_lora_10k_run1 \
bash jay-scripts/pi0/train_grabfruit_pi0_full.sh \
  --save_freq=1000 \
  --log_freq=20
```

### 12.4 启动 20k 训练

如果你要和 10k 公平对比，只改步数，不改 batch、LoRA、worker：

```bash
cd ~/self_learn_ws/lerobot

POLICY_DEVICE=cuda \
POLICY_DTYPE=bfloat16 \
BATCH_SIZE=1 \
NUM_WORKERS=0 \
STEPS=20000 \
PEFT_R=16 \
OUTPUT_DIR=/home/$USER/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_lora_20k_run1 \
JOB_NAME=pi0_grabfruit_lora_20k_run1 \
bash jay-scripts/pi0/train_grabfruit_pi0_full.sh \
  --save_freq=2000 \
  --log_freq=20
```

## 13. 后台运行与日志

推荐用 `nohup`：

```bash
nohup env POLICY_DEVICE=cuda POLICY_DTYPE=bfloat16 BATCH_SIZE=1 NUM_WORKERS=0 STEPS=20000 PEFT_R=16 \
  OUTPUT_DIR=/home/$USER/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_lora_20k_run1 \
  JOB_NAME=pi0_grabfruit_lora_20k_run1 \
  HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 HF_DATASETS_OFFLINE=1 \
  bash /home/$USER/self_learn_ws/lerobot/jay-scripts/pi0/train_grabfruit_pi0_full.sh \
  --save_freq=2000 --log_freq=20 \
  > /home/$USER/self_learn_ws/lerobot/outputs/train_logs/pi0_grabfruit_lora_20k_run1.log 2>&1 &
```

查看进度：

```bash
tail -f /home/$USER/self_learn_ws/lerobot/outputs/train_logs/pi0_grabfruit_lora_20k_run1.log
```

查看显卡占用：

```bash
nvidia-smi
```

## 14. 恢复训练

如果中断了，使用最近 checkpoint 的 `train_config.json`：

```bash
python -m lerobot.scripts.lerobot_train \
  --resume=true \
  --config_path=/home/$USER/self_learn_ws/lerobot/outputs/train/pi0_grabfruit_lora_20k_run1/checkpoints/020000/pretrained_model/train_config.json
```

SmolVLA 同理，把路径换成对应 checkpoint。

## 15. 训练完成后应保留什么

真正需要保留和迁移的是 checkpoint 里的 `pretrained_model/`：

- SmolVLA：
  - `outputs/train/fruit_smolvla/checkpoints/020000/pretrained_model`
- Pi0：
  - `outputs/train/pi0_grabfruit_lora_10k_run1/checkpoints/010000/pretrained_model`
  - `outputs/train/pi0_grabfruit_lora_20k_run1/checkpoints/020000/pretrained_model`

如果只是要部署和评估，不必复制整个 `training_state/`。

## 16. 常见错误与处理

### 16.1 `policy.repo_id argument missing`

原因：

- 默认想推 Hugging Face Hub，但你没给 repo id

处理：

```bash
--policy.push_to_hub=false
```

### 16.2 SmolVLA 训练时还在访问 `HuggingFaceTB/SmolVLM2-500M-Video-Instruct`

原因：

- 只下载了 `smolvla_base`
- 或者没有修补 `config.json` / `policy_preprocessor.json`

处理：

```bash
python ./jay-scripts/smolvla/patch_smolvla_local_paths.py \
  --policy-dir ./models/lerobot_smolvla_base \
  --vlm-dir ./models/HuggingFaceTB_SmolVLM2-500M-Video-Instruct
```

### 16.3 Pi0 下载 tokenizer 时报 403

原因：

- 没有接受 Gemma / PaliGemma license
- 或者没设置 `HF_TOKEN`

处理：

1. 去 Hugging Face 网页接受 license
2. `export HF_TOKEN=...`
3. 重跑 `bash jay-scripts/pi0/bootstrap_pi0_assets.sh`

### 16.4 Pi0 相机配置报错

不要加：

```bash
--policy.empty_cameras=1
```

对于 `pi0_base`，当前 front/side 数据集只需要：

```bash
--rename_map='{"observation.images.front":"observation.images.base_0_rgb","observation.images.side":"observation.images.left_wrist_0_rgb"}'
```

### 16.5 GPU 在 shell 里正常，但 Python 看不到

检查：

```bash
nvidia-smi
python - <<'PY'
import torch
print(torch.cuda.is_available())
print(torch.cuda.device_count())
PY
```

如果 `nvidia-smi` 正常但 `torch.cuda.is_available()` 是 `False`，通常是 PyTorch 装成了 CPU 版。

## 17. 最小执行清单

如果你只想最短路径把新服务器拉起来，按这个顺序：

1. 装系统依赖
2. 复制当前仓库到新服务器
3. 创建 `conda` 环境：`python=3.12`
4. 安装 GPU 版 PyTorch
5. `pip install -e ".[smolvla,pi,peft]" && pip install sentencepiece`
6. 配置 `HF_ENDPOINT`、`HFD_SCRIPT`
7. 复制数据集到 `~/.cache/huggingface/lerobot/grabfruit/test`
8. 下载 SmolVLA 两套模型并运行 `patch_smolvla_local_paths.py`
9. 运行 `bash jay-scripts/pi0/bootstrap_pi0_assets.sh`
10. 先做 smoke train
11. 再启动正式训练

做到这里，你就已经可以在一台全新的 NVIDIA GPU 服务器上复现当前这套 SmolVLA / Pi0 微调流程。
