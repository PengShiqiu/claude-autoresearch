#!/bin/bash
# generate-prompt.sh - 仅生成 Autoresearch 提示词，输出到 stdout
#
# 用法: ./generate-prompt.sh [项目目录]
#   - 若未提供目录，则自动从脚本所在位置向上探测包含 research-plan.md 的项目根。
#   - 错误信息输出到 stderr，提示词内容输出到 stdout。
#
# 依赖: 无（仅需标准 Unix 工具：sed、git 等可选）。

set -e

# --- 参数处理 -------------------------------------------------
PROJECT_DIR="${1:-}"

# --- 探测项目根与研究计划 -------------------------------------
find_project_root() {
    local start_dir="$1"
    local candidates=()

    # 若用户指定了目录，直接加入候选
    if [[ -n "$start_dir" ]]; then
        candidates+=("$(cd "$start_dir" && pwd)")
    else
        # 否则从脚本所在目录出发，按优先级探测
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

        # 1) Git 仓库根
        if GIT_ROOT=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null); then
            candidates+=("$GIT_ROOT")
        fi

        # 2) skills/run 内的脚本 → 仓库根在 skills/../..
        if [[ "$(basename "$script_dir")" == "run" ]] && [[ "$(basename "$(dirname "$script_dir")")" == "skills" ]]; then
            candidates+=("$(cd "$script_dir/../.." && pwd)")
        fi

        # 3) autoresearch/ 内的脚本 → 项目根在 ../
        if [[ "$(basename "$script_dir")" == "autoresearch" ]]; then
            candidates+=("$(cd "$script_dir/.." && pwd)")
        fi

        # 4) scripts/ 内的脚本 → 项目根在 ../
        if [[ "$(basename "$script_dir")" == "scripts" ]]; then
            candidates+=("$(cd "$script_dir/.." && pwd)")
        fi

        # 5) 当前工作目录
        candidates+=("$(pwd)")
    fi

    # 去重
    local unique_candidates=()
    local cand
    for cand in "${candidates[@]}"; do
        [[ -z "$cand" || ! -d "$cand" ]] && continue
        local already=""
        for u in "${unique_candidates[@]}"; do
            [[ "$u" == "$cand" ]] && already=1 && break
        done
        [[ -z "$already" ]] && unique_candidates+=("$cand")
    done

    # 查找含有 research-plan.md 的根
    for cand in "${unique_candidates[@]}"; do
        if [[ -f "$cand/autoresearch/research-plan.md" ]]; then
            PROJECT_ROOT="$cand"
            RESEARCH_PLAN="$cand/autoresearch/research-plan.md"
            return 0
        elif [[ -f "$cand/research-plan.md" ]]; then
            PROJECT_ROOT="$cand"
            RESEARCH_PLAN="$cand/research-plan.md"
            return 0
        fi
    done

    return 1
}

# --- 定位 run 技能文件 -----------------------------------------
find_run_skill() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$1"

    # 优先同目录的 SKILL.md
    if [[ -f "$script_dir/SKILL.md" ]]; then
        echo "$script_dir/SKILL.md"
    elif [[ -f "$project_root/skills/run/SKILL.md" ]]; then
        echo "$project_root/skills/run/SKILL.md"
    else
        return 1
    fi
}

# --- 主逻辑 ---------------------------------------------------
if ! find_project_root "$PROJECT_DIR"; then
    echo "错误: 未找到 research-plan.md。" >&2
    echo "请在项目根放置 research-plan.md 或 autoresearch/research-plan.md。" >&2
    exit 1
fi

RUN_SKILL=$(find_run_skill "$PROJECT_ROOT")
if [[ -z "$RUN_SKILL" ]]; then
    echo "错误: 未找到 run 技能文件 SKILL.md。" >&2
    exit 1
fi

# --- 组装提示词并输出到 stdout --------------------------------
{
    echo "# 研究执行指令"
    echo ""
    echo "以下是通用研究方法论和项目特定规则。严格遵循。"
    echo ""
    echo "---"
    echo ""

    # 去除 SKILL.md 的 YAML frontmatter（第一个 --- 到下一个 --- 之间的内容）
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
    echo "# 环境信息"
    echo ""
    echo "- 当前 commit: $(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    echo "- 当前分支: $(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
    echo "- 项目根目录: $PROJECT_ROOT"
}
