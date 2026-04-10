#!/bin/bash
# autoresearch - 通用自主研究循环
#
# 用法: ./autoresearch.sh [-d|--debug] [N]
#   N  — 最大迭代次数，默认 10
#
# 说明:
#   拼接通用研究技能 + 项目 research-plan.md 作为 Agent 提示词。
#   Agent 每轮迭代执行：阅读历史 → 构思方案 → 修改代码 → QA 门禁 → 决策。
#   当 Agent 输出 <promise>COMPLETE</promise> 时提前退出。
#
# 依赖: 已安装且在 PATH 中的 `claude` CLI（Anthropic Claude Code），使用 --print 非交互执行。
#
# 前置条件（满足其一即可）:
#   - 项目根目录下存在 research-plan.md（旧布局）
#   - 项目根目录下存在 autoresearch/research-plan.md（init 技能部署布局）
#   由 /autoresearch-init 生成。
#
# 调试: 设置 AUTORESEARCH_DEBUG=1，或传入 -d / --debug，可向 stderr 输出路径解析与迭代细节。

set -e

# ── 参数解析 ──────────────────────────────────────────────────

MAX_ITERATIONS=10
AUTORESEARCH_DEBUG="${AUTORESEARCH_DEBUG:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--debug)
      AUTORESEARCH_DEBUG=1
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      else
        echo "用法: $0 [-d|--debug] [N]  (N 为最大迭代次数，默认 10)" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# 调试日志（英文，输出到 stderr）
_debug() {
  [[ "$AUTORESEARCH_DEBUG" == "1" ]] || return 0
  echo "[autoresearch:debug] $*" >&2
}

# ── 解析项目根与研究计划路径 ─────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 将候选根目录依次加入列表（去重：仅追加未见过的路径）
ROOT_CANDIDATES=()

_append_root() {
  local d="$1"
  [[ -z "$d" || ! -d "$d" ]] && return
  local existing
  for existing in "${ROOT_CANDIDATES[@]}"; do
    [[ "$existing" == "$d" ]] && return
  done
  ROOT_CANDIDATES+=("$d")
  _debug "root candidate appended: $d"
}

# 1) Git 仓库根（优先）
if GIT_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null); then
  _append_root "$GIT_ROOT"
fi

# 2) 插件内布局: .../skills/run/autoresearch.sh → 仓库根 = skills/run/../..
if [[ "$(basename "$SCRIPT_DIR")" == "run" ]] && [[ "$(basename "$(dirname "$SCRIPT_DIR")")" == "skills" ]]; then
  _append_root "$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# 3) 部署布局: .../autoresearch/autoresearch.sh → 项目根 = autoresearch/..
if [[ "$(basename "$SCRIPT_DIR")" == "autoresearch" ]]; then
  _append_root "$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# 4) scripts/autoresearch.sh → 仓库根 = scripts/..
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
  _append_root "$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# 5) 旧逻辑兼容：曾将「插件根」误设为 PLUGIN_ROOT/..
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
_append_root "$PLUGIN_ROOT"
_append_root "$(cd "$PLUGIN_ROOT/.." && pwd)"

try_resolve() {
  local root="$1"
  _debug "try_resolve: root=$root"
  if [[ -f "$root/autoresearch/research-plan.md" ]]; then
    PROJECT_ROOT="$root"
    RESEARCH_PLAN="$root/autoresearch/research-plan.md"
    PROGRESS_FILE="$root/autoresearch/progress.txt"
    _debug "try_resolve: matched autoresearch/research-plan.md layout"
    return 0
  fi
  if [[ -f "$root/research-plan.md" ]]; then
    PROJECT_ROOT="$root"
    RESEARCH_PLAN="$root/research-plan.md"
    PROGRESS_FILE="$root/progress.txt"
    _debug "try_resolve: matched root research-plan.md layout"
    return 0
  fi
  _debug "try_resolve: no research-plan under $root"
  return 1
}

PROJECT_ROOT=""
RESEARCH_PLAN=""
PROGRESS_FILE=""

for cand in "${ROOT_CANDIDATES[@]}"; do
  if try_resolve "$cand"; then
    break
  fi
done

# 当前工作目录（用户在含研究计划的目录下执行）
if [[ -z "$PROJECT_ROOT" ]]; then
  _debug "fallback: try_resolve pwd=$(pwd)"
  try_resolve "$(pwd)" || true
fi

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "错误: 未找到 research-plan.md。" >&2
  echo "请在项目根放置 research-plan.md，或使用 autoresearch/research-plan.md；或先运行 /autoresearch-init。" >&2
  exit 1
fi

# run 技能文件：同目录副本优先，其次项目内 skills/run
RUN_SKILL=""
if [[ -f "$SCRIPT_DIR/SKILL.md" ]]; then
  RUN_SKILL="$SCRIPT_DIR/SKILL.md"
  _debug "RUN_SKILL: same-dir SKILL.md"
elif [[ -f "$PROJECT_ROOT/skills/run/SKILL.md" ]]; then
  RUN_SKILL="$PROJECT_ROOT/skills/run/SKILL.md"
  _debug "RUN_SKILL: project skills/run/SKILL.md"
else
  echo "错误: 未找到 run 技能 SKILL.md（已查 $SCRIPT_DIR 与 $PROJECT_ROOT/skills/run）" >&2
  exit 1
fi

# ── 前置检查 ──────────────────────────────────────────────────

if [ ! -f "$RESEARCH_PLAN" ]; then
  echo "错误: 未找到研究计划 ($RESEARCH_PLAN)" >&2
  echo "请先运行 /autoresearch-init 生成研究计划。" >&2
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "错误: claude CLI 未安装或不在 PATH 中" >&2
  exit 1
fi

_debug "SCRIPT_DIR=$SCRIPT_DIR"
_debug "PLUGIN_ROOT=$PLUGIN_ROOT"
_debug "claude=$(command -v claude)"
_debug "PROJECT_ROOT=$PROJECT_ROOT"
_debug "RESEARCH_PLAN=$RESEARCH_PLAN"
_debug "PROGRESS_FILE=$PROGRESS_FILE"
_debug "RUN_SKILL=$RUN_SKILL"

# ── 构建提示词 ────────────────────────────────────────────────

# 运行时拼接：通用研究方法论 + 项目特定规则
PROMPT_FILE=$(mktemp)
trap "rm -f \"$PROMPT_FILE\"" EXIT

{
  # 注入通用研究方法论
  echo "# 研究执行指令"
  echo ""
  echo "以下是通用研究方法论和项目特定规则。严格遵循。"
  echo ""
  echo "---"
  echo ""
  # 跳过 SKILL.md 的 YAML frontmatter（首行 --- 至下一个 ---）
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

_debug "PROMPT_FILE=$PROMPT_FILE size_bytes=$(wc -c <"$PROMPT_FILE" | tr -d ' ')"

# ── 初始化进度文件 ────────────────────────────────────────────
# 归档逻辑由 SKILL.md 指导 Agent 在首次迭代时执行

if [ ! -f "$PROGRESS_FILE" ]; then
  cat > "$PROGRESS_FILE" <<EOF
# Autoresearch 进度日志
# 项目: $(basename "$PROJECT_ROOT")
# 启动时间: $(date)
# 最大迭代: $MAX_ITERATIONS
---
EOF
fi

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

[[ "$AUTORESEARCH_DEBUG" == "1" ]] && _debug "AUTORESEARCH_DEBUG is on (set AUTORESEARCH_DEBUG=0 or omit -d to silence)"

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

  _debug "iteration=$i ITERATION_PROMPT=$ITERATION_PROMPT size_bytes=$(wc -c <"$ITERATION_PROMPT" | tr -d ' ')"

  CLAUDE_START=$(date +%s)
  # 运行 claude agent
  OUTPUT=$(claude --dangerously-skip-permissions --print --model haiku < "$ITERATION_PROMPT" 2>&1 | tee /dev/stderr) || true
  CLAUDE_END=$(date +%s)
  _debug "claude finished iteration=$i duration_sec=$((CLAUDE_END - CLAUDE_START)) output_chars=${#OUTPUT}"

  # 检查 Agent 是否发出完成信号
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    _debug "detected <promise>COMPLETE</promise>, exiting loop"
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
