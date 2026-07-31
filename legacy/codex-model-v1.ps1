#requires -Version 7.0
<#
.SYNOPSIS
    切换 Codex 桌面 App 的模型配置（模板播种 + 状态恢复）

.DESCRIPTION
    双击打开交互式菜单，选数字切换模型，o 打开模板目录。
    每个模型两份配置：
      模板    ~/.codex/models/<name>.toml         首次使用的种子（可随时编辑）
      状态    ~/.codex/model-states/<name>.toml   该模型最近一次使用时的完整 config
    切换逻辑：切出时把当前 config 完整保存为该模型的状态；
              切入时优先恢复该模型的最新状态，首次使用才用模板初始化。
    两个模型的状态完全独立，使用记录（信任项目/禁用 skill 等）不丢失。
    每次切换前自动备份（backups_model 保留最近 5 份）。

.EXAMPLE
    codex-model                    # 交互式菜单（双击）
    codex-model use deepseek       # 命令行切换
    codex-model use config         # 切到名为 config 的模板（GPT 完整配置）
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('list', 'current', 'use', 'help', 'menu')]
    [string]$Command = 'menu',

    [Parameter(Position = 1)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

$CodexHome  = Join-Path $env:USERPROFILE '.codex'
$ConfigPath = Join-Path $CodexHome 'config.toml'
$ModelsDir  = Join-Path $CodexHome 'models'
$BackupDir  = Join-Path $CodexHome 'backups_model'
$StateDir   = Join-Path $CodexHome 'model-states'

function Write-ColorOutput {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Text,
        [string]$Color = 'White'
    )
    Write-Host $Text -ForegroundColor $Color
}

# === 核心：从单个模板里提取 (model, model_provider, token 指纹) ===
# 返回 hashtable；任一字段缺失时该字段为 $null。
function Get-TemplateFingerprint {
    param([Parameter(Mandatory)] [string]$Path)
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    $m = $null; $p = $null; $tok = $null
    foreach ($line in ($content -split [char]10)) {
        $t = $line.Trim()
        if ($t.StartsWith('#')) { continue }
        if ($t -match '^\s*model\s*=\s*"(.*)"\s*$')                   { $m   = $Matches[1] }
        if ($t -match '^\s*model_provider\s*=\s*"(.*)"\s*$')         { $p   = $Matches[1] }
        if ($t -match '^\s*experimental_bearer_token\s*=\s*"(.*)"\s*$') { $tok = $Matches[1] }
    }
    $fp = $null
    if ($null -ne $tok -and $tok.Length -ge 12) {
        $fp = $tok.Substring(0, 6) + '|' + $tok.Substring($tok.Length - 6)
    } elseif ($null -ne $tok) {
        # 短 token 直接整串对比，避免前 6/后 6 重叠/越界
        $fp = $tok
    }
    return @{ Model = $m; Provider = $p; TokenFingerprint = $fp }
}

# === 工具：圆角框标题（自适应宽度，CJK/emoji 安全）===
function Show-TitleBox {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [string]$Color = 'Cyan'
    )
    $innerW = Get-DisplayWidth $Text
    $W = $innerW + 4   # 左右各 2 字符缓冲
    $dash = '─' * $W
    $pad  = ' ' * 2
    Write-Host "  ╭$dash╮" -ForegroundColor $Color
    Write-Host "  │$pad$Text$pad│" -ForegroundColor $Color
    Write-Host "  ╰$dash╯" -ForegroundColor $Color
}
# === 工具：计算字符串的终端显示宽度（CJK/emoji 安全）===
# ASCII = 1 字符；非 ASCII = 2 字符；零宽字符 = 0 字符
function Get-DisplayWidth {
    param([string]$str)
    if ([string]::IsNullOrEmpty($str)) { return 0 }
    $width = 0
    $chars = $str.ToCharArray()
    $i = 0
    while ($i -lt $chars.Length) {
        $cp = [int]$chars[$i]
        # 代理项对: emoji 等辅助平面字符，宽度 2
        if ($cp -ge 0xD800 -and $cp -le 0xDBFF -and $i + 1 -lt $chars.Length) {
            $low = [int]$chars[$i + 1]
            if ($low -ge 0xDC00 -and $low -le 0xDFFF) {
                $width += 2; $i += 2; continue
            }
        }
        # 零宽字符: 变体选择符、ZWSP/ZWNJ/ZWJ、Word Joiner
        if (($cp -ge 0xFE00 -and $cp -le 0xFE0F) -or ($cp -ge 0x200B -and $cp -le 0x200D) -or $cp -eq 0x2060) { $i++; continue }
        # CJK 字符范围 (中文/日文/韩文/全角符号): 宽度 2
        if (($cp -ge 0x1100 -and $cp -le 0x115F) -or
            ($cp -ge 0x2E80 -and $cp -le 0x303E) -or
            ($cp -ge 0x3041 -and $cp -le 0x33FF) -or
            ($cp -ge 0x3400 -and $cp -le 0x4DBF) -or
            ($cp -ge 0x4E00 -and $cp -le 0x9FFF) -or
            ($cp -ge 0xA000 -and $cp -le 0xA4CF) -or
            ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or
            ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or
            ($cp -ge 0xFE30 -and $cp -le 0xFE4F) -or
            ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or
            ($cp -ge 0xFFE0 -and $cp -le 0xFFE6)) {
            $width += 2
        }
        # 制表符/框线字符（Box Drawing U+2500-U+257F）：终端始终宽度 1
        elseif ($cp -ge 0x2500 -and $cp -le 0x257F) { $width += 1 }
        # Em dash（U+2014）：East Asian Ambiguous 标点，PowerShell/Windows Terminal 默认按 1 列渲染
        # （UAX#11：上下文不明时 Ambiguous 默认 narrow）。若算 2，含破折号的标题框右框会偏左 1 格
        elseif ($cp -eq 0x2014) { $width += 1 }
        # 其他非零宽字符：ASCII = 宽度 1，非 ASCII（含 emoji ✅🔑 等）= 宽度 2
        else { $width += if ($cp -gt 127) { 2 } else { 1 } }
        $i++
    }
    return $width
}
# === 核心：从 config.toml 提取当前生效的 (model, model_provider, token 指纹) ===
function Get-CurrentFingerprint {
    param([Parameter(Mandatory)] [string]$ConfigPath)
    $content = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
    $m = $null; $p = $null; $tok = $null
    foreach ($line in ($content -split [char]10)) {
        $t = $line.Trim()
        if ($t.StartsWith('#')) { continue }
        if ($t -match '^\s*model\s*=\s*"(.*)"\s*$')                   { $m   = $Matches[1] }
        if ($t -match '^\s*model_provider\s*=\s*"(.*)"\s*$')         { $p   = $Matches[1] }
        if ($t -match '^\s*experimental_bearer_token\s*=\s*"(.*)"\s*$') { $tok = $Matches[1] }
    }
    $fp = $null
    if ($null -ne $tok -and $tok.Length -ge 12) {
        $fp = $tok.Substring(0, 6) + '|' + $tok.Substring($tok.Length - 6)
    } elseif ($null -ne $tok) {
        $fp = $tok
    }
    return @{ Model = $m; Provider = $p; TokenFingerprint = $fp }
}

# === 核心：两阶段判断 — 给定模板列表 + 当前 config，标记每个模板是 active/backup/none ===
# 阶段 1: model + model_provider 匹配 (只比 model/provider 字段，不管密钥)
# 阶段 2: 阶段 1 命中多个时，按 token 指纹 (前6|后6) 进一步精筛
# 返回: 路径 -> 'active' | 'backup' | 'none'
function Resolve-ActiveMarkers {
    param(
        [Parameter(Mandatory)] [string[]]$Files,
        [Parameter(Mandatory)] [string]$ConfigPath
    )
    $current = Get-CurrentFingerprint -ConfigPath $ConfigPath
    $stage1Hits = [System.Collections.Generic.List[string]]::new()
    $markers = @{}
    foreach ($f in $Files) {
        $fp = Get-TemplateFingerprint -Path $f
        if ($fp.Model -eq $current.Model -and $fp.Provider -eq $current.Provider -and $null -ne $fp.Model) {
            $stage1Hits.Add($f)
            $markers[$f] = 'pending'
        } else {
            $markers[$f] = 'none'
        }
    }
    if ($stage1Hits.Count -eq 1) {
        $markers[$stage1Hits[0]] = 'active'
        return $markers
    }
    if ($stage1Hits.Count -ge 2 -and $null -ne $current.TokenFingerprint) {
        $matched = $false
        foreach ($f in $stage1Hits) {
            $fp = Get-TemplateFingerprint -Path $f
            if ($fp.TokenFingerprint -eq $current.TokenFingerprint) {
                $markers[$f] = 'active'
                $matched = $true
            } else {
                $markers[$f] = 'backup'
            }
        }
        # 极端兜底: 阶段 2 没匹配出（不该发生，但脚本不能崩）
        if (-not $matched) {
            foreach ($f in $stage1Hits) { $markers[$f] = 'backup' }
        }
        return $markers
    }
    # 阶段 1 命中 >= 2 但 config 无 token 指纹可比 — 按"无法识别"处理，全部标 backup
    foreach ($f in $stage1Hits) { $markers[$f] = 'backup' }
    return $markers
}

# === 核心：找出当前 config.toml 对应哪个模板（源模型名） ===
# 返回: 模板名（不带 .toml），匹配不到返回 $null
function Resolve-ActiveName {
    param(
        [Parameter(Mandatory)] [string[]]$Files,
        [Parameter(Mandatory)] [string]$ConfigPath
    )
    $markers = Resolve-ActiveMarkers -Files $Files -ConfigPath $ConfigPath
    foreach ($f in $Files) {
        if ($markers[$f] -eq 'active') {
            return [System.IO.Path]::GetFileNameWithoutExtension($f)
        }
    }
    return $null
}

# === 核心：切出时把当前 config 完整保存为 <name> 的最新状态 ===
function Save-ModelState {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$ConfigPath,
        [Parameter(Mandatory)] [string]$StateDir
    )
    if (-not [System.IO.Directory]::Exists($StateDir)) {
        [System.IO.Directory]::CreateDirectory($StateDir) | Out-Null
    }
    [System.IO.File]::Copy($ConfigPath, (Join-Path $StateDir "$Name.toml"), $true)
}

# === 核心：切入时取目标内容 — 优先该模型的最新状态，首次才用模板播种 ===
# 返回: @{ Source = 'state' | 'template'; Content = [string] }
function Get-SwitchContent {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$ModelsDir,
        [Parameter(Mandatory)] [string]$StateDir
    )
    $statePath = Join-Path $StateDir "$Name.toml"
    if ([System.IO.File]::Exists($statePath)) {
        return @{
            Source  = 'state'
            Content = [System.IO.File]::ReadAllText($statePath, [System.Text.UTF8Encoding]::new($false))
        }
    }
    $tplPath = Join-Path $ModelsDir "$Name.toml"
    if (-not [System.IO.File]::Exists($tplPath)) {
        throw "找不到 $Name 的状态文件或模板: $tplPath"
    }
    return @{
        Source  = 'template'
        Content = [System.IO.File]::ReadAllText($tplPath, [System.Text.UTF8Encoding]::new($false))
    }
}

# === 备份 ===
function Backup-Config {
    if (-not [System.IO.Directory]::Exists($BackupDir)) {
        [System.IO.Directory]::CreateDirectory($BackupDir) | Out-Null
    }
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $BackupDir "config.$timestamp.toml"
    [System.IO.File]::Copy($ConfigPath, $backupPath, $true)
    $files = [System.IO.Directory]::GetFiles($BackupDir, 'config.*.toml') |
        Sort-Object { [System.IO.File]::GetLastWriteTime($_) } -Descending
    if ($files.Count -gt 5) {
        $files | Select-Object -Skip 5 | ForEach-Object { [System.IO.File]::Delete($_) }
    }
    return $backupPath
}

# === 子命令 ===

function Invoke-Current {
    $content = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
    $lines = $content -split [char]10
    Write-ColorOutput "📦 当前生效的模型配置:" Cyan
    Write-ColorOutput ("=" * 56) DarkGray
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '') { continue }
        if ($trimmed -match '^\[') { break }  # 到第一个 [section] 就停
        Write-ColorOutput "  $trimmed" White
    }
}

function Invoke-List {
    if (-not [System.IO.Directory]::Exists($ModelsDir)) {
        [System.IO.Directory]::CreateDirectory($ModelsDir) | Out-Null
    }
    $files = [System.IO.Directory]::GetFiles($ModelsDir, '*.toml')

    if ($files.Count -eq 0) {
        Write-ColorOutput "❓ 模板目录为空: $ModelsDir" Yellow
        return
    }

    # 读当前 model + provider
    $currentContent = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
    $currentModel = ''
    $currentProvider = ''
    foreach ($line in ($currentContent -split [char]10)) {
        $t = $line.Trim()
        if ($t -match '^model\s*=\s*(.*)$')               { $currentModel = $Matches[1].Trim().Trim('"') }
        if ($t -match '^model_provider\s*=\s*(.*)$')      { $currentProvider = $Matches[1].Trim().Trim('"') }
        if ($currentModel -ne '' -and $currentProvider -ne '') { break }
    }

    # 解析每个模板的数据 + 标记
    $markers = Resolve-ActiveMarkers -Files $files -ConfigPath $ConfigPath
    $rows = [System.Collections.Generic.List[hashtable]]::new()
    for ($i = 0; $i -lt $files.Count; $i++) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($files[$i])
        $tplContent = [System.IO.File]::ReadAllText($files[$i], [System.Text.UTF8Encoding]::new($false))
        $tplModel = ''; $tplProvider = ''
        foreach ($line in ($tplContent -split [char]10)) {
            $t = $line.Trim()
            if ($t -match '^model\s*=\s*(.*)$')            { $tplModel = $Matches[1].Trim().Trim('"') }
            if ($t -match '^model_provider\s*=\s*(.*)$')    { $tplProvider = $Matches[1].Trim().Trim('"') }
        }
        $marker = switch ($markers[$files[$i]]) {
            'active' { '✅' }
            'backup' { '🔑' }
            default  { ''  }
        }
        $rows.Add(@{
            Num     = "$(($i + 1))"
            Status  = $marker
            Name    = $name
            Model   = $tplModel
            Provider = $tplProvider
        })
    }

    # ── 表格渲染 (CJK/emoji 安全, 自适应列宽) ──
    $headers = @('编号', '状态', 'NAME', 'MODEL', 'PROVIDER')
    $keys    = @('Num',  'Status', 'Name', 'Model', 'Provider')

    # 最小列宽 (给表头一点呼吸空间)
    $minWidths = @(6, 7, 20, 20, 24)
    $colCount = $headers.Count
    $widths = @()
    # 预计算每列所有值的显示宽度，避免在算式里反复调用函数
    $colWidths = for ($c = 0; $c -lt $colCount; $c++) {
        $list = [System.Collections.Generic.List[int]]::new()
        $list.Add((Get-DisplayWidth $headers[$c]))
        foreach ($r in $rows) {
            $list.Add((Get-DisplayWidth ([string]$r[$keys[$c]])))
        }
        ,$list.ToArray()
    }
    for ($c = 0; $c -lt $colCount; $c++) {
        $w = $minWidths[$c]
        foreach ($vw in $colWidths[$c]) { if ($vw -gt $w) { $w = $vw } }
        $widths += $w
    }

    # 水平线: ┌─┬─┐ ├─┼─┤ └─┴─┘
    function _HLine($L, $J, $R) {
        $line = $L
        for ($i = 0; $i -lt $colCount; $i++) {
            if ($i -gt 0) { $line += $J }
            $line += ('─' * $widths[$i])
        }
        return $line + $R
    }
    # 数据行: 边框灰, 内容按 $Color 染色
    function Write-DataRow($Values, $Color) {
        Write-Host '│' -NoNewline -ForegroundColor DarkGray
        for ($i = 0; $i -lt $colCount; $i++) {
            $val = [string]$Values[$i]
            $pad = $widths[$i] - (Get-DisplayWidth $val)
            if ($pad -lt 0) { $pad = 0 }
            if ($i -eq 0 -or $i -eq 1) {
                $leftPad  = [int][Math]::Floor($pad / 2)
                if ($i -eq 1) { $leftPad += 1 }
                $rightPad = $pad - $leftPad
                if ($rightPad -lt 0) { $rightPad = 0 }
                Write-Host (' ' * $leftPad) -NoNewline -ForegroundColor DarkGray
                Write-Host $val -NoNewline -ForegroundColor $Color
                Write-Host (' ' * $rightPad + '│') -NoNewline -ForegroundColor DarkGray
            } else {
                Write-Host $val -NoNewline -ForegroundColor $Color
                Write-Host (' ' * $pad + '│') -NoNewline -ForegroundColor DarkGray
            }
        }
        Write-Host ''
    }
    # 表头: 边框灰, 内容青
    function Write-HeadRow($Values, $Color) {
        Write-Host '│' -NoNewline -ForegroundColor DarkGray
        for ($i = 0; $i -lt $colCount; $i++) {
            $val = [string]$Values[$i]
            $pad = $widths[$i] - (Get-DisplayWidth $val)
            if ($pad -lt 0) { $pad = 0 }
            if ($i -eq 0 -or $i -eq 1) {
                $leftPad  = [int][Math]::Floor($pad / 2)
                if ($i -eq 1) { $leftPad += 1 }
                $rightPad = $pad - $leftPad
                if ($rightPad -lt 0) { $rightPad = 0 }
                Write-Host (' ' * $leftPad) -NoNewline -ForegroundColor DarkGray
                Write-Host $val -NoNewline -ForegroundColor $Color
                Write-Host (' ' * $rightPad + '│') -NoNewline -ForegroundColor DarkGray
            } else {
                Write-Host $val -NoNewline -ForegroundColor $Color
                Write-Host (' ' * $pad + '│') -NoNewline -ForegroundColor DarkGray
            }
        }
        Write-Host ''
    }

    Show-TitleBox '🔍 可用模型模板' Cyan
    # 水平线: 整行灰色
    Write-Host (_HLine '╭' '┬' '╮') -ForegroundColor DarkGray
    # 表头: 边框灰, 内容青
    Write-HeadRow $headers Cyan
    Write-Host (_HLine '├' '┼' '┤') -ForegroundColor DarkGray
    # 数据行: 边框灰, 内容按状态着色 (只有 status 内容变色, 编号/name/model/provider 都跟着状态色走)
    foreach ($r in $rows) {
        $vals = @(); foreach ($k in $keys) { $vals += $r[$k] }
        $color = if ($r.Status -eq '✅') { 'Green' } elseif ($r.Status -eq '🔑') { 'Yellow' } else { 'White' }
        Write-DataRow $vals $color
    }
    Write-Host (_HLine '╰' '┴' '╯') -ForegroundColor DarkGray
    Write-ColorOutput '✅ 激活中 🔑 备用密钥，同 model 不会被自动激活' DarkGray
}

# === 核心：切换 = 保存当前模型状态 + 恢复目标模型状态（首次用模板播种） ===
function Invoke-Use {
    param([Parameter(Mandatory)] [string]$Name)

    # 1. 切出：找出当前 config 对应的源模型，把最新状态完整存下
    $files = [System.IO.Directory]::GetFiles($ModelsDir, '*.toml')
    $sourceName = Resolve-ActiveName -Files $files -ConfigPath $ConfigPath
    if ($null -ne $sourceName) {
        Save-ModelState -Name $sourceName -ConfigPath $ConfigPath -StateDir $StateDir
        Write-ColorOutput "💾 已保存 $sourceName 的最新状态" DarkGray
    } else {
        Write-ColorOutput "⚠️ 当前 config 匹配不到任何模板，跳过状态保存（本次配置仍会备份）" Yellow
    }

    # 2. 目标已激活：无需切换
    if ($sourceName -eq $Name) {
        Write-ColorOutput "✅ $Name 已是最新状态，无需切换" Green
        return
    }

    # 3. 目标内容：优先恢复它的状态，首次才用模板播种
    $switch = Get-SwitchContent -Name $Name -ModelsDir $ModelsDir -StateDir $StateDir

    # 4. 备份
    $backupPath = Backup-Config
    Write-ColorOutput "📦 已备份 → $backupPath" DarkGray

    # 5. 原子写入：整个 config.toml 被目标内容覆盖
    $newContent = ($switch.Content.TrimEnd()) + "`n"
    $tmp = "$ConfigPath.tmp"
    try {
        [System.IO.File]::WriteAllText($tmp, $newContent, [System.Text.UTF8Encoding]::new($false))
        $verify = [System.IO.File]::ReadAllText($tmp, [System.Text.UTF8Encoding]::new($false))
        if ([string]::IsNullOrWhiteSpace($verify)) {
            throw "原子写校验失败：临时文件为空"
        }
        [System.IO.File]::Move($tmp, $ConfigPath, $true)
    } catch {
        if ([System.IO.File]::Exists($tmp)) { [System.IO.File]::Delete($tmp) }
        throw
    }

    $mode = if ($switch.Source -eq 'state') { '状态恢复' } else { '模板初始化' }
    $lineCount = ($newContent -split [char]10).Count
    Write-ColorOutput "✅ 已切换到: $Name（$mode，$lineCount 行）" Green
    foreach ($line in ($newContent -split [char]10)) {
        $t = $line.Trim()
        if ($t -eq '') { continue }
        if ($t -match '(token|key|password|secret)\s*=\s*"(.+)"') {
            $val = $Matches[2]
            if ($val.Length -gt 14) {
                $masked = $val.Substring(0, 6) + '****' + $val.Substring($val.Length - 6)
                $t = $t -replace [regex]::Escape($val), $masked
            }
        }
        Write-ColorOutput "   $t" White
    }
    Write-ColorOutput "⚠️  请重启 Codex App 生效" Yellow
}

# === 交互式菜单 ===
function Invoke-Menu {
    while ($true) {
        # 每次重绘菜单前清屏，避免终端内容无限累积
        Clear-Host
        Show-TitleBox '💻 codex-model v1 — 模型切换' Cyan
        Write-ColorOutput "   选数字切模型，q 退出" DarkGray
        Write-ColorOutput "" White

        # 读当前 model + provider（用于标 ✅）
        $currentContent = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
        $currentModel = ''
        $currentProvider = ''
        foreach ($line in ($currentContent -split [char]10)) {
            $t = $line.Trim()
            if ($t -match '^model\s*=\s*(.*)$')              { $currentModel = $Matches[1].Trim().Trim('"') }
            if ($t -match '^model_provider\s*=\s*(.*)$')     { $currentProvider = $Matches[1].Trim().Trim('"') }
            if ($currentModel -ne '' -and $currentProvider -ne '') { break }
        }

        $files = [System.IO.Directory]::GetFiles($ModelsDir, '*.toml')

        if ($files.Count -eq 0) {
            Write-ColorOutput "  ❓ 模板目录为空: $ModelsDir" Yellow
            Write-ColorOutput "     手动新建 .toml 模板文件后回车刷新" DarkGray
        } else {
            $markers = Resolve-ActiveMarkers -Files $files -ConfigPath $ConfigPath
            $rows = [System.Collections.Generic.List[hashtable]]::new()
            for ($i = 0; $i -lt $files.Count; $i++) {
                $name = [System.IO.Path]::GetFileNameWithoutExtension($files[$i])
                $tplContent = [System.IO.File]::ReadAllText($files[$i], [System.Text.UTF8Encoding]::new($false))
                $tplModel = ''; $tplProvider = ''
                foreach ($line in ($tplContent -split [char]10)) {
                    $t = $line.Trim()
                    if ($t -match '^model\s*=\s*(.*)$')            { $tplModel = $Matches[1].Trim().Trim('"') }
                    if ($t -match '^model_provider\s*=\s*(.*)$')    { $tplProvider = $Matches[1].Trim().Trim('"') }
                }
                $marker = switch ($markers[$files[$i]]) {
                    'active' { '✅' }
                    'backup' { '🔑' }
                    default  { ''  }
                }
                $rows.Add(@{
                    Num      = "$(($i + 1))"
                    Status   = $marker
                    Name     = $name
                    Model    = $tplModel
                    Provider = $tplProvider
                })
            }

            # 自适应列宽 (CJK/emoji 安全)
            $headers = @('编号', '状态', 'NAME', 'MODEL', 'PROVIDER')
            $keys    = @('Num',  'Status', 'Name', 'Model', 'Provider')
            $minWidths = @(6, 7, 20, 20, 24)
            $colCount = $headers.Count
            $widths = @()
            # 预计算每列所有值的显示宽度，避免在算式里反复调用函数
            $colWidths = for ($c = 0; $c -lt $colCount; $c++) {
                $list = [System.Collections.Generic.List[int]]::new()
                $list.Add((Get-DisplayWidth $headers[$c]))
                foreach ($r in $rows) {
                    $list.Add((Get-DisplayWidth ([string]$r[$keys[$c]])))
                }
                ,$list.ToArray()
            }
            for ($c = 0; $c -lt $colCount; $c++) {
                $w = $minWidths[$c]
                foreach ($vw in $colWidths[$c]) { if ($vw -gt $w) { $w = $vw } }
                $widths += $w
            }
            function _HLine($L, $J, $R) {
                $line = $L
                for ($i = 0; $i -lt $colCount; $i++) {
                    if ($i -gt 0) { $line += $J }
                    $line += ('─' * $widths[$i])
                }
                return $line + $R
            }
            function Write-DataRow($Values, $Color) {
                Write-Host '│' -NoNewline -ForegroundColor DarkGray
                for ($i = 0; $i -lt $colCount; $i++) {
                    $val = [string]$Values[$i]
                    $pad = $widths[$i] - (Get-DisplayWidth $val)
                    if ($pad -lt 0) { $pad = 0 }
                    if ($i -eq 0 -or $i -eq 1) {
                        $leftPad  = [int][Math]::Floor($pad / 2)
                        if ($i -eq 1) { $leftPad += 1 }
                        $rightPad = $pad - $leftPad
                        if ($rightPad -lt 0) { $rightPad = 0 }
                        Write-Host (' ' * $leftPad) -NoNewline -ForegroundColor DarkGray
                        Write-Host $val -NoNewline -ForegroundColor $Color
                        Write-Host (' ' * $rightPad + '│') -NoNewline -ForegroundColor DarkGray
                    } else {
                        Write-Host $val -NoNewline -ForegroundColor $Color
                        Write-Host (' ' * $pad + '│') -NoNewline -ForegroundColor DarkGray
                    }
                }
                Write-Host ''
            }
            function Write-HeadRow($Values, $Color) {
                Write-Host '│' -NoNewline -ForegroundColor DarkGray
                for ($i = 0; $i -lt $colCount; $i++) {
                    $val = [string]$Values[$i]
                    $pad = $widths[$i] - (Get-DisplayWidth $val)
                    if ($pad -lt 0) { $pad = 0 }
                    if ($i -eq 0 -or $i -eq 1) {
                        $leftPad  = [int][Math]::Floor($pad / 2)
                        if ($i -eq 1) { $leftPad += 1 }
                        $rightPad = $pad - $leftPad
                        if ($rightPad -lt 0) { $rightPad = 0 }
                        Write-Host (' ' * $leftPad) -NoNewline -ForegroundColor DarkGray
                        Write-Host $val -NoNewline -ForegroundColor $Color
                        Write-Host (' ' * $rightPad + '│') -NoNewline -ForegroundColor DarkGray
                    } else {
                        Write-Host $val -NoNewline -ForegroundColor $Color
                        Write-Host (' ' * $pad + '│') -NoNewline -ForegroundColor DarkGray
                    }
                }
                Write-Host ''
            }
            Write-Host (_HLine '╭' '┬' '╮') -ForegroundColor DarkGray
            Write-HeadRow $headers Cyan
            Write-Host (_HLine '├' '┼' '┤') -ForegroundColor DarkGray
            foreach ($r in $rows) {
                $vals = @(); foreach ($k in $keys) { $vals += $r[$k] }
                $color = if ($r.Status -eq '✅') { 'Green' } elseif ($r.Status -eq '🔑') { 'Yellow' } else { 'White' }
                Write-DataRow $vals $color
            }
            Write-Host (_HLine '╰' '┴' '╯') -ForegroundColor DarkGray
            Write-ColorOutput '✅ 激活中 🔑 备用密钥，同 model 不会被自动激活' DarkGray
        }

        Write-Host ''

        $prompt = if ($files.Count -gt 0) { "选择 (1-$($files.Count))，📂 o 打开目录，回车刷新，q 退出" } else { "📂 o 打开目录，回车刷新，q 退出" }
        $choice = Read-Host $prompt
        if ($choice -eq 'q' -or $choice -eq 'Q') { return }
        if ([string]::IsNullOrWhiteSpace($choice)) { continue }

        # 字母 o：打开模板目录
        if ($choice -eq 'o' -or $choice -eq 'O') {
            if (-not [System.IO.Directory]::Exists($ModelsDir)) {
                Write-ColorOutput "❌ 目录不存在: $ModelsDir" Yellow
            } else {
                Write-ColorOutput "📂 已打开: $ModelsDir" DarkGray
                Start-Process explorer.exe $ModelsDir
            }
            Write-ColorOutput "" White
            continue
        }

        $idx = 0
        if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $files.Count) {
            Write-ColorOutput "❌ 无效: $choice" Red
            Read-Host "`n按回车返回菜单"
            continue
        }

        $name = [System.IO.Path]::GetFileNameWithoutExtension($files[$idx - 1])
        try {
            Invoke-Use -Name $name
        } catch {
            Write-ColorOutput "❌ 切换失败: $_" Red
        }
        # 停留展示切换结果，回车后清屏重绘菜单
        Read-Host "`n按回车返回菜单"
    }
}

# === 主分发 ===
try {
    switch ($Command) {
        'help' { Write-ColorOutput "用法: codex-model [use <name>] | [list] | [current] | [help]" White; Write-ColorOutput "      菜单内: o 打开模板目录" DarkGray }
        'menu' { Invoke-Menu }
        'list' { Invoke-List }
        'current' { Invoke-Current }
        'use' {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                throw "use 需要指定模型名（例: codex-model use deepseek）"
            }
            Invoke-Use -Name $Name
        }
        default { Invoke-Menu }
    }
} catch {
    Write-Host "❌ 错误: $_" -ForegroundColor Red
} finally {
    Read-Host "`n按回车键退出"
}
