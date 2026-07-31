#!/usr/bin/env bash
# codex-switch 卸载器 (Linux/WSL2 独立分支)
# 仅删除 ~/.local/bin/codex-switch，数据目录 ~/.codex 不受影响
set -euo pipefail

LAUNCHER="$HOME/.local/bin/codex-switch"

if [ ! -f "$LAUNCHER" ]; then
    echo "未发现已安装的 codex-switch"
    exit 0
fi

read -r -p "确认卸载 codex-switch？（数据目录 ~/.codex 不受影响）[y/N] " ans
case "$ans" in
    y|Y|yes)
        rm -f "$LAUNCHER"
        printf '\033[32m✅ 已删除 %s\033[0m\n' "$LAUNCHER"
        echo "  数据目录 ~/.codex 未动（models/model-states 完好）"
        ;;
    *) echo "已取消" ;;
esac
