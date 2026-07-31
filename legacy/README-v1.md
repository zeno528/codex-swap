# codex-model — Codex 模型切换器

切换 Codex 桌面 App 的模型配置。**模板播种 + 状态恢复**机制：模板只负责首次进入，之后每个模型都维护自己最新的完整配置，来回切换互不丢失、互不污染。

- **v1（本目录）**：本地快捷版，Windows PowerShell 7 直接运行
- **v2（规划中）**：跨设备安装版（Windows `install.ps1` / WSL2 `install.sh`）

---

## 原理

### 核心矛盾

Codex 的 `config.toml` 是**活的状态**——使用过程中 App 会不断往里写入信任项目、禁用 skill、插件、主题等配置，文件会持续增长。而静态模板无法代表"最新状态"：

- **纯模板覆盖**：切回旧模型会丢失上次积累的全部配置（等于失忆）
- **配置合并**：两个模型的状态会互相污染、越滚越大

### 解决方案：双份配置

每个模型拥有两份配置，角色不同：

| 配置 | 路径 | 角色 |
|:-----|:-----|:-----|
| **模板** | `~/.codex/models/<name>.toml` | 首次使用的**种子**，静态，可随时编辑 |
| **状态** | `~/.codex/model-states/<name>.toml` | 该模型**最近一次使用**时的完整 config，动态演进 |

### 切换链路

```
            切出 deepseek                     切入 GPT
config.toml ────────────────► model-states/deepseek.toml   （完整保存，1:1 拷贝）
config.toml ◄──────────────── model-states/gpt.toml        （存在则恢复）
                              （不存在则用 models/gpt.toml 模板播种，首次使用）
```

具体步骤（`use <name>`）：

1. **识别源模型**：按 `model` + `model_provider`（+ token 指纹）匹配当前 config 属于哪个模板
2. **保存源状态**：把当前 config.toml **原样完整**拷贝为 `model-states/<源>.toml`
3. **取目标内容**：`model-states/<目标>.toml` 存在则恢复它；不存在则用模板播种
4. **备份兜底**：写入前备份当前 config 到 `backups_model/`（保留最近 5 份）
5. **原子写入**：写临时文件 → 校验非空 → Move 覆盖，失败自动回滚临时文件

### 目录结构

```
~/.codex/
├── config.toml              # 当前生效配置（Codex App 实际读取）
├── models/                  # 模板（首次播种用）
│   ├── deepseek.toml
│   ├── config.toml          # 例如 GPT 完整配置模板
│   └── ...
├── model-states/            # 各模型最新状态（核心数据，勿手删）
│   ├── deepseek.toml
│   ├── config.toml
│   └── ...
└── backups_model/           # 切换前自动备份（保留 5 份）
```

> 注：模型名的命名就是模板文件名（不含 `.toml`），`models/config.toml` 即名为 `config` 的模板。

### 几个设计细节

- **识别不做 key 白名单**：匹配只看 `model` / `model_provider` / `experimental_bearer_token`（token 取前 6 + 后 6 做指纹，避免明文比对），模板里写了什么字段就原样用
- **状态永远是最新的**：App 自己改写 config（如升级 runtime 路径）也会被如实存进状态，切回来时恢复的就是真实使用现场
- **恢复 vs 播种的判定**：有状态文件就恢复，没有才用模板——首次切换自动完成播种
- **菜单标记**：✅ = 当前激活模板，🔑 = 同 model 的备用密钥模板

---

## 使用

### 环境要求

- Windows + PowerShell 7（`pwsh`）
- Codex 桌面 App（config 位于 `~/.codex/config.toml`）

### 交互式菜单（双击或手动运行）

```powershell
pwsh .\codex-model-v1.ps1
```

```
  ╭──────────────────────────────╮
  │  💻 codex-model v1 — 模型切换 │
  ╰──────────────────────────────╯
  ┌──────┬───────┬────────────┬──────────...
  │ 编号 │ 状态  │ NAME       │ MODEL
  ├──────┼───────┼────────────┼──────────...
  │  1   │ ✅    │ deepseek   │ deepseek-v4-flash
  │  2   │       │ config     │ gpt-5.6-terra
  └──────┴───────┴────────────┴──────────...

选择 (1-2)，📂 o 打开目录，回车刷新，q 退出
```

- 输入数字切换模型
- `o` 打开模板目录（可在里面新建/编辑模板）
- 回车刷新菜单（每次重绘自动清屏）

### 命令行

```powershell
pwsh .\codex-model-v1.ps1 use deepseek   # 切换到 deepseek（恢复其最新状态/首次播种）
pwsh .\codex-model-v1.ps1 list          # 列出所有模板及激活状态
pwsh .\codex-model-v1.ps1 current       # 查看当前生效的模型配置
pwsh .\codex-model-v1.ps1 help          # 帮助
```

### 添加新模型

1. 在 `~/.codex/models/` 新建 `<名字>.toml`，内容为一个完整可用的 Codex 配置（顶层 `model` 字段 + 可选 `[model_providers.xxx]` 段，建议参考现有模板）
2. 首次切换时脚本自动播种 + 生成状态，之后该模型的状态独立演进

### 重置某模型（丢弃其积累，回到模板初始状态）

```powershell
Remove-Item ~\.codex\model-states\<名字>.toml   # 删除后下次切入会用模板重新播种
```

---

## 测试

```powershell
pwsh .\test_codex_model-v1.ps1
```

覆盖：模板/配置指纹解析、激活标记两阶段匹配（含 token 指纹精筛）、状态保存/恢复优先级、显示宽度计算。测试不触碰真实 `~/.codex`（全部走临时目录）。

---

## 文件清单

| 文件 | 说明 |
|:-----|:-----|
| `codex-model-v1.ps1` | 主脚本（菜单 + 子命令 + 状态机制） |
| `test_codex_model-v1.ps1` | 单元测试（23 项） |
| `README.md` | 本文档 |

## 规划：v2 跨设备安装版

- **Windows**：`install.ps1`（`irm <url> | iex`），`codex-model.cmd` 启动器进 PATH
- **WSL2**：`install.sh`（`curl ... | bash`），`codex-model` 可执行脚本进 `~/.local/bin`
- 路径解析抽象：Windows 用 `$env:USERPROFILE`，WSL2 用 `$HOME`（当前 v1 为 Windows 专用）
- 核心逻辑保持单份 `.ps1`，安装器只负责分发和启动器
