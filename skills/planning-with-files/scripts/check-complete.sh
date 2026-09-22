#!/usr/bin/env bash
# 检查 Task/task_plan.md 中所有阶段是否完成
# 始终以 0 退出 —— 通过 stdout 报告状态
# 供 Stop hook 调用以报告任务完成情况
#
# 用法: ./check-complete.sh [plan-file]

set -uo pipefail

PLAN_FILE="${1:-Task/task_plan.md}"

if [[ ! -f "$PLAN_FILE" ]]; then
    echo '[planning-with-files] No Task/task_plan.md found -- no active planning session.'
    exit 0
fi

content=$(cat "$PLAN_FILE")

count_matches() {
    # $1 = 固定字符串模式；用 grep -o 逐个匹配计数
    local n
    n=$(printf '%s' "$content" | grep -oF -- "$1" | wc -l)
    printf '%s' "$n"
}

TOTAL=$(count_matches '### Phase')

COMPLETE=$(count_matches '**Status:** complete')
IN_PROGRESS=$(count_matches '**Status:** in_progress')
PENDING=$(count_matches '**Status:** pending')

# 回退：若未使用 **Status:** 格式，改查 [complete] 行内格式
if [[ "$COMPLETE" -eq 0 && "$IN_PROGRESS" -eq 0 && "$PENDING" -eq 0 ]]; then
    COMPLETE=$(count_matches '[complete]')
    IN_PROGRESS=$(count_matches '[in_progress]')
    PENDING=$(count_matches '[pending]')
fi

# 报告状态 —— 始终 exit 0，任务未完成属于正常状态
if [[ "$COMPLETE" -eq "$TOTAL" && "$TOTAL" -gt 0 ]]; then
    echo "[planning-with-files] ALL PHASES COMPLETE ($COMPLETE/$TOTAL)"
else
    echo "[planning-with-files] Task in progress ($COMPLETE/$TOTAL phases complete)"
    if [[ "$IN_PROGRESS" -gt 0 ]]; then
        echo "[planning-with-files] $IN_PROGRESS phase(s) still in progress."
    fi
    if [[ "$PENDING" -gt 0 ]]; then
        echo "[planning-with-files] $PENDING phase(s) pending."
    fi
fi

exit 0
