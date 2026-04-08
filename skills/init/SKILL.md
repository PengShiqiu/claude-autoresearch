---
name: autoresearch-init
description: "交互式生成研究计划文档（research-plan.md）并部署执行文件到项目目录。适用于：启动自动化研究循环、性能优化、参数调优等探索性任务。Triggers on: init research, create research plan, start autoresearch, setup autoresearch."
user-invocable: true
---

# Autoresearch 初始化 — 生成研究计划 & 部署执行文件

交互式生成 `research-plan.md`，并将执行脚本和技能文件部署到项目的 `autoresearch/` 目录。

---

## 任务

1. 分析当前项目结构和代码
2. 通过交互式问答收集研究参数
3. 生成 `research-plan.md` 到项目 `autoresearch/` 目录
4. 部署执行文件到项目 `autoresearch/` 目录
5. 执行首次基准评估

---

## 第一步：项目分析

在提问前，先自动分析：

1. **读取项目 CLAUDE.md**（如存在）— 了解项目上下文
2. **扫描项目结构** — 识别主要源文件、测试文件、构建系统
3. **检查已有 autoresearch/research-plan.md** — 如存在，询问是否覆盖或更新
4. **检查已有 autoresearch/progress.txt** — 如存在，读取历史实验数据

---

## 第二步：交互式问答

按顺序提出以下问题（每题独立一条消息，带选项）：

### Q1：研究目标

> 这次研究要解决什么问题？
> A. 性能优化（降低延迟/提高吞吐）
> B. 内存优化（降低内存占用）
> C. 正确性修复（修复 bug/竞态）
> D. 其他：[请说明]

根据回答追问具体指标（如"将 X 的开销从 Y 降到 Z"）。

### Q2：评估方法

> 如何衡量改进效果？请描述评估命令和关键指标。
> A. 运行 benchmark 脚本，看 ns/op / QPS 等数值
> B. 运行测试套件，看通过率和覆盖率
> C. 运行特定命令，检查输出是否符合预期
> D. 其他：[请说明]

追问具体的：
- 评估命令（如 `make perf`、`python bench.py`）
- 关键指标名称（如 `mixed_load ns/op`）
- 指标方向（越低越好 / 越高越好）
- 目标值（如 `overhead < 2.0x`）

### Q3：允许修改的文件

> 哪些文件可以修改？哪些绝对不能改？

列出扫描到的关键文件，让用户标记：
- ✅ 可修改（研究目标）
- ❌ 不可修改（评估基准、构建系统等）

### Q4：QA 门禁

> 每次实验必须通过哪些检查？

建议选项：
- A. 编译通过 + 全量测试
- B. 编译通过 + 测试 + 稳定性测试
- C. 编译通过 + 测试 + 性能不退化
- D. 自定义

追问具体的门禁命令。

### Q5：稳定性验证

> 是否需要长时间稳定性测试？

- A. 需要（如 `bash scripts/stability_test.sh 300`）
- B. 不需要
- C. 仅在重大变更时需要

### Q6：迭代参数

> 最大迭代次数？（默认 10）
> 成功标准阈值？（如"连续 3 次无改善则提前结束"）

---

## 第三步：生成 research-plan.md

根据问答结果，按以下模板生成到 `autoresearch/research-plan.md`：

```markdown
# {项目名} 研究计划

> 由 autoresearch-init 自动生成 | {日期}

## 研究目标

{一句话描述研究目标}

**核心指标**：{指标名}，{方向}，目标：{目标描述}（「越低越好」写清上限/降幅，「越高越好」写清下限/升幅）

## 评估方法

| 步骤 | 命令 | 说明 |
|------|------|------|
| 构建 | {build_cmd} | 编译项目 |
| 评估 | {eval_cmd} | 采集性能数据 |
| 测试 | {test_cmd} | 全量测试 |
| 稳定性 | {stability_cmd} | 长时间运行（可选） |

**指标解析**：从 `{eval_output}` 中提取 `{metric_name}` 字段。

## 文件规则

| 文件 | 可修改？ | 说明 |
|------|---------|------|
| {file} | {status} | {reason} |

## QA 门禁

每次实验**必须**通过以下检查才能保留：

1. {gate_1}
2. {gate_2}
3. {gate_n}
4. 核心指标相对当前最优**不退化**（在约定噪声范围内视为持平）：以本计划「核心指标」中的**方向**为准——「越低越好」时新结果不得劣于当前最优，「越高越好」时新结果不得劣于当前最优

## 迭代参数

- **最大迭代次数**：{max_iterations}
- **提前结束条件**：连续 {consecutive_no_improve} 次无改善

## 实验记录

| # | 实验 | 结果 | 决策 | 指标值 |
|---|------|------|------|--------|
| - | *（Agent 自主填写）* | | | |

## 待探索方向

*（Agent 根据代码分析和实验结果自主维护此列表）*

## 当前最优

- **指标值**：{initial_value 或 "待首次评估"}
- **commit**：{current_commit}
```

---

## 第四步：部署执行文件到项目目录

生成 `research-plan.md` 后，将执行文件从插件技能目录拷贝到用户项目的 `autoresearch/` 目录。

### 目标结构

```
用户项目/
└── autoresearch/
    ├── research-plan.md    ← 刚生成的研究计划
    ├── autoresearch.sh     ← 主循环脚本（从插件拷贝）
    ├── SKILL.md            ← 执行技能（从插件拷贝）
    └── progress.txt        ← 运行时自动生成
```

### 源文件位置

| 文件 | 源路径（插件技能目录） | 目标路径（用户项目） |
|------|----------------------|-------------------|
| `autoresearch.sh` | 本技能目录 `../run/autoresearch.sh` | 用户项目 `autoresearch/autoresearch.sh` |
| `SKILL.md` | 本技能目录 `../run/SKILL.md` | 用户项目 `autoresearch/SKILL.md` |

### 操作步骤

1. 创建用户项目的 `autoresearch/` 目录（如不存在）
2. 将 `autoresearch.sh` 和 `SKILL.md` 从本插件技能目录拷贝到 `autoresearch/`（若目标已存在则**不覆盖**，提示用户确认）
3. 确认 `autoresearch/autoresearch.sh` 具有可执行权限（`chmod +x`）
4. 告知用户运行命令：`bash autoresearch/autoresearch.sh [N]`

### 注意

- 如果用户项目已有 `autoresearch/` 目录，不要覆盖其中不相关的文件
- 如果 `research-plan.md` 或 `progress.txt` 已存在，先执行归档（见下方）
- 此步骤在生成 research-plan.md 之后执行

---

## 归档上一轮运行

**写入新的 research-plan.md 前，检查用户项目 `autoresearch/` 目录下是否已有上一轮的文件：**

1. 若 `autoresearch/research-plan.md` 存在，先读取当前内容
2. 若 `progress.txt` 除标题外还有内容：
   - 创建归档目录：`autoresearch/archive/YYYY-MM-DD/`
   - 将当前 `research-plan.md` 与 `progress.txt` 复制到归档
   - 用新的标题头重置 `progress.txt`

---

## 第五步：首次基准评估

生成 research-plan.md 并部署文件后，执行一次基准评估：

1. 运行评估命令采集当前指标
2. 将结果写入 research-plan.md 的"当前最优"部分
3. 如果有历史数据（progress.txt），一并整理到实验记录表

---

## 保存前检查清单

写入文件前请确认：

- [ ] **autoresearch/ 目录已创建**
- [ ] **research-plan.md 已写入** `autoresearch/research-plan.md`
- [ ] **autoresearch.sh 已拷贝**到 `autoresearch/` 且具有可执行权限
- [ ] **SKILL.md 已拷贝**到 `autoresearch/`
- [ ] **已归档上一轮**（若已有 research-plan.md 且 progress.txt 有内容）
- [ ] **核心指标已填写**（名称、方向、目标值）
- [ ] **评估命令可执行**（build_cmd / eval_cmd / test_cmd）
- [ ] **文件规则已明确**（可修改 / 不可修改标记完整）
- [ ] **QA 门禁命令可执行**
- [ ] **基准评估已完成**，"当前最优"部分已填写
- [ ] **Git 状态干净**（无未提交的变更干扰后续实验）

---

## 注意事项

- research-plan.md 是 **配置文件**，不是提示词 — 简洁精确
- 文件规则中的"不可修改"列表会被 autoresearch 循环严格执行
- QA 门禁命令必须是可执行的 shell 命令
- 指标解析规则要明确到可以自动化提取数值
- 示例研究计划见本技能目录下的 `memhook-research-plan.md`
