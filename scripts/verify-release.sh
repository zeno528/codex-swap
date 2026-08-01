#!/usr/bin/env bash
# 校验版本一致性；传入 tag 时同时校验发行包结构。
# 版本唯一来源：根目录 VERSION 文件；三处源码为 @VERSION@ 占位符，由 scripts/build.sh 构建时注入。
set -euo pipefail

fail() { printf '错误：%s\n' "$1" >&2; exit 1; }

tag="${1:-}"

version="$(tr -d '[:space:]' < VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION 格式无效: $version"

# 三处源码版本必须与 VERSION 文件一致（版本唯一来源：根目录 VERSION）
psm1_ver="$(sed -n "s/^\$script:ScriptVersion[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" windows/src/codex-switch.psm1)"
psd1_ver="$(sed -n "s/^[[:space:]]*ModuleVersion[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" windows/src/codex-switch.psd1)"
linux_ver="$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' linux/codex-switch)"
for v in "$psm1_ver" "$psd1_ver" "$linux_ver"; do
    [ "$v" = "$version" ] || fail "源码版本 $v 与 VERSION $version 不一致"
done

if [ -n "$tag" ]; then
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag 格式无效: $tag"
    [ "${tag#v}" = "$version" ] || fail "tag $tag 与 VERSION $version 不一致"
fi

if [ "$#" -eq 3 ]; then
    windows_zip="$2"
    linux_zip="$3"
    [ -f "$windows_zip" ] || fail "缺少 Windows 发行包: $windows_zip"
    [ -f "$linux_zip" ] || fail "缺少 Linux 发行包: $linux_zip"

    unzip -Z1 "$windows_zip" | grep -Fxq 'src/codex-switch.psm1' || fail 'Windows 发行包缺少 src/codex-switch.psm1'
    unzip -Z1 "$windows_zip" | grep -Fxq 'bin/codex-switch.cmd' || fail 'Windows 发行包缺少 bin/codex-switch.cmd'
    unzip -Z1 "$linux_zip" | grep -Fxq 'codex-switch' || fail 'Linux 发行包缺少 codex-switch'

    # 包内版本必须已注入且与 VERSION 一致
    psm1_ver="$(unzip -p "$windows_zip" src/codex-switch.psm1 | sed -n "s/^\$script:ScriptVersion[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p")"
    psd1_ver="$(unzip -p "$windows_zip" src/codex-switch.psd1 | sed -n "s/^[[:space:]]*ModuleVersion[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p")"
    linux_ver="$(unzip -p "$linux_zip" codex-switch | sed -n 's/^VERSION="\([^"]*\)".*/\1/p')"
    for v in "$psm1_ver" "$psd1_ver" "$linux_ver"; do
        [ "$v" = "$version" ] || fail "发行包版本 $v 与 VERSION $version 不一致"
    done
fi

printf '版本校验通过：v%s\n' "$version"
