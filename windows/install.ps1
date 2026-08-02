#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Version = '',
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$coreUrl = 'https://raw.githubusercontent.com/zeno528/codex-swap/main/windows/install-core.ps1'

try {
    $coreText = Invoke-RestMethod -Uri $coreUrl -Headers @{ 'User-Agent' = 'codex-swap-bootstrap' } -TimeoutSec 30
    $coreText = $coreText -replace '^\uFEFF', ''
    $coreScript = [scriptblock]::Create($coreText)
    $invokeArgs = @{}
    if (-not [string]::IsNullOrWhiteSpace($Version)) { $invokeArgs.Version = $Version }
    if ($Uninstall) { $invokeArgs.Uninstall = $true }
    & $coreScript @invokeArgs
} catch {
    Write-Error "codex-swap installer failed: $_"
    exit 1
}
