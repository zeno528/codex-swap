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

output="$(bash linux/codex-switch list)"
grep -q deepseek <<< "$output"
grep -q '编号' <<< "$output"
output="$(bash linux/codex-switch current)"
grep -q deepseek-v4-flash <<< "$output"
output="$(bash linux/codex-switch doctor)"
grep -q '通过 7 / 7' <<< "$output"

output="$(bash linux/codex-switch use gpt)"
grep -q '已切换至 gpt' <<< "$output"
grep -q '当前配置' <<< "$output"
! grep -q '⚠️' <<< "$output"
cmp "$test_root/deepseek-before.toml" "$CODEX_HOME/model-states/deepseek.toml"
grep -q 'gpt-5.6-terra' "$CODEX_HOME/config.toml"

printf '%s\n' 'trusted_project = "test-project"' >> "$CODEX_HOME/config.toml"
output="$(bash linux/codex-switch use deepseek)"
grep -q '已切换至 deepseek' <<< "$output"
grep -q 'trusted_project = "test-project"' "$CODEX_HOME/model-states/gpt.toml"
cmp "$test_root/deepseek-before.toml" "$CODEX_HOME/config.toml"
test "$(find "$CODEX_HOME/backups_model" -name '*.toml' | wc -l)" -ge 2
output="$(printf '1\nq\nq\n' | bash linux/codex-switch 2>&1)"
test "$(grep -o '模型切换' <<< "$output" | wc -l)" -eq 1

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *'/VERSION'*) printf '0.2.3\n' ;;
    *'/releases/latest') printf '%s\n' '{"tag_name":"v0.2.0"}' ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$fake_bin/curl"
sed 's/@VERSION@/0.2.2/' linux/codex-switch > "$test_root/codex-switch"
if output="$(PATH="$fake_bin:$PATH" bash "$test_root/codex-switch" update 2>&1)"; then
    exit 1
fi
grep -q '找不到资产 codex-switch-linux.zip' <<< "$output"

echo 'Linux 端到端切换测试通过'
