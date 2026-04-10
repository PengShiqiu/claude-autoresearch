#!/bin/bash
# autoresearch - 通用自主研究循环
#
# 用法: ./autoresearch.sh [-d|--debug] [N]
#   N  — 最大迭代次数，默认 10
#
# 依赖: 已安装且在 PATH 中的 `claude` CLI（Anthropic Claude Code），使用 --print 非交互执行。

set -e

# ── 参数解析 ──────────────────────────────────────────────────

MAX_ITERATIONS=10
AUTORESEARCH_DEBUG="${AUTORESEARCH_DEBUG:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--debug) AUTORESEARCH_DEBUG=1; shift ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"; shift
      else
        echo "用法: $0 [-d|--debug] [N]" >&2; exit 1
      fi
      ;;
  esac
done

_debug() {
  [[ "$AUTORESEARCH_DEBUG" == "1" ]] && echo "[autoresearch:debug] $*" >&2 || true
}

# ── 探测项目根 ────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_project_root() {
  local candidates=()

  # Git 仓库根
  if GIT_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null); then
    candidates+=("$GIT_ROOT")
  fi
  # 插件内布局: skills/run/ → ../..
  if [[ "$(basename "$SCRIPT_DIR")" == "run" ]] && [[ "$(basename "$(dirname "$SCRIPT_DIR")")" == "skills" ]]; then
    candidates+=("$(cd "$SCRIPT_DIR/../.." && pwd)")
  fi
  # 部署布局: autoresearch/ → ../
  if [[ "$(basename "$SCRIPT_DIR")" == "autoresearch" ]]; then
    candidates+=("$(cd "$SCRIPT_DIR/.." && pwd)")
  fi
  # scripts/ → ../
  if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
    candidates+=("$(cd "$SCRIPT_DIR/.." && pwd)")
  fi
  # 当前工作目录
  candidates+=("$(pwd)")

  # 去重并查找 research-plan.md
  local seen=()
  for cand in "${candidates[@]}"; do
    [[ -z "$cand" || ! -d "$cand" ]] && continue
    local skip=""
    for s in "${seen[@]}"; do [[ "$s" == "$cand" ]] && skip=1 && break; done
    [[ -n "$skip" ]] && continue
    seen+=("$cand")

    if [[ -f "$cand/autoresearch/research-plan.md" ]]; then
      PROJECT_ROOT="$cand"
      RESEARCH_PLAN="$cand/autoresearch/research-plan.md"
      PROGRESS_FILE="$cand/autoresearch/progress.txt"
      return 0
    fi
    if [[ -f "$cand/research-plan.md" ]]; then
      PROJECT_ROOT="$cand"
      RESEARCH_PLAN="$cand/research-plan.md"
      PROGRESS_FILE="$cand/progress.txt"
      return 0
    fi
  done
  return 1
}

find_run_skill() {
  if [[ -f "$SCRIPT_DIR/SKILL.md" ]]; then
    echo "$SCRIPT_DIR/SKILL.md"
  elif [[ -f "$PROJECT_ROOT/skills/run/SKILL.md" ]]; then
    echo "$PROJECT_ROOT/skills/run/SKILL.md"
  else
    return 1
  fi
}

# ── 路径解析 ──────────────────────────────────────────────────

if ! find_project_root; then
  echo "错误: 未找到 research-plan.md。请先运行 /autoresearch-init。" >&2
  exit 1
fi

RUN_SKILL=$(find_run_skill) || {
  echo "错误: 未找到 SKILL.md（已查 $SCRIPT_DIR 与 $PROJECT_ROOT/skills/run）" >&2
  exit 1
}

command -v claude &>/dev/null || { echo "错误: claude CLI 未安装或不在 PATH 中" >&2; exit 1; }

_debug "PROJECT_ROOT=$PROJECT_ROOT RESEARCH_PLAN=$RESEARCH_PLAN RUN_SKILL=$RUN_SKILL"

# ── 提示词生成（无临时文件，输出到 stdout）──────────────────────

generate_prompt() {
  local iteration="$1"
  local max="$2"

  echo "# 研究执行指令"
  echo ""
  echo "以下是通用研究方法论和项目特定规则。严格遵循。"
  echo ""
  echo "---"
  echo ""
  # 去除 SKILL.md 的 YAML frontmatter
  sed '1{/^---$/d}; /^---$/{d; q}' "$RUN_SKILL" | tail -n +2
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
  echo "**本次是第 $iteration / $max 次迭代。**"
  echo "- 当前 commit: $(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
  echo "- 当前分支: $(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
}

# ── 初始化进度文件 ────────────────────────────────────────────

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

# ── 主循环 ────────────────────────────────────────────────────

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  迭代 $i / $MAX_ITERATIONS  —  $(date)"
  echo "==============================================================="

  _debug "running iteration $i"

  # 管道直接传递提示词，无临时文件
  OUTPUT=$(generate_prompt "$i" "$MAX_ITERATIONS" \
    | claude --dangerously-skip-permissions --print 2>&1 \
    | tee /dev/stderr) || true

  # 检查完成信号
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "==============================================================="
    echo "  Agent 发出完成信号。总共运行 $i 次迭代。"
    echo "  查看进度: $PROGRESS_FILE"
    echo "==============================================================="
    exit 0
  fi

  echo "迭代 $i 完成，准备下一次..."
  sleep 2
done

echo ""
echo "==============================================================="
echo "  已达到最大迭代次数 ($MAX_ITERATIONS)。"
echo "  查看进度: $PROGRESS_FILE"
echo "==============================================================="
