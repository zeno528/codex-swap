<div align="center">

# ⚡ codex-swap

**切换 Codex 模型配置的命令行工具**

模板播种 + 状态恢复：每个模型独立维护自己最新的完整配置，来回切换不丢使用记录、互不污染。

[![License](https://img.shields.io/badge/License-MIT-4CC61E)](LICENSE)
![平台](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-2B7489)
![运行时](https://img.shields.io/badge/PowerShell%205.1%2B%20%7C%207%20%E6%8E%A8%E8%8D%90%20%C2%B7%20Bash-8250DF)

</div>

---

## ⚡ 安装

### 🐧 Linux / WSL2 / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-swap/main/linux/install.sh)
```

macOS 与 Linux 共用同一 bash 分支（零 Windows 依赖），系统自带 bash 即可运行，安装器会自动写入 `~/.zshrc`（macOS 默认 shell）。

Release 页面会提供 `codex-swap-linux-macos.zip`，供 Linux、WSL2 与 macOS 共用。

### 🪟 Windows · PowerShell 5.1+（PowerShell 7 推荐）

```powershell
irm https://raw.githubusercontent.com/zeno528/codex-swap/main/windows/install.ps1 | iex
```

### 🗑️ 卸载

```bash
codex-swap uninstall
```

卸载只删除程序本体与快捷命令，数据目录 `~/.codex`（models/model-states/auth）不受影响。

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

Windows、Linux/WSL2 与 macOS 下均可用快捷命令 `sw`（等同 `codex-swap`）。

**首次使用**：模板目录 `~/.codex/models/` 为空时自动进入初始化向导 —— 检查 codex CLI（未安装时按系统给出安装命令）、选择导入已有模板或使用内置 🐳 DeepSeek 模板（V4-Flash / V4-Pro）、引导填写 API Key，并自动生成模型目录 `~/.codex/models.json`。

**随时新建配置**：菜单内按 `N` 可再次进入同一配置向导 —— 内置 DeepSeek 模板支持空格多选（V4-Flash / V4-Pro 可一次全建，初始全选、回车确认），也可打开目录导入自己的模板；已有模板与状态不受影响。

## 📖 工作原理

- **模板** `~/.codex/models/<name>.toml`：首次使用模型的种子配置，可随时编辑
- **状态** `~/.codex/model-states/<name>.toml`：模型最近一次使用时的完整配置，随使用自动演进
- **切换**：切出时完整保存当前配置；切入时优先恢复目标模型状态，无状态才用模板播种
- **登录凭据**：`auth.json` 走同一套机制 — 模板 `models/<name>.auth.json`（可选）、状态 `model-states/<name>.auth.json`。**默认托管**：切出时总是保存当前 auth 快照，切入时恢复目标快照；目标无任何 auth 记录时清空 `auth.json`（防凭据串用），切回原模型时从快照还原

## 📄 License

[MIT](LICENSE)
