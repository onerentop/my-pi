---
name: skill-monitor
description: 用 GitHub URL 持续监控远程仓库目录下的文件（如 skill、脚本、配置文件），不依赖 npx skills 安装。当用户提到"监控这个仓库/目录"、"检查有没有更新"、"帮我跟踪这个 URL 的变更"、"看看这个 skill 更新了什么"、"不想用 npx 安装"、或要求对比 GitHub 上某个文件的当前版本与本地版本差异时，都应使用此 skill。发现更新时生成变更摘要，由用户决定是否更新。
---

# Skill Monitor

监控 GitHub 仓库中某个目录下的所有文件，定期检查更新，生成变更摘要，由用户决定是否更新。

解决的核心问题：不使用 `npx skills`（可能因系统环境问题安装/更新失败），改为维护一份 URL 监控清单，自动跟踪上游文件的变更。

## 数据目录结构（~/.skill-monitor/）

```
~/.skill-monitor/
├── monitor.json          # 监控清单（唯一事实来源）
├── reports/              # 变更摘要报告（按日期分目录）
│   └── 2026-02-10/
│       └── <watch-id>.md
└── backups/              # 更新前的旧版本备份
    └── <watch-id>/
        └── 20260210-1430/
```

`monitor.json` 结构：

```json
{
  "watches": [
    {
      "id": "unique-id",
      "repo": "owner/repo",
      "path": "skills/some-skill",
      "ref": "main",
      "local_dir": "/home/<user>/.agents/skills/some-skill",
      "files": {
        "SKILL.md": "<blob sha>",
        "references/schema.md": "<blob sha>"
      }
    }
  ]
}
```

- `path` 为空表示仓库根目录
- `files` 记录目录下每个文件相对路径对应的 **blob sha**（GitHub contents API 返回），这是判断更新的依据
- 本地目标目录 `local_dir` 与远端目录一一对应，文件布局保持一致

## 核心操作

### 1. 添加监控（用户提供 URL 时）

用户给一个 GitHub 目录 URL（如 `https://github.com/owner/repo/tree/main/skills/foo`）或文件 URL，按以下步骤：

1. **解析 URL** → 得到 `repo`（owner/repo）、`path`（目录路径）、`ref`（分支/标签，默认 main）
2. **询问用户本地保存位置**（如果意图是安装 skill，默认建议 `~/.agents/skills/<目录名>`）
3. **用 GitHub API 递归列出目录下所有文件及 blob sha**：
   ```bash
   gh api "repos/{owner}/{repo}/contents/{path}?ref={ref}" --paginate
   ```
   （contents API 单层返回，子目录需递归；优先用 `gh api`，未登录时回退 `curl -s https://api.github.com/...`）
4. **下载所有文件**到 `local_dir`（raw 地址：`https://raw.githubusercontent.com/{repo}/{ref}/{path}/{file}`）
5. **写入 monitor.json**：追加 watch 条目，`files` 记录每个文件的 sha
6. 汇报：已监控 N 个文件，来源 URL，本地路径

### 2. 检查更新（用户说"检查更新"或运行脚本）

1. 读取 `monitor.json`，对每条 watch：
   - 用 GitHub API 重新列出目录文件，获取最新 sha
   - 与 `files` 中记录的 sha 对比 → 找出 **修改 / 新增 / 删除** 的文件
2. 对每个变化的文件，下载新版本到临时目录
3. **生成变更摘要**（不保存原始 diff，只生成人类可读摘要）到 `reports/<日期>/<watch-id>.md`：
   ```markdown
   # 更新摘要：<watch-id>（<日期>）
   来源: https://github.com/<repo>/tree/<ref>/<path>
   本地: <local_dir>

   ## 变更列表
   - [修改] SKILL.md（+12 −5 行）
   - [新增] references/schema.md
   - [删除] scripts/legacy.sh

   ## 变更详情
   ### SKILL.md
   - 关键改动点：...（用 git diff --no-index 对比本地与新版，节选要点）
   - 变更行示例：<少量关键行>
   ```
4. **暂不更新** `files` 的 sha 记录（等用户决定更新后一并更新），但把"待更新文件"标记记录在报告里，避免重复生成相同报告
5. 向用户汇报摘要，询问是否更新

> 注：手动检查时直接运行脚本最省事（见下），脚本输出报告后由 agent 读取并向用户汇报。

### 3. 执行更新（用户确认后）

用户说"更新" / "应用更新" 后：

1. **备份**：把 `local_dir` 下待更新的旧文件复制到 `~/.skill-monitor/backups/<watch-id>/<时间戳>/`
2. **下载新版本**覆盖到 `local_dir`（删除的远端文件：先询问用户再删除本地对应文件）
3. **更新 monitor.json** 中该 watch 的 `files` sha 为最新值
4. 汇报更新结果；如需回滚，指出备份位置即可

## 计划任务自动检查

`scripts/check-updates.sh` 实现自动检查（读取清单 → 网络就绪探测 → API 对比 → 生成摘要报告 → 更新 sha 记录）。注意：**脚本每次运行后直接更新 sha 记录**（它无人值守，无法等用户决策），因此同一文件的更新只报告一次；用户看到报告后如需更新，走上面的"执行更新"流程。

依赖：`jq`、`curl`、`git`（可选，用于 diff 节选）、`gh`（可选，登录后 GitHub API 限速更高）。

**配置文件（可手动修改）**：`~/.skill-monitor/monitor.json`

注册定时任务（**需要用户手动执行**，用户级 systemd，无需 root）。双触发：开机后延迟 30 分钟（覆盖开机没网）+ 每日 09:00，并启用 `Persistent` 补跑错过的计划。

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/skill-monitor.service <<'EOF'
[Unit]
Description=skill-monitor check for upstream skill updates
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash %h/.agents/skills/skill-monitor/scripts/check-updates.sh
TimeoutStartSec=15min
EOF

cat > ~/.config/systemd/user/skill-monitor.timer <<'EOF'
[Unit]
Description=skill-monitor schedule (boot+30min, daily 09:00)

[Timer]
OnBootSec=30min
OnCalendar=*-*-* 09:00:00
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now skill-monitor.timer

# 开机即生效（无需登录），需要开启 linger：
sudo loginctl enable-linger "$USER"

# 验证
systemctl --user list-timers skill-monitor.timer
```

说明：
- **OnBootSec=30min**：开机后延迟 30 分钟执行，给网络就绪留时间（脚本内部还会重试最多 5 分钟）
- **OnCalendar 09:00**：常规每日检查
- **Persistent=true**：关机错过计划时间，下次开机后尽快补跑
- **TimeoutStartSec=15min**：任务最长运行 15 分钟，防止卡住
- **enable-linger**：让用户级 timer 在未登录时也能运行；不需要可省略

若系统没有 systemd，改用 cron：

```bash
( crontab -l 2>/dev/null; echo "0 9 * * * /usr/bin/env bash $HOME/.agents/skills/skill-monitor/scripts/check-updates.sh >/dev/null 2>&1" ) | crontab -
```

**查看日志**：`~/.skill-monitor/logs/check-<日期>.log`，或 `journalctl --user -u skill-monitor.service`

**手动触发**（随时检查一次）：

```bash
bash ~/.agents/skills/skill-monitor/scripts/check-updates.sh
```

或直接在对话中说"检查更新"，agent 代为执行并汇报结果。

## 注意事项

- GitHub API 匿名限速 60 次/小时，每天检查一次足够；监控目录文件较多时注意调用次数（contents API 每层一次调用）
- 优先用 `gh api`（已认证，限速高）；gh 未登录时用 curl 匿名
- `git diff --no-index` 可用于本地与新版文件的差异提取（对比结束记得删除临时文件）
- 所有路径使用 Linux 风格（`/home/<user>/...` 或 `~/...`），脚本与 agent 操作保持一致
- 生成的摘要和汇报一律使用简体中文
- 保持 monitor.json 为唯一事实来源：所有 sha 更新必须同步写回该文件
