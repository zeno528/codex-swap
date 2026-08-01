# codex-switch

切换 Codex 模型配置的命令行工具。**模板播种 + 状态恢复**：每个模型独立维护自己最新的完整配置，来回切换不丢使用记录、互不污染。

支持两个独立分支，互不依赖：

| 分支 | 实现 | 运行环境 |
|:-----|:-----|:---------|
| **Windows** | PowerShell 7 模块（psm1） | Windows + pwsh |
| **Linux / WSL2** | 纯 bash（`linux/` 目录） | WSL2，零 pwsh/Windows 依赖 |

## 安装（Windows）

一行命令（PowerShell 7）：

```powershell
irm https://raw.githubusercontent.com/zeno528/codex-switch/main/windows/install.ps1 | iex
```

或下载后指定参数：

```powershell
.\windows\install.ps1            # 安装最新版
.\windows\install.ps1 -Version v0.2.0   # 指定版本
.\windows\install.ps1 -Uninstall # 卸载（不动数据）
```

安装内容：程序装到 `~/.local/bin/codex-switch/`，启动器 `~/.local/bin/codex-switch.cmd`（该目录不在 PATH 会自动添加，**新终端生效**）。数据目录 `~/.codex` 全程不受影响。

## 安装（Linux / WSL2）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-switch/main/linux/install.sh)
```

```bash
bash install.sh v0.2.0        # 指定版本
bash install.sh --uninstall   # 卸载（不动数据）
```

安装内容：`~/.local/bin/codex-switch`（单一可执行脚本），`~/.local/bin` 不在 PATH 会自动追加到 `~/.bashrc`。依赖仅 curl/unzip，**不需要 pwsh**。

## 使用（两分支命令一致）

```powershell
codex-switch                    # 交互式菜单（选数字切模型，o 打开模板目录）
codex-switch use deepseek       # 切换模型（恢复该模型最新状态 / 首次模板播种）
codex-switch list               # 列出模板及激活状态
codex-switch current            # 查看当前生效配置
codex-switch update             # 自更新（比对 GitHub 最新 Release）
codex-switch doctor             # 体检（目录/模板/状态/依赖检查）
```

## 原理

- **模板** `~/.codex/models/<name>.toml`：首次使用的种子，可随时编辑
- **状态** `~/.codex/model-states/<name>.toml`：该模型最近一次使用时的完整 config，随使用自动演进
- **切换**：切出时完整保存当前 config 为源模型状态；切入时优先恢复目标模型状态，无状态才用模板播种
- **备份**：每次切换前备份到 `~/.codex/backups_model/`（保留 5 份）
- 详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 开发

```powershell
pwsh .\windows\tests\test_codex-switch.ps1   # Windows 分支单元测试（26 项）
bash linux/codex-switch list         # Linux 分支直接运行
bash -n linux/codex-switch           # Linux 分支语法检查
```

## 目录结构

```
├── windows/              # Windows 分支：PowerShell 7，独立实现
│   ├── src/              #   核心模块（psm1 + psd1 + 入口脚本）
│   ├── bin/              #   启动器（.cmd shim）
│   ├── install.ps1       #   安装器（irm | iex）
│   ├── uninstall.ps1     #   卸载器
│   └── tests/            #   PowerShell 单元测试
├── linux/                # Linux/WSL2 分支：纯 bash 独立实现
│   ├── codex-switch      #   主脚本（自包含）
│   ├── install.sh        #   安装器
│   └── uninstall.sh      #   卸载器
├── .github/workflows/    # CI + Release 自动打包（双 zip）
└── legacy/               # v1 本地快捷版（codex-model，保留可用）
```

## License

MIT
