#!/usr/bin/env bash
# check-updates.sh
# skill-monitor 自动检查脚本（bash 版，移植自 check-updates.ps1）
# 读取 ~/.skill-monitor/monitor.json，对每条 watch 用 GitHub API 对比 blob sha，
# 发现变化则下载新版本、生成变更摘要报告（reports/<日期>/<watch-id>.md），
# 并更新 monitor.json 中的 sha 记录。
#
# 用法: ./check-updates.sh
# 定时: 用 systemd timer 或 cron，见 SKILL.md

set -uo pipefail

DATA_DIR="$HOME/.skill-monitor"
MANIFEST="$DATA_DIR/monitor.json"
REPORTS_DIR="$DATA_DIR/reports"
LOGS_DIR="$DATA_DIR/logs"

command -v jq >/dev/null 2>&1 || { echo "需要 jq，未安装" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "需要 curl，未安装" >&2; exit 1; }

mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/check-$(date +%Y-%m-%d).log"

log() {
    local line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    printf '%s\n' "$line" >> "$LOG_FILE"
    printf '%s\n' "$*"
}

if [[ ! -f "$MANIFEST" ]]; then
    log "monitor.json 不存在（$MANIFEST），跳过检查"
    exit 0
fi

mkdir -p "$REPORTS_DIR"
log '=== skill-monitor 检查开始 ==='

# ---------- GitHub token（有 gh 就用，限速更高） ----------
GH_TOKEN_VAL=""
if command -v gh >/dev/null 2>&1; then
    GH_TOKEN_VAL=$(gh auth token 2>/dev/null || true)
fi

curl_gh() {
    # $1 = url，其余透传给 curl
    local url="$1"; shift
    local -a hdr=(-H 'User-Agent: skill-monitor' -H 'Accept: application/vnd.github+json')
    [[ -n "$GH_TOKEN_VAL" ]] && hdr+=(-H "Authorization: Bearer $GH_TOKEN_VAL")
    curl -fsSL --max-time 30 "${hdr[@]}" "$@" "$url"
}

# ---------- 网络就绪检测 ----------
# 定时任务可能开机后立即运行而网络未就绪；探测失败则每 60 秒重试，最多 6 次（约 5 分钟）
wait_network_ready() {
    local attempt=0 code
    while [[ $attempt -lt 6 ]]; do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
               -H 'User-Agent: skill-monitor' 'https://api.github.com' 2>/dev/null || echo 000)
        # 只要服务器有响应（含 403 限速）就算网络通，000 才是不通
        [[ "$code" != "000" ]] && return 0
        attempt=$((attempt + 1))
        if [[ $attempt -lt 6 ]]; then
            log "网络未就绪（第 $attempt 次尝试失败），60 秒后重试..."
            sleep 60
        fi
    done
    log '网络探测失败，跳过本次检查'
    return 1
}

# 递归列出仓库中某目录下的所有文件，输出 TSV: <相对路径>\t<blob sha>
get_remote_files() {
    local repo="$1" path="$2" ref="$3" base="${4:-}"
    local json rel
    json=$(curl_gh "https://api.github.com/repos/$repo/contents/$path?ref=$ref") || return 1
    while IFS=$'\t' read -r name type itempath sha; do
        [[ -z "$name" ]] && continue
        rel="${base:+$base/}$name"
        if [[ "$type" == "dir" ]]; then
            get_remote_files "$repo" "$itempath" "$ref" "$rel" || return 1
        else
            printf '%s\t%s\n' "$rel" "$sha"
        fi
    done < <(printf '%s' "$json" | jq -r '.[] | [.name, .type, .path, (.sha // "")] | @tsv')
}

get_raw_file() {
    local repo="$1" ref="$2" filepath="$3" out="$4"
    local -a hdr=(-H 'User-Agent: skill-monitor')
    [[ -n "$GH_TOKEN_VAL" ]] && hdr+=(-H "Authorization: Bearer $GH_TOKEN_VAL")
    mkdir -p "$(dirname "$out")"
    curl -fsSL --max-time 60 "${hdr[@]}" \
        "https://raw.githubusercontent.com/$repo/$ref/$filepath" -o "$out"
}

# 用 git diff --no-index 提取变更统计与节选，输出: 第一行 stat，其余为节选
get_diff_summary() {
    local old="$1" new="$2" diff added removed
    if ! command -v git >/dev/null 2>&1; then
        printf '\n（本机未安装 git，无法生成 diff 节选）\n'
        return
    fi
    # git diff 有差异时退出码为 1，不算失败
    diff=$(git diff --no-index --unified=2 -- "$old" "$new" 2>/dev/null || true)
    added=$(printf '%s\n' "$diff"   | grep -cE '^\+[^+]' || true)
    removed=$(printf '%s\n' "$diff" | grep -cE '^-[^-]' || true)
    printf '+%s -%s\n' "$added" "$removed"
    printf '%s\n' "$diff" | grep -E '^[+-][^+-]' | head -30 | cut -c1-120
}

# ---------- 主流程 ----------
wait_network_ready || exit 1

TODAY=$(date +%Y-%m-%d)
changed=0
watch_count=$(jq '.watches | length' "$MANIFEST")

for ((i = 0; i < watch_count; i++)); do
    id=$(jq -r ".watches[$i].id" "$MANIFEST")
    repo=$(jq -r ".watches[$i].repo" "$MANIFEST")
    path=$(jq -r ".watches[$i].path" "$MANIFEST")
    ref=$(jq -r ".watches[$i].ref" "$MANIFEST")
    local_dir=$(jq -r ".watches[$i].local_dir" "$MANIFEST")

    log "==> 检查 $id ($repo/$path)"

    remote_tsv=$(get_remote_files "$repo" "$path" "$ref") || { log "    获取远端文件失败"; continue; }
    [[ -n "$remote_tsv" ]] || { log "    远端无文件，跳过"; continue; }

    # 已记录的 sha 表
    known_tsv=$(jq -r ".watches[$i].files // {} | to_entries[] | [.key, .value] | @tsv" "$MANIFEST")

    modified=(); added=(); deleted=()
    while IFS=$'\t' read -r file sha; do
        [[ -z "$file" ]] && continue
        old=$(printf '%s\n' "$known_tsv" | awk -F'\t' -v f="$file" '$1==f {print $2; exit}')
        if [[ -n "$old" ]]; then
            [[ "$old" != "$sha" ]] && modified+=("$file")
        else
            added+=("$file")
        fi
    done <<< "$remote_tsv"

    while IFS=$'\t' read -r file _; do
        [[ -z "$file" ]] && continue
        printf '%s\n' "$remote_tsv" | awk -F'\t' -v f="$file" '$1==f {found=1} END{exit !found}' \
            || deleted+=("$file")
    done <<< "$known_tsv"

    if [[ ${#modified[@]} -eq 0 && ${#added[@]} -eq 0 && ${#deleted[@]} -eq 0 ]]; then
        log "    无更新"
        continue
    fi

    changed=1
    log "    发现更新: 修改 ${#modified[@]} / 新增 ${#added[@]} / 删除 ${#deleted[@]}"

    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/skill-monitor-$id-XXXXXX")

    for f in ${modified[@]+"${modified[@]}"} ${added[@]+"${added[@]}"}; do
        get_raw_file "$repo" "$ref" "$path/$f" "$tmp_dir/$f" || log "    下载失败: $f"
    done

    # 生成变更摘要报告
    report_path="$REPORTS_DIR/$TODAY"
    mkdir -p "$report_path"
    report_file="$report_path/$id.md"
    {
        echo "# 更新摘要：$id（$TODAY）"
        echo "来源: https://github.com/$repo/tree/$ref/$path"
        echo "本地: $local_dir"
        echo ""
        echo "## 变更列表"
        for f in ${modified[@]+"${modified[@]}"}; do echo "- [修改] $f"; done
        for f in ${added[@]+"${added[@]}"};    do echo "- [新增] $f"; done
        for f in ${deleted[@]+"${deleted[@]}"}; do echo "- [删除] $f"; done
        echo ""
        echo "## 变更详情"
        for f in ${modified[@]+"${modified[@]}"}; do
            summary=$(get_diff_summary "$local_dir/$f" "$tmp_dir/$f")
            stat_line=$(printf '%s' "$summary" | head -1)
            sample=$(printf '%s' "$summary" | tail -n +2)
            echo "### $f（$stat_line）"
            if [[ -n "$sample" ]]; then
                echo '```diff'
                printf '%s\n' "$sample"
                echo '```'
            fi
            echo ""
        done
        for f in ${added[@]+"${added[@]}"}; do
            echo "### $f（新增文件）"
            echo '```'
            head -30 "$tmp_dir/$f" 2>/dev/null
            echo '```'
            echo ""
        done
        for f in ${deleted[@]+"${deleted[@]}"}; do
            echo "### $f（远端已删除）"
            echo ""
        done
    } > "$report_file"
    log "    报告已生成: $report_file"

    # 更新 sha 记录并写回 manifest（无人值守：同一更新只报告一次）
    new_files_json=$(printf '%s\n' "$remote_tsv" \
        | jq -R -s 'split("\n") | map(select(length>0) | split("\t")) | map({key: .[0], value: .[1]}) | from_entries')
    tmp_manifest=$(mktemp)
    jq --argjson idx "$i" --argjson nf "$new_files_json" \
       '.watches[$idx].files = $nf' "$MANIFEST" > "$tmp_manifest" && mv "$tmp_manifest" "$MANIFEST"

    rm -rf "$tmp_dir"
done

[[ "$changed" -eq 0 ]] && log "所有监控项均无更新（$TODAY）"
log '=== 检查完成 ==='
