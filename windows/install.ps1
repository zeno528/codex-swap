#requires -Version 7.0
<#
.SYNOPSIS
    codex-switch Windows 安装器

.DESCRIPTION
    从 GitHub Release 下载 codex-switch-windows.zip，安装到 ~/.local/bin/codex-switch，
    并在 ~/.local/bin 生成 codex-switch.cmd 启动器（该目录需在 PATH 中，缺失则自动添加）。
    数据目录 ~/.codex（models/model-states）不受安装/卸载影响。

    一行安装（PowerShell 7）：
        irm https://raw.githubusercontent.com/zeno528/codex-switch/main/windows/install.ps1 | iex

    或下载后指定参数运行：
        .\windows\install.ps1 -Version v0.2.0 # 指定版本
        .\install.ps1 -Yes                   # 跳过确认
        .\install.ps1 -Uninstall             # 卸载（仅删除程序本体，不动数据）

.EXAMPLE
    .\windows\install.ps1
#>
[CmdletBinding()]
param(
    [string]$Version = '',
    [switch]$Uninstall,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoOwner    = 'zeno528'
$RepoName     = 'codex-switch'
$AssetName    = 'codex-switch-windows.zip'
$InstallRoot  = Join-Path $env:USERPROFILE '.local\bin\codex-switch'
$BinDir       = Join-Path $env:USERPROFILE '.local\bin'
$ShimPath     = Join-Path $BinDir 'codex-switch.cmd'

function Write-Step([string]$Text) { Write-Host "  $Text" -ForegroundColor DarkGray }
function Write-Ok([string]$Text)   { Write-Host "  ✅ $Text" -ForegroundColor Green }
function Write-Bad([string]$Text)  { Write-Host "  ❌ $Text" -ForegroundColor Red }

# ---------- 卸载 ----------
if ($Uninstall) {
    Write-Host "🗑️  卸载 codex-switch..." -ForegroundColor Cyan
    $removed = 0
    if (Test-Path $ShimPath) { Remove-Item $ShimPath -Force; $removed++; Write-Ok "已删除启动器 $ShimPath" }
    if (Test-Path $InstallRoot) { Remove-Item $InstallRoot -Recurse -Force; $removed++; Write-Ok "已删除程序目录 $InstallRoot" }
    if ($removed -eq 0) { Write-Host "  未发现已安装的 codex-switch" -ForegroundColor Yellow }
    Write-Host "  ℹ️  数据目录 ~/.codex 未动（models/model-states 完好）" -ForegroundColor DarkGray
    return
}

Write-Host "💻 codex-switch 安装器" -ForegroundColor Cyan
Write-Host ("=" * 48) -ForegroundColor DarkGray

# ---------- 前置检查 ----------
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Bad "需要 PowerShell 7+（当前 $($PSVersionTable.PSVersion)），请先安装 pwsh"
    exit 1
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

# ---------- 获取 Release ----------
if ([string]::IsNullOrWhiteSpace($Version)) {
    $relUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
    $label = '最新版'
} else {
    $relUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$Version"
    $label = "指定版 $Version"
}
Write-Step "获取 GitHub Release（$label）..."
$release = $null
try {
    $release = Invoke-RestMethod -Uri $relUrl -Headers @{ 'User-Agent' = 'codex-switch-installer' } -TimeoutSec 20
} catch {
    Write-Bad "获取 Release 失败: $_"
    exit 1
}
$tag = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
if ($null -eq $asset) {
    Write-Bad "Release $tag 缺少资产 $AssetName"
    exit 1
}
Write-Ok "Release $tag"

# ---------- 确认 ----------
if (-not $Yes) {
    $ans = Read-Host "安装 codex-switch $tag 到 $InstallRoot ? [Y/n]"
    if ($ans -match '^(n|N|no)$') { Write-Host "已取消" -ForegroundColor Yellow; return }
}

# ---------- 下载 ----------
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-switch-install-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tmpDir) | Out-Null
$zipPath = Join-Path $tmpDir $AssetName
$extract = Join-Path $tmpDir 'extract'
try {
    Write-Step "下载 $($asset.name) ($([math]::Round($asset.size/1KB)) KB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -TimeoutSec 120
    Expand-Archive -Path $zipPath -DestinationPath $extract -Force

    # 校验结构
    if (-not (Test-Path (Join-Path $extract 'src\codex-switch.psm1')) -or
        -not (Test-Path (Join-Path $extract 'bin\codex-switch.cmd'))) {
        Write-Bad "下载包结构不完整（缺 src/codex-switch.psm1 或 bin/codex-switch.cmd）"
        exit 1
    }
    Write-Ok "下载并解压完成"

    # ---------- 安装（备份旧版） ----------
    if (Test-Path $InstallRoot) {
        $old = "$InstallRoot.old"
        if (Test-Path $old) { Remove-Item $old -Recurse -Force }
        Rename-Item $InstallRoot $old
        Write-Step "旧版本已备份为 $old"
    }
    [System.IO.Directory]::CreateDirectory($InstallRoot) | Out-Null
    Copy-Item (Join-Path $extract '*') $InstallRoot -Recurse -Force

    # 验证模块可加载
    Import-Module (Join-Path $InstallRoot 'src\codex-switch.psm1') -Force -ErrorAction Stop
    Write-Ok "模块加载验证通过"

    # ---------- 启动器 + PATH ----------
    $shim = "@echo off`r`nrem codex-switch launcher (Windows)`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\src\codex-switch.ps1`" %*`r`n"
    [System.IO.File]::WriteAllText($ShimPath, $shim, [System.Text.UTF8Encoding]::new($false))
    Write-Ok "启动器 $ShimPath"

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not ($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') })) {
        $newPath = ($userPath.TrimEnd(';') + ';' + $BinDir)
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Ok "已把 $BinDir 加入用户 PATH（新终端生效）"
    } else {
        Write-Ok "$BinDir 已在 PATH 中"
    }

    # ---------- 汇总 ----------
    Write-Host ""
    Write-Host "✅ codex-switch $tag 安装完成" -ForegroundColor Green
    Write-Host "   程序目录: $InstallRoot" -ForegroundColor DarkGray
    Write-Host "   数据目录: $env:USERPROFILE\.codex（未改动）" -ForegroundColor DarkGray
    Write-Host "   使用: 新终端里运行 codex-switch" -ForegroundColor DarkGray
    Write-Host "   升级: codex-switch update" -ForegroundColor DarkGray
} finally {
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}
