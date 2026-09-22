# 🧠 my-pi（Linux 分支）

个人 [pi](https://pi.dev) 编码智能体配置仓库 —— **Linux 版**。`windows` 分支是最新的 Windows 版（相同的 11 个包 + 17 个 skill，只有平台相关的部分不同），`main` 是早期的 Windows 配置；本分支把所有平台相关的部分做成 bash / Linux 事实。

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

### 1. 装 pi

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

需要 Node ≥ 22.19。

### 2. 放配置

```bash
git clone -b linux https://github.com/onerentop/my-pi.git
cd my-pi
mkdir -p ~/.pi/agent ~/.agents/skills
cp settings.json models.json mcp.json web-search.json pi-cc-extensions.json AGENTS.md APPEND_SYSTEM.md ~/.pi/agent/
mkdir -p ~/.pi/agent/extensions ~/.agents/skills
cp -a extensions/. ~/.pi/agent/extensions/
cp -a skills/* ~/.agents/skills/
chmod 600 ~/.pi/agent/models.json
```

> `extensions/` 用 `cp -a extensions/. 目标/` 而不是 `cp -a extensions 目标/` —— 后者在目标目录已存在时会把源目录整个嵌进去（得到 `extensions/extensions/`）。

### 3. 填 key

`models.json` 里两把 key 是环境变量占位符，pi 会自动展开 `$VAR`。二选一：

```bash
# 方式 A：写进 shell 环境
echo 'export ANTHROPIC_AUTH_TOKEN=sk-...'   >> ~/.bashrc   # Claude 路由
echo 'export SUB2API_DEEPSEEK_KEY=sk-...'   >> ~/.bashrc   # DeepSeek 路由
echo 'export TAVILY_API_KEY=tvly-...'       >> ~/.bashrc   # tavily MCP + pi-web-access 回退

# 方式 B：直接把 key 写进 ~/.pi/agent/models.json（文件已 600）
```

> ⚠️ `anthropic` provider **必须**带 `apiKey`（哪怕是 `$VAR`）。只给 `baseUrl` 会导致没有该环境变量的终端里 `/model` 中所有 Claude 模型不可选。

### 4. 扩展包会自动装

`settings.json` 里 `packages` 列了 11 个包。**首次启动 pi 时它会自己检测并 `npm install` 掉缺失的包**。所以第 2 步拷完配置就能直接用，第一次 `pi` 启动会静默补齐。想当场看到安装过程（或怀疑某个包没装上），也可以手动逐个装 —— 这个操作是幂等的，`addSourceToSettings` 发现条目已存在会直接返回，不会把 `packages` 数组写重复：

```bash
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

```bash
# rtk —— pi-rtk-optimizer 靠它压缩命令输出，没装则静默旁路
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

# 桌面通知（@pi-unipi/notify）
sudo apt install libnotify-bin

# chrome-devtools MCP 需要本机 Chrome/Chromium
```

可选：`pyright`、`ruff`、`eslint` 等 —— `pi-lens` 检测到就会用。

## 🧩 扩展包一览

| 包 | 作用 |
|---|---|
| `pi-mcp-adapter` | MCP 协议适配，把 mcp.json 里的服务器暴露为 `mcp` / `mcpScript` 工具 |
| `@ff-labs/pi-fff` | `ffgrep` / `fffind` 文件搜索（替代内置 grep/find） |
| `@juicesharp/rpiv-ask-user-question` | 结构化提问 `ask_user_question` |
| `@pi-unipi/notify` | 跨平台通知 `notify_user`（Linux 走 notify-send） |
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
| `planning-with-files` | 文件化任务规划（脚本已移植为 bash） |
| `skill-creator` | 创建、优化 skill，含 eval 评测 |
| `skill-monitor` | 监控 GitHub 仓库文件更新（脚本已移植为 bash，定时用 systemd timer） |
| `i-have-adhd` | ADHD 模式输出规则 |
| `humanizer-zh` | 去除中文文本的 AI 痕迹 |
| `naming` | 中文描述 → 英文标识符 |
| `todo-list` | 个人待办增删改查（数据在 `~/.todo/`） |
| `init-agents-md` | 扫描项目并初始化项目级 AGENTS.md |
| `add-anchor` / `add-frontmatter` | Markdown 锚点 / Frontmatter |
| `find-skills` | 发现并安装 agent skills |
| `github-issue-creator` / `pr-creator` / `pr-address-comments` | GitHub Issue / PR / 评论处理 |
| `grill-me-docs-standalone` | 需求不明确时反复追问澄清 |

## ⚙️ 与 Windows 版（`windows` / `main`）的差异

| 项 | main | linux |
|---|---|---|
| `defaultTools` | `powershell` | `bash` |
| mcp.json chrome-devtools | `cmd /c npx … --autoConnect` | `npx … --isolated`（自己拉起 Chrome） |
| AGENTS.md 环境声明 | Windows 11 / 无 Python | Linux / Python 3.12 / rg / jq / gh / uv |
| 4 个 `.ps1` 脚本 | PowerShell | 移植为 bash（`planning-with-files` ×3、`skill-monitor` ×1） |
| skill-monitor 定时 | schtasks XML | systemd user timer（附 cron 备选） |
| `httpProxy` | `127.0.0.1:7897` | 移除（直连即可） |
| 重试 | 8 次 / 10s | 3 次 / 3s |
| `defaultThinkingLevel` | high | medium |
| `compaction` | 关 | 开 |
| `.i-have-adhd-always` | 存在（ADHD 常开） | 移除（按需 `/adhd`） |
| 联网搜索 | tavily MCP | `pi-web-access`（tavily 保留为 MCP + 回退 provider） |
| 新增扩展 | — | `pi-web-access`、`pi-subagents`、`pi-lens`、`@plannotator/pi-extension` |
| 默认模型 | LinuxHub / deepseek | anthropic / claude-sonnet-4-5（`sub2api/deepseek-v4-flash` 备用） |

## 📝 已知事项

- **`models.json` 里两个 provider 的 `baseUrl` 都指向私有中转 `https://sub2api.topren.top`。** 这是配置作者的转发服务，不是公开端点。换台机器要么改掉这两处 `baseUrl`（官方 Anthropic 写 `https://api.anthropic.com`），要么就没有 key 可用 —— 填了 `$ENV` 同样会 401/404。
- **`~/.pi/agent/extensions/model-router/` 不在本仓库。** 那是本机的另一个扩展：每次输入先用分类模型判断该走「只读规划」还是「直接执行」。它的 `config.json` 里硬编码了 provider 名，必须与 `models.json` 的 provider 名保持一致（曾因为改名报过 `未找到模型` + `分类失败，已使用 Terra`），耦合太紧所以不随库分发。要迁移就把整个目录拷过去，并核对 `provider` 字段。
- **`superpowers` 系列 12 个 skill 不在本仓库。** 它们属于另一个项目，本机是以目录链接挂进 `~/.agents/skills/` 的。需要就单独装，或把它的 skills 目录写进 `settings.json` 的 `skills` 数组。
- **杀进程树要用进程组。** `kill <pid>` 只作用于那一个 PID，不杀子孙 —— 用 `&` 拉起的后台进程会在父进程退出后被 init 收养、继续占用终端和端口，表现为「命令跑完就卡住不继续」。正解：`kill -TERM -- -<pgid>`（**负号是关键**），或用 `setsid` 启动长驻进程。**不要在活动的 pi 会话里再起一个交互式 pi** —— 两个进程抢同一终端，父进程一被杀子进程就成孤儿。完整规范（含验证 TUI 类程序的安全做法）写在 `AGENTS.md` 的「进程管理」一节。
- `web-search.json` 放行了 `198.18.0.0/15`：某些代理的 fake-ip 模式会把外网域名解析到这个网段，`fetch_content` 的 SSRF 防护会拦，放行后正常。不用代理可删掉。
- `pi-lens` 有自动安装外部 linter 的策略（gitleaks / trivy 等安全扫描是 opt-in，默认不装）。
- `pi-subagents` 每个子代理是独立进程独立上下文，并行开多个 = 多倍 token。

## 感谢

感谢 [LinuxDo 社区](https://linux.do/) 对本项目的支持。
