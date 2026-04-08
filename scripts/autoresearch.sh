#!/bin/bash
# autoresearch - 通用自主研究循环
#
# 用法: ./autoresearch.sh [N]
#   N  — 最大迭代次数，默认 10
#
# 说明:
#   拼接通用研究技能 + 项目 research-plan.md 作为 Agent 提示词。
#   Agent 每轮迭代执行：阅读历史 → 构思方案 → 修改代码 → QA 门禁 → 决策。
#   当 Agent 输出 <promise>COMPLETE</promise> 时提前退出。
#
# 前置条件:
#   项目根目录下存在 research-plan.md（由 /autoresearch-init 生成）

set -e

# ── 参数解析 ──────────────────────────────────────────────────

MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS="$1"
  else
    echo "用法: $0 [N]  (N 为最大迭代次数，默认 10)" >&2
    exit 1
  fi
  shift
done

# ── 路径定义 ──────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/.." && pwd)"

# 检测是否在插件子目录运行，支持从项目根目录运行
if [[ ! -f "$PROJECT_ROOT/research-plan.md" ]]; then
  # 尝试当前工作目录
  if [[ -f "research-plan.md" ]]; then
    PROJECT_ROOT="$(pwd)"
  else
    echo "错误: 未找到 research-plan.md" >&2
    echo "请先运行 /autoresearch-init 生成研究计划。" >&2
    exit 1
  fi
fi

RESEARCH_PLAN="$PROJECT_ROOT/research-plan.md"
PROGRESS_FILE="$PROJECT_ROOT/progress.txt"
ARCHIVE_DIR="$PROJECT_ROOT/scripts/archive"

RUN_SKILL="$PLUGIN_ROOT/skills/run/SKILL.md"

# 如果技能文件不在插件目录（如从项目 scripts/ 运行），尝试相对路径
if [[ ! -f "$RUN_SKILL" ]]; then
  # 尝试从脚本同级的 autoresearch/ 目录查找
  RUN_SKILL="$SCRIPT_DIR/../skills/run/SKILL.md"
fi

# ── 前置检查 ──────────────────────────────────────────────────

if [ ! -f "$RESEARCH_PLAN" ]; then
  echo "错误: 未找到 research-plan.md ($RESEARCH_PLAN)" >&2
  echo "请先运行 /autoresearch-init 生成研究计划。" >&2
  exit 1
fi

if [ ! -f "$RUN_SKILL" ]; then
  echo "错误: 未找到 run 技能 ($RUN_SKILL)" >&2
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "错误: claude CLI 未安装或不在 PATH 中" >&2
  exit 1
fi

# ── 构建提示词 ────────────────────────────────────────────────

# 运行时拼接：通用研究方法论 + 项目特定规则
PROMPT_FILE=$(mktemp)
trap "rm -f $PROMPT_FILE" EXIT

{
  # 注入通用研究方法论
  echo "# 研究执行指令"
  echo ""
  echo "以下是通用研究方法论和项目特定规则。严格遵循。"
  echo ""
  echo "---"
  echo ""
  # 跳过 SKILL.md 的 YAML frontmatter
  sed '1{/^---$/d}; /^---$/{d; q}' "$RUN_SKILL" | tail -n +1
  echo ""
  echo "---"
  echo ""
  echo "# 项目研究计划"
  echo ""
  echo "以下是本项目的 research-plan.md，包含研究目标、评估方法、文件规则和 QA 门禁。"
  echo ""
  cat "$RESEARCH_PLAN"
  echo ""
  echo "---"
  echo ""
  echo "# 当前迭代信息"
  echo ""
  echo "- 迭代编号: 将在下方标注"
  echo "- 当前 commit: $(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
  echo "- 当前分支: $(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
  echo ""
} > "$PROMPT_FILE"

# ── 归档上次进度文件 ─────────────────────────────────────────

if [ -f "$PROGRESS_FILE" ]; then
  DATE=$(date +%Y-%m-%d)
  DEST_DIR="${ARCHIVE_DIR:-$PROJECT_ROOT/scripts/archive}/$DATE"
  mkdir -p "$DEST_DIR"

  ARCHIVE_DEST="$DEST_DIR/progress.txt"
  COUNTER=1
  while [ -f "$ARCHIVE_DEST" ]; do
    ARCHIVE_DEST="$DEST_DIR/progress-$COUNTER.txt"
    COUNTER=$((COUNTER + 1))
  done

  cp "$PROGRESS_FILE" "$ARCHIVE_DEST"
  echo "已归档上次进度到: $ARCHIVE_DEST"
fi

# ── 初始化进度文件 ────────────────────────────────────────────

cat > "$PROGRESS_FILE" <<EOF
# Autoresearch 进度日志
# 项目: $(basename "$PROJECT_ROOT")
# 启动时间: $(date)
# 最大迭代: $MAX_ITERATIONS
---
EOF

# ── 启动信息 ──────────────────────────────────────────────────

echo "==============================================================="
echo "  Autoresearch — 通用自主研究循环"
echo "==============================================================="
echo "  项目目录:   $PROJECT_ROOT"
echo "  最大迭代:   $MAX_ITERATIONS"
echo "  研究计划:   $RESEARCH_PLAN"
echo "  进度文件:   $PROGRESS_FILE"
echo "==============================================================="
echo ""

# ── 主循环 ────────────────────────────────────────────────────

for i in $(seq 1 $MAX_ITERATIONS); do
  ITERATION_START=$(date)
  echo "==============================================================="
  echo "  迭代 $i / $MAX_ITERATIONS"
  echo "  开始时间: $ITERATION_START"
  echo "==============================================================="

  # 注入迭代编号到提示词
  ITERATION_PROMPT=$(mktemp)
  {
    cat "$PROMPT_FILE"
    echo ""
    echo "**本次是第 $i / $MAX_ITERATIONS 次迭代。**"
  } > "$ITERATION_PROMPT"

  # 运行 claude agent
  OUTPUT=$(claude --dangerously-skip-permissions --print < "$ITERATION_PROMPT" 2>&1 | tee /dev/stderr) || true

  rm -f "$ITERATION_PROMPT"

  # 检查 Agent 是否发出完成信号
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "==============================================================="
    echo "  Agent 发出完成信号，Autoresearch 结束。"
    echo "  总共运行 $i 次迭代。"
    echo "  查看进度: $PROGRESS_FILE"
    echo "==============================================================="
    exit 0
  fi

  echo ""
  echo "迭代 $i 完成，准备下一次..."
  sleep 2
done

# ── 达到最大迭代 ──────────────────────────────────────────────

echo ""
echo "==============================================================="
echo "  已达到最大迭代次数 ($MAX_ITERATIONS)。"
echo "  查看进度: $PROGRESS_FILE"
echo "==============================================================="
exit 0
