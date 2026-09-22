# 🧠 my-pi（Linux 分支）

个人 [pi](https://pi.dev) 编码智能体配置仓库 —— **Linux 版**。`main` 分支是 Windows/PowerShell 版；本分支把所有平台相关的部分改成了 bash / Linux 事实，并加了一批扩展。

## 📦 目录结构

```
.
├── AGENTS.md              # 全局行为准则（语言、编码原则、工作流、工具使用策略）
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
cp settings.json models.json mcp.json web-search.json pi-cc-extensions.json AGENTS.md ~/.pi/agent/
cp -a extensions ~/.pi/agent/
cp -a skills/* ~/.agents/skills/
chmod 600 ~/.pi/agent/models.json
```

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

### 4. 装扩展包

`settings.json` 里 `packages` 列了 11 个包，逐个安装：

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

## ⚙️ 与 main（Windows 版）的差异

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

- `web-search.json` 放行了 `198.18.0.0/15`：某些代理的 fake-ip 模式会把外网域名解析到这个网段，`fetch_content` 的 SSRF 防护会拦，放行后正常。不用代理可删掉。
- `pi-lens` 有自动安装外部 linter 的策略（gitleaks / trivy 等安全扫描是 opt-in，默认不装）。
- `pi-subagents` 每个子代理是独立进程独立上下文，并行开多个 = 多倍 token。

## 感谢

感谢 [LinuxDo 社区](https://linux.do/) 对本项目的支持。
