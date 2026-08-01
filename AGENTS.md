# codex-switch 开发规范

## 双分支架构（强制）

| 分支 | 位置 | 实现 | 运行时 |
|:-----|:-----|:-----|:-------|
| **Windows** | `windows/` | PowerShell 7 模块（psm1 + psd1） | 必须用 pwsh 7+ |
| **Linux/WSL2** | `linux/` | 纯 bash（自包含单脚本） | **禁止**引入 pwsh/Windows 依赖 |

两条铁律：
- **WSL2 分支零 Windows 依赖**：不用 pwsh、不用 `.cmd`、不用 `explorer.exe`/Windows API，只用原生工具（grep/sed/awk/curl/unzip）
- **两分支零共享代码**：各自独立实现，改动互不牵连；功能行为保持一致（命令集、机制、输出风格）

## 目录结构

```
windows/              Windows 分支（src/、bin/、安装器、卸载器、测试）
linux/                Linux 分支（codex-switch 主脚本 / install.sh / uninstall.sh）
docs/                 架构文档
scripts/              构建与校验脚本（build.sh / verify-release.sh / test-linux.sh）
.githooks/            pre-commit（自动递增 VERSION）
```

## 版本管理（唯一版本源 + 构建注入）

版本唯一来源：根目录 `VERSION` 文件。三处源码一律为 `@VERSION@` 占位符，由 `scripts/build.sh` 在构建/发布时注入：

1. `linux/codex-switch` → `VERSION="@VERSION@"`
2. `windows/src/codex-switch.psm1` → `$script:ScriptVersion = '@VERSION@'`
3. `windows/src/codex-switch.psd1` → `ModuleVersion = '@VERSION@'`

- 改版本：只改 `VERSION` 一个文件；本地验证用 `scripts/build.sh --inject`
- `pre-commit` hook（`.githooks/pre-commit`，`core.hooksPath` 指向 `.githooks`）：改动发布物相关文件（`linux/*`、`windows/src/*`、`windows/bin/*`、安装器、`scripts/build.sh`）时自动递增 `VERSION` 的 patch（99 进位，0.0.99 → 0.1.0）；纯文档/CI/元数据改动不递增；检测到工作区 `VERSION` ≠ HEAD 时跳过（发版手动升 minor/major 不重复递增）
- 构建/发版：`scripts/build.sh --package` 注入并产出双 zip；`scripts/verify-release.sh [tag] [zip...]` 校验 VERSION 格式、源码占位符状态、包内注入版本
- 发版流程：递增 VERSION → 跑全量测试 → commit 并推送 main；release workflow 自动读取 VERSION、创建同名 vX.Y.Z tag、构建双 zip 并创建 Release（notes 为自上次 tag 以来的 commit 列表）
- git tag 由 release workflow 创建；源码永远不提交注入产物
- **本地同步禁令**：不得为把源码同步到本机安装目录而改动根目录 `VERSION`，也不得手动把 `@VERSION@` 替换为任意版本号。需要本地同步时，只能使用 `scripts/build.sh --package` 生成且版本已注入的发行资产；缺少构建条件时停止并报告，不得伪造版本。

## 开发规范（Windows 分支）

- 纯函数与命令分离：可测试的纯函数导出到 manifest `FunctionsToExport`，UI/IO 命令留在模块内
- 路径使用 Windows PowerShell 约定；临时目录使用 `[System.IO.Path]::GetTempPath()`，**禁止** `$env:TEMP`
- 文件读写统一 UTF-8 无 BOM：`[System.Text.UTF8Encoding]::new($false)`
- 终端输出中文时先设 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
- 密钥显示一律掩码（前 6 + `****` + 后 6），永不打印完整 token

## 开发规范（Linux 分支）

- 严格 `set -euo pipefail`；函数命名 `cmd_xxx` / `get_xxx` / 小写蛇形
- 复杂正则放变量再用于 `[[ =~ ]]`（直接内联复杂模式会导致 bash 解析错误，踩过坑）
- 路径引用一律双引号包裹，防止空格/通配
- 错误处理：`fail()` 统一退出；临时文件用 `mktemp -d` + `trap` 清理

## 测试规范

### Windows 分支（windows/tests/test_codex-switch.ps1）

- 运行：`pwsh ./windows/tests/test_codex-switch.ps1`，退出码非 0 = 失败
- 断言：`Assert-True` 输出 ✅/❌，结尾输出 通过/失败 计数
- **禁止触碰真实 `~/.codex`**：全部走临时目录，用完清理
- 测试数据用 `test-token-` 前缀的假密钥，**禁止**形似真实密钥（防扫描误报）
- 新增功能必须补对应断言；纯函数都必须可测（显式传路径参数，不依赖模块全局变量）

### Linux 分支

- 语法：`bash -n linux/codex-switch linux/install.sh linux/uninstall.sh`
- 冒烟：隔离 `CODEX_HOME`（或 HOME）跑 `list/current/use/doctor` 全链路
- 本地端到端参考 `wsl-smoke` 模式：模板播种 → 切换 → 模拟增长 → 切回 → 验证状态无污染

### CI（push 自动跑）

- `ci.yml`：Windows 跑 pwsh 测试 + Ubuntu 跑 bash 语法/冒烟
- `release.yml`：main 上 VERSION 变更触发，测试通过后构建 `codex-switch-windows.zip`（windows/src+windows/bin）和 `codex-switch-linux.zip`（linux/codex-switch）双包并创建 Release
- 修改 `.github/workflows/*.yml` 后必须运行 `actionlint`，并修复其报告的问题

## 安全规范

- 仓库**永不**出现：config.toml、模型模板、状态文件、真实 API Key/token
- 用户数据（`~/.codex/`）与程序代码严格分离，安装/卸载/更新不触碰
- 安装器从 GitHub Release 资产下载运行时（非 main 分支文件）
- 漏洞报告走 SECURITY.md 流程，公开 issue 里不贴密钥

## 提交规范

- 消息格式：`type: 简述（中文）`，type 用 `feat` / `fix` / `chore` / `docs` / `refactor` / `test`
- 提交前自查：`git diff` 无密钥、无本地数据文件（config.toml / *.zip / *.old / *.tmp）
- CI 红 = 不发布；release workflow 在 CI 全绿后自动创建 tag
