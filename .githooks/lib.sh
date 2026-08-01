#!/usr/bin/env bash
# .githooks 共享函数（pre-commit / prepare-commit-msg / post-commit 共用）
ROOT="$(git rev-parse --show-toplevel)"

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

# 从 git commit 进程命令行提取提交消息首行（支持 -m/--message、-F/--file、--amend）
# git 在 pre-commit 阶段尚未生成 COMMIT_EDITMSG，消息只能从 /proc 父进程 cmdline 获取；
# 编辑器交互提交（无 -m/-F）拿不到 → 输出空，由 prepare-commit-msg 兜底写入
get_commit_msg() {
    local ppid="$PPID" args=() i arg msg
    mapfile -d '' args < "/proc/$ppid/cmdline" 2>/dev/null || return 1
    for ((i = 1; i < ${#args[@]}; i++)); do
        arg="${args[$i]}"
        case "$arg" in
            --amend)
                if [ -f "$ROOT/.git/COMMIT_EDITMSG" ]; then
                    msg="$(grep -m1 -v '^[[:space:]]*$' "$ROOT/.git/COMMIT_EDITMSG" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                    [ -n "$msg" ] && { echo "$msg"; return 0; }
                fi
                ;;
            -m)
                [ $((i + 1)) -lt ${#args[@]} ] && msg="${args[$((i + 1))]}"
                [ -n "$msg" ] && { echo "$msg"; return 0; }
                ;;
            --message=*)
                msg="${arg#--message=}"
                [ -n "$msg" ] && { echo "$msg"; return 0; }
                ;;
            -F)
                [ $((i + 1)) -lt ${#args[@]} ] && msg="${args[$((i + 1))]}"
                if [ -n "$msg" ] && [ -f "$msg" ]; then
                    msg="$(grep -m1 -v '^[[:space:]]*$' "$msg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                    [ -n "$msg" ] && { echo "$msg"; return 0; }
                fi
                ;;
            --file=*)
                msg="${arg#--file=}"
                if [ -f "$msg" ]; then
                    msg="$(grep -m1 -v '^[[:space:]]*$' "$msg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                    [ -n "$msg" ] && { echo "$msg"; return 0; }
                fi
                ;;
        esac
    done
    return 1
}

# 写 CHANGELOG 条目（版本号 + 日期 + 消息首行），幂等：同消息已存在则跳过
write_changelog_entry() {
    local msg="$1" CL ver entry tmp
    [ -n "$msg" ] || return 0
    CL="$ROOT/CHANGELOG.md"
    ver="$(tr -d '[:space:]' < "$ROOT/VERSION")"
    [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 0
    if [ -f "$CL" ] && grep -Fq -- "- $msg" "$CL"; then
        return 0
    fi
    [ -f "$CL" ] || printf '# Changelog\n' > "$CL"
    entry="## [$ver] - $(date +%F)

- $msg"
    tmp="$(mktemp)"
    { head -n 1 "$CL"; echo ""; printf '%s\n' "$entry"; echo ""; tail -n +2 "$CL"; } > "$tmp"
    mv "$tmp" "$CL"
    git add "$CL"
    echo "已写入 CHANGELOG（v$ver）"
}
