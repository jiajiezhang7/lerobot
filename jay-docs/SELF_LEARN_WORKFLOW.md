# LeRobot 自学 Fork 工作流说明

本文档记录当前这份 `lerobot` 仓库在自学场景下的 Git 使用约定，包括为什么要 fork、当前分支结构，以及以后如何同步官方更新。

## 1. 这份仓库的定位

这不是一份“直接在官方仓库上开发并提 PR”的工作副本，而是一份**以个人学习为主的 fork 仓库**。

主要用途：

- 长期阅读 LeRobot 源码
- 编写个人学习笔记
- 做小范围实验和验证
- 保留自己的分支和提交历史
- 在需要时，仍然能够方便地跟进官方更新

## 2. 为什么选择 fork

选择 fork 的原因是：

1. 需要有一个**属于自己的远端仓库**，用来保存 `self-learn` 这类学习分支。
2. 不希望把个人笔记、实验性改动直接堆在官方仓库的上下文里。
3. 仍然希望保留与官方仓库的连接，方便同步 `huggingface/lerobot` 的最新更新。
4. 将来如果某些改动有价值，仍然可以基于自己的 fork 发起 PR。

简单说：

- `upstream` 负责跟踪官方
- `origin` 负责保存自己的工作

这正是 fork 最适合的场景。

## 3. 当前远端结构

当前本地仓库的 remote 约定如下：

```bash
origin   -> git@github.com:jiajiezhang7/lerobot.git
upstream -> https://github.com/huggingface/lerobot.git
```

含义：

- `origin` 是自己的 fork，默认推送目标
- `upstream` 是官方仓库，只用于拉取和同步

## 4. 当前分支策略

### `main`

`main` 的职责是：

- 尽量保持和官方 `upstream/main` 同步
- 作为本地其他学习分支的基线
- 不放个人学习笔记、临时实验和杂项提交

约定：

- `origin/main` 应尽量等于或紧跟 `upstream/main`
- 同步官方更新时，优先更新本地 `main`，再推送到 `origin/main`

### `self-learn`

`self-learn` 的职责是：

- 保存个人学习笔记
- 保存阅读源码过程中的说明文档
- 保存自学过程中的临时实验或辅助材料

当前状态约定：

- `self-learn` 基于最新的 `origin/main`
- 这是一个**个人使用分支**
- 因为只给自己使用，所以允许使用 `rebase`
- 在 rebase 之后，推送远端时使用 `--force-with-lease`

## 5. 当前 Git 身份

当前仓库的本地 Git 身份设置为：

```bash
user.name  = JiajieZhang
user.email = jerryzhang7@126.com
```

这是 `git config --local` 级别配置，只作用于当前仓库。

## 6. 推荐的日常工作方式

### 情况 A：继续记笔记、做学习实验

直接在 `self-learn` 上工作：

```bash
git checkout self-learn
```

完成后提交并推送：

```bash
git add <files>
git commit -m "your message"
git push origin self-learn
```

### 情况 B：同步官方更新

先同步官方到本地 `main`，再推到自己的 fork：

```bash
git checkout main
git fetch upstream
git merge --ff-only upstream/main
git push origin main
```

说明：

- 这里使用 `--ff-only`，是为了保持 `main` 尽量干净，不引入多余 merge commit
- 如果 `main` 被自己改脏了，`--ff-only` 会失败，从而提醒先处理分歧

### 情况 C：让 `self-learn` 跟上最新主线

由于这是一条纯个人分支，推荐使用 `rebase`：

```bash
git checkout self-learn
git fetch origin
git rebase origin/main
git push --force-with-lease origin self-learn
```

这样做的好处是：

- `self-learn` 历史更干净
- 自己的学习提交始终位于最新主线之上
- 更容易看出“官方更新”和“个人笔记”之间的差异

## 7. 推荐的完整同步流程

如果想完整同步一次官方更新，并让学习分支一起前进，推荐按这个顺序：

```bash
git checkout main
git fetch upstream
git merge --ff-only upstream/main
git push origin main

git checkout self-learn
git rebase origin/main
git push --force-with-lease origin self-learn
```

## 8. 为什么这里推荐 rebase

对 `self-learn` 使用 `rebase` 是因为这条分支满足以下条件：

- 主要是个人使用
- 不需要多人共享稳定提交哈希
- 更看重线性历史和阅读体验

如果以后这条分支开始被多人共同使用，就不应频繁 rebase 已公开共享的历史。

## 9. 建议遵守的规则

建议长期保持以下规则：

1. 不要把个人学习笔记直接提交到 `main`。
2. `main` 只承担“跟随官方”的职责。
3. 学习相关内容优先放在 `self-learn`。
4. 每次同步官方更新时，先更新 `main`，再更新 `self-learn`。
5. 对 `self-learn` 做 rebase 后，推送时使用 `git push --force-with-lease`，不要直接 `--force`。

## 10. 未来可以扩展的分支方式

如果后续学习更深入，可以在 `self-learn` 之外再开更细的主题分支，例如：

- `study/datasets`
- `study/policies`
- `study/teleop`
- `experiment/<topic>`

推荐做法：

- 主题分支从 `self-learn` 或最新 `main` 切出
- 阶段性成果再合并回 `self-learn`

这样可以让 `self-learn` 继续保持“个人主学习分支”的角色。

## 11. 一句话总结

当前这份仓库采用的是：

- `upstream` 跟踪官方
- `origin` 保存个人 fork
- `main` 负责同步官方
- `self-learn` 负责个人学习内容

这套结构适合长期阅读源码、写笔记、保留实验，同时不会失去与官方主线的同步能力。
