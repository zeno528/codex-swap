#!/usr/bin/env bash
# 验证 git hooks：发布物提交 → pre-commit 递增 VERSION + prepare-commit-msg 写 CHANGELOG；
# 非发布物提交 → 两者都不动。全程在临时 git 仓库中模拟，不触碰真实仓库。
set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

git init -q "$root"
git -C "$root" config user.email "hook-test@example.com"
git -C "$root" config user.name "hook-test"
git -C "$root" config core.hooksPath .githooks
cp -r .githooks "$root/"

# 初始状态：VERSION 0.2.18 + 一个发布物文件（.githooks 一并跟踪，贴近真实仓库）
printf '0.2.18\n' > "$root/VERSION"
mkdir -p "$root/linux"
printf 'VERSION="0.2.18"\n' > "$root/linux/codex-swap"

# === 第一轮：发布物提交（-m）→ 递增 + changelog 一次写入，无 amend ===
git -C "$root" add .githooks VERSION linux/codex-swap
first_out="$(git -C "$root" commit -m "feat: 初始发布物提交" 2>&1)"
[ "$(tr -d '[:space:]' < "$root/VERSION")" = "0.2.19" ] || { echo "失败: 发布物提交未递增 VERSION"; exit 1; }
grep -q '^VERSION="0.2.19"' "$root/linux/codex-swap" || { echo "失败: 源码版本未同步"; exit 1; }
grep -Fq '## [0.2.19] - ' "$root/CHANGELOG.md" || { echo "失败: changelog 缺版本条目"; exit 1; }
grep -Fq -- '- feat: 初始发布物提交' "$root/CHANGELOG.md" || { echo "失败: changelog 缺提交消息"; exit 1; }
git -C "$root" show HEAD:CHANGELOG.md | grep -Fq -- '- feat: 初始发布物提交' || { echo "失败: changelog 条目未进入本次提交"; exit 1; }
[ -z "$(git -C "$root" status --porcelain)" ] || { echo "失败: 发布物提交后工作区应干净"; exit 1; }
echo "$first_out" | grep -Fq 'post-commit: 自动 amend' && { echo "失败: -m 场景不应触发 post-commit amend"; exit 1; } || true

# === 第二轮：非发布物提交 → 不递增、不写 changelog ===
printf 'readme\n' > "$root/README.md"
git -C "$root" add README.md
git -C "$root" commit -q -m "docs: 文档调整"
[ "$(tr -d '[:space:]' < "$root/VERSION")" = "0.2.19" ] || { echo "失败: 非发布物提交不应递增 VERSION"; exit 1; }
[ "$(grep -c '^## \[' "$root/CHANGELOG.md")" = 1 ] || { echo "失败: 非发布物提交不应写 changelog"; exit 1; }
[ -z "$(git -C "$root" status --porcelain)" ] || { echo "失败: 非发布物提交后工作区应干净"; exit 1; }

# === 第三轮：-F 消息文件场景 → 解析 -F 一次写入，无 amend ===
printf 'feat: -F 消息文件提交\n' > "$root/msg.txt"
printf 'VERSION="0.2.19"\nfeat: 改动\n' > "$root/linux/codex-swap"
git -C "$root" add linux/codex-swap
third_out="$(git -C "$root" commit -F msg.txt 2>&1)"
[ "$(tr -d '[:space:]' < "$root/VERSION")" = "0.2.20" ] || { echo "失败: 第三次提交未递增"; exit 1; }
grep -Fq '## [0.2.20] - ' "$root/CHANGELOG.md" || { echo "失败: 第三次提交缺 changelog 条目"; exit 1; }
git -C "$root" show HEAD:CHANGELOG.md | grep -Fq -- '- feat: -F 消息文件提交' || { echo "失败: -F 场景条目未进入提交"; exit 1; }
rm -f "$root/msg.txt"
[ -z "$(git -C "$root" status --porcelain)" ] || { echo "失败: 第三轮后工作区应干净"; exit 1; }
echo "$third_out" | grep -Fq 'post-commit: 自动 amend' && { echo "失败: -F 场景不应触发 post-commit amend"; exit 1; } || true

echo "Git hooks 测试通过（递增联动 + CHANGELOG 自动写入）"
