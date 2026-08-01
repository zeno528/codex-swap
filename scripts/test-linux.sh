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
output="$(bash linux/codex-switch current)"
grep -q deepseek-v4-flash <<< "$output"
output="$(bash linux/codex-switch doctor)"
grep -q '通过 7 / 7' <<< "$output"

output="$(bash linux/codex-switch use gpt)"
grep -q '已切换到: gpt' <<< "$output"
cmp "$test_root/deepseek-before.toml" "$CODEX_HOME/model-states/deepseek.toml"
grep -q 'gpt-5.6-terra' "$CODEX_HOME/config.toml"

printf '%s\n' 'trusted_project = "test-project"' >> "$CODEX_HOME/config.toml"
output="$(bash linux/codex-switch use deepseek)"
grep -q '已切换到: deepseek' <<< "$output"
grep -q 'trusted_project = "test-project"' "$CODEX_HOME/model-states/gpt.toml"
cmp "$test_root/deepseek-before.toml" "$CODEX_HOME/config.toml"
test "$(find "$CODEX_HOME/backups_model" -name '*.toml' | wc -l)" -ge 2

echo 'Linux 端到端切换测试通过'
