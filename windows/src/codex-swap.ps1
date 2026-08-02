#requires -Version 7.0
<#
.SYNOPSIS
    codex-switch 入口脚本（Windows 安装版 / 开发模式通用）

.DESCRIPTION
    导入同目录 codex-switch.psm1 模块并分发命令。
    安装版由 bin/codex-switch.cmd 调用；开发模式可直接 pwsh 运行。

.EXAMPLE
    .\src\codex-switch.ps1                    # 菜单
    .\src\codex-switch.ps1 use deepseek       # 切换
    .\src\codex-switch.ps1 update             # 自更新
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'current', 'use', 'update', 'doctor', 'help', 'menu')]
    [string]$Command = 'menu',

    [Parameter(Position = 1)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $moduleDir 'codex-switch.psd1') -Force -ErrorAction Stop
Invoke-CodexSwitch -Command $Command -Name $Name
