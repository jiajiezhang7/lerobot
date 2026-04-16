# 新服务器模型微调迁移总手册

## 1. 文档定位

这份文档是给“另一台全新的服务器上的 code agent”看的第一份总手册。

目标不是解释 LeRobot 基础概念，而是把我们这台机器上已经跑通过、踩过坑、修过补丁的这一整套方法固定下来，让另一个 agent 直接照着复现：

- 把当前这份仓库迁移到新服务器
- 在新服务器上准备环境、模型、数据和缓存
- 用当前代码继续做 `ACT / PI0 / PI0Fast / GR00T` 相关训练和微调
- 重点复现 `GR00T N1.5 + grabfruit` 的 GPU 微调链路
- 避免重复踩我们已经踩过的坑

如果只能读一份文档，先读这一份。

## 2. 结论先行

### 2.1 当前仓库已经具备的能力

当前这份仓库已经包含以下模型的下载、加载、训练或微调代码：

| 模型 | 代码状态 | 入口方式 | 备注 |
|---|---|---|---|
| ACT | 已集成 | `lerobot-train --policy.type=act` | 基本走上游标准链路 |
| PI0 | 已集成 | `jay-scripts/pi0/` + `lerobot-train` | 本地有辅助脚本和路径修补 |
| PI0Fast | 已集成 | `jay-scripts/pi0_fast/` + `lerobot-train` | 本地有额外 tokenizer/processor 修补 |
| GR00T N1.5 | 已集成 | `lerobot-train --policy.type=groot` | 走本仓库集成，不走 NVIDIA 原仓库训练流程 |

### 2.2 最重要的现实

当前仓库不是一份“干净的官方上游仓库”。

它带有对训练有实际影响的**本地代码修改**，而且这些修改目前还没有全部提交到 git 远端。

因此，新服务器上最稳妥的做法不是：

```bash
git clone upstream
```

而是：

1. 直接复制当前整个工作树到新服务器。
2. 或者先把当前工作树提交到你自己的 fork，再在新服务器拉取。
3. 最差方案才是导出 patch 后手工应用。

不要假设“重新 clone 官方仓库后再装环境”就能复现出我们现在的结果，尤其是 `GR00T` 和 `PI0Fast`。

## 3. 总原则

### 3.1 复制整个工作树，而不是只复制远端仓库

优先复制：

- 全部源码
- `jay-scripts/`
- `jay-docs/`
- `artifacts/wheels/`
- 必要时连 `outputs/` 和 Hugging Face cache 一起复制

### 3.2 不在 `base` 环境里训练

所有训练都放进隔离的 `conda` 环境里。  
`base` 环境只用于系统管理，不用于模型训练。

### 3.3 先 smoke test，再正式训练

新服务器上：

1. 先验证 import 和 GPU
2. 再做 1 个极小 smoke test
3. smoke 通过后再开正式 run

### 3.4 显式验证 GPU 链路，不做想当然推断

特别是 `GR00T`：

- 要确认 `torch.cuda.is_available()` 为 `True`
- 要确认 `flash-attn` 真能 import
- 要确认日志里出现 `flash_attention_2`
- 要确认 `nvidia-smi` 里有训练进程

### 3.5 磁盘是训练的一部分

`GR00T` checkpoint 很大。  
如果不做轮转保存，磁盘会先满，训练后死。

因此当前做法是：

- `save_freq` 不要太密
- 只滚动保留最近 `1-2` 个 checkpoint
- 恢复训练时只从**完整 checkpoint**恢复

### 3.6 能离线就离线

模型、processor、数据、wheel 一旦在新服务器上落好，就优先走离线缓存。

我们当前实践里会用：

```bash
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_DATASETS_OFFLINE=1
```

## 4. 当前仓库里必须随迁的本地修改

下面这些文件不是“可有可无的实验代码”，而是当前训练链路里的关键改动：

### 4.1 GR00T 相关

- `src/lerobot/policies/groot/groot_n1.py`
  - 自动选择 `flash_attention_2 / sdpa / eager`
  - 避免 flash-attn 不可用时直接崩溃
  - 增加 `post_init()`
- `src/lerobot/policies/groot/eagle2_hg_model/modeling_eagle2_5_vl.py`
  - 放宽 Eagle/Qwen attention implementation 约束
  - 增加 `post_init()`
- `src/lerobot/policies/groot/eagle2_hg_model/processing_eagle2_5_vl.py`
  - 规范 image processor 输出为 tensor
  - 修正 GR00T processor 在新组合下的 shape 假设
- `src/lerobot/policies/groot/action_head/flow_matching_action_head.py`
  - 调整 Beta 分布采样，避免当前链路里的 dtype/device 问题

### 4.2 训练恢复与 checkpoint 管理

- `src/lerobot/configs/train.py`
  - 新增 `save_total_limit`
- `src/lerobot/utils/train_utils.py`
  - 新增 `prune_old_checkpoints`
- `src/lerobot/scripts/lerobot_train.py`
  - checkpoint 保存后自动 pruning
  - `resume=true` 时不再错误注入不匹配的 normalizer/unnormalizer override

### 4.3 PI0Fast / tokenizer / processor 相关

- `src/lerobot/policies/factory.py`
  - 为 `PI0Fast` 恢复 processor 时补齐 tokenizer override
- `src/lerobot/processor/tokenizer_processor.py`
  - 序列化 `fast_skip_tokens`
  - 序列化 `paligemma_tokenizer_name`

### 4.4 辅助文件和脚本

以下目录和脚本也要一起迁移：

- `jay-scripts/pi0/`
- `jay-scripts/pi0_fast/`
- `jay-scripts/smolvla/`
- `artifacts/wheels/flash_attn-2.8.3-cp312-cp312-linux_x86_64.whl`

## 5. 当前本机参考路径

这些不是绝对必须保持一致，但它们是当前成功实践的参考值：

| 项目 | 当前路径 |
|---|---|
| 仓库根目录 | `/home/johnny/self_learn_ws/lerobot` |
| 数据集根目录 | `/home/johnny/.cache/huggingface/lerobot/grabfruit/test` |
| flash-attn wheel | `/home/johnny/self_learn_ws/lerobot/artifacts/wheels/flash_attn-2.8.3-cp312-cp312-linux_x86_64.whl` |
| GR00T 输出目录 | `/home/johnny/self_learn_ws/lerobot/outputs/groot/grabfruit_ft_20260416_20k` |
| GR00T 可靠恢复点 | `.../checkpoints/005000` |
| 当前已生成的新 checkpoint | `.../checkpoints/010000` |

## 6. 数据集约定

### 6.1 真正的训练根目录

这次 `grabfruit` 的训练根目录不是父目录：

```bash
/home/johnny/.cache/huggingface/lerobot/grabfruit
```

而是：

```bash
/home/johnny/.cache/huggingface/lerobot/grabfruit/test
```

### 6.2 数据集事实

当前本地确认过的事实：

- LeRobot v3 数据
- 50 episodes
- 19378 frames
- 双相机视频
- 6 维 state
- 6 维 action
- 当前任务文本是 `fruit grab wax apple`

### 6.3 原则

- 不改原始数据集内容
- 不重新转格式
- 直接走当前仓库内置 LeRobot dataset 读取链路

## 7. 新服务器建议目录布局

建议统一放到一个 workspace，例如：

```text
~/self_learn_ws/lerobot
```

推荐结构：

```text
lerobot/
├── artifacts/
│   └── wheels/
├── jay-docs/
├── jay-scripts/
├── outputs/
├── src/
└── models/
```

如果要完全复刻当前经验，建议一并迁移：

- `~/.cache/huggingface/`
- 仓库里的 `artifacts/wheels/`

## 8. 新服务器启动前检查

先检查这些条件：

```bash
nvidia-smi
df -h
free -h
python3 --version
conda --version
```

最低要求：

- Linux
- NVIDIA 驱动正常
- 至少 1 张可用 GPU
- 建议至少 24GB 显存做 `GR00T`
- 建议至少 100GB 空闲磁盘

## 9. 环境策略

### 9.1 推荐环境划分

最稳妥的方式是：

- `lerobot` 或类似环境：跑 `ACT / PI0 / PI0Fast / SmolVLA`
- `lerobot-groot`：专门跑 `GR00T`

原因：

- `GR00T` 对 `flash-attn` 和 CUDA 用户态工具链要求更高
- 单独环境更容易排错，也不会污染其他模型链路

### 9.2 GR00T 环境标准做法

如果新服务器没有 `nvcc`，当前成功做法是直接在 conda 环境里装用户态 CUDA toolkit，再编译或安装 `flash-attn`。

```bash
conda create -y -n lerobot-groot python=3.12
conda activate lerobot-groot
conda install -y -c nvidia cuda-toolkit=12.4

export CUDA_HOME="$CONDA_PREFIX"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
export TORCH_CUDA_ARCH_LIST=8.6
export PIP_INDEX_URL=https://pypi.org/simple

pip install -U pip setuptools wheel
pip install --index-url https://download.pytorch.org/whl/cu124 torch==2.7.1 torchvision==0.22.1
pip install ninja "packaging>=24.2,<26.0"

MAX_JOBS=8 pip install --no-build-isolation flash-attn==2.8.3

cd ~/self_learn_ws/lerobot
pip install -e ".[pi,smolvla,peft,test]"
pip install -e ".[groot]"
```

### 9.3 保存本地 wheel

成功装好 `flash-attn` 后，把 wheel 固定保存下来，便于新服务器或后续环境复用：

```bash
mkdir -p artifacts/wheels
pip wheel --no-deps flash-attn==2.8.3 -w artifacts/wheels
```

当前本地已保存：

```text
artifacts/wheels/flash_attn-2.8.3-cp312-cp312-linux_x86_64.whl
```

### 9.4 环境验证

```bash
python - <<'PY'
import torch, flash_attn, transformers, accelerate, av, torchvision, lerobot
print(torch.__version__, torch.version.cuda)
print("cuda", torch.cuda.is_available(), "count", torch.cuda.device_count())
print("flash", flash_attn.__version__)
PY
```

必须满足：

- `torch.cuda.is_available()` 为 `True`
- `flash_attn` 可以 import
- `lerobot` 可以 import

## 10. 资源下载与缓存策略

### 10.1 PI0 / PI0Fast / SmolVLA

优先使用仓库内已有脚本和修补器，不要重新发明一套下载流程：

- `jay-scripts/pi0/bootstrap_pi0_assets.sh`
- `jay-scripts/pi0/patch_pi0_tokenizer_path.py`
- `jay-scripts/pi0/verify_pi0_setup.py`
- `jay-scripts/pi0_fast/bootstrap_pi0_fast_assets.sh`
- `jay-scripts/pi0_fast/patch_pi0_fast_local_paths.py`
- `jay-scripts/pi0_fast/verify_pi0_fast_setup.py`
- `jay-scripts/smolvla/patch_smolvla_local_paths.py`

### 10.2 GR00T

`GR00T` 当前走的是**本仓库集成**：

- 基础模型：`nvidia/GR00T-N1.5-3B`
- processor assets repo：`lerobot/eagle2hg-processor-groot-n1p5`
- vendor Eagle 文件会由当前代码复制到 Hugging Face cache

结论：

- 不用切到 NVIDIA 官方训练仓库
- 不用做 `modality.json` 那套数据转换
- 直接用本仓库的 `groot` policy 和 LeRobot dataset 即可

### 10.3 缓存 ready 后转离线

第一次把模型、processor 和数据拉下来以后，推荐后续训练都带上：

```bash
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_DATASETS_OFFLINE=1
```

## 11. 模型级工作流

### 11.1 ACT

`ACT` 当前基本是上游标准链路：

- 配置：`src/lerobot/policies/act/configuration_act.py`
- 模型：`src/lerobot/policies/act/modeling_act.py`
- processor：`src/lerobot/policies/act/processor_act.py`

做法：

- 直接用 `lerobot-train --policy.type=act`
- 不依赖本次新增的特殊补丁

### 11.2 PI0

优先走现有脚本：

- `jay-scripts/pi0/train_grabfruit_pi0_smoke.sh`
- `jay-scripts/pi0/train_grabfruit_pi0_full.sh`

原则：

- 用本地模型路径
- 先跑 verify 脚本
- smoke 通过再开 full

### 11.3 PI0Fast

优先走现有脚本：

- `jay-scripts/pi0_fast/train_grabfruit_pi0_fast_smoke.sh`
- `jay-scripts/pi0_fast/train_grabfruit_pi0_fast_full.sh`

必须保留的本地修补：

- `factory.py` 的 `PI0FastConfig` processor override 支持
- `tokenizer_processor.py` 的 tokenizer config 序列化补丁

否则恢复训练或从本地 tokenizer 路径加载时容易丢关键信息。

### 11.4 GR00T

这是当前最特殊、最依赖本地经验的一条链路。

核心原则：

1. 走本仓库的 `groot` policy，不走 NVIDIA 原仓库训练流程。
2. 用 `flash-attn`，并在日志中验证真的启用了 `flash_attention_2`。
3. 在 `RTX 3090 24GB` 上采用保守成功配置：
   - 冻结 LLM
   - 冻结视觉 backbone
   - 训练 projector
   - 不训练 diffusion model
4. 先 smoke，再 full。
5. checkpoint 只保留最近 `1-2` 个。

## 12. GR00T 标准命令

### 12.1 通用环境变量

```bash
export CUDA_VISIBLE_DEVICES=0
export TOKENIZERS_PARALLELISM=false
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_DATASETS_OFFLINE=1
```

### 12.2 GR00T smoke test

```bash
accelerate launch --num_processes 1 -m lerobot.scripts.lerobot_train \
  --output_dir=/home/johnny/self_learn_ws/lerobot/outputs/groot/grabfruit_smoke \
  --job_name=groot_grabfruit_smoke \
  --policy.type=groot \
  --policy.device=cuda \
  --policy.base_model_path=nvidia/GR00T-N1.5-3B \
  --policy.push_to_hub=false \
  --policy.embodiment_tag=new_embodiment \
  --policy.chunk_size=16 \
  --policy.n_action_steps=16 \
  --policy.tune_llm=false \
  --policy.tune_visual=false \
  --policy.tune_projector=true \
  --policy.tune_diffusion_model=false \
  --policy.use_bf16=true \
  --dataset.repo_id=grabfruit \
  --dataset.root=/home/johnny/.cache/huggingface/lerobot/grabfruit/test \
  --dataset.video_backend=pyav \
  --batch_size=1 \
  --num_workers=0 \
  --steps=2 \
  --save_checkpoint=true \
  --save_freq=1 \
  --log_freq=1 \
  --wandb.enable=false \
  --seed=1000
```

### 12.3 GR00T 正式训练推荐参数

当前建议直接把磁盘策略一开始就带上：

```bash
accelerate launch --num_processes 1 -m lerobot.scripts.lerobot_train \
  --output_dir=/home/johnny/self_learn_ws/lerobot/outputs/groot/grabfruit_ft_20260416_20k \
  --job_name=groot_grabfruit_n15_20k \
  --policy.type=groot \
  --policy.device=cuda \
  --policy.base_model_path=nvidia/GR00T-N1.5-3B \
  --policy.push_to_hub=false \
  --policy.embodiment_tag=new_embodiment \
  --policy.chunk_size=16 \
  --policy.n_action_steps=16 \
  --policy.tune_llm=false \
  --policy.tune_visual=false \
  --policy.tune_projector=true \
  --policy.tune_diffusion_model=false \
  --policy.use_bf16=true \
  --dataset.repo_id=grabfruit \
  --dataset.root=/home/johnny/.cache/huggingface/lerobot/grabfruit/test \
  --dataset.video_backend=pyav \
  --batch_size=1 \
  --num_workers=4 \
  --steps=20000 \
  --save_checkpoint=true \
  --save_freq=5000 \
  --save_total_limit=2 \
  --log_freq=20 \
  --wandb.enable=false \
  --seed=1000
```

### 12.4 从可靠 checkpoint 恢复训练

恢复时不要直接把 `checkpoint_path` 手写成训练状态目录。  
当前训练入口的正确做法是：

- `--config_path=<checkpoint>/pretrained_model/train_config.json`
- `--resume=true`

示例：

```bash
accelerate launch --num_processes 1 -m lerobot.scripts.lerobot_train \
  --config_path=/home/johnny/self_learn_ws/lerobot/outputs/groot/grabfruit_ft_20260416_20k/checkpoints/005000/pretrained_model/train_config.json \
  --resume=true \
  --save_freq=5000 \
  --save_total_limit=2 \
  --steps=20000
```

## 13. GR00T 成功判据

至少满足：

1. `nvidia-smi` 里有训练进程。
2. 日志里出现：
   - `flash-attn`
   - `[GROOT] Using Eagle attention implementation: flash_attention_2`
3. checkpoint 目录中出现：
   - `pretrained_model/model.safetensors`
   - `pretrained_model/config.json`
   - `pretrained_model/train_config.json`
4. `last` symlink 指向最新 checkpoint。
5. 如果启用了 `save_total_limit=2`，旧 checkpoint 会被自动清理。

## 14. 磁盘与 checkpoint 策略

### 14.1 当前策略

现在代码已经支持：

- `save_freq`
- `save_total_limit`
- 自动 pruning 老 checkpoint

推荐：

- `save_freq=5000`
- `save_total_limit=2`

### 14.2 恢复前只信完整 checkpoint

判断 checkpoint 是否完整，看：

```text
checkpoints/<step>/training_state/
├── optimizer_param_groups.json
├── optimizer_state.safetensors
├── rng_state.safetensors
├── scheduler_state.json
└── training_step.json
```

如果这些不齐，不要拿它恢复。

### 14.3 空间清理优先级

磁盘不够时优先删：

1. 旧 smoke 输出
2. 老 checkpoint
3. 不完整 checkpoint
4. `~/.cache/pip`

不要先删：

- 最近一个可靠 checkpoint
- 当前正在写的 checkpoint

## 15. 新服务器迁移的推荐顺序

### 15.1 最稳妥顺序

1. 把当前整个仓库工作树复制到新服务器。
2. 如果条件允许，再把 `~/.cache/huggingface` 也复制过去。
3. 创建隔离 conda 环境。
4. 安装 GPU 版 PyTorch。
5. 安装 `flash-attn` 并验证。
6. `pip install -e` 当前仓库。
7. 验证模型 import 与 CLI。
8. 跑 smoke。
9. smoke 通过后跑 full。
10. 如果中断，只从完整 checkpoint 恢复。

### 15.2 如果不能直接复制整个仓库

次优方案：

1. 先把当前所有本地修改提交到自己的 fork。
2. 新服务器 clone 你的 fork。
3. 再同步模型和数据缓存。

不要用“官方上游纯净代码 + 人脑回忆 patch”的方式复现。

## 16. 给下一位 code agent 的执行要求

下一位 agent 上手时，应当先完成下面这个 checklist：

1. 先读本文件。
2. 执行 `git status --short`，确认本地是否为我们这份工作树。
3. 检查 `jay-scripts/`、`artifacts/wheels/` 是否齐全。
4. 检查数据集根目录是否真的是 `grabfruit/test`。
5. 检查 `flash-attn` 是否可用。
6. 对 `GR00T` 必须先 smoke。
7. 正式训练必须启用 checkpoint 轮转。
8. 恢复训练必须用 `config_path + resume=true`。

## 17. 相关文档

这份文档是总入口，其他细分文档可以配合看：

- `jay-docs/NVIDIA_SERVER_FINETUNE_RUNBOOK.md`
- `jay-docs/PI0_SO101_RUNBOOK.md`
- `jay-docs/SO101_DISTRIBUTED_DEPLOYMENT.md`
- `jay-docs/SELF_LEARN_WORKFLOW.md`

## 18. 一句话总结

新服务器复现时，最核心的不是“重新安装一遍 LeRobot”，而是：

- 复制当前这份带本地修补的仓库
- 用隔离 GPU 环境安装依赖
- 先验证 `flash-attn`
- 先 smoke 再 full
- 用滚动 checkpoint 策略跑 `GR00T`
- 只从完整 checkpoint 恢复

