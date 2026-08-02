<div align="center">

# ⚡ codex-switch

**切换 Codex 模型配置的命令行工具**

模板播种 + 状态恢复：每个模型独立维护自己最新的完整配置，来回切换不丢使用记录、互不污染。

[![版本](https://img.shields.io/github/v/tag/zeno528/codex-switch?label=版本&color=blue)](https://github.com/zeno528/codex-switch/releases)
[![License](https://img.shields.io/github/license/zeno528/codex-switch?label=License)](LICENSE)

</div>

---

## ⚡ 安装

### 🪟 Windows · PowerShell 7

```powershell
irm https://raw.githubusercontent.com/zeno528/codex-switch/main/windows/install.ps1 | iex
```

### 🐧 Linux / WSL2

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-switch/main/linux/install.sh)
```

> 卸载：Windows `.\windows\install.ps1 -Uninstall` ｜ Linux `bash install.sh --uninstall`。数据目录 `~/.codex` 全程不受影响。

## 🚀 使用

```bash
codex-switch            # 交互式菜单：选数字切换模型
codex-switch use gpt    # 切换模型（恢复该模型最新状态 / 首次模板播种）
codex-switch list       # 列出模板及激活状态
codex-switch current    # 查看当前生效配置
codex-switch update     # 自更新
codex-switch doctor     # 环境体检
```

Windows 与 Linux/WSL2 下均可用快捷命令 `sw`（等同 `codex-switch`）。

**首次使用**：模板目录 `~/.codex/models/` 为空时自动进入初始化向导 —— 检查 codex CLI（未安装时按系统给出安装命令）、选择导入已有模板或使用内置 🐳 DeepSeek 模板（V4-Flash / V4-Pro）、引导填写 API Key，并自动生成模型目录 `~/.codex/models.json`。

## 📖 工作原理

- **模板** `~/.codex/models/<name>.toml`：首次使用模型的种子配置，可随时编辑
- **状态** `~/.codex/model-states/<name>.toml`：模型最近一次使用时的完整配置，随使用自动演进
- **切换**：切出时完整保存当前配置；切入时优先恢复目标模型状态，无状态才用模板播种
- **登录凭据**：`auth.json` 走同一套机制 — 模板 `models/<name>.auth.json`（可选）、状态 `model-states/<name>.auth.json`。**默认托管**：切出时总是保存当前 auth 快照，切入时恢复目标快照；目标无任何 auth 记录时清空 `auth.json`（防凭据串用），切回原模型时从快照还原

## 📄 License

[MIT](LICENSE)
