# Autoresearch — 通用自主研究循环插件

> 自动化实验、QA 门禁、结果追踪。适用于性能优化、参数调优等探索性任务。

## 概述

Autoresearch 是一个 Claude Code 插件，通过自主 Agent 循环自动化探索性研究任务。Agent 自主决定实验方向、实施变更、执行 QA 验证、记录结果并决策保留或回退。

### 典型场景

- 性能优化（降低延迟、提高吞吐）
- 内存优化（降低内存占用）
- 参数调优（寻找最优配置）
- 算法对比（测试不同实现）

## 工作原理

```
初始化 → 生成研究计划 → 循环实验 → 自动决策
```

1. **初始化**：`/autoresearch-init` 交互式生成 `research-plan.md`
2. **循环**：`bash skills/run/autoresearch.sh [N]` 执行最多 N 次迭代
3. **每轮**：
   - 阅读 history → 选择方向 → 修改代码 → QA 门禁 → 决策
   - 成功：保留 commit，记录结果
   - 失败：`git reset`，记录失败原因

## 安装

### 作为 Claude Code 插件安装

```bash
# 克隆到项目的插件目录
git clone git@github.com:PengShiqiu/claude-auto-research-plugin.git your-project/scripts/autoresearch

# 或作为符号链接
ln -s /path/to/claude-auto-research-plugin your-project/scripts/autoresearch
```

插件结构会被自动识别：
- `.claude-plugin/plugin.json`
- `skills/*/SKILL.md`

### 快速开始

```bash
cd your-project

# 1. 生成研究计划
/autoresearch-init

# 2. 启动自主研究循环（最多 10 次迭代）
bash skills/run/autoresearch.sh 10
```

## 使用指南

### 步骤 1：生成研究计划

运行 `/autoresearch-init` 技能，回答以下问题：

1. **研究目标**：要解决什么问题？（如：降低 memhook 开销）
2. **评估方法**：如何衡量改进？（如：`make autoperf`，看 `mixed_load ns/op`）
3. **文件规则**：哪些文件可修改？哪些不可修改？
4. **QA 门禁**：每次实验必须通过哪些检查？
5. **迭代参数**：最大迭代次数、成功阈值

示例生成的 `research-plan.md` 见 `skills/init/memhook-research-plan.md`。

### 步骤 2：启动研究循环

```bash
# 运行最多 10 次迭代
bash skills/run/autoresearch.sh 10
```

循环会在以下情况结束：
- 达到最大迭代次数
- Agent 输出 `<promise>COMPLETE</promise>`（目标达成或无新思路）

### 步骤 3：查看进度

```bash
# 实时进度文件
cat progress.txt

# 历史归档
ls scripts/archive/
```

## 示例：memhook 性能优化

参见 `skills/init/memhook-research-plan.md` 完整示例。

**研究目标**：降低 memhook（内存泄漏检测工具）的运行时开销

**评估命令**：`make autoperf`

**核心指标**：`mixed_load ns/op`（有 hook），越低越好

**QA 门禁**：
1. `make test` — 全量测试通过
2. `make autoperf` — 性能数据正常采集
3. `bash scripts/stability_test.sh 300` — 5 分钟稳定性

**结果**：50+ 次迭代，开销从 3.4x 降至 0.3-0.4x

## 技能

### `/autoresearch-init`

交互式生成 `research-plan.md`。

**触发词**：`init research`、`create research plan`、`start autoresearch`

### `/autoresearch-run`

执行单次实验。通常由 `autoresearch.sh` 自动调用，也可手动运行。

**触发词**：`run experiment`、`autoresearch run`、`execute experiment`

## 插件结构

```
autoresearch/
├── .claude-plugin/
│   ├── plugin.json               # 插件配置
│   └── marketplace.json          # 市场元数据
├── skills/
│   ├── init/
│   │   ├── SKILL.md              # 初始化技能
│   │   └── memhook-research-plan.md  # 研究计划示例
│   └── run/
│       ├── SKILL.md              # 运行技能
│       └── autoresearch.sh       # 主循环脚本
├── CLAUDE.md                     # 插件开发文档
└── README.md                     # 本文件
```

## 设计原则

1. **一次一个实验** — 每次只测一个假设，避免混合变更
2. **严格 QA** — 不跳过任何门禁步骤
3. **诚实记录** — 失败的实验也要详细记录
4. **自主决策** — Agent 根据数据和代码分析判断方向
5. **噪声感知** — 区分性能数据的信号和噪声

## 常见问题

### Q：Agent 会不会无限循环？

A：不会。通过 `autoresearch.sh N` 限制最大迭代次数，Agent 也可主动输出 `<promise>COMPLETE</promise>` 提前结束。

### Q：如何恢复中断的循环？

A：`progress.txt` 保留完整历史，重新运行 `autoresearch.sh` 会继续迭代（不会重复实验）。

### Q：可以手动干预吗？

A：可以。随时 `Ctrl+C` 中断，手动修改代码或调整 research-plan.md，然后重新运行。

### Q：如何修改研究的激进程度？

A：调整 `research-plan.md` 中的迭代参数：
- `最大迭代次数`：控制总探索次数
- `提前结束条件`：如"连续 3 次无改善则结束"

## 许可

MIT

## 作者

PengShiqiu
