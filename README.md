# Personal-MCP-management

多端 Trae 配置统一：**Git 管配置（含密钥占位符），脚本管落地，网盘管备份和大文件，账号登录管插件/技能**。

三台机器（公司台机 / 笔记本 / 家里电脑）都在本仓库拉取，仓库内容三端一致；差异只剩 `local/` 一个目录和各机已装的依赖。

## 目录结构

```
.
├── config/
│   ├── mcp.template.json   # 占位符版 mcp 配置，不含任何密钥
│   ├── skill-config.json
│   ├── plugin-config.json
│   └── settings.json
├── local/                  # 各机私有，已被 .gitignore 忽略
│   ├── secrets.json        # GitHub PAT / 歌者 API_KEY
│   └── machine.json        # 本机路径：Trae 配置目录、venv、memory 路径
├── sync.ps1                # 拉取 + 占位符替换 + 写回目标路径
├── sync.tests.ps1          # sync.ps1 自检
└── README.md               # 本清单
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

变量来自 `local/secrets.json` 与 `local/machine.json`（后者同名键覆盖前者）。`config/` 下的普通 `*.json` 不含占位符，原样写回。

> 当前 `config/` 是空骨架（`{}`）。把本机 `.trae-cn/User` 下真实的 `mcp.json` / `skill-config.json` / `plugin-config.json` / `settings.json` 搬进来，并按上面约定把密钥、绝对路径改成 `${变量名}`。空文件运行 `sync.ps1` 会被跳过，不会清空本机现有配置。

## 新机 bootstrap（每台做一次）

1. 装 `node` + `uv`（供 npx / uvx 类 MCP 使用）。
2. `git clone` 本仓库；在 `local/` 下把 `.example` 复制成 `secrets.json`、`machine.json`，填真实值。
3. 按下方「各机必装」装本地依赖（蓝印 RPA 客户端、SAP GUI、`mcp-sap-gui` 的 clone+venv 等）。
4. 跑 `pwsh ./sync.ps1`，用**同一个 Trae 账号**登录（官方插件 / 市场技能自动到账，只需同步"启用状态"）。

## 日常用法

| 场景 | 命令 |
| --- | --- |
| 改了 `config/` 里的模板，上传 | `pwsh ./sync.ps1 -Push` |
| 换到另一台机器落地 | `pwsh ./sync.ps1` |
| 只想看会写哪些文件 | `pwsh ./sync.ps1 -WhatIf` |
| 验证脚本逻辑没坏 | `pwsh ./sync.tests.ps1` |

落地后若配置有变，**重启 Trae** 生效。

## 各机必装 / 迁移难度

| 服务 | 类型 | 迁移要点 |
| --- | --- | --- |
| GitHub / windows-cli / Pandoc / 歌者PPT / context7 / Knowledge Graph Memory / Excel / markitdown | npx / uvx | 配置可同步，各机装好 node、uv 即可 |
| markitdown | uvx | 同上，注意别让路径占位符问题复发 |
| lanyin-rpa | `http://127.0.0.1:18765` | 各机需安装并运行蓝印 RPA 客户端 |
| mcp-sap-gui | 本地 venv | 各机 clone + 建 venv，路径写进 `machine.json` |
| Knowledge Graph Memory | 本地 jsonl | `MEMORY_FILE_PATH` 走 `machine.json`，数据文件本身按需单独备份 |

## 网盘的正确用法

- WPS / 百度网盘 VIP 只放：仓库的 zip 快照备份、大文件（扩展包、素材、导出文档），以及没装 Git 的临时机器做手工搬运。
- **不要**把 `.trae-cn` 或 `User` 目录直接指到网盘目录运行——缓存和文件锁会让网盘同步频繁失败。

## 安全提醒

- `mcp.json` 里的 GitHub PAT、歌者 API_KEY 属于明文密钥，只能放进被 gitignore 的 `local/secrets.json`，**绝不提交进仓库**。
- 密钥一旦进过会话/聊天记录，建议轮换。
- `memory/` 目录含大量项目绝对路径，跨机不一定通用，按需单独同步，别并进主仓库。
