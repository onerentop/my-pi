# 全局开发配置

## 语言和环境

- **语言**: 所有输出（包括思考过程、回复、代码注释和 commit 信息）一律使用简体中文
- **操作系统**: Windows 11（内核 10.0.26220，x64）| **AI 终端**: PowerShell | **用户终端**: PowerShell（`pwsh` 7 / `powershell` 5.1）、Git Bash
- **Python 环境**: 已安装 Python 3.13（`python3`，`%LOCALAPPDATA%\Programs\Python\Python313`）与 Python 3.11（`python`，hermes venv）；包管理器另有 `uv`
- **已安装 CLI**: GitHub CLI（`gh`）、`git`、`rg`（ripgrep）、`fd`、`npx`、`uv`、`cargo`、`go`、`rtk`。涉及 GitHub 仓库操作时优先使用 `gh`
- **未安装**: `jq`（改用 `python -c` 或 PowerShell 的 `ConvertFrom-Json`）
- **网络代理**: 本机有 HTTP 代理 `127.0.0.1:7897`，但 pi **不走**它（网关、MCP、npm 均已验证可直连）；个别命令需要时手动加 `$env:HTTPS_PROXY="http://127.0.0.1:7897"`
- **rtk**: 已安装 `%LOCALAPPDATA%\Programs\rtk\v0.45.0\rtk.exe`，`pi-rtk-optimizer` 会自动把 git/test/lint 等命令重写为 `rtk …` 以压缩输出，无需手动调用

### Windows 平台注意事项

- **路径**：给用户看的路径用 `C:\…` 反斜杠风格；Git Bash 下的 `/c/…` 同样有效，脚本里注意区分
- **换行**：仓库统一 LF，必要时 `git config core.autocrlf input`
- **编码**：PowerShell 输出中文前可先 `[Console]::OutputEncoding = [Text.Encoding]::UTF8`，避免乱码
- **长路径**：超过 260 字符可能失败，必要时用 `\\?\` 前缀
- **Shell 选择**：默认 PowerShell；涉及 POSIX 工具链（`sed`/`awk`/`.sh` 脚本）时才切 Git Bash

## 权限

- 拥有读取任意文件的权限，无需询问确认

## 编码原则（核心哲学）

### 1. 先思考，再编码

- 明确说明假设；有多种解读时，列出选项，不要悄悄选一个
- 遇到更简单的方案，主动说出来；真正不清楚时，**停下来问**，主动使用 `grill-me-docs-standalone` skill 询问

### 2. 简洁优先

- 只实现被要求的功能，不写投机性代码
- 单次使用的代码不做抽象；不要"未来可能用到"的灵活性
- 写了 200 行但 50 行能解决 → 重写

### 3. 外科手术式修改

- 只改必须改的地方；不"顺手优化"无关代码
- 保持现有代码风格，即使你会用不同写法
- 你的改动产生的孤儿代码（无用 import/变量）→ 删掉；原有死代码 → 仅提及，不删除

### 4. 目标驱动执行

将任务转化为可验证的目标：

- "修复 bug" → "写一个能复现它的测试，然后让它通过"
- "重构 X" → "确保重构前后测试都通过"

多步骤任务先列计划：

```text
1. [步骤] → 验证: [检查点]
2. [步骤] → 验证: [检查点]
```

## 命令执行策略

### AI 自动执行（✅ 允许）

- **文件操作**：使用专用工具（read、write、edit、ffgrep、fffind），不用 find/grep/cat/echo 等 shell 命令
- **Git 只读**：`git status/log/diff/branch/show/blame`
- **GitHub 操作**：`gh pr/issue/repo/search` 等

### 提供给用户执行（PowerShell 代码块）

需要管理员权限、交互式操作、长运行进程的命令 → 给出 PowerShell 代码块，由用户手动执行

典型需要用户执行的场景：`winget install`、`Start-Process -Verb RunAs`、服务管理（`Start-Service` / `Set-Service` / `sc.exe`）、`docker` 守护进程操作、交互式登录（`gh auth login`、`gcloud auth login`）

### 绝对禁止

- 交互式命令（`vim`/`notepad` 等文本编辑器、交互式安装向导）
- 系统管理命令（需要管理员权限或 `-Verb RunAs` 的操作）
- 破坏性文件操作（`Remove-Item -Recurse -Force`、覆盖式 `Move-Item`、`curl`/`Invoke-WebRequest` 覆盖下载等）

### 进程管理（孤儿进程陷阱）

PowerShell 的 `Stop-Process` 和 .NET 的 `Process.Kill()` **只杀你指定的那一个 PID，不杀进程树**（[PowerShell #15075](https://github.com/PowerShell/PowerShell/issues/15075) 提了很多年，至今没实现 `-Tree`）。从 `cmd.exe` 或 `Start-Process` 拉起的长驻子进程，会在父进程被杀后变成孤儿，继续占用终端 —— 表现为“命令跑完就卡住、不继续、也没结束提示”。**换 shell 不能解决**：Git Bash 的 `kill $!` 同样只作用于直接子进程。

- **杀进程树用 `taskkill /PID <pid> /T /F`**。`/T` 连子孙，`/F` 强制。在 Git Bash 里写 `taskkill //PID <pid> //T //F`，否则开头那个 `/` 会被 MSYS 的路径转换吃掉。
- **不得在活动的 pi 会话里启动第二个交互式 pi**（比如 `cmd /c pi`）。两个进程抢同一控制台，父进程一被杀子进程就成孤儿。
- 需要验证 TUI 类程序时，按安全性从高到低选：① 只验模块能不能解析（`node -e "import('包名')"`）；② 重定向 stdin（`' ' | pi --no-session`）；③ `Start-Job`（父进程退出时作业会被一并清理）。
- 排查孤儿：`Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Select-Object ProcessId, ParentProcessId, CreationDate, CommandLine`，`ParentProcessId` 对应的进程已不存在就是孤儿。

## 核心工作流

### 普通功能

规划 → 编码 → `reviewer` 子代理审查 → `/gencom` 提交

### 复杂功能 / 架构变更

`/plannotator-plan-mode` 生成计划 → 浏览器审阅批准 → `worker` 分阶段实现 → 并行 `reviewer` → `/gencom` 提交

### 自动触发代理

| 代理                   | 触发条件                               |
| ---------------------- | -------------------------------------- |
| `reviewer` 子代理      | 写完任何代码后，立即触发（必须）       |
| Plannotator 计划模式   | 复杂功能或大型重构，编码前触发（推荐） |

## 网络访问（pi-web-access）

**优先用这组工具**，零配置（默认走 Exa，免 key；`TAVILY_API_KEY` 未设置时 tavily 自动跳过）。

| 工具 | 用途 |
|------|------|
| `web_search` | 联网搜索。可一次传多个 `queries` 并发；`recencyFilter: day/week/month/year`；`domainFilter: ["github.com","-reddit.com"]`；`provider: "all"` 让所有引擎并发各出一张结果卡 |
| `fetch_content` | 抓 URL 转 markdown，**自动识别类型**：GitHub 仓库默认返回 API 视图（README + 结构，不 clone），要完整源码就 `git clone`；PR/issue 用 `gh` 渲染；PDF、YouTube、图片均可；长页面用 `mode: "answer"` + `prompt` 只取要点 |
| `get_search_content` | 按 `responseId` 翻之前搜索结果的全文，`findText` 定位关键词（缓存 1 小时） |
| `source_check` | 给一个断言收集证据并返回 `supported / contradicted / unclear`，只收集不判断 |

**任何模型下都可用**（搜索不经过对话模型）。需要查最新信息、文档、版本号、报错时直接调 `web_search`，不要凭记忆作答；涉及包版本号可再用 `npm view` 交叉核对。

网络注意：本机 DNS 可能把外网域名解析成 `198.18.x.x`（代理 fake-ip），`web-search.json` 已放行该网段；若 `fetch_content` 报 SSRF 拦截，检查该配置。

## 子代理（pi-subagents）

`subagent` 工具可把任务委托给独立上下文的子代理，内置角色：

| 角色 | 何时用 |
|------|--------|
| `scout` | 还不了解代码时先侦察：相关文件、入口、数据流、风险 |
| `researcher` | 需要外部事实时做网络调研，带来源 |
| `evidence-auditor` | 重要调研结论要独立核验来源时 |
| `worker` | 按已批准的计划实现，遇到未授权决策会上报而不是猜 |
| `reviewer` | 代码审查（正确性、测试、边界、简洁性） |
| `oracle` | 动手前要第二意见、挑战假设时，不改文件 |

推荐循环：澄清 → `scout` → `worker` → 新开 `reviewer` → `worker` 修。**写完任何代码后，用 `reviewer` 子代理审查再总结**（替代原来的 `/code-review-expert` skill；两者都在，优先子代理，因为它在独立上下文里跑）。可并行：「跑三个 reviewer：正确性、测试、多余复杂度」。TUI 里 `/subagents-fleet` 查看/干预运行中的子代理。

## 代码诊断（pi-lens）

每次 `write`/`edit` 后自动把 LSP 诊断、linter（ruff/eslint 等）、类型检查结果附在工具返回里 —— **看到诊断就修，不要忽略**。额外工具：`lens_diagnostics`（按需对文件/目录跑诊断）、`symbol_search` / `read_symbol` / `read_enclosing`（按符号定位读取，比整文件 read 省 token）、`project_report` / `module_report`（项目/模块健康概览）。本机已有 `ruff`、`mypy`、`rust-analyzer`；未装 pyright、eslint、typescript-language-server、bash-language-server（需要时用 `npm i -g` 或 `uv tool install` 补）。

## 计划模式（Plannotator）

复杂任务先进计划模式：`/plannotator-plan-mode`（或 `Ctrl+Alt+P`，可带计划文件路径）。计划模式下**只能写计划文件**，破坏性命令被拦截；探索代码后写 markdown 清单式计划，调用 `plannotator_submit_plan` 会在浏览器打开审阅 UI，用户标注/批准后再实现。它替代原来的 `/planning-with-files` 作为首选；`planning-with-files` 仍可用于需要 Task/ 目录持久化追踪的长任务。

## MCP 工具

当前配置了 3 个 MCP 服务器，按需调用。首次使用某服务器时需先 `connect`。

### searchcode — 公开 Git 仓库代码搜索/分析（6 tools）

| 工具 | 用途 |
|------|------|
| `searchcode_code_search` | 在指定的公开 Git 仓库内搜索代码（必须传 repo URL，不能全局搜） |
| `searchcode_code_analyze` | 仓库概览：语言、复杂度、目录结构 |
| `searchcode_code_get_file` | 获取远程仓库单个文件内容 |
| `searchcode_code_get_files` | 批量获取远程仓库多个文件内容 |
| `searchcode_code_file_tree` | 列出远程仓库的目录/文件树 |
| `searchcode_code_get_findings` | 获取远程仓库代码质量分析结果 |

> 适用场景：分析开源项目、搜索别人怎么实现某个功能、查看依赖源码。

### tavily-remote-mcp — 网络搜索与网页提取（5 tools）

| 工具 | 用途 |
|------|------|
| `tavily-remote-mcp_tavily_search` | 搜索当前信息、新闻、事实 |
| `tavily-remote-mcp_tavily_extract` | 提取指定 URL 的页面内容（纯文本） |
| `tavily-remote-mcp_tavily_crawl` | 从起始 URL 爬取网站，提取页面内容 |
| `tavily-remote-mcp_tavily_map` | 映射网站结构，返回 URL 列表 |
| `tavily-remote-mcp_tavily_research` | 对某个话题进行深度综合研究 |

> 鉴权靠环境变量 `TAVILY_API_KEY`（mcp.json 的 url 里以 `?tavilyApiKey=${TAVILY_API_KEY}` 引用）。变量未设置时该服务器连不上，不影响其他 MCP。
> 日常查资料优先用上面的 `web_search`（零配置）；需要爬站、批量提页面正文、映射站点结构时再用 tavily。

### chrome-devtools — Chrome 浏览器自动化（3 tools）

| 工具 | 用途 |
|------|------|
| `chrome-devtools_navigate` | 加载/跳转 URL |
| `chrome-devtools_screenshot` | 截图 |
| `chrome-devtools_evaluate` | 执行 JS 脚本 |

> 适用场景：需要浏览器交互时（登录、JS 渲染页面、截图验证等）。
> 注意：Windows 上以 `cmd /c npx … --autoConnect` 启动，连接本机已装的 Chrome（`C:\Program Files\Google\Chrome\Application\chrome.exe`）。

### 使用方式

- 查看服务器状态：`mcp({})`
- 连接服务器：`mcp({ connect: "server-name" })`
- 搜索工具：`mcp({ search: "keyword" })`
- 查看工具详情：`mcp({ describe: "tool_name" })`
- 调用工具：`mcp({ tool: "tool_name", args: { ... } })`
- 批量调用：用 `mcpScript` 编写 JavaScript 串联多个调用

## 工作原则

- 优先查阅项目级 `CLAUDE.md` 或者 `AGENTS.md`
- 优先编辑现有文件，不创建新文件

## 错误处理

- **工具失败**：分析原因 → 尝试替代方案（fffind 失败 → 试 ffgrep）→ 连续失败 3 次向用户说明
- **构建/测试失败**：增量修复，一次处理一个错误，每次修复后验证
