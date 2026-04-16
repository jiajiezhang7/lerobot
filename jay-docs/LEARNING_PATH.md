# LeRobot 学习路径指南

> 🤗 LeRobot 是 Hugging Face 开发的机器人学习库，旨在为真实世界机器人提供模型、数据集和工具。本指南将帮助你由浅入深地掌握这个项目。

---

## 📋 目录

0. [实战迁移入口](#0-实战迁移入口)
1. [项目概览](#1-项目概览)
2. [环境搭建](#2-环境搭建)
3. [学习阶段一：基础概念](#3-学习阶段一基础概念)
4. [学习阶段二：数据集系统](#4-学习阶段二数据集系统)
5. [学习阶段三：策略与模型](#5-学习阶段三策略与模型)
6. [学习阶段四：硬件集成](#6-学习阶段四硬件集成)
7. [学习阶段五：训练与评估](#7-学习阶段五训练与评估)
8. [学习阶段六：高级主题](#8-学习阶段六高级主题)
9. [推荐学习资源](#9-推荐学习资源)
10. [项目架构速查](#10-项目架构速查)

---

## 0. 实战迁移入口

如果你的目标不是“学习源码”，而是把当前这套训练/微调流程复刻到另一台新服务器，先读：

- `jay-docs/NEW_SERVER_MODEL_FINETUNE_TRANSFER_RUNBOOK.md`
- `jay-docs/NVIDIA_SERVER_FINETUNE_RUNBOOK.md`

其中第一份是当前这套工作树的总入口，覆盖了：

- 当前仓库里 ACT / PI0 / PI0Fast / GR00T 的实际支持情况
- 当前本地未提交补丁对训练链路的影响
- 新服务器环境、缓存、wheel、smoke、full、resume 的标准做法
- GR00T 的 flash-attn、checkpoint 轮转、磁盘治理经验

---

## 1. 项目概览

### 1.1 LeRobot 是什么？

LeRobot 是一个用于真实世界机器人的 PyTorch 机器学习库，核心目标是：

- **硬件无关的统一接口**：标准化控制各种机器人平台
- **标准化数据格式**：LeRobotDataset 格式（Parquet + MP4）
- **SOTA 策略实现**：模仿学习、强化学习、VLA 模型
- **开源生态支持**：与 Hugging Face Hub 深度集成

### 1.2 核心能力

| 能力 | 描述 |
|------|------|
| 🤖 机器人控制 | 支持 SO100/101, Koch, LeKiwi, Reachy2, Unitree G1 等 |
| 📊 数据集管理 | 录制、存储、流式加载、可视化 |
| 🧠 策略训练 | ACT, Diffusion, VQ-BeT, Pi0, SmolVLA, GR00T 等 |
| 🎮 遥操作 | Leader-Follower 臂、手柄、键盘、手机 |
| 🔬 仿真环境 | LIBERO, MetaWorld, Aloha, PushT |

### 1.3 项目结构概览

```
lerobot/
├── src/lerobot/           # 核心源代码
│   ├── datasets/          # 数据集处理
│   ├── policies/          # 策略模型实现
│   ├── robots/            # 机器人接口
│   ├── teleoperators/     # 遥操作设备
│   ├── cameras/           # 相机驱动
│   ├── motors/            # 电机控制
│   ├── envs/              # 仿真环境
│   ├── processor/         # 数据处理管道
│   ├── configs/           # 配置系统
│   ├── scripts/           # CLI 脚本
│   └── utils/             # 工具函数
├── docs/                  # 文档
├── examples/              # 示例代码
├── tests/                 # 测试用例
└── benchmarks/            # 性能基准
```

---

## 2. 环境搭建

### 2.1 基础安装

```bash
# 1. 创建 conda 环境
conda create -y -n lerobot python=3.10
conda activate lerobot

# 2. 安装 ffmpeg
conda install ffmpeg -c conda-forge

# 3. 安装 LeRobot
pip install lerobot

# 4. 验证安装
lerobot-info
```

### 2.2 开发模式安装

```bash
git clone https://github.com/huggingface/lerobot.git
cd lerobot
pip install -e ".[dev,test]"
```

### 2.3 可选依赖

```bash
# 仿真环境
pip install -e ".[aloha,pusht,libero]"

# 电机控制
pip install -e ".[feetech,dynamixel]"

# VLA 模型
pip install -e ".[smolvla,pi,groot]"
```

---

## 3. 学习阶段一：基础概念

> **目标**：理解 LeRobot 的核心抽象和设计理念

### 3.1 入口文件学习

**文件**: `src/lerobot/__init__.py`

这个文件定义了所有可用的组件：

```python
import lerobot

# 查看可用环境
print(lerobot.available_envs)

# 查看可用数据集
print(lerobot.available_datasets)

# 查看可用策略
print(lerobot.available_policies)

# 查看可用机器人
print(lerobot.available_robots)
```

### 3.2 配置系统

**目录**: `src/lerobot/configs/`

| 文件 | 用途 |
|------|------|
| `default.py` | 默认配置 |
| `train.py` | 训练配置 |
| `eval.py` | 评估配置 |
| `policies.py` | 策略配置基类 |
| `types.py` | 类型定义 |

LeRobot 使用 `draccus` 进行配置管理，支持 CLI 参数覆盖。

### 3.3 CLI 命令速览

```bash
# 查看系统信息
lerobot-info

# 查找相机
lerobot-find-cameras

# 查找串口
lerobot-find-port

# 遥操作
lerobot-teleoperate

# 录制数据
lerobot-record

# 训练模型
lerobot-train

# 评估模型
lerobot-eval

# 数据集可视化
lerobot-dataset-viz
```

### 3.4 推荐阅读顺序

1. `README.md` - 项目概述
2. `docs/source/installation.mdx` - 安装指南
3. `docs/source/index.mdx` - 文档首页
4. `src/lerobot/__init__.py` - 了解可用组件

---

## 4. 学习阶段二：数据集系统

> **目标**：掌握 LeRobotDataset v3.0 格式和数据处理流程

### 4.1 核心概念

LeRobotDataset v3.0 的三大支柱：

1. **表格数据**：状态、动作、时间戳 → Parquet 格式
2. **视觉数据**：相机图像 → MP4 视频
3. **元数据**：Schema、统计信息、Episode 分割

### 4.2 目录结构

```
dataset/
├── meta/
│   ├── info.json          # Schema 定义
│   ├── stats.json         # 归一化统计
│   ├── tasks.jsonl        # 任务描述
│   └── episodes/          # Episode 元数据
├── data/                  # Parquet 数据分片
└── videos/                # MP4 视频分片
```

### 4.3 关键文件学习

| 文件 | 内容 |
|------|------|
| `datasets/lerobot_dataset.py` | 核心数据集类 |
| `datasets/streaming_dataset.py` | 流式数据集 |
| `datasets/utils.py` | 工具函数 |
| `datasets/video_utils.py` | 视频处理 |
| `datasets/compute_stats.py` | 统计计算 |
| `datasets/transforms.py` | 数据增强 |

### 4.4 代码示例

```python
from lerobot.datasets.lerobot_dataset import LeRobotDataset

# 从 Hub 加载数据集
dataset = LeRobotDataset("lerobot/aloha_mobile_cabinet")

# 访问单个样本
sample = dataset[0]
print(sample.keys())
# dict_keys(['observation.state', 'action', 'observation.images.front', ...])

# 使用时间窗口
delta_timestamps = {
    "observation.images.front": [-0.2, -0.1, 0.0]
}
dataset = LeRobotDataset("lerobot/aloha_mobile_cabinet", 
                         delta_timestamps=delta_timestamps)

# 流式加载（不下载）
from lerobot.datasets.streaming_dataset import StreamingLeRobotDataset
stream_dataset = StreamingLeRobotDataset("lerobot/aloha_mobile_cabinet")
```

### 4.5 推荐阅读

1. `docs/source/lerobot-dataset-v3.mdx` - 数据集格式详解
2. `docs/source/using_dataset_tools.mdx` - 数据集工具使用
3. `examples/dataset/` - 数据集示例

---

## 5. 学习阶段三：策略与模型

> **目标**：理解各类策略的实现原理和使用方法

### 5.1 策略分类

| 类别 | 策略 | 特点 |
|------|------|------|
| **模仿学习** | ACT, Diffusion, VQ-BeT | 从演示数据学习 |
| **强化学习** | HIL-SERL, TDMPC, SAC | 在线交互学习 |
| **VLA 模型** | Pi0, Pi0Fast, SmolVLA, GR00T, XVLA | 视觉-语言-动作 |

### 5.2 策略目录结构

```
policies/
├── __init__.py
├── factory.py             # 策略工厂
├── pretrained.py          # 预训练基类
├── utils.py               # 工具函数
├── act/                   # ACT 策略
│   ├── configuration_act.py
│   └── modeling_act.py
├── diffusion/             # Diffusion 策略
├── vqbet/                 # VQ-BeT 策略
├── pi0/                   # Pi0 策略
├── smolvla/               # SmolVLA 策略
├── groot/                 # GR00T 策略
└── ...
```

### 5.3 策略工厂模式

**文件**: `policies/factory.py`

```python
from lerobot.policies.factory import get_policy_class, make_policy_config

# 获取策略类
ACTPolicy = get_policy_class("act")

# 创建配置
config = make_policy_config("act", ...)

# 实例化策略
policy = ACTPolicy(config)
```

### 5.4 策略学习顺序

**入门级（推荐先学）**：
1. **ACT** - `policies/act/` - 最简单的 Transformer 策略
2. **Diffusion** - `policies/diffusion/` - 扩散模型策略

**进阶级**：
3. **VQ-BeT** - `policies/vqbet/` - 离散化动作空间
4. **TDMPC** - `policies/tdmpc/` - 模型预测控制

**高级（VLA）**：
5. **SmolVLA** - `policies/smolvla/` - 轻量级 VLA
6. **Pi0** - `policies/pi0/` - Physical Intelligence
7. **GR00T** - `policies/groot/` - NVIDIA 方案

### 5.5 关键文件阅读

每个策略目录通常包含：
- `configuration_*.py` - 配置类定义
- `modeling_*.py` - 模型实现

### 5.6 推荐阅读

1. `docs/source/act.mdx` - ACT 策略详解
2. `docs/source/smolvla.mdx` - SmolVLA 详解
3. `docs/source/bring_your_own_policies.mdx` - 自定义策略
4. `examples/tutorial/` - 各策略教程

---

## 6. 学习阶段四：硬件集成

> **目标**：理解机器人、相机、电机的抽象接口

### 6.1 机器人接口

**核心文件**: `robots/robot.py`

```python
from abc import ABC, abstractmethod

class Robot(ABC):
    @property
    @abstractmethod
    def observation_features(self) -> dict:
        """观测空间定义"""
        pass
    
    @property
    @abstractmethod
    def action_features(self) -> dict:
        """动作空间定义"""
        pass
    
    @abstractmethod
    def connect(self, calibrate: bool = True) -> None:
        """连接机器人"""
        pass
    
    @abstractmethod
    def get_observation(self) -> RobotObservation:
        """获取观测"""
        pass
    
    @abstractmethod
    def send_action(self, action: RobotAction) -> RobotAction:
        """发送动作"""
        pass
```

### 6.2 支持的机器人

| 机器人 | 目录 | 特点 |
|--------|------|------|
| SO-100/101 | `robots/so_follower/` | 低成本桌面臂 |
| Koch | `robots/koch_follower/` | 开源机械臂 |
| LeKiwi | `robots/lekiwi/` | 移动底盘 |
| Reachy2 | `robots/reachy2/` | 人形机器人 |
| Unitree G1 | `robots/unitree_g1/` | 人形机器人 |
| Hope Jr | `robots/hope_jr/` | 教育机器人 |

### 6.3 遥操作设备

**目录**: `teleoperators/`

| 设备 | 目录 | 用途 |
|------|------|------|
| Leader 臂 | `so_leader/`, `koch_leader/` | 主从控制 |
| 手柄 | `gamepad/` | 游戏手柄控制 |
| 键盘 | `keyboard/` | 键盘控制 |
| 手机 | `phone/` | 手机遥操作 |

### 6.4 相机系统

**目录**: `cameras/`

```python
from lerobot.cameras.opencv.configuration_opencv import OpenCVCameraConfig

camera_config = {
    "front": OpenCVCameraConfig(
        index_or_path=0,
        width=1920,
        height=1080,
        fps=30
    )
}
```

### 6.5 电机控制

**目录**: `motors/`

- `dynamixel/` - Dynamixel 舵机
- `feetech/` - Feetech 舵机

### 6.6 推荐阅读

1. `docs/source/integrate_hardware.mdx` - 硬件集成指南
2. `docs/source/so100.mdx` / `so101.mdx` - SO 系列教程
3. `docs/source/cameras.mdx` - 相机设置
4. `docs/source/phone_teleop.mdx` - 手机遥操作
5. `jay-docs/SO101_DISTRIBUTED_DEPLOYMENT.md` - SO-ARM101 双机部署实战：本地控制机 + 远端 GPU server

---

## 7. 学习阶段五：训练与评估

> **目标**：掌握完整的训练和评估流程

### 7.1 训练脚本

**文件**: `scripts/lerobot_train.py`

```bash
# 基础训练命令
lerobot-train \
  --policy=act \
  --dataset.repo_id=lerobot/aloha_mobile_cabinet

# 自定义配置
lerobot-train \
  --policy=diffusion \
  --dataset.repo_id=lerobot/pusht \
  --training.batch_size=32 \
  --training.num_epochs=100
```

### 7.2 评估脚本

**文件**: `scripts/lerobot_eval.py`

```bash
# 仿真评估
lerobot-eval \
  --policy.path=lerobot/act_aloha_sim \
  --env.type=aloha \
  --env.task=AlohaInsertion-v0 \
  --eval.n_episodes=10

# 真实机器人评估
lerobot-eval \
  --policy.path=outputs/train/act/checkpoints/last \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyUSB0
```

### 7.3 数据录制

**文件**: `scripts/lerobot_record.py`

```bash
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyUSB0 \
  --teleop.type=so101_leader \
  --teleop.port=/dev/ttyUSB1 \
  --dataset.repo_id=my_user/my_dataset \
  --dataset.num_episodes=50
```

### 7.4 完整工作流

```
1. 硬件设置
   └── lerobot-find-port / lerobot-find-cameras
   
2. 校准
   └── lerobot-calibrate
   
3. 遥操作测试
   └── lerobot-teleoperate
   
4. 数据录制
   └── lerobot-record
   
5. 数据可视化
   └── lerobot-dataset-viz
   
6. 模型训练
   └── lerobot-train
   
7. 模型评估
   └── lerobot-eval
```

### 7.5 推荐阅读

1. `docs/source/il_robots.mdx` - 完整模仿学习教程
2. `docs/source/hilserl.mdx` - 强化学习教程
3. `docs/source/multi_gpu_training.mdx` - 多 GPU 训练
4. `examples/training/` - 训练示例

---

## 8. 学习阶段六：高级主题

> **目标**：深入理解高级功能和扩展机制

### 8.1 Processor 管道

**目录**: `processor/`

Processor 是数据预处理和后处理的核心抽象：

| 文件 | 功能 |
|------|------|
| `pipeline.py` | 处理管道 |
| `normalize_processor.py` | 归一化处理 |
| `batch_processor.py` | 批处理 |
| `tokenizer_processor.py` | 分词处理 |

### 8.2 异步推理

**目录**: `async_inference/`

用于实时控制的异步推理框架。

```bash
# 安装异步依赖
pip install -e ".[async]"
```

### 8.3 仿真环境

**目录**: `envs/`

| 文件 | 环境 |
|------|------|
| `configs.py` | 环境配置 |
| `factory.py` | 环境工厂 |
| `libero.py` | LIBERO 环境 |
| `metaworld.py` | MetaWorld 环境 |

### 8.4 自定义扩展

**添加新策略**：
1. 在 `policies/` 下创建目录
2. 实现 `configuration_*.py` 和 `modeling_*.py`
3. 在 `policies/factory.py` 中注册
4. 更新 `__init__.py`

**添加新机器人**：
1. 在 `robots/` 下创建目录
2. 继承 `Robot` 基类
3. 实现所有抽象方法

### 8.5 推荐阅读

1. `docs/source/introduction_processors.mdx` - Processor 介绍
2. `docs/source/async.mdx` - 异步推理
3. `docs/source/envhub.mdx` - 环境 Hub
4. `docs/source/bring_your_own_policies.mdx` - 自定义策略

---

## 9. 推荐学习资源

### 9.1 官方资源

| 资源 | 链接 |
|------|------|
| 📖 官方文档 | https://huggingface.co/docs/lerobot |
| 🎓 机器人学习教程 | https://huggingface.co/spaces/lerobot/robot-learning-tutorial |
| 💬 Discord 社区 | https://discord.gg/q8Dzzpym3f |
| 🐦 Twitter/X | https://x.com/LeRobotHF |
| 🗃️ 数据集 Hub | https://huggingface.co/lerobot |

### 9.2 文档阅读顺序

**第一周：基础**
1. `installation.mdx`
2. `lerobot-dataset-v3.mdx`
3. `cameras.mdx`

**第二周：实践**
4. `il_robots.mdx`
5. `act.mdx`
6. `so100.mdx` 或 `so101.mdx`

**第三周：进阶**
7. `smolvla.mdx`
8. `hilserl.mdx`
9. `introduction_processors.mdx`

**第四周：深入**
10. `bring_your_own_policies.mdx`
11. `integrate_hardware.mdx`
12. `async.mdx`

### 9.3 示例代码

```
examples/
├── tutorial/
│   ├── act/              # ACT 教程
│   ├── diffusion/        # Diffusion 教程
│   ├── pi0/              # Pi0 教程
│   ├── smolvla/          # SmolVLA 教程
│   └── rl/               # 强化学习教程
├── dataset/              # 数据集示例
├── training/             # 训练示例
└── port_datasets/        # 数据集迁移示例
```

### 9.4 深入掌握验收清单

如果你已经完成了基础跑通，准备从“会用 LeRobot”进入“深入掌握 LeRobot”阶段，建议配合下面这份验收题库一起使用：

- `jay-docs/LEROBOT_DEEP_MASTERY_CHECKLIST.md`

这份文档不是目录式教程，而是一份源码理解与系统理解的自测清单。建议你在阅读源码、做实验、排查问题时，持续对照这份问题列表打勾。

---

## 10. 项目架构速查

### 10.1 核心类关系

```
┌─────────────────────────────────────────────────────────────┐
│                        LeRobot                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Dataset    │    │    Policy    │    │    Robot     │  │
│  │              │    │              │    │              │  │
│  │ LeRobotData  │───▶│ PreTrained   │───▶│   Robot      │  │
│  │    set       │    │   Policy     │    │  (Abstract)  │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                   │                   │           │
│         ▼                   ▼                   ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Streaming   │    │  ACT/Diff/   │    │ SO100/Koch/  │  │
│  │   Dataset    │    │  VLA/...     │    │  LeKiwi/...  │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Supporting Components:                                      │
│  - Cameras: OpenCV, RealSense                               │
│  - Motors: Dynamixel, Feetech                               │
│  - Teleoperators: Leader arms, Gamepad, Phone               │
│  - Processors: Normalize, Batch, Tokenize                   │
│  - Environments: Aloha, PushT, LIBERO, MetaWorld            │
└─────────────────────────────────────────────────────────────┘
```

### 10.2 CLI 命令速查

| 命令 | 功能 | 常用参数 |
|------|------|----------|
| `lerobot-info` | 系统信息 | - |
| `lerobot-find-port` | 查找串口 | - |
| `lerobot-find-cameras` | 查找相机 | - |
| `lerobot-calibrate` | 校准机器人 | `--robot.type`, `--robot.port` |
| `lerobot-teleoperate` | 遥操作 | `--robot.*`, `--teleop.*` |
| `lerobot-record` | 录制数据 | `--dataset.repo_id`, `--dataset.num_episodes` |
| `lerobot-train` | 训练模型 | `--policy`, `--dataset.repo_id` |
| `lerobot-eval` | 评估模型 | `--policy.path`, `--env.*` |
| `lerobot-dataset-viz` | 数据可视化 | `--repo_id` |

### 10.3 关键文件索引

| 功能 | 文件路径 |
|------|----------|
| 入口定义 | `src/lerobot/__init__.py` |
| 数据集核心 | `src/lerobot/datasets/lerobot_dataset.py` |
| 策略工厂 | `src/lerobot/policies/factory.py` |
| 机器人基类 | `src/lerobot/robots/robot.py` |
| 遥操作基类 | `src/lerobot/teleoperators/teleoperator.py` |
| 训练脚本 | `src/lerobot/scripts/lerobot_train.py` |
| 评估脚本 | `src/lerobot/scripts/lerobot_eval.py` |
| 录制脚本 | `src/lerobot/scripts/lerobot_record.py` |

---

## 🎯 学习建议

1. **循序渐进**：按照阶段顺序学习，不要跳跃
2. **动手实践**：每个阶段都运行示例代码
3. **阅读源码**：理解抽象接口后深入实现
4. **参与社区**：加入 Discord 讨论问题
5. **贡献代码**：从小 PR 开始参与开源

---

*最后更新: 2025-01-15*

*本文档基于 LeRobot v0.4.3 编写*
