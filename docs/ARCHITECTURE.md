# codex-switch 架构

## 核心矛盾

Codex 的 `config.toml` 是活的状态：使用中 App 会持续写入信任项目、禁用 skill、插件、主题等，文件不断增长。静态模板无法代表"最新状态"：

- 纯模板覆盖 → 切回旧模型丢失全部积累（失忆）
- 配置合并 → 模型间互相污染、越滚越大

## 方案：模板播种 + 状态恢复

每个模型两份配置（config 与 auth 各一套，机制对称）：

| 配置 | 路径 | 角色 |
|:-----|:-----|:-----|
| 模板 | `~/.codex/models/<name>.toml` | 首次使用种子，静态，可编辑 |
| 状态 | `~/.codex/model-states/<name>.toml` | 最近一次使用的完整 config，动态演进 |
| auth 模板 | `~/.codex/models/<name>.auth.json` | 模型专属登录凭据种子（可选） |
| auth 状态 | `~/.codex/model-states/<name>.auth.json` | 最近一次切出时的 auth.json 快照 |

## 切换链路

```
切出 deepseek                    切入 GPT
config.toml ───────────────► model-states/deepseek.toml   （1:1 拷贝）
config.toml ◄─────────────── model-states/gpt.toml        （存在则恢复）
                            （不存在 → models/gpt.toml 模板播种）
auth.json ────────────────► model-states/<src>.auth.json  （仅源模型托管 auth 时）
auth.json ◄──────────────── model-states/<target>.auth.json（优先）
                            models/<target>.auth.json（模板兜底，未托管则不碰）
```

`use <name>` 五步：

1. **识别源**：`Resolve-ActiveMarkers` 两阶段 — model+provider 匹配 → 多命中时按 token 指纹（前6|后6）精筛
2. **存源状态**：`Save-ModelState` 原样拷贝；源模型托管 auth 时 `Save-ModelAuth` 同步快照（auth.json 不存在则删除旧快照记录空态）
3. **取目标**：`Get-SwitchContent` 状态优先、模板兜底；auth 同理由 `Get-SwitchAuth` 解析
4. **备份**：`Backup-Config` → `backups_model/`（config + auth 同时间戳，保留 5 份以 config 为准，过期时配套删除）
5. **原子写**：config 与 auth.json 均 tmp → 校验非空 → Move 覆盖，失败删 tmp 回滚；auth 内容永不打印

## 模块结构

```
windows/src/
├── codex-switch.psd1        # manifest（版本号唯一来源）
├── codex-switch.psm1        # 全部逻辑
│   ├── 纯函数（可测试）: Get-TemplateFingerprint / Get-CurrentFingerprint /
│   │   Resolve-ActiveMarkers / Resolve-ActiveName / Save-ModelState /
│   │   Get-SwitchContent / Save-ModelAuth / Get-SwitchAuth /
│   │   Compare-Version / Get-DisplayWidth / Get-CodexHome
│   └── 命令: Invoke-CodexSwitch（分发）/ Invoke-Menu / Invoke-List /
│       Invoke-Current / Invoke-Use / Invoke-Update / Invoke-Doctor
└── codex-switch.ps1         # 入口：Import-Module + 分发
windows/bin/codex-switch.cmd # 启动器（调 pwsh -File 入口）
```

## 分发

- **Windows**：`windows/install.ps1`（irm|iex）→ GitHub API 取 latest release → 下载 `codex-switch-windows.zip` → 解压到 `~/.local/bin/codex-switch/` → 写 `.cmd` shim → 确保 PATH
- **Linux/WSL2**：`linux/install.sh`（bash <(curl ...)）→ 下载 `codex-switch-linux.zip` → 安装 `~/.local/bin/codex-switch`（单一脚本）→ 确保 PATH。**纯 bash 独立实现，零 pwsh/Windows 依赖**
- **自更新**：Windows `Invoke-Update` / Linux `cmd_update` 只以根目录 `VERSION` 与本机版本判断是否更新；Release 仅提供下载资产。下载后必须校验资产内部版本等于 `VERSION`，不匹配即拒绝替换。
- **CI**：ci.yml（Windows+Linux 跑测试 + Linux bash 冒烟）/ release.yml（main 上 VERSION 变更时自动构建双 zip 上传）

## 双分支架构

```
Windows 分支                 Linux/WSL2 分支（独立实现，零共享代码）
├── windows/src/*.psm1       ├── linux/codex-switch   （纯 bash 主脚本）
├── windows/bin/*.cmd        ├── linux/install.sh
├── windows/install.ps1      └── linux/uninstall.sh
├── windows/uninstall.ps1
├── windows/tests/
└── 数据机制完全一致: models/ + model-states/ + backups_model/
```

## 版本管理

- 唯一版本源：根目录 `VERSION`；三处源码为 `@VERSION@` 占位符，由 `scripts/build.sh` 构建时注入
- 发版：递增 `VERSION`（pre-commit hook 自动）→ 全量测试 → commit 并推送 main；release workflow 读取 VERSION 后创建同名 tag 和 Release
- 两分支的 `update` 均以根目录 `VERSION` 为唯一版本源；不比较 Release tag。下载的资产内部版本必须与 `VERSION` 一致，才允许升级。Windows 用 `Compare-Version` 做 semver 比对（支持 v 前缀、缺位补零）。

## 数据安全

- 模板/状态/备份都在 `~/.codex/`，与程序目录（`~/.local/bin/codex-switch/`）分离
- 卸载只删程序本体，数据永不触碰
- 密钥永不进仓库：token 只在用户本机模板/状态里
