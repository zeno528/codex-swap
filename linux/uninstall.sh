#!/usr/bin/env bash
# codex-swap 卸载器 (Linux/WSL2 独立分支)
# 仅删除 ~/.local/bin/codex-swap 及其 sw 快捷命令，数据目录 ~/.codex 不受影响
set -euo pipefail

LAUNCHER="$HOME/.local/bin/codex-swap"
SHORTCUT="$HOME/.local/bin/sw"

shortcut_is_ours() {
    [ -L "$SHORTCUT" ] && [ "$(readlink "$SHORTCUT")" = "codex-swap" ]
}

if [ ! -f "$LAUNCHER" ] && ! shortcut_is_ours; then
    echo "未发现已安装的 codex-swap"
    exit 0
fi

read -r -p "确认卸载 codex-swap？（数据目录 ~/.codex 不受影响）[y/N] " ans
case "$ans" in
    y|Y|yes)
        rm -f "$LAUNCHER"
        printf '\033[32m✅ 已删除 %s\033[0m\n' "$LAUNCHER"
        if shortcut_is_ours; then
            rm -f "$SHORTCUT"
            printf '\033[32m✅ 已删除快捷命令 %s\033[0m\n' "$SHORTCUT"
        fi
        echo "  数据目录 ~/.codex 未动（models/model-states 完好）"
        ;;
    *) echo "已取消" ;;
esac
