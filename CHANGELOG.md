# Changelog

## [0.2.45] - 2026-08-02

- refactor: 移除入口脚本中的 ValidateSet，优化未知命令处理逻辑


## [0.2.44] - 2026-08-02

- refactor: 更新 Invoke-Use 函数以优化配置输出和提示信息


## [0.2.43] - 2026-08-02

- refactor: 添加卸载功能，更新相关文档和命令


## [0.2.42] - 2026-08-02

- refactor: rename codex-switch to codex-swap across the project


## [0.2.41] - 2026-08-02

- Add unit tests for codex-switch module functionality


## [0.2.40] - 2026-08-02

- refactor: 更新菜单提示信息，增强用户交互体验


## [0.2.39] - 2026-08-02

- refactor: 更新快捷命令为 sw，调整安装和卸载脚本以支持新命令


## [0.2.38] - 2026-08-02

- refactor: 移除备份相关逻辑，更新文档以反映数据目录变更


## [0.2.37] - 2026-08-02

- refactor: 更新模板激活逻辑，统一与 Linux 分支一致


## [0.2.36] - 2026-08-02

- refactor: 更新快捷命令为 sw，移除旧的 cxs 快捷命令


## [0.2.35] - 2026-08-02

- chore: 更新版本日期，调整输出格式以支持加粗显示


## [0.2.34] - 2026-08-02

- refactor: 更新供应商图标显示逻辑，移除模板名称格式化函数


## [0.2.33] - 2026-08-02

- fix(linux): 修复模型列表名称列宽错位


## [0.2.32] - 2026-08-02

- refactor(linux): 移除菜单 X 卸载入口（卸载走 install.sh --uninstall）


## [0.2.31] - 2026-08-02

- refactor: 向导移除「跳过」选项，无效输入重试，q 退出


## [0.2.30] - 2026-08-02

- refactor: 向导选项更名「DeepSeek 官方接入配置」（与官方文档一致）


## [0.2.29] - 2026-08-02

- fix(linux): 安装询问改用 printf+read（read -p 在非终端不打印提示）


## [0.2.28] - 2026-08-02

- feat: 向导询问后代执行官方 codex 安装命令并验证


## [0.2.27] - 2026-08-02

- feat(windows): 首次使用初始化向导，内置 🐳 DeepSeek 模板与官方 models.json（含系统提示词）


## [0.2.26] - 2026-08-02

- feat(linux): models.json 升级为 DeepSeek 官方完整版（含系统提示词）


## [0.2.25] - 2026-08-02

- feat(linux): API Key 输入逐字符掩码显示（•），支持退格


## [0.2.24] - 2026-08-01

- refactor(linux): 向导仅保留官方独立安装器，移除 npm 备选提示


## [0.2.23] - 2026-08-01

- fix(linux): 安装引导改用官方独立安装器，npm 仅作备选


## [0.2.22] - 2026-08-01

- feat(linux): 首次使用初始化向导，内置 🐳 DeepSeek 模板与 models.json


## [0.2.21] - 2026-08-01

- feat(auth): auth.json 默认托管，切走快照切回恢复，无记录清空防串用


## [0.2.20] - 2026-08-01

- fix(windows): 导出 Save-ModelAuth/Get-SwitchAuth，修复 CI 测试失败

