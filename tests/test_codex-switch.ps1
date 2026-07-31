#requires -Version 7.0
# 单元测试 codex-switch v2 核心模块

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '../src/codex-switch.psm1'
Import-Module $modulePath -Force

$pass = 0
$fail = 0
function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) { $script:pass++; Write-Host "  ✅ $Msg" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  ❌ $Msg" -ForegroundColor Red }
}

Write-Host "`n=== Test 1: Get-TemplateFingerprint ===" -ForegroundColor Cyan
$tmpTpl = [System.IO.Path]::GetTempFileName() + '.toml'
try {
    [System.IO.File]::WriteAllText($tmpTpl, @'
model = "deepseek-v4-flash"
model_provider = "deepseek"
[model_providers.deepseek]
experimental_bearer_token = "test-token-abcdefghijklmnopqrstuvwxyz123456"
'@, [System.Text.UTF8Encoding]::new($false))
    $fp = Get-TemplateFingerprint -Path $tmpTpl
    Assert-True ($fp.Model -eq 'deepseek-v4-flash') '解析 model'
    Assert-True ($fp.Provider -eq 'deepseek') '解析 model_provider'
    Assert-True ($fp.TokenFingerprint -eq 'test-t|123456') 'token 指纹 = 前6|后6'
} finally { Remove-Item $tmpTpl -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 2: Get-CurrentFingerprint ===" -ForegroundColor Cyan
$tmpCfg = [System.IO.Path]::GetTempFileName() + '.toml'
try {
    [System.IO.File]::WriteAllText($tmpCfg, @'
notify = [ "x", "y" ]
model = "gpt-5.6-terra"
[desktop]
show-context-window-usage = true
'@, [System.Text.UTF8Encoding]::new($false))
    $fp = Get-CurrentFingerprint -ConfigPath $tmpCfg
    Assert-True ($fp.Model -eq 'gpt-5.6-terra') '解析 config 的 model'
    Assert-True ($null -eq $fp.Provider) '无 model_provider 时为 $null'
} finally { Remove-Item $tmpCfg -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 3: Resolve-ActiveMarkers ===" -ForegroundColor Cyan
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
try {
    $dsPath = Join-Path $tmpDir 'deepseek.toml'
    [System.IO.File]::WriteAllText($dsPath, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))
    $gptPath = Join-Path $tmpDir 'gpt.toml'
    [System.IO.File]::WriteAllText($gptPath, 'model = "gpt-5.6-terra"' + "`n" + 'model_provider = "openai"', [System.Text.UTF8Encoding]::new($false))
    $cfgDir = Join-Path $tmpDir 'cfg'
    New-Item -ItemType Directory -Path $cfgDir | Out-Null
    $cfgPath = Join-Path $cfgDir 'config.toml'
    [System.IO.File]::WriteAllText($cfgPath, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))

    $markers = Resolve-ActiveMarkers -Files @($dsPath, $gptPath) -ConfigPath $cfgPath
    Assert-True ($markers[$dsPath] -eq 'active') 'deepseek 模板标为 active'
    Assert-True ($markers[$gptPath] -eq 'none') 'gpt 模板标为 none'
} finally { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 4: 同 model 多模板按 token 指纹精筛 ===" -ForegroundColor Cyan
$tmpDir2 = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
try {
    $t1 = Join-Path $tmpDir2 'a.toml'
    [System.IO.File]::WriteAllText($t1, 'model = "x"' + "`n" + 'model_provider = "p"' + "`n" + 'experimental_bearer_token = "test-token-AAAAAAAAAAAA11111111111111"', [System.Text.UTF8Encoding]::new($false))
    $t2 = Join-Path $tmpDir2 'b.toml'
    [System.IO.File]::WriteAllText($t2, 'model = "x"' + "`n" + 'model_provider = "p"' + "`n" + 'experimental_bearer_token = "test-token-BBBBBBBBBB22222222222222"', [System.Text.UTF8Encoding]::new($false))
    $cfg2 = Join-Path $tmpDir2 'config.toml'
    [System.IO.File]::WriteAllText($cfg2, 'model = "x"' + "`n" + 'model_provider = "p"' + "`n" + 'experimental_bearer_token = "test-token-BBBBBBBBBB22222222222222"', [System.Text.UTF8Encoding]::new($false))

    $markers = Resolve-ActiveMarkers -Files @($t1, $t2) -ConfigPath $cfg2
    Assert-True ($markers[$t1] -eq 'backup') 'token 不匹配 → backup'
    Assert-True ($markers[$t2] -eq 'active') 'token 匹配 → active'
} finally { Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 5: Save-ModelState + Get-SwitchContent 状态优先 ===" -ForegroundColor Cyan
$tmpState = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
$tmpModels = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpState, $tmpModels | Out-Null
try {
    [System.IO.File]::WriteAllText((Join-Path $tmpModels 'deepseek.toml'), '模板内容', [System.Text.UTF8Encoding]::new($false))
    $cfg = Join-Path $tmpModels 'config.toml'
    $grown = "模板内容" + "`n" + "`n[projects.'c:\users\zwf\demo']" + "`ntrust_level = ""trusted"""
    [System.IO.File]::WriteAllText($cfg, $grown, [System.Text.UTF8Encoding]::new($false))

    Save-ModelState -Name 'deepseek' -ConfigPath $cfg -StateDir $tmpState
    Assert-True ([System.IO.File]::Exists((Join-Path $tmpState 'deepseek.toml'))) '状态文件已生成'
    Assert-True (([System.IO.File]::ReadAllText((Join-Path $tmpState 'deepseek.toml'))).Contains('trusted')) '状态保存了增长的配置'

    $s = Get-SwitchContent -Name 'deepseek' -ModelsDir $tmpModels -StateDir $tmpState
    Assert-True ($s.Source -eq 'state') '有状态时用状态'
    Assert-True ($s.Content.Contains('trusted')) '恢复的是增长后的完整配置'

    $threw = $false
    try { Get-SwitchContent -Name 'nonexist' -ModelsDir $tmpModels -StateDir $tmpState } catch { $threw = $true }
    Assert-True $threw '状态和模板都不存在时抛错'
} finally { Remove-Item $tmpState, $tmpModels -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 6: Resolve-ActiveName ===" -ForegroundColor Cyan
$tmpDir6 = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir6 | Out-Null
try {
    $dsPath = Join-Path $tmpDir6 'deepseek.toml'
    [System.IO.File]::WriteAllText($dsPath, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))
    $cfg6 = Join-Path $tmpDir6 'cfg.toml'
    [System.IO.File]::WriteAllText($cfg6, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))
    Assert-True ((Resolve-ActiveName -Files @($dsPath) -ConfigPath $cfg6) -eq 'deepseek') '识别源为 deepseek'

    [System.IO.File]::WriteAllText($cfg6, 'model = "unknown"' + "`n" + 'model_provider = "xxx"', [System.Text.UTF8Encoding]::new($false))
    Assert-True ($null -eq (Resolve-ActiveName -Files @($dsPath) -ConfigPath $cfg6)) '匹配不到返回 $null'
} finally { Remove-Item $tmpDir6 -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 7: Compare-Version ===" -ForegroundColor Cyan
Assert-True ((Compare-Version -A 'v2.0.0' -B '2.0.0') -eq 0) 'v 前缀忽略'
Assert-True ((Compare-Version -A '2.1.0' -B '2.0.9') -eq 1) '2.1.0 > 2.0.9'
Assert-True ((Compare-Version -A '2.0.0' -B '2.0.1') -eq -1) '2.0.0 < 2.0.1'
Assert-True ((Compare-Version -A '2.0' -B '2.0.0') -eq 0) '缺位补零'
Assert-True ((Compare-Version -A 'v10.0.0' -B 'v9.9.9') -eq 1) '两位数版本号'

Write-Host "`n=== Test 8: Get-DisplayWidth ===" -ForegroundColor Cyan
Assert-True ((Get-DisplayWidth 'abc') -eq 3) 'ASCII 3 列'
Assert-True ((Get-DisplayWidth '中文') -eq 4) '中文 4 列'
Assert-True ((Get-DisplayWidth '✅') -eq 2) 'emoji 2 列'
Assert-True ((Get-DisplayWidth 'a中b') -eq 4) '混合宽度'

Write-Host "`n=== Test 9: Get-CodexHome ===" -ForegroundColor Cyan
Assert-True ((Get-CodexHome).EndsWith('.codex')) '返回以 .codex 结尾'

Write-Host "`n=== 总结 ===" -ForegroundColor Cyan
Write-Host "通过: $pass" -ForegroundColor Green
Write-Host "失败: $fail" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
