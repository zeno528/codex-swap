#!/usr/bin/env bash
# .githooks 共享函数（pre-commit / prepare-commit-msg 共用）
# 发布物相关路径：改动这些才视为发布物变更（版本递增 + CHANGELOG 记录）
is_release_change() {
    while IFS= read -r f; do
        case "$f" in
            linux/*|windows/src/*|windows/bin/*|windows/install.ps1|windows/uninstall.ps1|scripts/build.sh)
                return 0 ;;
        esac
    done < <(git diff --cached --name-only)
    return 1
}
