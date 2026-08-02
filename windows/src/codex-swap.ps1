#requires -Version 5.1
<#
.SYNOPSIS
    codex-swap 入口脚本（Windows 安装版 / 开发模式通用）

.DESCRIPTION
    导入同目录 codex-swap.psm1 模块并分发命令。
    安装版由 bin/codex-swap.cmd 调用；开发模式可直接用 pwsh 或 powershell 运行。

.EXAMPLE
    .\src\codex-swap.ps1                    # 菜单
    .\src\codex-swap.ps1 use deepseek       # 切换
    .\src\codex-swap.ps1 update             # 自更新
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'menu',

    [Parameter(Position = 1)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $moduleDir 'codex-swap.psd1') -Force -ErrorAction Stop
Invoke-CodexSwap -Command $Command -Name $Name
