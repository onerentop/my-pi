#!/usr/bin/env bash
# planning-with-files: 会话补全脚本（bash + jq 版，移植自 session-catchup.ps1）
# 分析上一次会话，在最后一次 planning 文件更新之后，提取尚未同步到文件的上下文。
# 设计用于 SessionStart hook。
# 用法: ./session-catchup.sh [project-path]
#
# 会话目录解析顺序：
#   1. $PLANNING_PROJECTS_DIR（显式覆盖）
#   2. 脚本所在位置上溯三级 + /projects（对应原 Windows 版行为）
#   3. ~/.claude/projects（Claude Code 默认会话目录）

set -uo pipefail

PROJECT_PATH="${1:-$PWD}"
TASK_DIR="Task"
PLANNING_FILES=("task_plan.md" "progress.md" "findings.md")

command -v jq >/dev/null 2>&1 || { echo "[planning-with-files] 需要 jq，未安装，跳过 catchup" >&2; exit 0; }

# ---------- 前置检查：本项目是否有 planning 文件 ----------
has_planning=0
for pf in "${PLANNING_FILES[@]}"; do
    [[ -f "$PROJECT_PATH/$TASK_DIR/$pf" ]] && { has_planning=1; break; }
done
[[ "$has_planning" -eq 1 ]] || exit 0

# ---------- 定位会话目录 ----------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DERIVED_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"

# 路径消毒：与 Claude Code 的项目目录命名一致（/ : _ \ 全部换成 -）
sanitized=$(printf '%s' "$PROJECT_PATH" | sed 's#[\\/:_]#-#g')

projects_dir=""
for candidate in \
    "${PLANNING_PROJECTS_DIR:-}" \
    "$DERIVED_ROOT/projects" \
    "$HOME/.claude/projects"
do
    [[ -n "$candidate" && -d "$candidate/$sanitized" ]] && { projects_dir="$candidate/$sanitized"; break; }
done
[[ -n "$projects_dir" ]] || exit 0

# ---------- 挑选目标会话：按修改时间降序，取第一个大于 5000 字节的 ----------
TARGET=""
while IFS= read -r -d '' f; do
    [[ "$(basename "$f")" == agent-* ]] && continue
    if [[ $(stat -c %s "$f") -gt 5000 ]]; then TARGET="$f"; break; fi
done < <(find "$projects_dir" -maxdepth 1 -type f -name '*.jsonl' -printf '%T@ %p\0' 2>/dev/null \
         | sort -zrn | sed -z 's/^[0-9.]* //')

[[ -n "$TARGET" ]] || exit 0

# ---------- 解析会话为 [行号, 消息对象] ----------
PARSED=$(mktemp) && trap 'rm -f "$PARSED"' EXIT
jq -Rc '[input_line_number - 1, (fromjson?)] | select(.[1] != null)' "$TARGET" > "$PARSED" 2>/dev/null
[[ -s "$PARSED" ]] || exit 0

# ---------- 找到最后一次 planning 文件更新 ----------
LAST=$(jq -sc '
  [ .[]
    | . as [$ln, $msg]
    | select($msg.type == "assistant")
    | ($msg.message.content // empty)
    | select(type == "array")
    | .[]
    | select(.type == "tool_use" and (.name == "Write" or .name == "Edit"))
    | (.input.file_path // "") as $fp
    | (["task_plan.md","progress.md","findings.md"][] | select($fp | endswith(.))) as $pf
    | [$ln, $pf]
  ] | last // [-1, null]' "$PARSED")

LAST_LINE=$(printf '%s' "$LAST" | jq -r '.[0]')
LAST_FILE=$(printf '%s' "$LAST" | jq -r '.[1] // ""')
[[ "$LAST_LINE" -ge 0 ]] || exit 0

# ---------- 提取该行之后、尚未同步的消息 ----------
AFTER=$(jq -sc --argjson after "$LAST_LINE" '
  def short($n): if . == null then "" elif (. | length) <= $n then . else .[0:$n] end;
  [ .[]
    | . as [$ln, $msg]
    | select($ln > $after)
    | if $msg.type == "user" and ($msg.isMeta // false) == false then
        ( $msg.message.content
          | if type == "array" then ([.[] | select(type=="object" and .type=="text") | .text] | first // "")
            elif type == "string" then .
            else "" end ) as $c
        | select($c | type == "string" and length > 20)
        | select($c | (startswith("<local-command") or startswith("<command-") or startswith("<task-notification")) | not)
        | {role: "user", content: $c}
      elif $msg.type == "assistant" then
        ( $msg.message.content ) as $mc
        | ( if $mc | type == "string" then $mc
            elif $mc | type == "array" then ([$mc[] | select(.type=="text") | .text] | last // "")
            else "" end ) as $text
        | ( if $mc | type == "array" then
              [ $mc[] | select(.type=="tool_use")
                | if .name == "Edit" then "Edit: " + (.input.file_path // "")
                  elif .name == "Write" then "Write: " + (.input.file_path // "")
                  elif .name == "Bash" then "Bash: " + ((.input.command // "") | short(80))
                  else .name end ]
            else [] end ) as $tools
        | select(($text | length) > 0 or ($tools | length) > 0)
        | {role: "assistant", content: ($text | short(600)), tools: $tools}
      else empty end
  ]' "$PARSED")

COUNT=$(printf '%s' "$AFTER" | jq 'length')
[[ "$COUNT" -gt 0 ]] || exit 0

# ---------- 输出报告 ----------
echo ''
echo '[planning-with-files] SESSION CATCHUP DETECTED'
echo "Previous session: $(basename "$TARGET" .jsonl)"
echo "Last planning update: $LAST_FILE at message #$LAST_LINE"
echo "Unsynced messages: $COUNT"
echo ''
echo '--- UNSYNCED CONTEXT ---'

printf '%s' "$AFTER" | jq -r '
  def short($n): if . == null then "" elif (. | length) <= $n then . else .[0:$n] end;
  .[-15:][]
  | if .role == "user" then
      "USER: " + (.content | short(300))
    else
      ( if (.content | length) > 0 then "CLAUDE: " + (.content | short(300)) + "\n" else "" end )
      + ( if ((.tools // []) | length) > 0 then "  Tools: " + ((.tools[0:4]) | join(", ")) else "" end )
    end
  | select(length > 0)'

echo ''
echo '--- RECOMMENDED ---'
echo '1. Run: git diff --stat'
echo '2. Read: Task/task_plan.md, Task/progress.md, Task/findings.md'
echo '3. Update planning files based on above context'
echo '4. Continue with task'
