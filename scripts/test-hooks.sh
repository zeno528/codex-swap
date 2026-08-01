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

# 初始状态：VERSION 0.2.18 + 一个发布物文件
printf '0.2.18\n' > "$root/VERSION"
mkdir -p "$root/linux"
printf 'VERSION="0.2.18"\n' > "$root/linux/codex-switch"

# === 第一轮：发布物提交 → 递增 + 写 changelog ===
git -C "$root" add VERSION linux/codex-switch
git -C "$root" commit -q -m "feat: 初始发布物提交"
[ "$(tr -d '[:space:]' < "$root/VERSION")" = "0.2.19" ] || { echo "失败: 发布物提交未递增 VERSION"; exit 1; }
grep -q '^VERSION="0.2.19"' "$root/linux/codex-switch" || { echo "失败: 源码版本未同步"; exit 1; }
grep -Fq '## [0.2.19] - ' "$root/CHANGELOG.md" || { echo "失败: changelog 缺版本条目"; exit 1; }
grep -Fq -- '- feat: 初始发布物提交' "$root/CHANGELOG.md" || { echo "失败: changelog 缺提交消息"; exit 1; }

# === 第二轮：非发布物提交 → 不递增、不写 changelog ===
printf 'readme\n' > "$root/README.md"
git -C "$root" add README.md
git -C "$root" commit -q -m "docs: 文档调整"
[ "$(tr -d '[:space:]' < "$root/VERSION")" = "0.2.19" ] || { echo "失败: 非发布物提交不应递增 VERSION"; exit 1; }
[ "$(grep -c '^## \[' "$root/CHANGELOG.md")" = 1 ] || { echo "失败: 非发布物提交不应写 changelog"; exit 1; }

# === 第三轮：再次发布物提交 → 递增到 0.2.20 + 新条目 ===
printf 'VERSION="0.2.19"\nfeat: 改动\n' > "$root/linux/codex-switch"
git -C "$root" add linux/codex-switch
git -C "$root" commit -q -m "feat: 第二次发布物提交"
[ "$(tr -d '[:space:]' < "$root/VERSION")" = "0.2.20" ] || { echo "失败: 第二次发布物提交未递增"; exit 1; }
grep -Fq '## [0.2.20] - ' "$root/CHANGELOG.md" || { echo "失败: 第二次提交缺 changelog 条目"; exit 1; }

echo "Git hooks 测试通过（递增联动 + CHANGELOG 自动写入）"
