# codex-switch 开发规范

## 双分支架构（强制）

| 分支 | 位置 | 实现 | 运行时 |
|:-----|:-----|:-----|:-------|
| **Windows** | `src/` + `bin/` | PowerShell 7 模块（psm1 + psd1） | 必须用 pwsh 7+ |
| **Linux/WSL2** | `linux/` | 纯 bash（自包含单脚本） | **禁止**引入 pwsh/Windows 依赖 |

两条铁律：
- **WSL2 分支零 Windows 依赖**：不用 pwsh、不用 `.cmd`、不用 `explorer.exe`/Windows API，只用原生工具（grep/sed/awk/curl/unzip）
- **两分支零共享代码**：各自独立实现，改动互不牵连；功能行为保持一致（命令集、机制、输出风格）

## 目录结构

```
src/                  Windows 分支核心（codex-switch.psm1 / .psd1 / .ps1 入口）
bin/codex-switch.cmd  Windows 启动器
linux/                Linux 分支（codex-switch 主脚本 / install.sh / uninstall.sh）
install.ps1 / uninstall.ps1   Windows 安装器/卸载器
tests/                Windows 分支单元测试
docs/                 架构文档
legacy/               v1 冻结代码，只读不维护
```

## 版本管理（强制同步）

发版时四处必须同步，缺一不可：

1. `src/codex-switch.psm1` → `$script:ScriptVersion`
2. `src/codex-switch.psd1` → `ModuleVersion`
3. `linux/codex-switch` → `VERSION="..."`
4. git tag → `vX.Y.Z`

发版流程：改版本 → 跑全量测试 → commit → `git tag vX.Y.Z && git push origin vX.Y.Z`（release workflow 自动构建双 zip + 创建 Release）。

## 开发规范（Windows 分支）

- 纯函数与命令分离：可测试的纯函数导出到 manifest `FunctionsToExport`，UI/IO 命令留在模块内
- 路径必须跨平台：测试/代码里用正斜杠（`../src/...`）、`[System.IO.Path]::GetTempPath()`，**禁止** `$env:TEMP`（Linux 为 null）
- 文件读写统一 UTF-8 无 BOM：`[System.Text.UTF8Encoding]::new($false)`
- 终端输出中文时先设 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
- 密钥显示一律掩码（前 6 + `****` + 后 6），永不打印完整 token

## 开发规范（Linux 分支）

- 严格 `set -euo pipefail`；函数命名 `cmd_xxx` / `get_xxx` / 小写蛇形
- 复杂正则放变量再用于 `[[ =~ ]]`（直接内联复杂模式会导致 bash 解析错误，踩过坑）
- 路径引用一律双引号包裹，防止空格/通配
- 错误处理：`fail()` 统一退出；临时文件用 `mktemp -d` + `trap` 清理

## 测试规范

### Windows 分支（tests/test_codex-switch.ps1）

- 运行：`pwsh ./tests/test_codex-switch.ps1`，退出码非 0 = 失败
- 断言：`Assert-True` 输出 ✅/❌，结尾输出 通过/失败 计数
- **禁止触碰真实 `~/.codex`**：全部走临时目录，用完清理
- 测试数据用 `test-token-` 前缀的假密钥，**禁止**形似真实密钥（防扫描误报）
- 新增功能必须补对应断言；纯函数都必须可测（显式传路径参数，不依赖模块全局变量）

### Linux 分支

- 语法：`bash -n linux/codex-switch linux/install.sh linux/uninstall.sh`
- 冒烟：隔离 `CODEX_HOME`（或 HOME）跑 `list/current/use/doctor` 全链路
- 本地端到端参考 `wsl-smoke` 模式：模板播种 → 切换 → 模拟增长 → 切回 → 验证状态无污染

### CI（push 自动跑）

- `ci.yml`：Windows+Ubuntu 跑 pwsh 测试（**两平台都必须过**）+ Ubuntu bash 语法/冒烟
- `release.yml`：tag 触发，测试通过后构建 `codex-switch-windows.zip`（src+bin）和 `codex-switch-linux.zip`（linux/codex-switch）双包

## 安全规范

- 仓库**永不**出现：config.toml、模型模板、状态文件、真实 API Key/token
- 用户数据（`~/.codex/`）与程序代码严格分离，安装/卸载/更新不触碰
- 安装器从 GitHub Release 资产下载运行时（非 main 分支文件）
- 漏洞报告走 SECURITY.md 流程，公开 issue 里不贴密钥

## 提交规范

- 消息格式：`type: 简述（中文）`，type 用 `feat` / `fix` / `chore` / `docs` / `refactor` / `test`
- 提交前自查：`git diff` 无密钥、无本地数据文件（config.toml / *.zip / *.old / *.tmp）
- CI 红 = 不推 tag；release 只在 CI 全绿后打 tag
