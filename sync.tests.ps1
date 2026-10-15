# sync.ps1 自检：临时目录里跑一遍落地逻辑，断言占位符替换与空文件跳过。
# 用法：pwsh ./sync.tests.ps1
$ErrorActionPreference = 'Stop'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("mcp-sync-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'config'), (Join-Path $tmp 'local'), (Join-Path $tmp 'out') | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'sync.ps1') $tmp

@'
{"mcpServers":{"github":{"env":{"TOKEN":"${GITHUB_PAT}"}},"sap":{"path":"${SAP_VENV}"}}}
'@ | Set-Content (Join-Path $tmp 'config/mcp.template.json') -Encoding utf8
'{}' | Set-Content (Join-Path $tmp 'config/empty.template.json') -Encoding utf8
@{ GITHUB_PAT = 'ghp_secret' } | ConvertTo-Json | Set-Content (Join-Path $tmp 'local/secrets.json') -Encoding utf8
@{ TRAE_CONFIG_DIR = (Join-Path $tmp 'out'); SAP_VENV = 'C:\sap-venv' } | ConvertTo-Json |
  Set-Content (Join-Path $tmp 'local/machine.json') -Encoding utf8

& (Join-Path $tmp 'sync.ps1') *> $null

$mcp = Get-Content (Join-Path $tmp 'out/mcp.json') -Raw
if ($mcp -notmatch 'ghp_secret')                    { throw 'FAIL: GITHUB_PAT 未替换' }
if ($mcp -notmatch 'C:\\sap-venv')                  { throw 'FAIL: SAP_VENV 未替换' }
if ($mcp -match '\$\{')                             { throw 'FAIL: 仍有未替换占位符' }
if (Test-Path (Join-Path $tmp 'out/empty.json'))    { throw 'FAIL: 空占位模板未被跳过' }

Remove-Item $tmp -Recurse -Force
Write-Host 'OK: sync.ps1 自检通过'
