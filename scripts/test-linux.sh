#!/usr/bin/env bash
# 在隔离 CODEX_HOME 中验证 Linux 分支的完整状态切换链路。
set -euo pipefail

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

export CODEX_HOME="$test_root/.codex"
mkdir -p "$CODEX_HOME/models" "$CODEX_HOME/model-states"

printf '%s\n' 'model = "deepseek-v4-flash"' 'model_provider = "deepseek"' '[model_providers.deepseek]' 'name = "deepseek"' > "$CODEX_HOME/models/deepseek.toml"
printf '%s\n' 'model = "gpt-5.6-terra"' 'model_provider = "openai"' '[model_providers.openai]' 'name = "openai"' > "$CODEX_HOME/models/gpt.toml"
cp "$CODEX_HOME/models/deepseek.toml" "$CODEX_HOME/config.toml"
cp "$CODEX_HOME/config.toml" "$test_root/deepseek-before.toml"

output="$(bash linux/codex-swap list)"
grep -q deepseek <<< "$output"
grep -q '编号' <<< "$output"
grep -q '🐳 deepseek' <<< "$output"
grep -q '💠 openai' <<< "$output"
output="$(bash linux/codex-swap current)"
grep -q deepseek-v4-flash <<< "$output"
output="$(bash linux/codex-swap doctor)"
grep -q '通过 7 / 7' <<< "$output"

# provider 缺省按内置 OpenAI；单一 provider 模板允许模型名变化后仍识别激活
fallback_home="$test_root/fallback/.codex"
mkdir -p "$fallback_home/models" "$fallback_home/model-states"
printf '%s\n' 'model = "gpt-5.6-luna"' > "$fallback_home/config.toml"
printf '%s\n' 'model = "gpt-5.6-terra"' > "$fallback_home/models/openai.toml"
output="$(CODEX_HOME="$fallback_home" bash linux/codex-swap list)"
grep -q '✅' <<< "$output"
printf '%s\n' 'model = "gpt-5.6-sol"' > "$fallback_home/models/openai-alt.toml"
output="$(CODEX_HOME="$fallback_home" bash linux/codex-swap list)"
! grep -q '✅' <<< "$output"

# 名称列自适应：长名称完整显示，超过上限截断为 ...
long_home="$test_root/longname"
mkdir -p "$long_home/models" "$long_home/model-states"
printf '%s\n' 'model = "gpt-5.6-terra"' > "$long_home/models/long-template-name-123456789.toml"
printf '%s\n' 'model = "gpt-5.6-terra"' > "$long_home/config.toml"
output="$(CODEX_HOME="$long_home" bash linux/codex-swap list)"
grep -q 'long-template-name-123456789' <<< "$output"
printf '%s\n' 'model = "gpt-5.6-terra"' > "$long_home/models/very-long-template-name-1234567890.toml"
output="$(CODEX_HOME="$long_home" bash linux/codex-swap list)"
if grep -q 'very-long-template-name-1234567890' <<< "$output"; then exit 1; fi
grep -q '\.\.\.' <<< "$output"

output="$(bash linux/codex-swap use gpt)"
grep -q '已切换至 gpt' <<< "$output"
grep -q '📋 当前配置 · 4 行' <<< "$output"
! grep -q '⚠️' <<< "$output"
cmp "$test_root/deepseek-before.toml" "$CODEX_HOME/model-states/deepseek.toml"
grep -q 'gpt-5.6-terra' "$CODEX_HOME/config.toml"

printf '%s\n' 'trusted_project = "test-project"' >> "$CODEX_HOME/config.toml"
output="$(bash linux/codex-swap use deepseek)"
grep -q '已切换至 deepseek' <<< "$output"
grep -q 'trusted_project = "test-project"' "$CODEX_HOME/model-states/gpt.toml"
cmp "$test_root/deepseek-before.toml" "$CODEX_HOME/config.toml"

# === auth.json 快照链路 ===
printf '%s\n' '{ "token": "test-token-deepseek-auth" }' > "$CODEX_HOME/models/deepseek.auth.json"
printf '%s\n' '{ "token": "test-token-gpt-auth" }' > "$CODEX_HOME/models/gpt.auth.json"
printf '%s\n' '{ "token": "test-token-deepseek-auth" }' > "$CODEX_HOME/auth.json"

output="$(bash linux/codex-swap use gpt)"
grep -q '已切换至 gpt' <<< "$output"
grep -q 'auth.json 已同步（gpt）' <<< "$output"
grep -q 'test-token-gpt-auth' "$CODEX_HOME/auth.json"
test ! -f "$CODEX_HOME/model-states/gpt.auth.json"

printf '%s\n' '{ "token": "test-token-gpt-auth-grown" }' > "$CODEX_HOME/auth.json"
output="$(bash linux/codex-swap use deepseek)"
grep -q '已保存 auth 状态：gpt' <<< "$output"
grep -q 'test-token-gpt-auth-grown' "$CODEX_HOME/model-states/gpt.auth.json"
grep -q 'test-token-deepseek-auth' "$CODEX_HOME/auth.json"

output="$(bash linux/codex-swap use gpt)"
grep -q 'auth.json 已同步（gpt）' <<< "$output"
grep -q 'test-token-gpt-auth-grown' "$CODEX_HOME/auth.json"

# 无 auth 记录的模型：切入清空防串用；切回时 auth 从快照恢复
printf '%s\n' 'model = "claude-4"' 'model_provider = "anthropic"' > "$CODEX_HOME/models/claude.toml"
output="$(bash linux/codex-swap use claude)"
grep -q '无 auth 记录，已清空 auth.json' <<< "$output"
test ! -f "$CODEX_HOME/auth.json"
output="$(bash linux/codex-swap use gpt)"
grep -q 'auth.json 已同步（gpt）' <<< "$output"
grep -q 'test-token-gpt-auth-grown' "$CODEX_HOME/auth.json"
output="$(printf '1\nq\nq\n' | bash linux/codex-swap 2>&1)"
test "$(grep -o '模型切换' <<< "$output" | wc -l)" -eq 1

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *'/releases/latest') printf '%s\n' '{"tag_name":"v0.2.3"}' ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$fake_bin/curl"
sed 's/^VERSION="[^"]*"/VERSION="0.2.2"/' linux/codex-swap > "$test_root/codex-swap"
if output="$(PATH="$fake_bin:$PATH" bash "$test_root/codex-swap" update 2>&1)"; then
    exit 1
fi
grep -q '找不到资产 codex-swap-linux-macos.zip' <<< "$output"

# === 首次使用向导 ===
wizard_home="$test_root/wizard"
mkdir -p "$wizard_home"

# 已有 Codex 数据目录时，即使 CLI 不在 PATH 也不应触发安装向导
if ! command -v codex >/dev/null 2>&1; then
    output="$(CODEX_HOME="$wizard_home" bash linux/codex-swap menu </dev/null 2>&1)"
    ! grep -q '未检测到 codex CLI' <<< "$output"
    grep -q '模型配置来源' <<< "$output"
fi

# 内置 🐳 DeepSeek 模板：假 codex + 管道输入走完整向导（默认创建 Flash 模板）
cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--version" ] && printf '0.144.0\n'
EOF
chmod +x "$fake_bin/codex"
output="$(printf '1\nsk-wizard-test-key\n\n\nq\n' | CODEX_HOME="$wizard_home" PATH="$fake_bin:$PATH" bash linux/codex-swap menu 2>&1)"
grep -q '模板已创建' <<< "$output"
grep -q '╌' <<< "$output"
grep -q 'https://platform.deepseek.com/api_keys' <<< "$output"
grep -q '模板名称' <<< "$output"
grep -q 'deepseek-v4-flash' "$wizard_home/models/deepseek.toml"
grep -q 'sk-wizard-test-key' "$wizard_home/models/deepseek.toml"
grep -q 'deepseek-v4-flash' "$wizard_home/config.toml"
grep -q 'deepseek-v4-flash' "$wizard_home/models.json"
grep -q 'deepseek-v4-pro' "$wizard_home/models.json"

# 未填 API Key：写入官方占位符 <你的 DeepSeek API Key>
empty_home="$test_root/emptykey"
mkdir -p "$empty_home"
output="$(printf '1\n\n\n\nq\n' | CODEX_HOME="$empty_home" PATH="$fake_bin:$PATH" bash linux/codex-swap menu 2>&1)"
grep -q '你的 DeepSeek API Key' "$empty_home/models/deepseek.toml"

# 菜单内 N 新建配置：已有模板时仍能进入 DeepSeek 向导（默认 Flash，不覆盖现有配置）
new_home="$test_root/newcfg"
mkdir -p "$new_home/models" "$new_home/model-states"
printf '%s\n' 'model = "gpt-5.6-terra"' 'model_provider = "openai"' > "$new_home/models/gpt.toml"
printf '%s\n' 'model = "gpt-5.6-terra"' > "$new_home/config.toml"
output="$(printf 'n\n1\nsk-newcfg-key\n\nN\n\nq\n' | CODEX_HOME="$new_home" PATH="$fake_bin:$PATH" bash linux/codex-swap menu 2>&1)"
grep -q 'N 新建配置' <<< "$output"
grep -q '新建配置完成' <<< "$output"
grep -q 'deepseek-v4-flash' "$new_home/models/deepseek.toml"
grep -q 'sk-newcfg-key' "$new_home/models/deepseek.toml"
grep -q 'deepseek-v4-flash' "$new_home/models.json"
grep -q 'deepseek-v4-pro' "$new_home/models.json"
test -f "$new_home/models/gpt.toml"
grep -q 'gpt-5.6-terra' "$new_home/config.toml"

# 模板命名：非法名重问 → 默认名重名 → 选择重新命名 → 创建新名且不覆盖旧模板
dup_home="$test_root/dupcfg"
mkdir -p "$dup_home/models" "$dup_home/model-states"
printf '%s\n' 'model = "gpt-5.6-terra"' 'model_provider = "openai"' > "$dup_home/models/deepseek.toml"
printf '%s\n' 'model = "gpt-5.6-terra"' > "$dup_home/config.toml"
output="$(printf 'n\n1\nsk-dup-key\na/b\ndeepseek\nr\ndeepseek2\nN\n\nq\n' | CODEX_HOME="$dup_home" PATH="$fake_bin:$PATH" bash linux/codex-swap menu 2>&1)"
grep -q '名称仅支持' <<< "$output"
grep -q '已存在同名模板' <<< "$output"
grep -q 'deepseek-v4-flash' "$dup_home/models/deepseek2.toml"
grep -q 'sk-dup-key' "$dup_home/models/deepseek2.toml"
grep -q 'gpt-5.6-terra' "$dup_home/models/deepseek.toml"

echo 'Linux 端到端切换测试通过'
