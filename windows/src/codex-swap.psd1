@{
    RootModule        = 'codex-swap.psm1'
    ModuleVersion     = '0.2.49'
    GUID              = '3a7c9f2e-5b4d-4a1c-9e8f-6d2b7a4c1e50'
    Author            = 'Scott Z'
    CompanyName       = 'zeno528'
    Copyright         = '(c) Scott Z. MIT License.'
    Description       = 'Codex 模型切换器：模板播种 + 状态恢复，跨模型独立维护最新配置。'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-CodexSwap',
        'Get-TemplateFingerprint',
        'Get-CurrentFingerprint',
        'Resolve-ActiveMarkers',
        'Resolve-ActiveName',
        'Save-ModelState',
        'Get-SwitchContent',
        'Save-ModelAuth',
        'Get-SwitchAuth',
        'Compare-Version',
        'Get-DisplayWidth',
        'Get-CodexHome',
        'Get-ProviderIcon',
        'Get-CodexInstallHint',
        'Test-CodexVersion',
        'Write-TemplateFile',
        'Write-ModelsJsonFile'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('codex', 'model', 'switch'); LicenseUri = 'https://github.com/zeno528/codex-swap/blob/main/LICENSE' } }
}
