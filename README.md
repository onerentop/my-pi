# 🧠 my-pi（Windows 分支）

个人 [pi](https://pi.dev) 编码智能体配置仓库 —— **Windows 版**。基于 `linux` 分支的完整扩展列表与目录结构，把所有平台相关的部分改回 Windows 事实（PowerShell、schtasks、SnoreToast、无 jq）。

`main` 分支是早期的 Windows 配置（7 个包、AGENTS.md 较旧），已被本分支取代 —— 本分支多了 4 个扩展包、全套 pi-web-access / pi-subagents / pi-lens / plannotator 集成，以及 AGENTS.md 的完整工具清单。

## 📦 目录结构

```
.
├── AGENTS.md              # 全局行为准则（语言、编码原则、工作流、工具使用策略）
├── APPEND_SYSTEM.md       # 追加到 system prompt 的内容（人设 / 输出风格）
├── settings.json          # pi 核心设置（主题、包列表、重试、压缩、默认模型等）
├── models.json            # 自定义 provider（key 用 $ENV 占位，见下）
├── mcp.json               # MCP 服务器（chrome-devtools / searchcode / tavily）
├── web-search.json        # pi-web-access 配置（SSRF 放行、tavily key 引用）
├── pi-cc-extensions.json  # pi-cc-extensions 的 UI 配置
├── extensions/            # 本地扩展
│   ├── footer/                 # 自绘底部状态栏（cwd / 计时 / context / token / git）
│   ├── i-have-adhd/            # ADHD 模式输出规则（按需用 /adhd 开启）
│   ├── pi-rtk-optimizer/       # pi-rtk-optimizer 的 config.json
│   └── tools.ts                # /tools 命令：交互式启停工具
├── skills/                # 17 个 skill（见下）
└── LICENSE
```

## 🚀 安装

### 1. 装 pi 和 Git for Windows

```powershell
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

需要 Node ≥ 22.19。

**Git for Windows 也必须装** —— pi 在 Windows 上默认用 Git Bash 承载 `bash` 工具与 `!` 命令（`C:\Program Files\Git\bin\bash.exe`）。若装在别处，在 `settings.json` 里用 `shellPath` 指过去。

### 2. 放配置

```powershell
git clone -b windows https://github.com/onerentop/my-pi.git
cd my-pi
New-Item -ItemType Directory -Force "$env:USERPROFILE\.pi\agent", "$env:USERPROFILE\.agents\skills" | Out-Null
Copy-Item AGENTS.md, APPEND_SYSTEM.md, settings.json, models.json, mcp.json, web-search.json, pi-cc-extensions.json "$env:USERPROFILE\.pi\agent\"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.pi\agent\extensions" | Out-Null
Copy-Item -Recurse -Force extensions\* "$env:USERPROFILE\.pi\agent\extensions\"
Copy-Item -Recurse -Force skills\* "$env:USERPROFILE\.agents\skills\"
```

> `~/.agents/skills/` 是 pi 的全局 skill 发现目录（与 `~/.pi/agent/skills/` 并列）。放在这里而不是 `~/.claude/skills/`，SKILL.md 里的路径引用也已按此改过。

### 3. 填 key

`models.json` 里两把 key 是环境变量占位符，pi 会自动展开 `$VAR`。二选一：

```powershell
# 方式 A：写进用户级环境变量（推荐 —— 文件里不留明文）
[Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN',  'sk-...',   'User')  # Claude 路由
[Environment]::SetEnvironmentVariable('SUB2API_DEEPSEEK_KEY',   'sk-...',   'User')  # DeepSeek 路由
[Environment]::SetEnvironmentVariable('TAVILY_API_KEY',         'tvly-...', 'User')  # tavily MCP + pi-web-access 回退
# 改完重开终端

# 方式 B：直接把 key 写进 $env:USERPROFILE\.pi\agent\models.json
```

> ⚠️ `anthropic` provider **必须**带 `apiKey`（哪怕是 `$VAR`）。只给 `baseUrl` 会导致没有该环境变量的终端里 `/model` 中所有 Claude 模型不可选。

> ⚠️ 若走方式 B，记得锁文件权限：
> ```powershell
> icacls "$env:USERPROFILE\.pi\agent\models.json" /inheritance:r /grant:r "$env:USERNAME:(R,W)"
> ```

### 4. 扩展包会自动装

`settings.json` 里 `packages` 列了 11 个包。**首次启动 pi 时它会自己检测并 `npm install` 掉缺失的包** —— 实测：把一个包目录移走后启动，输出 `added 1 package in 2s` 并装回原版本。

所以第 2 步拷完配置就能直接用，第一次 `pi` 启动会静默补齐。想当场看到安装过程（或怀疑某个包没装上），也可以手动逐个装 —— 这个操作是幂等的，`addSourceToSettings` 发现条目已存在会直接返回，不会把 `packages` 数组写重复：

```powershell
pi install npm:pi-mcp-adapter
pi install npm:@ff-labs/pi-fff
pi install npm:@juicesharp/rpiv-ask-user-question
pi install npm:@pi-unipi/notify
pi install npm:pi-cc-extensions
pi install npm:pi-rtk-optimizer
pi install npm:@juicesharp/rpiv-todo
pi install npm:pi-web-access
pi install npm:pi-subagents
pi install npm:pi-lens
pi install npm:@plannotator/pi-extension
```

### 5. 装外部依赖

```powershell
# rtk —— pi-rtk-optimizer 靠它压缩命令输出，没装则静默旁路
# 官方没有 PowerShell 安装脚本，从 release 下 zip：
#   https://github.com/rtk-ai/rtk/releases → rtk-x86_64-pc-windows-msvc.zip
# 解压后把 rtk.exe 所在目录加进 PATH
rtk --version

# 装完后跑一次让 hook 生效（省 token）：
rtk init -g
```

- **桌面通知**（`@pi-unipi/notify`）：Windows 走 SnoreToast，随包自动带，零配置。
- **chrome-devtools MCP**：需要本机有 Chrome 或 Edge。
- **PowerShell**：`pwsh` 7 优先，没有则回落 Windows PowerShell 5.1。

可选：`ruff`、`mypy`、`rust-analyzer` 等 —— `pi-lens` 检测到就会用。

## 🧩 扩展包一览

| 包 | 作用 |
|---|---|
| `pi-mcp-adapter` | MCP 协议适配，把 mcp.json 里的服务器暴露为 `mcp` / `mcpScript` 工具 |
| `@ff-labs/pi-fff` | `ffgrep` / `fffind` 文件搜索（替代内置 grep/find） |
| `@juicesharp/rpiv-ask-user-question` | 结构化提问 `ask_user_question` |
| `@pi-unipi/notify` | 跨平台通知 `notify_user`（Windows 走 SnoreToast） |
| `pi-cc-extensions` | Claude Code 风格 UI、`/context`、diff 渲染等 |
| `pi-rtk-optimizer` | 把 git/test/lint 命令重写为 `rtk …` 压缩输出 |
| `@juicesharp/rpiv-todo` | `todo` 工具 + 常驻覆盖层 |
| `pi-web-access` | `web_search` / `fetch_content` / `get_search_content` / `source_check`，默认 Exa 免 key，多引擎回退 |
| `pi-subagents` | `subagent` 工具，内置 scout / researcher / worker / reviewer / oracle |
| `pi-lens` | write/edit 后自动附 LSP 诊断 + linter 结果；`symbol_search` / `read_symbol` 等按符号读代码 |
| `@plannotator/pi-extension` | `/plannotator-plan-mode` 计划模式 + 浏览器审阅 UI |

## 🎯 Skills

| Skill | 功能 |
|-------|------|
| `gencom` | 根据 git diff 生成符合项目风格的提交信息 |
| `code-review-expert` | 资深工程师视角的代码审查 |
| `planning-with-files` | 文件化任务规划（脚本已移植为 PowerShell） |
| `skill-creator` | 创建、优化 skill，含 eval 评测 |
| `skill-monitor` | 监控 GitHub 仓库文件更新（脚本已移植为 PowerShell，定时用 schtasks） |
| `i-have-adhd` | ADHD 模式输出规则 |
| `humanizer-zh` | 去除中文文本的 AI 痕迹 |
| `naming` | 中文描述 → 英文标识符 |
| `todo-list` | 个人待办增删改查（数据在 `~/.todo/`） |
| `init-agents-md` | 扫描项目并初始化项目级 AGENTS.md |
| `add-anchor` / `add-frontmatter` | Markdown 锚点 / Frontmatter |
| `find-skills` | 发现并安装 agent skills |
| `github-issue-creator` / `pr-creator` / `pr-address-comments` | GitHub Issue / PR / 评论处理 |
| `grill-me-docs-standalone` | 需求不明确时反复追问澄清 |

`i-have-adhd` 与 `grill-me-docs-standalone` 带 `disable-model-invocation: true`，不会出现在模型的 skill 列表里，只能手动 `/i-have-adhd`、`/grill-with-docs` 调用。

## ⚙️ 与 linux 分支的差异

| 项 | linux | windows |
|---|---|---|
| mcp.json chrome-devtools | `npx … --isolated`（自己拉起 Chrome） | `cmd /c npx … --autoConnect`（连已开的 Chrome） |
| AGENTS.md 环境声明 | Linux / Python 3.12 / jq / rg | Windows 11 / PowerShell / 无 jq |
| 4 个脚本 | bash `.sh` | PowerShell `.ps1`（`planning-with-files` ×3、`skill-monitor` ×1） |
| skill-monitor 定时 | systemd user timer | schtasks XML（每日 09:00 + 登录延迟 30 分钟） |
| 桌面通知 | notify-send / libnotify | SnoreToast（自动） |
| rtk 安装 | `install.sh \| sh` | release zip 解压进 PATH |
| wttr.in 之外的网络工具 | curl / jq | `Invoke-RestMethod`；无 jq 时用 Python |
| 联网搜索 | `pi-web-access` | 同 |
| 默认模型 | anthropic / claude-sonnet-4-5 | 同 |
| 重试 / 思考等级 / 压缩 | 3 次 / 3s、medium、开 | 同 |
| `.i-have-adhd-always` | 移除（按需 `/adhd`） | 移除（同） |

## 🔧 本分支相对 linux 修的问题

1. **`anthropic` provider 走 sub2api 中转必然 400**

   ```
   400 ... messages.0.content.0.cache_control.ttl: a ttl='1h' cache_control block
   must not come after a ttl='5m' cache_control block
   ```

   中转把 `system` 上的 `ttl: "1h"` 排在 `messages` 上的 `ttl: "5m"` 之前，顺序反了。已在 `models.json` 的 anthropic provider 加：

   ```json
   "compat": { "supportsLongCacheRetention": false }
   ```

   若你换用 Anthropic 官方端点，去掉这段可以恢复 1h 长缓存。字段见 pi 文档 `docs/models.md` 的 Anthropic Messages Compatibility。

2. **`planning-with-files/SKILL.md` 的 3 处 `$HOME/.claude/skills/` → `$HOME/.agents/skills/`** —— pi 读 `.agents`，`.claude` 是 Claude Code 的路径，原样会导致脚本找不到。

3. **`planning-with-files/SKILL.md` 末尾把 `init-session.sh` / `check-complete.sh` 改成 `.ps1`** —— 上游改脚本时漏掉的。

4. **`todo-list/SKILL.md` 里作者机器的绝对路径改成 `$env:USERPROFILE\.agents\skills\todo-list\scripts\todo.js`** —— 否则换台机器就断。

## 📝 已知事项

- **内置 shell 用 Git Bash（`defaultTools: ["read","bash","edit","write"]`），不用 `powershell` 工具。** 早期版本用的是 `powershell`：PowerShell 的 `Stop-Process` 与 .NET 的 `Process.Kill()` **只杀你指定的那一个 PID，不杀进程树**（[PowerShell #15075](https://github.com/PowerShell/PowerShell/issues/15075) 提了很多年，至今没实现 `-Tree`）。从 `cmd.exe` 或 `Start-Process` 拉起的长驻子进程会在父进程被杀后变成孤儿、继续占用控制台，表现为「命令跑完就卡住不继续、也没结束提示」。

  ⚠️ **换 shell 本身并不能解决这个问题** —— Git Bash 的 `kill $!` 同样只作用于直接子进程。真正的解法有两条：
  1. 杀进程树一律用 `taskkill /PID <pid> /T /F`（`/T` 连子孙、`/F` 强制）。在 Git Bash 里要写 `taskkill //PID <pid> //T //F`，否则开头那个 `/` 会被 MSYS 的路径转换吃掉。
  2. 不要在活动的 pi 会话里再起一个交互式 pi —— 两个进程抢同一终端，父进程一被杀子进程就成孤儿。

  完整规范（含验证 TUI 类程序的三种安全做法、孤儿排查命令）写在 `AGENTS.md` 的「进程管理」一节。
- **`models.json` 里两个 provider 的 `baseUrl` 都指向私有中转 `https://sub2api.topren.top`。** 这是配置作者的转发服务，不是公开端点。换台机器要么改掉这两处 `baseUrl`（官方 Anthropic 写 `https://api.anthropic.com`），要么就没有 key 可用 —— 填了 `$ENV` 同样会 401/404。
- **`~/.pi/agent/extensions/model-router/` 不在本仓库。** 那是本机的另一个扩展：每次输入先用分类模型判断该走「只读规划」还是「直接执行」。它的 `config.json` 里硬编码了 provider 名，必须与 `models.json` 的 provider 名保持一致（曾经因为改名报过 `未找到模型` + `分类失败，已使用 Terra`），耦合太紧所以不随库分发。要迁移就把整个目录拷过去，并核对 `provider` 字段。
- **`superpowers` 系列 12 个 skill 不在本仓库。** 它们属于另一个项目，本机是以目录链接（Windows junction）挂进 `~/.agents/skills/` 的。需要就单独装，或把它的 skills 目录写进 `settings.json` 的 `skills` 数组。
- `web-search.json` 放行了 `198.18.0.0/15`：某些代理的 fake-ip 模式会把外网域名解析到这个网段，`fetch_content` 的 SSRF 防护会拦，放行后正常。不用代理可删掉。
- `mcp.json` 里的 `tavily-remote-mcp` 靠 `TAVILY_API_KEY` 鉴权。变量没设时该服务器连不上，启动会打一行警告，**不影响其他 MCP**。不用 tavily 的话把那节删掉即可。
- `mcp.json` 用 `cmd` + `["/c", "npx", ...]` 而不是直接 `npx`：Windows 上 `npx` 是 `.cmd` 批处理，直接 spawn 会失败。已在 `autoConnect` 模式下实测连通。
- `pi-lens` 有自动安装外部 linter 的策略（gitleaks / trivy 等安全扫描是 opt-in，默认不装）。
- `pi-subagents` 每个子代理是独立进程独立上下文，并行开多个 = 多倍 token。
- `!` 和 `!!` 编辑器命令**始终**走 Bash，不受 `defaultTools` 影响。

## 感谢

感谢 [LinuxDo 社区](https://linux.do/) 对本项目的支持。
