# LeRobot 深入掌握验收清单

> 这份文档不是“阅读目录”，而是“掌握验收表”。  
> 你的目标不是把命令跑通，也不是把教程抄会，而是直到你能稳定回答下面这些问题，并能结合源码和实验自证，你才算真正深入掌握了 `LeRobot`。

---

## 1. 使用说明

### 1.1 判定标准

对每一个问题，至少满足下面 3 条，才算真正掌握：

1. 能用自己的话解释清楚，不依赖原文背诵。
2. 能指出对应源码入口，知道应该去哪个文件、哪个函数验证。
3. 能做一个最小实验或最小改动，证明你的理解是对的。

### 1.2 掌握等级

- `会用`：能跟着教程跑通命令。
- `理解`：知道主链路在做什么，能解释输入输出关系。
- `深入掌握`：能自己改代码、接组件、排查问题、解释设计取舍。
- `能独立开发`：能给 `LeRobot` 接新策略、接新机器人、接新 processor，并跑通全链路。

### 1.3 推荐自测方式

每个问题都建议你补充 3 栏：

- `我的回答`
- `对应源码`
- `验证实验`

---

## 2. 必须先建立的总心智模型

在进入细节前，你至少要能完整说出这条主链：

```text
CLI -> Config -> Factory -> Object Construction -> Processor -> Main Loop -> Dataset / Policy / Robot / Env
```

如果这条链你还说不顺，说明你还没有进入“系统理解”阶段。

---

## 3. 系统主干与整体架构

关键源码入口：

- `src/lerobot/configs/parser.py`
- `src/lerobot/policies/factory.py`
- `src/lerobot/datasets/factory.py`
- `src/lerobot/envs/factory.py`

### 3.1 核心问题

- [ ] `LeRobot` 的核心抽象有哪些？`robot / teleop / dataset / policy / processor / env / config / script` 分别负责什么？
- [ ] 为什么 `LeRobot` 要把系统拆成 `script -> config -> factory -> object -> processor -> loop`？
- [ ] `LeRobot` 里哪些东西是“算法层”，哪些是“系统层”，哪些是“硬件层”？
- [ ] `LeRobot` 为什么能做到“同一套训练/部署框架复用到不同机器人和不同策略”？
- [ ] `LeRobot` 的“统一接口”具体统一了什么，没有统一什么？
- [ ] 你能否画出 `dataset / policy / robot / env / processor` 之间的关系图？

### 3.2 验收标准

- [ ] 你能在不看图的情况下口述整体架构。
- [ ] 你能解释为什么 `processor` 在 `LeRobot` 里不是边角料，而是主干。
- [ ] 你能说明为什么很多表面上的“模型问题”其实最后会落到 `processor` 或 `features`。

---

## 4. CLI、配置系统与对象创建

关键源码入口：

- `src/lerobot/configs/parser.py`
- `src/lerobot/configs/train.py`
- `src/lerobot/configs/eval.py`
- `src/lerobot/configs/policies.py`
- `src/lerobot/scripts/*.py`

### 4.1 核心问题

- [ ] `lerobot-record`、`lerobot-train`、`lerobot-eval`、`lerobot-teleoperate` 是如何从 CLI 参数进入 Python 代码的？
- [ ] `@parser.wrap()` 实际做了什么？
- [ ] `draccus` 在 `LeRobot` 中承担什么角色？
- [ ] `--policy.path=...` 和 `--policy.type=...` 各自意味着什么？
- [ ] 配置什么时候来自 CLI，什么时候来自 checkpoint，什么时候来自 Hub？
- [ ] `config_path` 的加载路径和 `policy.path` 的加载路径有何区别？
- [ ] plugin 机制是怎么接入的？第三方包如何注册自己的 config / env / robot / policy？
- [ ] 如果 CLI 里同时给了冲突参数，`LeRobot` 是在哪一层检查并报错的？

### 4.2 验收标准

- [ ] 你能从一个 CLI 参数追踪到它最终影响的对象属性。
- [ ] 你能解释为什么 `LeRobot` 的 config 设计适合实验复现和工程扩展。
- [ ] 你能自己加一个新的 config 字段，并让 CLI 覆盖它。

---

## 5. 命令背后的主链路

关键源码入口：

- `src/lerobot/scripts/lerobot_record.py`
- `src/lerobot/scripts/lerobot_train.py`
- `src/lerobot/scripts/lerobot_eval.py`
- `src/lerobot/scripts/lerobot_replay.py`
- `src/lerobot/scripts/lerobot_teleoperate.py`

### 5.1 记录、训练、评估、遥操分别在干什么

- [ ] `lerobot-record` 的主循环是怎样的？
- [ ] `lerobot-train` 的完整启动顺序是什么？
- [ ] `lerobot-eval` 的 rollout 主循环是怎样的？
- [ ] `lerobot-replay` 为什么看起来简单，但本质上仍然依赖 dataset schema 和 robot 接口？
- [ ] `lerobot-teleoperate` 与 `lerobot-record --teleop ...` 的主要差异在哪里？
- [ ] 这些命令虽然目标不同，但内部结构为什么高度相似？

### 5.2 验收标准

- [ ] 你能从源码里指出每个命令真正的主入口函数。
- [ ] 你能不用教程，只靠代码解释某条命令为什么生效。
- [ ] 你能自己写一份“这条命令内部调用链”的简图。

---

## 6. Processor 管线

关键源码入口：

- `src/lerobot/policies/factory.py`
- `src/lerobot/processor/factory.py`
- `src/lerobot/processor/pipeline.py`
- `src/lerobot/utils/control_utils.py`

### 6.1 核心问题

- [ ] 为什么 `LeRobot` 不把原始 observation 直接喂给模型？
- [ ] `preprocessor` 和 `postprocessor` 分别处理什么？
- [ ] `robot_observation_processor`、`teleop_action_processor`、`robot_action_processor` 分别位于哪一层？
- [ ] 为什么 normalization / unnormalization 被设计成 processor step，而不是硬编码进模型？
- [ ] tokenizer、rename、device transfer、relative action 这些逻辑为什么也适合放在 processor 里？
- [ ] 什么时候加载 checkpoint 里保存的 processor，什么时候按当前 config 重新构建？
- [ ] 如果 processor 的配置和 policy 的预期不一致，通常会出现什么类型的问题？
- [ ] `relative action` 为什么必须 pre/post 两侧成对出现？
- [ ] 如果要新增一个 preprocessing step，应该插在哪条管线？

### 6.2 验收标准

- [ ] 你能手动画出 `raw obs -> preprocessor -> policy -> postprocessor -> robot action`。
- [ ] 你能修改一个已有 processor step，并验证它只影响你预期的层。
- [ ] 你能解释为什么 `processor` 是 `LeRobot` 最核心的工程抽象之一。

---

## 7. 遥操作、控制环与动作链

关键源码入口：

- `src/lerobot/scripts/lerobot_teleoperate.py`
- `src/lerobot/scripts/lerobot_record.py`
- `src/lerobot/utils/control_utils.py`
- `src/lerobot/utils/robot_utils.py`

### 7.1 核心问题

- [ ] `teleop.get_action()` 返回的动作和 `robot.send_action()` 接受的动作，为什么不一定相同？
- [ ] 遥操作动作为什么还要经过 processor？
- [ ] `record_loop()` 中 teleop 模式、policy 模式、interpolation 模式分别怎么走？
- [ ] 为什么插值模式下存在“执行动作但不记录帧”的循环？
- [ ] `fps` 在控制环里到底控制的是什么？
- [ ] `precise_sleep()` 为什么比普通 `time.sleep()` 更适合控制环？
- [ ] 控制环为什么总是要先读 observation，再决定最终动作？
- [ ] 多 teleop 的支持为什么有限？限制写在什么地方？
- [ ] 如果 teleop 动作维度和 robot action feature 不匹配，会在哪一层暴露？
- [ ] 当机器人控制延迟高、动作抖动、掉帧时，你应该优先检查哪几层？

### 7.2 验收标准

- [ ] 你能独立解释一次完整的 teleop 控制周期。
- [ ] 你能解释为什么 record loop 和 teleop loop 是 `LeRobot` 实机使用的关键。
- [ ] 你能自己做一次最小实验，验证插值与数据录制频率的区别。

---

## 8. 数据集系统与 LeRobotDataset

关键源码入口：

- `src/lerobot/datasets/lerobot_dataset.py`
- `src/lerobot/datasets/streaming_dataset.py`
- `src/lerobot/datasets/factory.py`
- `src/lerobot/datasets/feature_utils.py`
- `src/lerobot/datasets/compute_stats.py`

### 8.1 核心问题

- [ ] `LeRobotDataset v3` 的基本结构是什么？`meta / data / videos` 分别存什么？
- [ ] 为什么视觉数据要做成视频而不是直接塞进 parquet？
- [ ] `features` 在 `LeRobot` 里为什么如此关键？
- [ ] `build_dataset_frame()` 是怎么按 feature schema 组装单帧的？
- [ ] `observation.state`、`action`、`observation.images.xxx` 的命名规范为什么影响全链路？
- [ ] `stats.json` 的作用是什么？如果统计错了，会怎样影响训练和部署？
- [ ] `delta_timestamps` 是怎样从 policy config 推出来的？
- [ ] 为什么 dataset loader 要把 delta index 转成秒，而不是直接保留离散索引？
- [ ] streaming dataset 和普通 dataset 的差异是什么？
- [ ] `use_imagenet_stats` 会修改哪部分统计？在什么场景下有意义？
- [ ] 如果你新增一个相机键名，dataset、processor、policy 哪几层要一起改？
- [ ] 如果 dataset 的 feature 名和真实机器人键名不一致，应该优先在哪一层修复？

### 8.2 验收标准

- [ ] 你能不看文档，自己解释 dataset schema 是如何约束训练和部署的。
- [ ] 你能从一个样本追踪它如何被 dataset loader、processor、policy 消费。
- [ ] 你能独立定位一次由 `features` 或 `stats` 引起的 bug。

---

## 9. 特征推断、工厂注册与策略接线

关键源码入口：

- `src/lerobot/policies/factory.py`
- `src/lerobot/configs/types.py`
- `src/lerobot/datasets/feature_utils.py`
- `src/lerobot/envs/utils.py`

### 9.1 核心问题

- [ ] `make_policy()` 为什么必须拿到 `ds_meta` 或 `env_cfg` 之一？
- [ ] `dataset_to_policy_features()` 做了什么转换？
- [ ] `input_features` 和 `output_features` 是如何自动推导的？
- [ ] action feature names 为什么对 relative action 很关键？
- [ ] 为什么用 dataset metadata 初始化 policy 和用 env config 初始化 policy 的后果不同？
- [ ] `cfg.pretrained_path` 存在时，policy 到底是怎样加载的？
- [ ] 为什么 `processor` 和 `policy` 都会从 checkpoint 恢复，但恢复逻辑并不相同？
- [ ] 当 feature shape 推断错误时，常见报错会出现在什么地方？
- [ ] 如果你接入一个新策略，为什么通常必须同时加 `configuration / modeling / processor / factory 注册`？
- [ ] 工厂为什么是 `LeRobot` 扩展能力的核心入口？

### 9.2 验收标准

- [ ] 你能给现有策略改一个 feature 名，并把整个链路修通。
- [ ] 你能解释为什么 feature 推断是训练和部署接线的核心。
- [ ] 你能独立给一个最小新策略完成工厂注册。

---

## 10. 训练链路

关键源码入口：

- `src/lerobot/scripts/lerobot_train.py`
- `src/lerobot/optim/factory.py`
- `src/lerobot/utils/train_utils.py`
- `src/lerobot/utils/logging_utils.py`

### 10.1 核心问题

- [ ] `train()` 从 config validate 开始，到训练结束，主流程依次经过哪些阶段？
- [ ] 为什么 dataset 在主进程和其他进程上要分阶段创建？
- [ ] `Accelerator` 除了多卡，还负责哪些事？
- [ ] `policy.forward()` 和 `update_policy()` 各自负责什么？
- [ ] loss backward、gradient clipping、optimizer step、scheduler step 为什么按那个顺序执行？
- [ ] `policy.update()` 的语义是什么？哪些策略会用到？
- [ ] `eval_freq` 在训练过程中怎么触发评估？
- [ ] checkpoint 究竟保存了哪些对象？
- [ ] `resume` 恢复了什么，没有恢复什么？
- [ ] 为什么即便使用固定 seed，训练结果仍不一定完全可复现？
- [ ] `dataset.meta.stats` 在训练时具体影响哪些模块？
- [ ] 当训练一开始就 NaN、loss 不降、梯度爆炸时，你如何沿着调用链排查？

### 10.2 验收标准

- [ ] 你能自己解释一次训练 step 的完整数据流。
- [ ] 你能修改一个训练超参，并说明它最终作用于哪层代码。
- [ ] 你能独立定位一次训练阶段的 processor / stats / batch 相关问题。

---

## 11. 评估与 rollout

关键源码入口：

- `src/lerobot/scripts/lerobot_eval.py`
- `src/lerobot/envs/factory.py`
- `src/lerobot/envs/utils.py`

### 11.1 核心问题

- [ ] rollout 的完整循环是什么？
- [ ] 为什么 eval 也必须经过 `env_preprocessor -> preprocessor -> policy -> postprocessor -> env_postprocessor`？
- [ ] `policy.reset()` 在 eval 开始时为什么必须调用？
- [ ] vector env 下，为什么 `done` 需要做 cumulative mask？
- [ ] rollout 返回的 `action / reward / success / done / observation` 各代表什么？
- [ ] 为什么并行环境中“有的环境先结束，有的后结束”会影响数据处理方式？
- [ ] 为什么 success rate 看起来简单，但背后统计并不完全直观？
- [ ] LIBERO 这类环境为什么还需要特定的 env processor？
- [ ] sim eval 表现好，为什么不等于 real-world 部署稳定？
- [ ] 如果 `lerobot-eval` 和真实机器人部署结果差很多，先查哪些层？

### 11.2 验收标准

- [ ] 你能自己追完一次 rollout 的 observation 和 action 流向。
- [ ] 你能解释为什么 eval 并不是“简单跑一下模型”。
- [ ] 你能独立区分 env 问题、processor 问题和 policy 问题。

---

## 12. 推理与部署

关键源码入口：

- `src/lerobot/utils/control_utils.py`
- `src/lerobot/scripts/lerobot_record.py`
- `src/lerobot/policies/*/modeling_*.py`

### 12.1 核心问题

- [ ] `predict_action()` 的 5 个关键步骤是什么？
- [ ] `prepare_observation_for_inference()` 做了什么？
- [ ] 为什么 inference 也要加 batch 维度？
- [ ] 为什么 deployment 依赖的不只是 model，还包括 processor 和 stats？
- [ ] `policy.reset()` 在真实机器人推理时为什么尤其重要？
- [ ] action chunking 在部署时怎么被消费？
- [ ] queue、temporal ensemble、interpolator 分别解决什么问题？
- [ ] sim eval 与 real deployment 哪些假设相同，哪些不同？
- [ ] camera key、task text、robot_type、stats 不一致时为什么特别容易炸？
- [ ] 如果一个 checkpoint 在 `eval` 正常、在 `record --policy.path=...` 不正常，你怎么查？

### 12.2 验收标准

- [ ] 你能自己把一个 checkpoint 接到真实机器人推理链路。
- [ ] 你能解释为什么部署问题很多时候不是模型结构问题。
- [ ] 你能独立定位一次 inference 与 deployment 不一致的问题。

---

## 13. 环境系统

关键源码入口：

- `src/lerobot/envs/factory.py`
- `src/lerobot/envs/libero.py`
- `src/lerobot/envs/metaworld.py`
- `src/lerobot/processor/env_processor.py`

### 13.1 核心问题

- [ ] `make_env()` 如何根据本地 config 或 Hub 远端代码创建环境？
- [ ] 为什么 env 也要有自己的 pre/post processor？
- [ ] LIBERO、MetaWorld、真实机器人 eval 在接口层的共同点和差异是什么？
- [ ] `task` 是如何被注入 observation 的？
- [ ] 环境 observation 键名和 policy 期望键名不一致时，应该在哪层修？
- [ ] 如果自己接一个新的仿真环境，最少要满足哪些接口？
- [ ] 为什么 env 是独立对象而不是 policy 的附属？
- [ ] 环境问题和 policy 问题，最有效的分离方法是什么？

### 13.2 验收标准

- [ ] 你能独立接一个最小自定义环境并跑通 eval。
- [ ] 你能指出 env-specific processor 的必要性。
- [ ] 你能解释为什么 env 适配是 benchmark 复现的关键一环。

---

## 14. 机器人、硬件与遥操设备抽象

关键源码入口：

- `src/lerobot/robots/robot.py`
- `src/lerobot/teleoperators/teleoperator.py`
- `src/lerobot/cameras/`
- `src/lerobot/motors/`

### 14.1 核心问题

- [ ] `Robot` 抽象最核心的方法有哪些？
- [ ] `Teleoperator` 抽象最核心的方法有哪些？
- [ ] `action_features` 和 `observation_features` 为什么是硬件抽象的关键？
- [ ] 为什么 `LeRobot` 能在不改训练框架的情况下替换不同机器人？
- [ ] 相机、马达、机械臂在 `LeRobot` 的抽象层次分别在哪里？
- [ ] robot calibration、port、id、camera config 分别在哪一层生效？
- [ ] 如果你要接一个新机器人，最少要实现哪些接口？
- [ ] “机器人能 send_action” 和 “机器人能完整接入 LeRobot 全链路” 之间差了哪些工作？
- [ ] 为什么硬件接入的真正难点常常不是串口，而是 feature 对齐？
- [ ] 如果动作空间维度变了，哪几层必须同时调整？

### 14.2 验收标准

- [ ] 你能解释现有某个机器人类是如何接入整个系统的。
- [ ] 你能给现有机器人加一个新的 observation key，并解释影响范围。
- [ ] 你能说清楚新增机器人最小骨架的实现路径。

---

## 15. 策略与模型实现阅读

关键源码入口：

- `src/lerobot/policies/act/`
- `src/lerobot/policies/smolvla/`
- `src/lerobot/policies/pi0/`
- `src/lerobot/policies/pi05/`
- `src/lerobot/policies/groot/`

### 15.1 通用问题

- [ ] 每个策略的 `configuration_*.py`、`modeling_*.py`、`processor_*.py` 分别负责什么？
- [ ] `select_action()` 和 `forward()` 的职责为什么不同？
- [ ] 哪些策略依赖语言输入，哪些主要依赖状态和图像？
- [ ] 为什么学策略时不能只读 `modeling_*.py`，必须联动 `processor_*.py` 一起看？
- [ ] 模型输入输出的 tensor shape 是在哪里确定的？
- [ ] action chunk / temporal ensemble / flow matching / tokenizer 这些概念分别在哪层落地？

### 15.2 ACT

- [ ] `ACT` 的输入、输出、loss、action chunking 是怎么实现的？
- [ ] `ACT` 的 temporal ensembling 解决了什么问题？
- [ ] 为什么 `ACT` 是最适合作为第一个完整读懂的策略？

### 15.3 SmolVLA

- [ ] `SmolVLA` 的 VLM、语言 token、action expert、flow matching 是怎么接起来的？
- [ ] 它的 processor 在语言和视觉输入中承担了什么角色？

### 15.4 PI0 / PI0.5

- [ ] `PI0` 和 `PI0.5` 的关键结构差异是什么？
- [ ] 哪些实现是从 OpenPI 直接 port 过来的？
- [ ] relative action、tokenizer、AdaRMS conditioning 在这两个模型里分别怎么体现？

### 15.5 GR00T

- [ ] `GR00T` 在 `LeRobot` 里究竟是完整实现，还是主要作为 wrapper 和集成层？
- [ ] 为什么学习 `GR00T` 时必须区分“LeRobot 集成代码”和“NVIDIA 官方核心代码”？

### 15.6 验收标准

- [ ] 你能完整讲清一个策略的训练输入、推理输入、输出和 loss。
- [ ] 你能对比两个策略的差异，而不是只会单独读文件。
- [ ] 你能自己回答“为什么这个策略需要这种 processor 设计”。

---

## 16. 一致性、排障与独立 debug 能力

### 16.1 核心问题

- [ ] 训练能跑但部署动作乱跳，你先检查哪 5 个地方？
- [ ] sim eval 很好但真实机器人很差，你先怀疑哪些层，为什么？
- [ ] 为什么很多问题最后并不是 model bug，而是 `feature names / stats / rename map / camera order / task text` 问题？
- [ ] 什么时候应该怀疑 checkpoint 中保存的 processor 已经过时？
- [ ] 哪类问题属于 dataset schema 问题，哪类属于输入分布问题，哪类属于控制环问题？
- [ ] 你如何判断错误发生在 `raw observation -> preprocessor` 之前，还是在 `policy -> postprocessor` 之后？
- [ ] 如果新增一路相机后模型性能明显下降，你如何分层定位？
- [ ] `action dim mismatch` 最常见的成因链是什么？
- [ ] 当你看到报错时，如何快速回溯到对应的 config、factory、processor 或 model？
- [ ] 你能否仅凭代码和日志，而不是教程，定位一次完整问题？

### 16.2 验收标准

- [ ] 你能独立完成一次系统级排障，不依赖教程。
- [ ] 你能把错误归因到正确的层，而不是笼统说“模型不行”。
- [ ] 你能复盘一次 bug，并总结它属于哪一类工程问题。

---

## 17. 真正深入掌握后，你应该已经能做到的事

- [ ] 不看教程，从零跑通一次 `teleop -> record -> dataset -> train -> eval -> deploy`
- [ ] 独立解释这条链上每一步的输入输出
- [ ] 修改一个 processor step，并验证全链路影响
- [ ] 给现有机器人增加一个 camera key，并修通训练和部署
- [ ] 读取一个策略源码，讲清输入、输出、loss、推理路径
- [ ] 独立定位一次训练和部署不一致的问题
- [ ] 给 `LeRobot` 接一个新策略的最小骨架
- [ ] 给 `LeRobot` 接一个新机器人的最小骨架
- [ ] 自己画出 `LeRobot` 全链路数据流图
- [ ] 用源码而不是教程回答“为什么某条命令有效”

---

## 18. 推荐阅读顺序

如果你准备正式进入“深入掌握”阶段，建议按这个顺序做：

1. 先建立系统主干心智模型  
   目标：能说清 `CLI -> Config -> Factory -> Processor -> Loop`
2. 再打通实机主链  
   目标：读懂 `teleoperate / record / replay`
3. 再读数据集系统  
   目标：真正理解 `features / stats / delta_timestamps`
4. 再读训练链与 eval 链  
   目标：理解训练和推理两条链的异同
5. 最后进入策略源码  
   目标：先 `ACT`，再 `SmolVLA`，再 `PI0 / PI0.5`，最后 `GR00T`

推荐策略阅读顺序：

1. `ACT`
2. `SmolVLA`
3. `PI0`
4. `PI0.5`
5. `GR00T`

---

## 19. 最后的判断标准

当你满足下面这些条件时，才建议把自己定义为“深入掌握 LeRobot”：

- 你已经不再依赖教程命令记忆，而是依赖系统理解。
- 你能独立从源码解释一条命令为何生效。
- 你能独立定位训练、评估、部署三条链中的问题。
- 你能解释 `processor`、`features`、`stats` 在全链路里的核心作用。
- 你能独立阅读并解释至少一个策略的完整实现。
- 你能自己扩展 `LeRobot`，而不只是使用 `LeRobot`。

如果你还做不到这些，不代表你学得差，只代表你仍处于“会用”或“理解中”的阶段。  
这很正常。关键不是着急下结论，而是继续沿着这份验收清单把理解补齐。
