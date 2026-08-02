#requires -Version 5.1
<#
.SYNOPSIS
    codex-swap Windows 安装器核心逻辑

.DESCRIPTION
    由 windows/install.ps1 的 ASCII bootstrap 下载并执行；也可以直接运行。
    从 GitHub Release 下载 codex-swap-windows.zip，安装到 ~/.local/bin/codex-swap，
    并在 ~/.local/bin 生成 codex-swap.cmd 启动器（该目录需在 PATH 中，缺失则自动添加）。
    数据目录 ~/.codex（models/model-states）不受安装/卸载影响。
#>
[CmdletBinding()]
param(
    [string]$Version = '',
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoOwner    = 'zeno528'
$RepoName     = 'codex-swap'
$AssetName    = 'codex-swap-windows.zip'
$InstallRoot  = Join-Path $env:USERPROFILE '.local\bin\codex-swap'
$BinDir       = Join-Path $env:USERPROFILE '.local\bin'
$ShimPath     = Join-Path $BinDir 'codex-swap.cmd'
$SwShimPath   = Join-Path $BinDir 'sw.cmd'

function Write-Ok([string]$Text)   { Write-Host "  ✅ $Text" -ForegroundColor Green }
function Write-Bad([string]$Text)  { Write-Host "  ❌ $Text" -ForegroundColor Red }

# ---------- 卸载 ----------
if ($Uninstall) {
    Write-Host "🗑️  卸载 codex-swap..." -ForegroundColor Cyan
    $removed = 0
    if (Test-Path $ShimPath) { Remove-Item $ShimPath -Force; $removed++; Write-Ok "已删除启动器 $ShimPath" }
    if (Test-Path $SwShimPath) { Remove-Item $SwShimPath -Force; $removed++; Write-Ok "已删除快捷命令 $SwShimPath" }
    if (Test-Path $InstallRoot) { Remove-Item $InstallRoot -Recurse -Force; $removed++; Write-Ok "已删除程序目录 $InstallRoot" }
    if ($removed -eq 0) { Write-Host "  未发现已安装的 codex-swap" -ForegroundColor Yellow }
    Write-Host "  ℹ️  数据目录 ~/.codex 未动（models/model-states 完好，可自行删除）" -ForegroundColor DarkGray
    return
}

# ---------- 前置检查 ----------
if ($PSVersionTable.PSVersion -lt [version]'5.1') {
    Write-Bad "需要 PowerShell 5.1+（当前 $($PSVersionTable.PSVersion)）"
    exit 1
}

# ---------- 获取 Release ----------
if ([string]::IsNullOrWhiteSpace($Version)) {
    $relUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
} else {
    $relUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$Version"
}
$release = $null
try {
    $release = Invoke-RestMethod -Uri $relUrl -Headers @{ 'User-Agent' = 'codex-swap-installer' } -TimeoutSec 20
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

# ---------- 下载 ----------
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-swap-install-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tmpDir) | Out-Null
$zipPath = Join-Path $tmpDir $AssetName
$extract = Join-Path $tmpDir 'extract'
try {
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zipPath -TimeoutSec 120
    Expand-Archive -Path $zipPath -DestinationPath $extract -Force

    # 校验结构
    if (-not (Test-Path (Join-Path $extract 'src\codex-swap.psm1')) -or
        -not (Test-Path (Join-Path $extract 'bin\codex-swap.cmd'))) {
        Write-Bad "下载包结构不完整（缺 src/codex-swap.psm1 或 bin/codex-swap.cmd）"
        exit 1
    }

    # ---------- 安装（备份旧版） ----------
    if (Test-Path $InstallRoot) {
        $old = "$InstallRoot.old"
        if (Test-Path $old) { Remove-Item $old -Recurse -Force }
        Rename-Item $InstallRoot $old
    }
    [System.IO.Directory]::CreateDirectory($InstallRoot) | Out-Null
    Copy-Item (Join-Path $extract '*') $InstallRoot -Recurse -Force

    # 验证模块可加载
    Import-Module (Join-Path $InstallRoot 'src\codex-swap.psm1') -Force -ErrorAction Stop

    # ---------- 启动器 + PATH ----------
    $shim = "@echo off`r`nrem codex-swap launcher (Windows)`r`nwhere pwsh >nul 2>&1`r`nif not errorlevel 1 (`r`n    pwsh -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\src\codex-swap.ps1`" %*`r`n) else (`r`n    powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\src\codex-swap.ps1`" %*`r`n)`r`n"
    [System.IO.File]::WriteAllText($ShimPath, $shim, [System.Text.UTF8Encoding]::new($false))

    $swShim = $shim
    if (-not (Test-Path $SwShimPath) -or ([System.IO.File]::ReadAllText($SwShimPath) -match 'codex-swap launcher')) {
        [System.IO.File]::WriteAllText($SwShimPath, $swShim, [System.Text.UTF8Encoding]::new($false))
    } else {
        Write-Host "  ⚠️ 快捷命令未创建：$SwShimPath 已被占用" -ForegroundColor Yellow
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not ($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') })) {
        $newPath = ($userPath.TrimEnd(';') + ';' + $BinDir)
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Ok "已把 $BinDir 加入用户 PATH（新终端生效）"
    }

    # ---------- 汇总 ----------
    Write-Host ""
    Write-Host "✅ codex-swap $tag 安装完成" -ForegroundColor Green
    Write-Host "   安装到: $InstallRoot · 快捷启动命令: sw" -ForegroundColor DarkGray
    Write-Host "   升级: codex-swap update" -ForegroundColor DarkGray
} finally {
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}
