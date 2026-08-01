#!/usr/bin/env bash
# 校验双分支版本同步；传入 tag 时同时校验发行包结构。
set -euo pipefail

fail() { printf '错误：%s\n' "$1" >&2; exit 1; }

tag="${1:-}"
windows_script_version="$(sed -n "s/^\$script:ScriptVersion[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" windows/src/codex-switch.psm1)"
windows_module_version="$(sed -n "s/^[[:space:]]*ModuleVersion[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" windows/src/codex-switch.psd1)"
linux_version="$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' linux/codex-switch)"

for version in "$windows_script_version" "$windows_module_version" "$linux_version"; do
    [ -n "$version" ] || fail '无法读取版本号'
done

[ "$windows_script_version" = "$windows_module_version" ] || fail 'Windows 脚本与模块版本不一致'
[ "$windows_script_version" = "$linux_version" ] || fail 'Windows 与 Linux 版本不一致'

if [ -n "$tag" ]; then
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag 格式无效: $tag"
    [ "${tag#v}" = "$windows_script_version" ] || fail "tag $tag 与程序版本 $windows_script_version 不一致"
fi

if [ "$#" -eq 3 ]; then
    windows_zip="$2"
    linux_zip="$3"
    [ -f "$windows_zip" ] || fail "缺少 Windows 发行包: $windows_zip"
    [ -f "$linux_zip" ] || fail "缺少 Linux 发行包: $linux_zip"

    unzip -Z1 "$windows_zip" | grep -Fxq 'src/codex-switch.psm1' || fail 'Windows 发行包缺少 src/codex-switch.psm1'
    unzip -Z1 "$windows_zip" | grep -Fxq 'bin/codex-switch.cmd' || fail 'Windows 发行包缺少 bin/codex-switch.cmd'
    unzip -Z1 "$linux_zip" | grep -Fxq 'codex-switch' || fail 'Linux 发行包缺少 codex-switch'
fi

printf '版本校验通过：v%s\n' "$windows_script_version"
