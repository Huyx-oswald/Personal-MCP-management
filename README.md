# Personal-MCP-management

只管一件事：**用一份带占位符的 MCP 模板 + 各机私有的 `local/` 值，把整套 MCP 配置同步到三台机器。**

> 官方插件、市场技能、启用状态——登录同一个 Trae 账号即自动到账，不进本仓库。
> 机器专属的密钥/路径（PAT、API_KEY、venv、memory）逐机不同、Git 同步不了，由 `local/` 承载。
> Trae 的运行缓存 `~/.trae-cn/mcps/`（按项目分的 `SERVER_METADATA.json` + 工具 schema）是派生数据，同样不进仓库。

## 目录结构

```
.
├── config/
│   └── mcp.template.json   # 占位符版 mcp 配置，含全部 10 个 server，不含任何密钥
├── local/                  # 各机私有，已被 .gitignore 忽略
│   ├── secrets.json        # 各机密钥：GitHub PAT / 歌者 API_KEY
│   └── machine.json        # 各机路径：Trae 配置目录、venv、.env、memory
├── sync.ps1                # 拉取 + 占位符替换 + 写回目标路径
├── sync.tests.ps1          # sync.ps1 自检
└── README.md
```

## 占位符约定

`config/*.template.json` 里，凡是**密钥或本机绝对路径**都写成 `${变量名}`：

```json
"GitHub": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PAT}" }
},
"mcp-sap-gui": {
  "command": "${SAP_VENV}\\Scripts\\python.exe",
  "env": { "SAP_ENV_FILE": "${SAP_ENV_FILE}" }
}
```

变量来自 `local/secrets.json` 与 `local/machine.json`（后者同名键覆盖前者）：

| 变量 | 放哪 | 用途 |
| --- | --- | --- |
| `GITHUB_PAT` | `local/secrets.json` | `GitHub` server 的 `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `GEZHE_API_KEY` | `local/secrets.json` | `歌者PPT` server 的 `API_KEY`（拼进 URL） |
| `TRAE_CONFIG_DIR` | `local/machine.json` | 本机 Trae 配置目录，即 `mcp.json` 的写回目标。实测路径：`%APPDATA%\Trae CN\User` |
| `SAP_VENV` | `local/machine.json` | `mcp-sap-gui` 的 venv 目录 |
| `SAP_ENV_FILE` | `local/machine.json` | `mcp-sap-gui` 的 `.env` 文件 |
| `MEMORY_FILE_PATH` | `local/machine.json` | `Knowledge Graph Memory` 的 `.jsonl` 数据文件 |

### 为什么是全量模板

那 7 个市场来源的 MCP（GitHub、windows-cli、Pandoc、歌者PPT、Memory、Excel、markitdown）虽然能在平台一键重装，但**重装时仍要手输 PAT / API_KEY**；把 10 条全放进模板，新机**粘贴一次**就把密钥和路径一次接好，比"装 7 个 + 逐个填 env"更省事。

## 新机 bootstrap（每台做一次）

1. 装 `node` + `uv`（供 npx / uvx 类 MCP 使用）。
2. `git clone` 本仓库；把 `local/*.example` 复制成 `secrets.json`、`machine.json`，填真实值。
3. 装本地依赖（下方「各机必装」）。
4. 登录**同一个 Trae 账号**，官方插件 / 市场技能自动到账。
5. `pwsh ./sync.ps1` 落地（写回 `%APPDATA%\Trae CN\User\mcp.json`）。
   - 若以后 Trae 换了存放位置：把 `machine.json` 的 `TRAE_CONFIG_DIR` 改成实际目录；实在找不到可写路径时，就把它临时指向一个空目录跑一遍，再打开「设置 > MCP > 手动添加 > 原始配置(JSON)」粘贴生成的内容。

## 日常用法

| 场景 | 命令 |
| --- | --- |
| 在本机改了 `mcp.json`（在 Trae 设置里改的），回填模板并上传 | `pwsh ./sync.ps1 -Push` |
| 换到另一台机器落地 | `pwsh ./sync.ps1` |
| 只想看会写哪些文件 | `pwsh ./sync.ps1 -WhatIf` |
| 验证脚本逻辑没坏 | `pwsh ./sync.tests.ps1` |

落地后若配置有变，**重启 Trae** 生效。

## 各机必装（平台装不回来的部分）

| 服务 | 类型 | 迁移要点 |
| --- | --- | --- |
| npx / uvx 类（GitHub、windows-cli、Pandoc、歌者PPT、Memory、Excel、markitdown、context7） | npx / uvx | 命令与参数走模板，各机装好 node、uv |
| lanyin-rpa | `http://127.0.0.1:18765/mcp` | 各机安装并运行蓝印 RPA 客户端 |
| mcp-sap-gui | 本地 venv | 各机 clone + 建 venv，路径写进 `machine.json` |
| Knowledge Graph Memory | 本地 jsonl | `MEMORY_FILE_PATH` 走 `machine.json`，数据文件按需单独备份 |

## 网盘的正确用法

- WPS / 百度网盘 VIP 只放：仓库的 zip 快照备份、大文件（扩展包、素材、导出文档），以及没装 Git 的临时机器做手工搬运。
- **不要**把 `.trae-cn` 或 `User` 目录直接指到网盘目录运行——缓存和文件锁会让网盘同步频繁失败。

## 安全提醒

- `mcp.json` 里的 GitHub PAT、歌者 API_KEY 是明文密钥，只能放进被 gitignore 的 `local/secrets.json`，**绝不提交进仓库**。
- 这两个密钥已经在会话里出现过，**建议轮换**（PAT 去 GitHub 吊销重建、歌者 KEY 去后台重置），再填进 `local/`。
- `memory/` 目录含大量项目绝对路径，跨机不一定通用，按需单独同步，别并进主仓库。
