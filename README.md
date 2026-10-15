# Personal-MCP-management

只管一件事：**把你手搓、平台装不回来的 MCP 配置（含密钥占位符）用 Git 统一到三台机器。**

> 官方插件、市场技能、平台里能直接下载的 MCP——登录同一个 Trae 账号即自动到账，不进本仓库。
> 机器专属的密钥/路径（PAT、API_KEY、venv、memory）本来就逐机不同、Git 同步不了，由 `local/` 承载。
> 所以真正值得进 Git 的，只有 `config/mcp.template.json` 这一个文件。

## 目录结构

```
.
├── config/
│   └── mcp.template.json   # 占位符版 mcp 配置，不含任何密钥
├── local/                  # 各机私有，已被 .gitignore 忽略
│   ├── secrets.json        # 各机密钥：GitHub PAT / 歌者 API_KEY
│   └── machine.json        # 各机路径：Trae 配置目录、venv、memory
├── sync.ps1                # 拉取 + 占位符替换 + 写回目标路径
├── sync.tests.ps1          # sync.ps1 自检
└── README.md
```

## 占位符约定

`config/*.template.json` 里，凡是**密钥或本机绝对路径**都写成 `${变量名}`：

```json
{
  "mcpServers": {
    "github": { "command": "npx", "args": ["-y", "..."], "env": { "TOKEN": "${GITHUB_PAT}" } },
    "sap":    { "command": "${SAP_VENV}\\Scripts\\python.exe" }
  }
}
```

变量来自 `local/secrets.json` 与 `local/machine.json`（后者同名键覆盖前者）。

> 目前 `mcp.template.json` 仍是空骨架 `{}`。把本机 `mcp.json` 里那些**平台装不回来的自建 server** 搬进来，密钥/绝对路径改成 `${变量名}`。空文件运行 `sync.ps1` 会被跳过，不会清空本机现有配置。

## 新机 bootstrap（每台做一次）

1. 装 `node` + `uv`（供 npx / uvx 类 MCP 使用）。
2. `git clone` 本仓库；在 `local/` 下把 `.example` 复制成 `secrets.json`、`machine.json`，填真实值。
3. 装本地依赖（下方「各机必装」）。
4. 在平台里用**同一个 Trae 账号**登录，把要用的官方插件 / 市场技能 / 可下载的 MCP 装上（自动到账，不占本仓库）。
5. 跑 `pwsh ./sync.ps1` 落地自建 MCP。

## 日常用法

| 场景 | 命令 |
| --- | --- |
| 改了 `mcp.template.json`，上传 | `pwsh ./sync.ps1 -Push` |
| 换到另一台机器落地 | `pwsh ./sync.ps1` |
| 只想看会写哪些文件 | `pwsh ./sync.ps1 -WhatIf` |
| 验证脚本逻辑没坏 | `pwsh ./sync.tests.ps1` |

落地后若配置有变，**重启 Trae** 生效。

## 各机必装（平台装不回来的部分）

| 服务 | 类型 | 迁移要点 |
| --- | --- | --- |
| 自建 npx / uvx MCP（歌者PPT、windows-cli、Excel、markitdown 等） | npx / uvx | 命令与参数走模板，各机装好 node、uv |
| lanyin-rpa | `http://127.0.0.1:18765` | 各机安装并运行蓝印 RPA 客户端 |
| mcp-sap-gui | 本地 venv | 各机 clone + 建 venv，路径写进 `machine.json` |
| Knowledge Graph Memory | 本地 jsonl | `MEMORY_FILE_PATH` 走 `machine.json`，数据文件按需单独备份 |

## 网盘的正确用法

- WPS / 百度网盘 VIP 只放：仓库的 zip 快照备份、大文件（扩展包、素材、导出文档），以及没装 Git 的临时机器做手工搬运。
- **不要**把 `.trae-cn` 或 `User` 目录直接指到网盘目录运行——缓存和文件锁会让网盘同步频繁失败。

## 安全提醒

- `mcp.json` 里的 GitHub PAT、歌者 API_KEY 属于明文密钥，只能放进被 gitignore 的 `local/secrets.json`，**绝不提交进仓库**。
- 密钥一旦进过会话/聊天记录，建议轮换。
- `memory/` 目录含大量项目绝对路径，跨机不一定通用，按需单独同步，别并进主仓库。
