#!/usr/bin/env bash
# codex-swap 安装器 (Linux/WSL2 独立分支)
# 纯 bash + 原生工具：curl / grep / sed / unzip，零 pwsh / Windows 依赖
#
# 用法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/zeno528/codex-swap/main/linux/install.sh)
#   bash install.sh v0.2.0          # 指定版本
#   bash install.sh --uninstall     # 卸载（不动 ~/.codex 数据）
set -euo pipefail

REPO_OWNER="zeno528"
REPO_NAME="codex-swap"
ASSET_NAME="codex-swap-linux.zip"
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/codex-swap"
SHORTCUT="$BIN_DIR/sw"

say()  { printf '\033[32m  %s\033[0m\n' "$1"; }
warn() { printf '\033[33m  %s\033[0m\n' "$1"; }
fail() { printf '\033[31m  %s\033[0m\n' "$1" >&2; exit 1; }

# ---------- 卸载 ----------
if [ "${1:-}" = "--uninstall" ]; then
    echo "卸载 codex-swap..."
    rm -f "$LAUNCHER" && say "已删除启动器 $LAUNCHER" || true
    if [ -f "$BIN_DIR/codex-switch" ]; then
        rm -f "$BIN_DIR/codex-switch" && say "已删除旧版启动器 $BIN_DIR/codex-switch"
    fi
    if [ -L "$SHORTCUT" ] && [ "$(readlink "$SHORTCUT")" = "codex-swap" ]; then
        rm -f "$SHORTCUT" && say "已删除快捷命令 $SHORTCUT"
    fi
    if [ -L "$BIN_DIR/cxs" ] && { [ "$(readlink "$BIN_DIR/cxs")" = "codex-swap" ] || [ "$(readlink "$BIN_DIR/cxs")" = "codex-switch" ]; }; then
        rm -f "$BIN_DIR/cxs" && say "已删除旧快捷命令 $BIN_DIR/cxs"
    fi
    echo "  数据目录 ~/.codex 未动（models/model-states 完好）"
    exit 0
fi

# ---------- 前置检查 ----------
for tool in curl unzip; do
    command -v "$tool" >/dev/null 2>&1 || fail "缺少 $tool，请先安装（sudo apt install $tool）"
done
say "前置工具检查通过（curl / unzip）"

# ---------- 获取 Release ----------
VERSION="${1:-}"
if [ -n "$VERSION" ]; then
    REL_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$VERSION"
else
    REL_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
fi
echo "  获取 GitHub Release..."
JSON="$(curl -fsSL -H 'User-Agent: codex-swap-installer' "$REL_URL")" || fail "获取 Release 失败（网络或限流）"
TAG="$(printf '%s' "$JSON" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
URL="$(printf '%s' "$JSON" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*codex-swap-linux\.zip"' | head -n1 | sed 's/.*"\(http[^"]*\)".*/\1/')"
[ -n "$TAG" ] && [ -n "$URL" ] || fail "Release 缺少资产 $ASSET_NAME"
say "Release $TAG"

# ---------- 下载 ----------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "  下载 $ASSET_NAME..."
curl -fsSL -o "$TMP/$ASSET_NAME" "$URL" || fail "下载失败"
unzip -qo "$TMP/$ASSET_NAME" -d "$TMP/x" || fail "解压失败"
NEW="$TMP/x/codex-swap"
[ -f "$NEW" ] || fail "包内缺少 codex-swap 主脚本"
bash -n "$NEW" || fail "主脚本语法校验失败"
say "下载并语法校验通过"

# ---------- 安装 ----------
mkdir -p "$BIN_DIR"
if [ -f "$LAUNCHER" ]; then
    cp "$LAUNCHER" "$LAUNCHER.old"
    warn "旧版本已备份为 $LAUNCHER.old"
fi
cp "$NEW" "$LAUNCHER"
chmod +x "$LAUNCHER"
say "启动器 $LAUNCHER"
if [ -f "$BIN_DIR/codex-switch" ]; then
    rm -f "$BIN_DIR/codex-switch"
    warn "已移除旧版启动器 $BIN_DIR/codex-switch"
fi

if [ -e "$SHORTCUT" ] || [ -L "$SHORTCUT" ]; then
    if [ -L "$SHORTCUT" ] && [ "$(readlink "$SHORTCUT")" = "codex-swap" ]; then
        say "快捷命令 $SHORTCUT"
    else
        warn "快捷命令未创建：$SHORTCUT 已被占用"
    fi
else
    ln -s "codex-swap" "$SHORTCUT"
    say "快捷命令 $SHORTCUT"
fi

# ---------- PATH ----------
case ":$PATH:" in
    *":$BIN_DIR:"*) say "$BIN_DIR 已在 PATH 中" ;;
    *)
        printf '\n# codex-swap\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
        [ -f "$HOME/.zshrc" ] && printf '\n# codex-swap\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
        warn "已把 ~/.local/bin 加入 ~/.bashrc（新终端生效）"
        ;;
esac

# ---------- 汇总 ----------
printf '\n\033[32m✅ codex-swap %s 安装完成\033[0m\n' "$TAG"
echo "   程序: $LAUNCHER"
echo "   快捷: sw"
echo "   数据目录: $HOME/.codex（未改动）"
echo "   使用: 新终端里运行 sw（或 codex-swap）"
echo "   升级: codex-swap update"
