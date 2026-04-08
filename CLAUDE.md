# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Autoresearch 插件架构

通用自主研究循环插件，用于自动化实验迭代、QA 门禁和结果追踪。适用于性能优化、参数调优等探索性任务。

### 核心组件

**插件目录结构：**

```
autoresearch/                     # 插件根目录
├── .claude-plugin/
│   ├── plugin.json               # 插件配置
│   └── marketplace.json          # 市场元数据
├── skills/
│   ├── init/
│   │   ├── SKILL.md              # 生成研究计划 + 部署文件的交互式技能
│   │   └── memhook-research-plan.md  # 研究计划示例
│   └── run/
│       ├── SKILL.md              # 执行单次实验的技能
│       └── autoresearch.sh       # 主循环脚本（源文件）
├── scripts/
│   └── autoresearch.sh           # 主循环脚本（副本，与 skills/run/ 同步）
├── CLAUDE.md
└── README.md
```

**部署到用户项目后的结构（由 init 技能创建）：**

```
用户项目/
└── autoresearch/
    ├── research-plan.md    ← 研究计划（init 生成）
    ├── autoresearch.sh     ← 执行脚本（从插件拷贝）
    ├── SKILL.md            ← 执行技能（从插件拷贝）
    ├── progress.txt        ← 日志（运行时生成）
    └── archive/            ← 进度归档（运行时生成）
```

### 工作流程

```
1. 用户运行 /autoresearch-init
   ↓
2. init 技能通过问答生成 research-plan.md
   ↓
3. init 技能部署执行文件到项目 autoresearch/ 目录
   （拷贝 autoresearch.sh + SKILL.md）
   ↓
4. 用户运行 bash autoresearch/autoresearch.sh [N]
   ↓
5. autoresearch.sh 拼接 run 技能 + research-plan.md 作为提示词
   ↓
6. Claude Agent 执行迭代：
   - 阅读 research-plan.md 和 progress.txt
   - 选择实验方向（自主决策）
   - 修改代码 → git commit
   - 执行 QA 门禁
   - 决策：保留 or git reset
   - 记录结果到 progress.txt 和 research-plan.md
   ↓
7. 输出 <promise>COMPLETE</promise> 时结束，否则继续下一轮
```

### 技能设计

#### init 技能

- **触发词**：`/autoresearch-init`、`init research`、`create research plan`
- **输出**：项目 `autoresearch/research-plan.md` + 部署执行文件
- **流程**：
  1. 分析项目（CLAUDE.md、文件结构、已有研究计划）
  2. 交互式问答收集：研究目标、评估方法、文件规则、QA 门禁
  3. 生成 research-plan.md 到 autoresearch/
  4. 部署 autoresearch.sh + SKILL.md 到项目 autoresearch/ 目录
  5. 执行首次基准评估

#### run 技能

- **触发词**：`/autoresearch-run`、`run experiment`
- **用途**：autoresearch.sh 调用或手动单次实验
- **流程**：
  1. 理解上下文（research-plan.md + progress.txt）
  2. 选择实验方向（自主决策，基于历史和代码分析）
  3. 实施实验 + git commit
  4. QA 门禁（严格顺序，失败即回退）
  5. 决策（保留/回退）+ 记录结果
  6. 输出 `<promise>CONTINUE</promise>` 或 `<promise>COMPLETE</promise>`

### research-plan.md 结构

```markdown
## 研究目标
## 评估方法（命令 + 指标解析）
## 文件规则（可修改/不可修改）
## QA 门禁
## 迭代参数（最大次数、提前结束条件）
## 实验记录表（Agent 自主填充）
## 待探索方向（Agent 自主维护）
## 当前最优（基准指标）
```

### autoresearch.sh 机制

1. **提示词拼接**：通用研究方法论（SKILL.md）+ 项目规则（research-plan.md）
2. **迭代控制**：for 循环，最多 N 次，检测 `<promise>COMPLETE</promise>` 提前退出
3. **进度归档**：每次运行前归档旧的 progress.txt 到 `autoresearch/archive/{date}/`
4. **路径检测**：自动检测 research-plan.md 位置（优先 `autoresearch/`，其次项目根目录）；支持部署布局、插件内布局、旧布局

### 设计原则

1. **一次一个实验** — 每次只测一个假设，避免混合变更
2. **严格 QA** — 不跳过任何门禁步骤
3. **诚实记录** — 失败的实验也要详细记录
4. **自主决策** — Agent 根据数据和代码分析判断方向
5. **噪声感知** — 区分性能数据的信号和噪声（±10% 波动视为噪声）

### 扩展到新项目

1. 将本插件安装到 Claude Code
2. 在目标项目中运行 `/autoresearch-init`
3. init 技能自动在项目中创建 `autoresearch/` 目录并部署执行文件
4. 运行 `bash autoresearch/autoresearch.sh [N]` 启动自主研究循环

### 代码规范

- 注释使用中文
- 变量/函数名使用英文
- 日志使用英文
- 遵循现有项目代码风格
