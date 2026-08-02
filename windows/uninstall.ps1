#requires -Version 5.1
<#
.SYNOPSIS
    codex-swap 卸载器（Windows）

.DESCRIPTION
    删除启动器 ~/.local/bin/codex-swap.cmd 和程序目录 ~/.local/bin/codex-swap。
    数据目录 ~/.codex（models/model-states）不受影响。

.EXAMPLE
    .\windows\uninstall.ps1
#>
[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$InstallRoot = Join-Path $env:USERPROFILE '.local\bin\codex-swap'
$ShimPath    = Join-Path $env:USERPROFILE '.local\bin\codex-swap.cmd'
$SwShimPath  = Join-Path $env:USERPROFILE '.local\bin\sw.cmd'

if (-not (Test-Path $ShimPath) -and -not (Test-Path $InstallRoot)) {
    Write-Host "未发现已安装的 codex-swap" -ForegroundColor Yellow
    return
}

if (-not $Yes) {
    $ans = Read-Host "确认卸载 codex-swap？（数据目录 ~/.codex 不受影响）[y/N]"
    if ($ans -notmatch '^(y|Y|yes)$') { Write-Host "已取消" -ForegroundColor Yellow; return }
}

if (Test-Path $ShimPath) {
    Remove-Item $ShimPath -Force
    Write-Host "✅ 已删除 $ShimPath" -ForegroundColor Green
}
if (Test-Path $SwShimPath) {
    Remove-Item $SwShimPath -Force
    Write-Host "✅ 已删除 $SwShimPath" -ForegroundColor Green
}
if (Test-Path $InstallRoot) {
    Remove-Item $InstallRoot -Recurse -Force
    Write-Host "✅ 已删除 $InstallRoot" -ForegroundColor Green
}
Write-Host "  ℹ️  数据目录 ~/.codex 未动（models/model-states 完好，可自行删除）" -ForegroundColor DarkGray
