<#
sync.ps1 — 多端 Trae 配置同步（多端统一方案里的"脚本管落地"）

前向（落地）：
  1. git pull
  2. 用 local/ 的值替换 config/*.template.json 里的 ${占位符}
  3. 去掉 .template 写回 TRAE_CONFIG_DIR
后向（回填上传）：
  1. 把本机改过的 mcp.json 里的真实值换回 ${占位符}，写进 config/*.template.json
  2. git 提交并上传

用法：
  pwsh ./sync.ps1            # 拉取 + 落地（新机、换机时跑）
  pwsh ./sync.ps1 -WhatIf    # 只预览，不写、不碰 git
  pwsh ./sync.ps1 -Push      # 在本机改过 mcp.json 后：回填模板 + 提交上传
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
$templates = @(Get-ChildItem (Join-Path $ConfigDir '*.template.json') -ErrorAction SilentlyContinue)

if ($Push) {
  if ($target) {
    foreach ($f in $templates) {
      $live = Join-Path $target ($f.Name -replace '\.template\.json$', '.json')
      if (-not (Test-Path $live)) { continue }
      $text = Get-Content $live -Raw
      # 回填：真实值 -> ${占位符}。反斜杠也要按渲染时的转义形式去匹配
      foreach ($k in $vars.Keys) { $text = $text.Replace($vars[$k].Replace('\', '\\'), '${' + $k + '}') }
      # ponytail: 只有 local/ 登记过的变量会被换掉；新加的密钥会以明文留在模板里，粗扫一下告警
      $leak = [regex]::Matches($text, '[A-Za-z0-9_\-]{32,}') | ForEach-Object { $_.Value } | Sort-Object -Unique
      if ($leak) { Write-Warning "$($f.Name) 回填后疑似仍有明文密钥，确认后再上传: $($leak -join ', ')" }
      if ($WhatIf) { Write-Host "[whatif] 回填 $($f.Name) <- $live" }
      else { [IO.File]::WriteAllText($f.FullName, $text); Write-Host "已回填 $($f.Name) <- $live" }
    }
  } else {
    Write-Warning '缺少 TRAE_CONFIG_DIR，跳过回填（仅提交 config/ 里现有改动）'
  }
  Invoke-Git 'add', 'config'
  if ($isRepo -and -not $WhatIf) {
    if (git -C $Root diff --cached --quiet) { Write-Host '无变更可提交。'; return }
    Invoke-Git 'commit', '-m', $Message
  }
  Invoke-Git 'push'
  return
}

if (-not $target) { throw 'local/machine.json 缺少 TRAE_CONFIG_DIR（本机 Trae 配置目录的绝对路径）' }
Invoke-Git 'pull', '--ff-only'

foreach ($f in $templates) {
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
  else { [IO.File]::WriteAllText($dest, $text); Write-Host "已写回 $dest" }   # 逐字节写，避免 Set-Content 每次多加一个换行
}

Write-Host '完成。配置有变动请重启 Trae 使其生效。'
