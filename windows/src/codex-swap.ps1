#requires -Version 7.0
<#
.SYNOPSIS
    codex-swap 入口脚本（Windows 安装版 / 开发模式通用）

.DESCRIPTION
    导入同目录 codex-swap.psm1 模块并分发命令。
    安装版由 bin/codex-swap.cmd 调用；开发模式可直接 pwsh 运行。

.EXAMPLE
    .\src\codex-swap.ps1                    # 菜单
    .\src\codex-swap.ps1 use deepseek       # 切换
    .\src\codex-swap.ps1 update             # 自更新
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'current', 'use', 'update', 'doctor', 'uninstall', 'help', 'menu')]
    [string]$Command = 'menu',

    [Parameter(Position = 1)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $moduleDir 'codex-swap.psd1') -Force -ErrorAction Stop
Invoke-CodexSwap -Command $Command -Name $Name
