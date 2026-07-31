# Security Policy

## 数据边界（Data Boundary）

- **本仓库不含任何用户数据**：模型模板（`~/.codex/models/`）、模型状态（`~/.codex/model-states/`）、备份（`~/.codex/backups_model/`）全部只存在于用户本机，其中包含用户的 API Token 等敏感信息
- 安装器、更新器仅与 `github.com`（Release 资产）通信，**无任何其他网络回传**
- 卸载/升级**永不触碰** `~/.codex/` 数据目录

## 供应链说明（Supply Chain）

- 安装命令从 `raw.githubusercontent.com/zeno528/codex-switch/main/install.ps1`（或 `linux/install.sh`）拉取安装器
- 安装器通过 GitHub API 从 **Release 资产**（非 main 分支文件）下载运行时，tag 由 CI 构建，减少主分支被篡改的影响面
- 生产环境使用建议：固定版本安装（`install.ps1 -Version vX.Y.Z` / `install.sh vX.Y.Z`）

## 报告漏洞（Reporting a Vulnerability）

请通过 GitHub 私有漏洞报告（Private Vulnerability Reporting）或 [Issues](https://github.com/zeno528/codex-switch/issues) 提交，**不要**在公开 issue 中粘贴任何密钥或 config 片段。

报告内容建议包含：影响面、复现步骤、期望行为。

## 默认安全机制（GitHub 自动生效）

- Secret scanning + Push protection：公开仓库默认开启，阻止密钥入 repo
- 依赖告警：本项目无第三方运行时依赖（PowerShell 7 / bash 均调用系统能力）
