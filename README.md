<div align="center">

# ⚡ codex-switch

**切换 Codex 模型配置的命令行工具**

模板播种 + 状态恢复：每个模型独立维护自己最新的完整配置，来回切换不丢使用记录、互不污染。

[![版本](https://img.shields.io/github/v/tag/zeno528/codex-switch?label=版本&color=blue)](https://github.com/zeno528/codex-switch/releases)
[![License](https://img.shields.io/github/license/zeno528/codex-switch?label=License)](LICENSE)

</div>

---

## ⚡ 安装

| 🪟 Windows · PowerShell 7 | 🐧 Linux / WSL2 |
|:--------------------------|:----------------|
| `irm https://raw.githubusercontent.com/zeno528/codex-switch/main/windows/install.ps1 \| iex` | `bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-switch/main/linux/install.sh)` |

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

Linux/WSL2 下还可用快捷命令 `cxs`（等同 `codex-switch`）。

## 📖 工作原理

- **模板** `~/.codex/models/<name>.toml`：首次使用模型的种子配置，可随时编辑
- **状态** `~/.codex/model-states/<name>.toml`：模型最近一次使用时的完整配置，随使用自动演进
- **切换**：切出时完整保存当前配置；切入时优先恢复目标模型状态，无状态才用模板播种
- **备份**：每次切换前自动备份到 `~/.codex/backups_model/`（保留 5 份）

## 📄 License

[MIT](LICENSE)
