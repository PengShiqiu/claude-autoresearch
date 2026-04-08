# Autoresearch 插件重构计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 参考 claude-ralph-hub 插件规范，重写 plugin.json 配置、添加 marketplace.json、将脚本和示例移入 skill 目录、更新所有引用路径。

**Architecture:** 将 `scripts/autoresearch.sh` 移入 `skills/run/`、`examples/memhook-research-plan.md` 移入 `skills/init/`，重写 JSON 配置增加 marketplace.json，更新 SKILL.md 和 CLAUDE.md/README.md 中的路径引用。

**Tech Stack:** Claude Code 插件规范、Bash、Markdown

---

### Task 1: 重写 plugin.json 配置

**Files:**
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: 重写 plugin.json**

将现有 plugin.json 重写为 ralph-hub 风格，更新 name、description、keywords：

```json
{
  "name": "claude-auto-research-skills",
  "version": "1.1.0",
  "description": "Skills for the Autoresearch autonomous experiment loop - Generate research plans and execute iterative optimization experiments with QA gates",
  "author": {
    "name": "PengShiqiu"
  },
  "keywords": ["autoresearch", "experiment", "optimization", "iteration", "qa-gate", "research"],
  "skills": "./skills/"
}
```

- [ ] **Step 2: 验证 JSON 格式正确**

Run: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"`
Expected: 无输出（无报错）

---

### Task 2: 添加 marketplace.json

**Files:**
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: 创建 marketplace.json**

参考 ralph-hub 的 marketplace.json 格式：

```json
{
  "name": "claude-auto-research",
  "owner": {
    "name": "PengShiqiu"
  },
  "metadata": {
    "description": "Skills for the Autoresearch autonomous experiment loop - Generate research plans and execute iterative optimization experiments with QA gates",
    "version": "1.1.0"
  },
  "plugins": [
    {
      "name": "claude-auto-research-skills",
      "source": "./",
      "description": "Research plan generation and autonomous experiment execution skills with QA gates and progress tracking",
      "version": "1.1.0",
      "keywords": ["autoresearch", "experiment", "optimization", "iteration", "qa-gate", "research"],
      "category": "productivity",
      "skills": "./skills/"
    }
  ]
}
```

- [ ] **Step 2: 验证 JSON 格式正确**

Run: `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))"`
Expected: 无输出（无报错）

---

### Task 3: 移动 autoresearch.sh 到 skills/run/ 目录

**Files:**
- Move: `scripts/autoresearch.sh` → `skills/run/autoresearch.sh`
- Modify: `skills/run/autoresearch.sh` (更新路径引用)
- Delete: `scripts/` 目录（移空后）

- [ ] **Step 1: 移动脚本文件**

Run: `mv scripts/autoresearch.sh skills/run/autoresearch.sh`

- [ ] **Step 2: 更新脚本中的路径定义**

在 `skills/run/autoresearch.sh` 中，`SCRIPT_DIR` 现在指向 `skills/run/`，需要调整 `PLUGIN_ROOT` 计算。

将：
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/.." && pwd)"
```

改为：
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/.." && pwd)"
```

因为 `SCRIPT_DIR` 现在是 `skills/run/`，`../..` 才能回到插件根目录。

- [ ] **Step 3: 更新 RUN_SKILL 路径**

将：
```bash
RUN_SKILL="$PLUGIN_ROOT/skills/run/SKILL.md"
```

改为：
```bash
RUN_SKILL="$SCRIPT_DIR/SKILL.md"
```

因为 `autoresearch.sh` 和 `SKILL.md` 现在在同一目录。

同时将备用路径查找：
```bash
if [[ ! -f "$RUN_SKILL" ]]; then
  RUN_SKILL="$SCRIPT_DIR/../skills/run/SKILL.md"
fi
```

改为：
```bash
if [[ ! -f "$RUN_SKILL" ]]; then
  RUN_SKILL="$PLUGIN_ROOT/skills/run/SKILL.md"
fi
```

- [ ] **Step 4: 确保脚本可执行**

Run: `chmod +x skills/run/autoresearch.sh`

- [ ] **Step 5: 删除空的 scripts 目录**

Run: `rmdir scripts`

- [ ] **Step 6: 验证脚本路径逻辑**

Run: `bash -n skills/run/autoresearch.sh`
Expected: 无输出（语法正确）

---

### Task 4: 移动示例文件到 skills/init/ 目录

**Files:**
- Move: `examples/memhook-research-plan.md` → `skills/init/memhook-research-plan.md`
- Delete: `examples/` 目录（移空后）

- [ ] **Step 1: 移动示例文件**

Run: `mv examples/memhook-research-plan.md skills/init/memhook-research-plan.md`

- [ ] **Step 2: 删除空的 examples 目录**

Run: `rmdir examples`

---

### Task 5: 更新 SKILL.md 中的路径引用

**Files:**
- Modify: `skills/init/SKILL.md`
- Modify: `skills/run/SKILL.md`

- [ ] **Step 1: 更新 init/SKILL.md**

init/SKILL.md 中没有直接引用脚本路径，但可在末尾添加示例文件引用说明。

在 `## 注意事项` 部分末尾添加：

```markdown
- 示例研究计划见本技能目录下的 `memhook-research-plan.md`
```

- [ ] **Step 2: 更新 run/SKILL.md**

在 run/SKILL.md 中没有直接引用脚本路径，但可在 `## 退出条件` 之前添加脚本调用说明：

```markdown
## 批量循环

使用 `autoresearch.sh` 可自动循环执行本技能：

```bash
# 从插件根目录运行
bash skills/run/autoresearch.sh 10

# 或从 skills/run/ 目录运行
cd skills/run && bash autoresearch.sh 10
```
```

---

### Task 6: 更新 CLAUDE.md 插件结构说明

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 更新目录结构图**

将 CLAUDE.md 中的目录结构：

```
autoresearch/
├── .claude-plugin/plugin.json    # 插件配置
├── skills/
│   ├── init/SKILL.md             # 生成 research-plan.md 的交互式技能
│   └── run/SKILL.md              # 执行单次实验的技能
├── scripts/
│   └── autoresearch.sh           # 主循环脚本
└── examples/
    └── memhook-research-plan.md  # 研究计划示例
```

替换为：

```
autoresearch/
├── .claude-plugin/
│   ├── plugin.json               # 插件配置
│   └── marketplace.json          # 市场元数据
├── skills/
│   ├── init/
│   │   ├── SKILL.md              # 生成 research-plan.md 的交互式技能
│   │   └── memhook-research-plan.md  # 研究计划示例
│   └── run/
│       ├── SKILL.md              # 执行单次实验的技能
│       └── autoresearch.sh       # 主循环脚本
├── CLAUDE.md
└── README.md
```

- [ ] **Step 2: 更新工作流程中的脚本路径引用**

将：
```
3. 用户运行 `./scripts/autoresearch.sh [N]`
```

改为：
```
3. 用户运行 `bash skills/run/autoresearch.sh [N]`
```

- [ ] **Step 3: 更新 autoresearch.sh 机制说明**

将：
```
`scripts/archive/{date}/`
```

保持不变（archive 路径是相对于项目根目录的，不是插件目录）。

- [ ] **Step 4: 更新插件结构部分**

将 `### autoresearch.sh 机制` 中的路径引用更新。

- [ ] **Step 5: 提交变更**

```bash
git add -A
git commit -m "refactor: 重构插件目录结构，将脚本和示例移入 skill 目录

- scripts/autoresearch.sh → skills/run/autoresearch.sh
- examples/ → skills/init/
- 添加 marketplace.json
- 重写 plugin.json（v1.1.0）
- 更新所有路径引用"
```

---

### Task 7: 更新 README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 更新安装和使用说明中的路径**

将所有 `./scripts/autoresearch.sh` 替换为 `bash skills/run/autoresearch.sh`。
将 `./scripts/autoresearch/autoresearch.sh` 替换为 `bash skills/run/autoresearch.sh`。

- [ ] **Step 2: 更新插件结构图**

将：
```
autoresearch/
├── .claude-plugin/plugin.json    # 插件配置
├── skills/
│   ├── init/SKILL.md             # 初始化技能
│   └── run/SKILL.md              # 运行技能
├── scripts/
│   └── autoresearch.sh           # 主循环脚本
├── examples/
│   └── memhook-research-plan.md  # 研究计划示例
├── CLAUDE.md                      # 插件开发文档
└── README.md                      # 本文件
```

替换为：

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

- [ ] **Step 3: 更新示例路径引用**

将 `examples/memhook-research-plan.md` 替换为 `skills/init/memhook-research-plan.md`。

- [ ] **Step 4: 更新历史归档路径**

将 `scripts/archive/` 保持不变或更新为说明归档目录是项目级别的。
