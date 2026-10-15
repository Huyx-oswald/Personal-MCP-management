<#
sync.ps1 — 多端 Trae 配置同步（多端统一方案里的"脚本管落地"）

做的事：
  1. git pull
  2. 合并读取 local/secrets.json 与 local/machine.json
  3. 把 config/*.template.json 里的 ${占位符} 替换成本机真实值，去掉 .template 写回目标目录
  4. config/ 有改动时，用 -Push 提交并上传

用法：
  pwsh ./sync.ps1            # 拉取 + 落地（新机、换机时跑）
  pwsh ./sync.ps1 -WhatIf    # 只预览会写哪些文件，不写、不碰 git
  pwsh ./sync.ps1 -Push      # 提交并上传 config/ 里的模板变更
#>
[CmdletBinding()]
param(
  [switch]$Push,
  [switch]$WhatIf,
  [string]$Message = 'sync: update config templates'
)

$ErrorActionPreference = 'Stop'
$Root      = $PSScriptRoot
$ConfigDir = Join-Path $Root 'config'
$LocalDir  = Join-Path $Root 'local'
$isRepo    = Test-Path (Join-Path $Root '.git')

function Invoke-Git {
  param([string[]]$GitArgs)
  if ($WhatIf) { Write-Host "[whatif] git $($GitArgs -join ' ')"; return }
  if (-not $isRepo) { Write-Warning "非 Git 仓库，跳过 git $($GitArgs -join ' ')"; return }
  git -C $Root @GitArgs
}

if ($Push) {
  Invoke-Git 'add', 'config'
  if (-not $WhatIf) {
    if (git -C $Root diff --cached --quiet) { Write-Host '无变更可提交。'; return }
    Invoke-Git 'commit', '-m', $Message
  }
  Invoke-Git 'push'
  return
}

Invoke-Git 'pull', '--ff-only'

function Read-FlatJson {
  param([string]$Path)
  $h = @{}
  if (-not (Test-Path $Path)) { return $h }
  (Get-Content $Path -Raw | ConvertFrom-Json).PSObject.Properties |
    ForEach-Object { $h[$_.Name] = [string]$_.Value }
  return $h
}

$vars   = @{}
$vars  += Read-FlatJson (Join-Path $LocalDir 'secrets.json')
$vars  += Read-FlatJson (Join-Path $LocalDir 'machine.json')
$target = $vars['TRAE_CONFIG_DIR']
if (-not $target) { throw 'local/machine.json 缺少 TRAE_CONFIG_DIR（本机 Trae 配置目录的绝对路径）' }

foreach ($f in Get-ChildItem (Join-Path $ConfigDir '*.template.json') -ErrorAction SilentlyContinue) {
  $text    = Get-Content $f.FullName -Raw
  $outName = $f.Name -replace '\.template\.json$', '.json'

  # 值里的反斜杠要先转义再塞进 JSON 文本，否则 Windows 路径会写出非法 JSON
  foreach ($k in $vars.Keys) {
    $value = $vars[$k].Replace('\', '\\')   # ponytail: 只转义反斜杠；值里若含双引号需另想办法
    $text  = $text.Replace('${' + $k + '}', $value)
  }
  $missing = [regex]::Matches($text, '\$\{[A-Za-z0-9_]+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique
  if ($missing) { Write-Warning "$($f.Name) 仍有未替换占位符: $($missing -join ', ')" }

  # 空的骨架文件不写回，避免把本机现有配置清空
  if ([string]::IsNullOrWhiteSpace($text) -or $text.Trim() -eq '{}') {
    Write-Warning "跳过空占位文件 $($f.Name)（粘贴真实配置后再同步）"; continue
  }

  $dest = Join-Path $target $outName
  if ($WhatIf) { Write-Host "[whatif] $($f.Name) -> $dest" }
  else { Set-Content -Path $dest -Value $text -Encoding utf8; Write-Host "已写回 $dest" }
}

Write-Host '完成。配置有变动请重启 Trae 使其生效。'
