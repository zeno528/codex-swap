#requires -Version 7.0
# 单元测试 codex-swap v0.2.0 核心模块

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '../src/codex-swap.psm1'
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

Write-Host "`n=== Test 4: 同 model 多模板按 model+provider 匹配（与 Linux 一致） ===" -ForegroundColor Cyan
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
    Assert-True ($markers[$t1] -eq 'active') '同 model+provider 模板 1 标为 active'
    Assert-True ($markers[$t2] -eq 'active') '同 model+provider 模板 2 标为 active'
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

    # 多模板同 model+provider：用当前 token 指纹消歧（与 Linux resolve_active 一致）
    $t1 = Join-Path $tmpDir6 'a-model.toml'
    $t2 = Join-Path $tmpDir6 'b-model.toml'
    [System.IO.File]::WriteAllText($t1, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"' + "`n" + 'experimental_bearer_token = "test-token-aaaaaaaaaa1111"', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($t2, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"' + "`n" + 'experimental_bearer_token = "test-token-bbbbbbbbbb2222"', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($cfg6, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"' + "`n" + 'experimental_bearer_token = "test-token-bbbbbbbbbb2222"', [System.Text.UTF8Encoding]::new($false))
    Assert-True ((Resolve-ActiveName -Files @($t1, $t2) -ConfigPath $cfg6) -eq 'b-model') '多命中按 token 指纹消歧'

    # 多命中但当前 token 为空：无法唯一确定 → $null（避免 auth 误存到错误模型）
    [System.IO.File]::WriteAllText($cfg6, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))
    Assert-True ($null -eq (Resolve-ActiveName -Files @($t1, $t2) -ConfigPath $cfg6)) '多命中且无指纹时返回 $null'
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

Write-Host "`n=== Test 10: 更新以 VERSION 为准 ===" -ForegroundColor Cyan
$moduleText = [System.IO.File]::ReadAllText($modulePath, [System.Text.UTF8Encoding]::new($false))
Assert-True ($moduleText -match 'Get-SourceVersion' -and $moduleText -notmatch 'sourceVsRelease') '更新决策只比较 VERSION 与本机版本'
Assert-True ($moduleText -match '下载资产版本 v\$packageVersion 与 VERSION v\$sourceVersion 不一致') '下载资产必须校验 VERSION'

Write-Host "`n=== Test 11: Save-ModelAuth 保存/覆盖/删除空态 ===" -ForegroundColor Cyan
$tmpAuth = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpAuth | Out-Null
try {
    $authFile = Join-Path $tmpAuth 'auth.json'
    [System.IO.File]::WriteAllText($authFile, '{ "token": "test-token-aaaaaaa1111111" }', [System.Text.UTF8Encoding]::new($false))
    $stateDir = Join-Path $tmpAuth 'states'
    Save-ModelAuth -Name 'deepseek' -AuthPath $authFile -StateDir $stateDir
    Assert-True ([System.IO.File]::Exists((Join-Path $stateDir 'deepseek.auth.json'))) 'auth 状态已保存'
    [System.IO.File]::WriteAllText($authFile, '{ "token": "test-token-bbbbbbb2222222" }', [System.Text.UTF8Encoding]::new($false))
    Save-ModelAuth -Name 'deepseek' -AuthPath $authFile -StateDir $stateDir
    Assert-True ((([System.IO.File]::ReadAllText((Join-Path $stateDir 'deepseek.auth.json'))).Contains('test-token-bbbbbbb2222222'))) '再次保存覆盖旧状态'
    [System.IO.File]::Delete($authFile)
    Save-ModelAuth -Name 'deepseek' -AuthPath $authFile -StateDir $stateDir
    Assert-True (-not [System.IO.File]::Exists((Join-Path $stateDir 'deepseek.auth.json'))) 'auth 不存在时删除旧状态（空态）'
} finally { Remove-Item $tmpAuth -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 12: Get-SwitchAuth 状态 > 模板 > 无托管 ===" -ForegroundColor Cyan
$tmpAuth2 = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tmpAuth2 'models'), (Join-Path $tmpAuth2 'states') | Out-Null
try {
    $models2 = Join-Path $tmpAuth2 'models'
    $states2 = Join-Path $tmpAuth2 'states'
    [System.IO.File]::WriteAllText((Join-Path $models2 'gpt.auth.json'), '{ "token": "test-token-tpl-auth" }', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $states2 'gpt.auth.json'), '{ "token": "test-token-state-auth" }', [System.Text.UTF8Encoding]::new($false))
    $a = Get-SwitchAuth -Name 'gpt' -ModelsDir $models2 -StateDir $states2
    Assert-True ($a.Source -eq 'state') '有状态时用状态'
    Assert-True ([System.IO.File]::ReadAllText($a.Path).Contains('test-token-state-auth')) '恢复的是状态内容'
    [System.IO.File]::Delete((Join-Path $states2 'gpt.auth.json'))
    $b = Get-SwitchAuth -Name 'gpt' -ModelsDir $models2 -StateDir $states2
    Assert-True ($b.Source -eq 'template') '无状态用模板'
    Assert-True ([System.IO.File]::ReadAllText($b.Path).Contains('test-token-tpl-auth')) '恢复的是模板内容'
    $c = Get-SwitchAuth -Name 'nonexist' -ModelsDir $models2 -StateDir $states2
    Assert-True ($null -eq $c.Source) '无托管时 Source 为 $null'
    Assert-True ($null -eq $c.Path) '无托管时 Path 为 $null'
} finally { Remove-Item $tmpAuth2 -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 13: 首次向导基础（安装提示/版本检查/🐳 命名） ===" -ForegroundColor Cyan
# 无 codex 时给出官方安装命令（CI 环境无 codex 可断言非空）
$hint = Get-CodexInstallHint
if ($null -ne $hint) {
    Assert-True (($hint -join ' ') -match 'codex') '安装提示包含官方 codex 命令'
} else {
    Assert-True $true '本机已装 codex，跳过安装提示断言'
}
$vt = Test-CodexVersion
Assert-True ($null -eq $vt -or $vt -is [bool]) 'Test-CodexVersion 返回 $null 或 bool'
Assert-True ((Get-ProviderIcon 'deepseek' 'x') -eq '🐳 ') 'deepseek 供应商显示 🐳'
Assert-True ((Get-ProviderIcon 'openai' 'x') -eq '💠 ') 'openai 供应商显示 💠'
Assert-True ((Get-ProviderIcon '' 'gpt-5.6-terra') -eq '💠 ') 'provider 为空按模型回退 💠'
Assert-True ((Get-ProviderIcon 'custom' 'deepseek-v4-flash') -eq '🐳 ') '模型名 deepseek 回退 🐳'
Assert-True ((Get-ProviderIcon 'custom' 'custom-model') -eq '') '未知供应商不加图标'

Write-Host "`n=== Test 14: 内置模板写入（DeepSeek + 官方 models.json） ===" -ForegroundColor Cyan
$tmpW = Join-Path ([System.IO.Path]::GetTempPath()) ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpW | Out-Null
try {
    $tplDs = & (Get-Module codex-swap) { $script:TemplateDeepseek }
    Assert-True (-not [string]::IsNullOrWhiteSpace($tplDs)) '内置 Flash 模板非空'
    $p = Write-TemplateFile -Name 'deepseek' -Content $tplDs -ApiKey 'sk-test-key-123456789' -ModelsDir $tmpW
    Assert-True ([System.IO.File]::Exists($p)) '模板文件已生成'
    $c = [System.IO.File]::ReadAllText($p, [System.Text.UTF8Encoding]::new($false))
    Assert-True ($c -match 'model = "deepseek-v4-flash"') 'model 字段正确'
    Assert-True ($c -match 'sk-test-key-123456789') 'API Key 已替换'
    Assert-True ($c -notmatch '__API_KEY__|__MODELS_JSON__') '占位符已全部清除'
    Assert-True ($c -match 'models\.json') 'model_catalog_json 已替换为实际路径'
    Assert-True ($c -match 'wire_api = "responses"') '走 Responses API'

    $jp = Write-ModelsJsonFile -Path (Join-Path $tmpW 'models.json')
    Assert-True ([System.IO.File]::Exists($jp)) 'models.json 已生成'
    $jc = [System.IO.File]::ReadAllText($jp, [System.Text.UTF8Encoding]::new($false))
    Assert-True ($jc -match '"deepseek-v4-flash"' -and $jc -match '"deepseek-v4-pro"') 'models.json 含两个模型'
    Assert-True ($jc -match 'base_instructions') '含官方系统提示词 base_instructions'
    Assert-True ($jc -match 'comp_hash') '含官方 comp_hash 元数据'
} finally { Remove-Item $tmpW -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n=== Test 15: uninstall 短命令与 Linux 对齐 ===" -ForegroundColor Cyan
$moduleText = [System.IO.File]::ReadAllText($modulePath, [System.Text.UTF8Encoding]::new($false))
Assert-True ($moduleText -match "'uninstall' \{ Invoke-Uninstall \}") 'psm1 分发含 uninstall 命令'
Assert-True ($moduleText -match "'Invoke-Uninstall'") 'Invoke-Uninstall 已导出'
Assert-True ($moduleText -match '未知命令') 'psm1 未知命令中文提示（与 Linux 一致）'
Assert-True ($moduleText -match 'exit 1') 'psm1 致命错误非零退出码（与 Linux fail 一致）'
$entryPath = Join-Path $PSScriptRoot '../src/codex-swap.ps1'
$entryText = [System.IO.File]::ReadAllText($entryPath, [System.Text.UTF8Encoding]::new($false))
Assert-True ($entryText -notmatch 'ValidateSet') '入口脚本不拦截未知命令（走中文提示）'

Write-Host "`n=== 总结 ===" -ForegroundColor Cyan
Write-Host "通过: $pass" -ForegroundColor Green
Write-Host "失败: $fail" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
