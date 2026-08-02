#!/usr/bin/env bash
# 版本注入构建：VERSION 是唯一版本源，构建时把 @VERSION@ 占位符注入三处源码并打包双平台 zip。
# 用法: scripts/build.sh [--inject|--package]
#   --inject   就地注入版本到源码三处（本地开发/调试用）
#   --package  构建 dist/ 并产出 Windows 与 Linux/macOS 两个 zip（默认）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "错误: VERSION 格式无效: '$VERSION'（应为 x.y.z）" >&2; exit 1; }

VFILE="$ROOT/linux/codex-swap"
PSM1="$ROOT/windows/src/codex-swap.psm1"
PSD1="$ROOT/windows/src/codex-swap.psd1"

inject() { sed -i "s/@VERSION@/$VERSION/g" "$VFILE" "$PSM1" "$PSD1"; }

case "${1:---package}" in
    --inject)
        inject
        echo "已注入 v$VERSION 到源码（工作区）"
        ;;
    --package)
        command -v zip >/dev/null || { echo "错误: 需要 zip 命令" >&2; exit 1; }
        rm -rf "$ROOT/dist"
        mkdir -p "$ROOT/dist/src" "$ROOT/dist/bin"
        cp "$ROOT/windows/src"/*.psm1 "$ROOT/windows/src"/*.psd1 "$ROOT/windows/src"/*.ps1 "$ROOT/dist/src/"
        cp -R "$ROOT/windows/bin"/. "$ROOT/dist/bin/"
        cp "$VFILE" "$ROOT/dist/codex-swap"
        sed -i "s/@VERSION@/$VERSION/g" "$ROOT/dist/src"/*.psm1 "$ROOT/dist/src"/*.psd1 "$ROOT/dist/codex-swap"
        grep -rq '@VERSION@' "$ROOT/dist" && { echo "错误: dist 仍残留占位符 @VERSION@" >&2; exit 1; }
        (cd "$ROOT/dist" && zip -qr "$ROOT/codex-swap-windows.zip" src bin && zip -qr "$ROOT/codex-swap-linux-macos.zip" codex-swap)
        echo "已构建 v$VERSION:"
        echo "  codex-swap-windows.zip（src/ bin/）"
        echo "  codex-swap-linux-macos.zip（codex-swap）"
        ;;
    *) echo "用法: $0 [--inject|--package]" >&2; exit 1 ;;
esac
