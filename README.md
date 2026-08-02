<div align="center">

# ⚡ codex-swap

**切换 Codex 模型配置的命令行工具**

模板播种 + 状态恢复：每个模型独立维护自己最新的完整配置，来回切换不丢使用记录、互不污染。

[![License](https://img.shields.io/github/license/zeno528/codex-swap?label=License)](LICENSE)
![平台](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%2FWSL2-3FAEC2)
![运行时](https://img.shields.io/badge/PowerShell%207%20%C2%B7%20Bash-3FAEC2)

</div>

---

## ⚡ 安装

### 🪟 Windows · PowerShell 7

```powershell
irm https://raw.githubusercontent.com/zeno528/codex-swap/main/windows/install.ps1 | iex
```

### 🐧 Linux / WSL2

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-swap/main/linux/install.sh)
```

### 🗑️ 卸载

卸载只删除程序本体与快捷命令，数据目录 `~/.codex`（models/model-states/auth）全程不受影响。

Linux / WSL2：

```bash
# 安装器自带卸载（无确认，直接删）
bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-swap/main/linux/install.sh) --uninstall

# 独立卸载器（带 [y/N] 确认）
bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-swap/main/linux/uninstall.sh)
```

Windows · PowerShell 7：

```powershell
# 安装器自带卸载（无确认，直接删）
Invoke-RestMethod https://raw.githubusercontent.com/zeno528/codex-swap/main/windows/install.ps1 -OutFile "$env:TEMP\codex-swap-install.ps1"; & "$env:TEMP\codex-swap-install.ps1" -Uninstall

# 独立卸载器（带 [y/N] 确认，加 -Yes 跳过）
Invoke-RestMethod https://raw.githubusercontent.com/zeno528/codex-swap/main/windows/uninstall.ps1 -OutFile "$env:TEMP\codex-swap-uninstall.ps1"; & "$env:TEMP\codex-swap-uninstall.ps1"
```

## 🚀 使用

```bash
codex-swap            # 交互式菜单：选数字切换模型
codex-swap use gpt    # 切换模型（恢复该模型最新状态 / 首次模板播种）
codex-swap list       # 列出模板及激活状态
codex-swap current    # 查看当前生效配置
codex-swap update     # 自更新
codex-swap doctor     # 环境体检
codex-swap uninstall  # 卸载本机安装（带确认，数据目录不动）
```

Windows 与 Linux/WSL2 下均可用快捷命令 `sw`（等同 `codex-swap`）。

**首次使用**：模板目录 `~/.codex/models/` 为空时自动进入初始化向导 —— 检查 codex CLI（未安装时按系统给出安装命令）、选择导入已有模板或使用内置 🐳 DeepSeek 模板（V4-Flash / V4-Pro）、引导填写 API Key，并自动生成模型目录 `~/.codex/models.json`。

## 📖 工作原理

- **模板** `~/.codex/models/<name>.toml`：首次使用模型的种子配置，可随时编辑
- **状态** `~/.codex/model-states/<name>.toml`：模型最近一次使用时的完整配置，随使用自动演进
- **切换**：切出时完整保存当前配置；切入时优先恢复目标模型状态，无状态才用模板播种
- **登录凭据**：`auth.json` 走同一套机制 — 模板 `models/<name>.auth.json`（可选）、状态 `model-states/<name>.auth.json`。**默认托管**：切出时总是保存当前 auth 快照，切入时恢复目标快照；目标无任何 auth 记录时清空 `auth.json`（防凭据串用），切回原模型时从快照还原

## 📄 License

[MIT](LICENSE)
