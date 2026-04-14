# SO-ARM101 双机部署方案

> 目标场景：`LOCAL_PC` 直连 `SO-ARM101 follower + leader + 1 个 Intel RealSense`，`GPU_SERVER` 负责训练与远端策略推理；两台机器位于同一局域网，`LOCAL_PC` 通过 Wi-Fi 接入网络。

---

## 1. 场景定义与架构图

这份文档面向下面这个固定场景：

- 本地机器人控制机：`LOCAL_PC`
  - Ubuntu 22.04 LTS
  - x86_64 小主机或台式机
  - 不要求独立 GPU
  - 直接连接 follower、leader、RealSense
- 远端算力机：`GPU_SERVER`
  - 负责训练
  - 负责远端实时推理 `policy_server`
- 网络
  - 两台机器在同一局域网
  - `LOCAL_PC` 通过 Wi-Fi 接入
  - `GPU_SERVER` 建议固定私网 IP

职责边界：

- `LOCAL_PC` 负责硬件 bring-up、校准、遥操作、录数、真机控制闭环
- `GPU_SERVER` 负责训练与策略推理
- Wi-Fi 只承载 `LOCAL_PC <-> GPU_SERVER` 的网络链路
- RealSense 和机械臂都必须本地 USB 直连，不走网络相机方案

架构图：

```text
                   同一局域网 / Wi-Fi

  +-------------------------------------------------------------+
  |                                                             |
  |   +-------------------+         gRPC / async inference      |
  |   |     LOCAL_PC      |  <------------------------------->  |
  |   | Ubuntu 22.04 LTS  |                                     |
  |   | robot_client      |                                     |
  |   +---------+---------+                                     |
  |             |                                               |
  |             | USB 直连                                      |
  |             v                                               |
  |   +-------------------+         +------------------------+  |
  |   | SO-ARM101         |         |     GPU_SERVER         |  |
  |   | follower + leader |         | 训练 / policy_server   |  |
  |   +-------------------+         +------------------------+  |
  |             |                                               |
  |             v                                               |
  |      Intel RealSense                                        |
  |                                                             |
  +-------------------------------------------------------------+
```

一句话原则：

- 直接碰硬件的事情，都在 `LOCAL_PC`
- 吃算力的事情，都在 `GPU_SERVER`

---

## 2. 硬件与网络前提

### 2.1 必要条件

`LOCAL_PC` 必须满足：

- Ubuntu 22.04 LTS
- `x86_64` 架构
- 能稳定识别 `/dev/ttyACM*` 或 `/dev/ttyUSB*`
- 至少 2 个可用 USB 口给 leader / follower
- 至少 1 个 USB 3.0 口给 RealSense
- 稳定 SSD
- 建议 16GB RAM 起步

`GPU_SERVER` 必须满足：

- 已安装可用的 CUDA / PyTorch 环境
- 可以被 `LOCAL_PC` 通过私网 IP 访问
- 可以常驻运行 `policy_server`

### 2.2 网络要求

本方案接受 `LOCAL_PC` 使用 Wi-Fi，但要明确边界：

- 可以用 Wi-Fi
- 不建议跨公网
- 不建议把 RealSense 数据源改成网络摄像头来绕过本地 USB

推荐网络条件：

- `GPU_SERVER` 固定私网 IP，例如 `192.168.1.50`
- `LOCAL_PC` 与 `GPU_SERVER` 可直接互 ping
- 尽量使用 5GHz 或 Wi-Fi 6
- 机器人实验时避免和大量设备争抢同一个 AP

首版统一占位符：

```bash
LOCAL_PC=<你的本地机器人控制机>
GPU_SERVER=<你的远端 GPU server>

SERVER_IP=192.168.1.50
SERVER_PORT=8080

FOLLOWER_PORT=/dev/ttyACM0
LEADER_PORT=/dev/ttyACM1

FOLLOWER_ID=so101_follower_main
LEADER_ID=so101_leader_main

REALSENSE_SN=233522074606

POLICY_TYPE=act
POLICY_PATH=/data/lerobot/outputs/train/act/checkpoints/last/pretrained_model
```

这里默认：

- `POLICY_TYPE=act`
- 远端实时推理先以轻量闭环为目标
- 如果你以后改用 `smolvla` / `pi0`，只替换策略安装和启动参数

---

## 3. 本地机器人控制机环境部署

### 3.1 建议安装方式

`LOCAL_PC` 使用 `conda`，原因是：

- 官方安装文档默认推荐
- Python 3.12 更容易与当前 LeRobot 对齐
- `ffmpeg` 更好处理

### 3.2 创建环境

```bash
conda create -y -n lerobot python=3.12
conda activate lerobot
conda install ffmpeg=7.1.1 -c conda-forge
ffmpeg -version
```

注意：

- 不要用 `ffmpeg 8.x`
- 每次新开终端都要先 `conda activate lerobot`

### 3.3 安装 LeRobot 与本地所需 extras

在仓库根目录执行：

```bash
pip install -e ".[feetech,intelrealsense,async]"
lerobot-info
```

为什么是这三个 extras：

- `feetech`：SO-ARM101 电机控制
- `intelrealsense`：RealSense 相机
- `async`：本地跑 `robot_client`

### 3.4 本地机安装完成后的自检

```bash
python - <<'PY'
import importlib
mods = ["lerobot", "pyrealsense2", "grpc", "scservo_sdk"]
for name in mods:
    try:
        importlib.import_module(name)
        print(f"OK  {name}")
    except Exception as e:
        print(f"ERR {name}: {e}")
PY
```

最少需要确认：

- `lerobot-info` 能运行
- `pyrealsense2` 可导入
- 没有 `grpcio` 缺失

---

## 4. 远端 GPU server 环境部署

### 4.1 环境目标

`GPU_SERVER` 不接硬件，因此最小职责是：

- 训练策略
- 启动 `policy_server`
- 持有 `POLICY_PATH`

### 4.2 远端最小安装

```bash
conda create -y -n lerobot python=3.12
conda activate lerobot
conda install ffmpeg=7.1.1 -c conda-forge
pip install -e ".[async]"
lerobot-info
```

如果你只打算先跑 `ACT`：

- 上面的安装就够做最小闭环

如果你要在远端使用更重的策略：

- `SmolVLA`：再装 `pip install -e ".[smolvla,async]"`
- `Pi0/Pi0.5`：再装 `pip install -e ".[pi,async]"`

### 4.3 远端统一版本要求

`LOCAL_PC` 和 `GPU_SERVER` 最好满足：

- 同一份仓库 commit
- 同一 Python 主版本
- 同一 LeRobot 安装方式

否则最容易出现：

- policy config 不兼容
- features rename 不一致
- 推理端能起，但 client/server 握手后报错

### 4.4 远端端口检查

启动前先确认端口未被占用：

```bash
ss -ltnp | rg 8080
```

如果没有输出，表示 `SERVER_PORT=8080` 当前空闲。

---

## 5. 本地硬件 bring-up

这一步只在 `LOCAL_PC` 做。

### 5.1 查找串口

```bash
lerobot-find-port
```

在 Ubuntu 上如果权限不足：

```bash
sudo chmod 666 /dev/ttyACM0
sudo chmod 666 /dev/ttyACM1
```

把识别出的端口填回占位符：

```bash
FOLLOWER_PORT=/dev/ttyACM0
LEADER_PORT=/dev/ttyACM1
```

### 5.2 设置电机

Follower：

```bash
lerobot-setup-motors \
  --robot.type=so101_follower \
  --robot.port=${FOLLOWER_PORT}
```

Leader：

```bash
lerobot-setup-motors \
  --teleop.type=so101_leader \
  --teleop.port=${LEADER_PORT}
```

这一步只做一次，除非：

- 更换控制板
- 更换电机
- 电机 ID / baudrate 被改坏

### 5.3 标定 follower / leader

Follower：

```bash
lerobot-calibrate \
  --robot.type=so101_follower \
  --robot.port=${FOLLOWER_PORT} \
  --robot.id=${FOLLOWER_ID}
```

Leader：

```bash
lerobot-calibrate \
  --teleop.type=so101_leader \
  --teleop.port=${LEADER_PORT} \
  --teleop.id=${LEADER_ID}
```

标定原则：

- 这两个 `id` 后续必须保持不变
- `teleoperate`、`record`、`robot_client` 都应复用同一组 `FOLLOWER_ID` / `LEADER_ID`

### 5.4 查找 RealSense

```bash
lerobot-find-cameras realsense
```

确认拿到：

- `REALSENSE_SN`
- 可用分辨率
- 相机确实能被 `pyrealsense2` 打开

建议先统一为：

- `width=640`
- `height=480`
- `fps=30`

这是更适合首版闭环调试的配置。

---

## 6. 本地 teleop 与录数

这一步仍然只在 `LOCAL_PC` 做。

### 6.1 先跑最小 teleop

不带相机先确认主从控制正常：

```bash
lerobot-teleoperate \
  --robot.type=so101_follower \
  --robot.port=${FOLLOWER_PORT} \
  --robot.id=${FOLLOWER_ID} \
  --teleop.type=so101_leader \
  --teleop.port=${LEADER_PORT} \
  --teleop.id=${LEADER_ID}
```

验收标准：

- leader 移动时 follower 跟随
- 不出现明显抖动或关节异常
- 不再触发重新校准

### 6.2 带 RealSense 的 teleop

首版统一使用单相机键名 `front`：

```bash
lerobot-teleoperate \
  --robot.type=so101_follower \
  --robot.port=${FOLLOWER_PORT} \
  --robot.id=${FOLLOWER_ID} \
  --robot.cameras="{ front: {type: intelrealsense, serial_number_or_name: ${REALSENSE_SN}, width: 640, height: 480, fps: 30}}" \
  --teleop.type=so101_leader \
  --teleop.port=${LEADER_PORT} \
  --teleop.id=${LEADER_ID} \
  --display_data=true
```

这里把相机键名固定成 `front`，后续录数和推理都沿用这个键名。

### 6.3 录第一批数据

默认采用 Hugging Face Hub 作为数据中转层，原因是：

- 和 LeRobot 默认流程一致
- 远端训练更直接
- 后续模型与数据可复用同一套命名

先登录：

```bash
hf auth login
HF_USER=$(NO_COLOR=1 hf auth whoami | awk -F': *' 'NR==1 {print $2}')
echo $HF_USER
```

开始录数：

```bash
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=${FOLLOWER_PORT} \
  --robot.id=${FOLLOWER_ID} \
  --robot.cameras="{ front: {type: intelrealsense, serial_number_or_name: ${REALSENSE_SN}, width: 640, height: 480, fps: 30}}" \
  --teleop.type=so101_leader \
  --teleop.port=${LEADER_PORT} \
  --teleop.id=${LEADER_ID} \
  --display_data=true \
  --dataset.repo_id=${HF_USER}/so101_single_arm_front_rs \
  --dataset.single_task="Pick and place the target object" \
  --dataset.num_episodes=10 \
  --dataset.streaming_encoding=true \
  --dataset.encoder_threads=2
```

首版建议：

- 先录 10 个 episode 做闭环验证
- 确认数据格式、相机命名、动作链路全部通
- 再扩充到正式训练集

本地缓存位置通常在：

```bash
~/.cache/huggingface/lerobot/
```

---

## 7. 远端训练与模型交接

### 7.1 数据流推荐

首版默认数据流：

```text
LOCAL_PC 录数
  -> 推到 Hugging Face dataset repo
  -> GPU_SERVER 从 dataset repo 训练
  -> 产出 checkpoint 到 GPU_SERVER 本地
  -> GPU_SERVER 直接拿该 checkpoint 启动 policy_server
```

这条路径的优点是：

- 本地和远端职责清晰
- 不需要手工搬 Parquet / MP4
- 后续也方便切回官方教程

### 7.2 远端最小训练示例

以 `ACT` 为默认策略：

```bash
lerobot-train \
  --policy=act \
  --dataset.repo_id=${HF_USER}/so101_single_arm_front_rs
```

训练结束后，你需要拿到实际 checkpoint 路径，例如：

```bash
POLICY_PATH=/data/lerobot/outputs/train/act/checkpoints/last/pretrained_model
```

### 7.3 如果暂时不训练

你也可以先用一个已经可用的 `ACT` checkpoint 做部署联调：

- 目标不是任务成功率
- 目标是先把 `robot_client <-> policy_server` 闭环跑通

也就是说，首版闭环可以先验证“链路通”，再追求“策略好”。

---

## 8. 远端实时推理闭环

这一节是首版验收终点。

### 8.1 先验证局域网

在 `LOCAL_PC`：

```bash
ping -c 4 ${SERVER_IP}
nc -vz ${SERVER_IP} ${SERVER_PORT}
```

解释：

- `ping` 看基本互通
- `nc -vz` 看目标端口是否可达

如果 `nc` 失败，但 `ping` 正常：

- 大概率是 `policy_server` 未启动
- 或 server 侧防火墙 / 监听地址不对

### 8.2 在远端启动 `policy_server`

在 `GPU_SERVER`：

```bash
conda activate lerobot

python -m lerobot.async_inference.policy_server \
  --host=0.0.0.0 \
  --port=${SERVER_PORT}
```

建议使用 `0.0.0.0`，因为这样 `LOCAL_PC` 能通过局域网 IP 直接访问。

### 8.3 在本地启动 `robot_client`

在 `LOCAL_PC`：

```bash
conda activate lerobot

python -m lerobot.async_inference.robot_client \
  --server_address=${SERVER_IP}:${SERVER_PORT} \
  --robot.type=so101_follower \
  --robot.port=${FOLLOWER_PORT} \
  --robot.id=${FOLLOWER_ID} \
  --robot.cameras="{ front: {type: intelrealsense, serial_number_or_name: ${REALSENSE_SN}, width: 640, height: 480, fps: 30}}" \
  --task="Pick and place the target object" \
  --policy_type=${POLICY_TYPE} \
  --pretrained_name_or_path=${POLICY_PATH} \
  --policy_device=cuda \
  --client_device=cpu \
  --actions_per_chunk=50 \
  --chunk_size_threshold=0.5 \
  --aggregate_fn_name=weighted_average \
  --debug_visualize_queue_size=True
```

这个命令的关键点：

- `robot_client` 跑在 `LOCAL_PC`
- 真正连接 follower 和 RealSense 的是 `LOCAL_PC`
- 远端只负责推理，不直接碰硬件

### 8.4 首版推荐参数

Wi-Fi 场景首版先用下面这组：

- `policy_server --fps=30`
- `robot_client --fps=30`
- `actions_per_chunk=50`
- `chunk_size_threshold=0.5`
- 相机 `640x480 @ 30fps`

如果你发现动作队列容易吃空，再按下面顺序调：

1. 先把 `policy_server` 和 `robot_client` 的 `fps` 一起降低，例如都改成 `15`
2. 再尝试增大 `actions_per_chunk`
3. 再调 `chunk_size_threshold`

### 8.5 Wi-Fi 下的三条调优原则

#### 原则 1：先保守，再变快

不要一开始就追求高帧率。Wi-Fi 下更怕的是抖动，不是纯带宽。

#### 原则 2：优先看队列是否见底

`--debug_visualize_queue_size=True` 的价值在于：

- 如果动作队列经常归零，说明网络 + 推理链路赶不上控制循环
- 这时先降 `fps`，不要先盲目加分辨率

#### 原则 3：先保闭环稳定，再追求任务效果

真实部署第一阶段应该优先达到：

- client/server 能稳定跑 5 到 10 分钟
- 队列不频繁见底
- 机械臂动作没有明显卡顿

而不是一开始就追求任务成功率。

---

## 9. 验证与故障排查

### 9.1 验收清单

只有下面这些全部通过，才算首版部署完成：

- `LOCAL_PC` 能运行 `lerobot-info`
- `LOCAL_PC` 能识别 leader / follower 串口
- `LOCAL_PC` 能完成 `setup-motors` 与 `calibrate`
- `LOCAL_PC` 能通过 `lerobot-find-cameras realsense` 找到 `REALSENSE_SN`
- `LOCAL_PC` 能完成一次带相机的 `teleoperate`
- `LOCAL_PC` 能完成一次带相机的 `record`
- `LOCAL_PC` 能 `ping ${SERVER_IP}`
- `GPU_SERVER` 能启动 `policy_server`
- `LOCAL_PC` 能启动 `robot_client` 并连上远端 server

### 9.2 排查顺序

按这个顺序排查，不要跳：

1. 先看本地硬件
2. 再看局域网
3. 最后看远端推理

### 9.3 本地硬件问题

症状：

- `lerobot-find-port` 找不到设备
- `lerobot-calibrate` 无法连接
- `lerobot-find-cameras realsense` 找不到相机

优先检查：

- USB 线是否稳定
- 供电是否正常
- `/dev/ttyACM*` 权限
- `pyrealsense2` 是否可导入

### 9.4 局域网问题

症状：

- `ping ${SERVER_IP}` 不通
- `nc -vz ${SERVER_IP} ${SERVER_PORT}` 不通

优先检查：

- 两台机器是否在同一网段
- `GPU_SERVER` 是否真的是固定私网 IP
- `policy_server` 是否监听在 `0.0.0.0:${SERVER_PORT}`
- 系统防火墙是否拦截端口

### 9.5 远端推理问题

症状：

- `policy_server` 已启动，但 `robot_client` 握手失败
- 连接成功，但动作卡顿

优先检查：

- `LOCAL_PC` 和 `GPU_SERVER` 是否使用同一份 LeRobot 代码
- `POLICY_TYPE` 和 `POLICY_PATH` 是否匹配
- `policy_device=cuda` 是否真的可用
- Wi-Fi 抖动下动作队列是否经常见底

### 9.6 一组常用检查命令

`LOCAL_PC`：

```bash
lerobot-info
lerobot-find-port
lerobot-find-cameras realsense
ping -c 4 ${SERVER_IP}
nc -vz ${SERVER_IP} ${SERVER_PORT}
```

`GPU_SERVER`：

```bash
nvidia-smi
ss -ltnp | rg ${SERVER_PORT}
python -m lerobot.async_inference.policy_server --host=0.0.0.0 --port=${SERVER_PORT}
```

---

## 10. 你现在的推荐执行顺序

如果你今天就准备开始部署，按这个顺序做：

1. 在 `LOCAL_PC` 安装 `.[feetech,intelrealsense,async]`
2. 在 `GPU_SERVER` 安装 `.[async]`
3. 在 `LOCAL_PC` 完成 `find-port -> setup-motors -> calibrate`
4. 在 `LOCAL_PC` 完成 `find-cameras realsense`
5. 在 `LOCAL_PC` 跑无相机 `teleoperate`
6. 在 `LOCAL_PC` 跑带 RealSense 的 `teleoperate`
7. 在 `LOCAL_PC` 录 10 个 episode
8. 在 `GPU_SERVER` 训练或准备一个可用 checkpoint
9. 在 `GPU_SERVER` 启动 `policy_server`
10. 在 `LOCAL_PC` 启动 `robot_client`

只要你按这个顺序走，问题会更容易定位。

---

## 11. 后续扩展，但不属于首版范围

下面这些是下一阶段可以再加的内容，本文件不展开：

- 双臂方案
- 多相机方案
- 不经 HF Hub 的数据中转
- 本地直接推理
- 更重的 VLA 模型部署
- 有线网络替代 Wi-Fi

首版先把最小闭环跑通，再扩展。
