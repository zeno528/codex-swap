#requires -Version 7.0
# 单元测试 codex-model-v1.ps1 的核心函数（纯全量覆盖模式）
# 加载脚本但不执行（dot-source 到当前 scope 但不跑 main dispatch）

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# 把脚本内容读进来，跳过 main dispatch（try { switch } 块）
$scriptPath = 'C:\Users\zwf\Scripts\codex-model\codex-model-v1.ps1'
$content = Get-Content $scriptPath -Raw

# 截取到 "main dispatch" 之前的部分 — 用 "# === 主分发 ===" 标记定位
$mainStart = $content.IndexOf("# === 主分发 ===")
if ($mainStart -gt 0) {
    $bodyOnly = $content.Substring(0, $mainStart)
} else {
    $bodyOnly = $content
}

# 在临时文件里执行函数定义
$tmpScript = [System.IO.Path]::GetTempFileName() + '.ps1'
[System.IO.File]::WriteAllText($tmpScript, $bodyOnly, [System.Text.UTF8Encoding]::new($false))
. $tmpScript
Remove-Item $tmpScript

$pass = 0
$fail = 0
function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) { $script:pass++; Write-Host "  ✅ $Msg" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  ❌ $Msg" -ForegroundColor Red }
}

Write-Host "`n=== Test 1: Get-TemplateFingerprint 解析模板 ===" -ForegroundColor Cyan
$tmpTpl = [System.IO.Path]::GetTempFileName() + '.toml'
try {
    [System.IO.File]::WriteAllText($tmpTpl, @'
# deepseek 模板
model = "deepseek-v4-flash"
model_provider = "deepseek"
model_reasoning_effort = "max"

[model_providers.deepseek]
name = "deepseek"
base_url = "https://api.deepseek.com/"
experimental_bearer_token = "sk-abcdefghijklmnopqrstuvwxyz123456"
'@, [System.Text.UTF8Encoding]::new($false))
    $fp = Get-TemplateFingerprint -Path $tmpTpl
    Assert-True ($fp.Model -eq 'deepseek-v4-flash') '解析 model'
    Assert-True ($fp.Provider -eq 'deepseek') '解析 model_provider'
    Assert-True ($fp.TokenFingerprint -eq 'sk-abc|123456') 'token 指纹 = 前6|后6'
} finally {
    Remove-Item $tmpTpl -ErrorAction SilentlyContinue
}

Write-Host "`n=== Test 2: Get-CurrentFingerprint 从 config 提取 ===" -ForegroundColor Cyan
$tmpCfg = [System.IO.Path]::GetTempFileName() + '.toml'
try {
    [System.IO.File]::WriteAllText($tmpCfg, @'
notify = [ "x", "y" ]
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
[desktop]
show-context-window-usage = true
'@, [System.Text.UTF8Encoding]::new($false))
    $fp = Get-CurrentFingerprint -ConfigPath $tmpCfg
    Assert-True ($fp.Model -eq 'gpt-5.6-terra') '解析 config 的 model'
    Assert-True ($null -eq $fp.Provider) '无 model_provider 时为 $null'
    Assert-True ($null -eq $fp.TokenFingerprint) '无 token 时指纹为 $null'
} finally {
    Remove-Item $tmpCfg -ErrorAction SilentlyContinue
}

Write-Host "`n=== Test 3: Resolve-ActiveMarkers 标记 ===" -ForegroundColor Cyan
$tmpDir = [System.IO.Path]::GetTempFileName()  # 用作目录名占位
Remove-Item $tmpDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmpDir | Out-Null
try {
    # 两个模板: 不同 model
    $dsPath = Join-Path $tmpDir 'deepseek.toml'
    [System.IO.File]::WriteAllText($dsPath, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))
    $gptPath = Join-Path $tmpDir 'gpt.toml'
    [System.IO.File]::WriteAllText($gptPath, 'model = "gpt-5.6-terra"' + "`n" + 'model_provider = "openai"', [System.Text.UTF8Encoding]::new($false))

    # 当前 config 是 deepseek（放在独立目录，避免与模板同名冲突）
    $cfgTmp = Join-Path $tmpDir 'cfg'
    New-Item -ItemType Directory -Path $cfgTmp | Out-Null
    $cfgPath = Join-Path $cfgTmp 'config.toml'
    [System.IO.File]::WriteAllText($cfgPath, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))

    $markers = Resolve-ActiveMarkers -Files @($dsPath, $gptPath) -ConfigPath $cfgPath
    Assert-True ($markers[$dsPath] -eq 'active') 'deepseek 模板标为 active'
    Assert-True ($markers[$gptPath] -eq 'none') 'gpt 模板标为 none'
} finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== Test 4: 同 model 多模板按 token 指纹精筛 ===" -ForegroundColor Cyan
$tmpDir2 = [System.IO.Path]::GetTempFileName()
Remove-Item $tmpDir2 -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmpDir2 | Out-Null
try {
    $t1 = Join-Path $tmpDir2 'a.toml'
    [System.IO.File]::WriteAllText($t1, 'model = "x"' + "`n" + 'model_provider = "p"' + "`n" + 'experimental_bearer_token = "sk-AAAAAAAAAAAA11111111111111"', [System.Text.UTF8Encoding]::new($false))
    $t2 = Join-Path $tmpDir2 'b.toml'
    [System.IO.File]::WriteAllText($t2, 'model = "x"' + "`n" + 'model_provider = "p"' + "`n" + 'experimental_bearer_token = "sk-BBBBBBBBBB22222222222222"', [System.Text.UTF8Encoding]::new($false))

    $cfg2 = Join-Path $tmpDir2 'config.toml'
    [System.IO.File]::WriteAllText($cfg2, 'model = "x"' + "`n" + 'model_provider = "p"' + "`n" + 'experimental_bearer_token = "sk-BBBBBBBBBB22222222222222"', [System.Text.UTF8Encoding]::new($false))

    $markers = Resolve-ActiveMarkers -Files @($t1, $t2) -ConfigPath $cfg2
    Assert-True ($markers[$t1] -eq 'backup') 'token 不匹配 → backup'
    Assert-True ($markers[$t2] -eq 'active') 'token 匹配 → active'
} finally {
    Remove-Item $tmpDir2 -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== Test 5: Get-DisplayWidth CJK/emoji 宽度 ===" -ForegroundColor Cyan
Assert-True ((Get-DisplayWidth 'abc') -eq 3) 'ASCII 3 列'
Assert-True ((Get-DisplayWidth '中文') -eq 4) '中文 4 列'
Assert-True ((Get-DisplayWidth '✅') -eq 2) 'emoji 2 列'
Assert-True ((Get-DisplayWidth 'a中b') -eq 4) '混合宽度'

Write-Host "`n=== Test 6: Save-ModelState + Get-SwitchContent 状态优先 ===" -ForegroundColor Cyan
$tmpState = Join-Path $env:TEMP ("cm-test-" + [guid]::NewGuid().ToString('N'))
$tmpModels = Join-Path $env:TEMP ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpState, $tmpModels | Out-Null
try {
    # 模板（播种用）
    [System.IO.File]::WriteAllText((Join-Path $tmpModels 'deepseek.toml'), '模板内容', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $tmpModels 'gpt.toml'), 'gpt模板', [System.Text.UTF8Encoding]::new($false))

    # 模拟使用中的 config（比模板大）
    $cfg = Join-Path $tmpModels 'config.toml'
    $grown = "模板内容" + "`n" + "`n[projects.'c:\users\zwf\demo']" + "`ntrust_level = ""trusted"""
    [System.IO.File]::WriteAllText($cfg, $grown, [System.Text.UTF8Encoding]::new($false))

    # 切出 deepseek: 保存状态
    Save-ModelState -Name 'deepseek' -ConfigPath $cfg -StateDir $tmpState
    Assert-True ([System.IO.File]::Exists((Join-Path $tmpState 'deepseek.toml'))) '状态文件已生成'
    Assert-True (([System.IO.File]::ReadAllText((Join-Path $tmpState 'deepseek.toml'))).Contains('trusted')) '状态保存了增长的配置'

    # 切回 deepseek: 优先状态
    $s = Get-SwitchContent -Name 'deepseek' -ModelsDir $tmpModels -StateDir $tmpState
    Assert-True ($s.Source -eq 'state') '有状态时用状态'
    Assert-True ($s.Content.Contains('trusted')) '恢复的是增长后的完整配置'

    # gpt 无状态: 用模板播种
    $s2 = Get-SwitchContent -Name 'gpt' -ModelsDir $tmpModels -StateDir $tmpState
    Assert-True ($s2.Source -eq 'template') '无状态时用模板'
    Assert-True ($s2.Content -eq 'gpt模板') '模板内容原样'

    # 状态和模板都没有: 抛错
    $threw = $false
    try { Get-SwitchContent -Name 'nonexist' -ModelsDir $tmpModels -StateDir $tmpState } catch { $threw = $true }
    Assert-True $threw '两者都不存在时抛错'
} finally {
    Remove-Item $tmpState, $tmpModels -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== Test 7: Resolve-ActiveName 源模型识别 ===" -ForegroundColor Cyan
$tmpDir7 = Join-Path $env:TEMP ("cm-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir7 | Out-Null
try {
    $dsPath = Join-Path $tmpDir7 'deepseek.toml'
    [System.IO.File]::WriteAllText($dsPath, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))
    $gptPath = Join-Path $tmpDir7 'gpt.toml'
    [System.IO.File]::WriteAllText($gptPath, 'model = "gpt-5.6-terra"' + "`n" + 'model_provider = "openai"', [System.Text.UTF8Encoding]::new($false))

    $cfg7 = Join-Path $tmpDir7 'cfg.toml'
    [System.IO.File]::WriteAllText($cfg7, 'model = "deepseek-v4-flash"' + "`n" + 'model_provider = "deepseek"', [System.Text.UTF8Encoding]::new($false))

    $n1 = Resolve-ActiveName -Files @($dsPath, $gptPath) -ConfigPath $cfg7
    Assert-True ($n1 -eq 'deepseek') '识别源为 deepseek'

    # config 被 App 改得匹配不到任何模板
    [System.IO.File]::WriteAllText($cfg7, 'model = "unknown-model"' + "`n" + 'model_provider = "xxx"', [System.Text.UTF8Encoding]::new($false))
    $n2 = Resolve-ActiveName -Files @($dsPath, $gptPath) -ConfigPath $cfg7
    Assert-True ($null -eq $n2) '匹配不到返回 $null'
} finally {
    Remove-Item $tmpDir7 -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== 总结 ===" -ForegroundColor Cyan
Write-Host "通过: $pass" -ForegroundColor Green
Write-Host "失败: $fail" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if ($fail -gt 0) { exit 1 }
