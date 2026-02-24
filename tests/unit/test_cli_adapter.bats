#!/usr/bin/env bats
# test_cli_adapter.bats — cli_adapter.sh ユニットテスト
# Multi-CLI統合設計書 §4.1 準拠

# --- セットアップ ---

setup() {
    # テスト用のtmpディレクトリ
    TEST_TMP="$(mktemp -d)"

    # プロジェクトルート
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # デフォルトsettings（cliセクションなし = 後方互換テスト）
    cat > "${TEST_TMP}/settings_none.yaml" << 'YAML'
language: ja
shell: bash
display_mode: shout
YAML

    # claude only settings
    cat > "${TEST_TMP}/settings_claude_only.yaml" << 'YAML'
cli:
  default: claude
YAML

    # mixed CLI settings (dict形式)
    cat > "${TEST_TMP}/settings_mixed.yaml" << 'YAML'
cli:
  default: claude
  agents:
    shogun:
      type: claude
      model: opus
    karo:
      type: claude
      model: opus
    ashigaru1:
      type: claude
      model: sonnet
    ashigaru2:
      type: claude
      model: sonnet
    ashigaru3:
      type: claude
      model: sonnet
    ashigaru4:
      type: claude
      model: sonnet
    ashigaru5:
      type: codex
    ashigaru6:
      type: codex
YAML

    # 文字列形式のagent設定
    cat > "${TEST_TMP}/settings_string_agents.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru5: codex
YAML

    # 不正CLI名
    cat > "${TEST_TMP}/settings_invalid_cli.yaml" << 'YAML'
cli:
  default: claudee
  agents:
    ashigaru1: invalid_cli
YAML

    # codexデフォルト
    cat > "${TEST_TMP}/settings_codex_default.yaml" << 'YAML'
cli:
  default: codex
YAML

    # 空ファイル
    cat > "${TEST_TMP}/settings_empty.yaml" << 'YAML'
YAML

    # YAML構文エラー
    cat > "${TEST_TMP}/settings_broken.yaml" << 'YAML'
cli:
  default: [broken yaml
  agents: {{invalid
YAML

    # モデル指定付き
    cat > "${TEST_TMP}/settings_with_models.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: haiku
    ashigaru5:
      type: codex
      model: gpt-5
models:
  karo: sonnet
YAML
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ヘルパー: 特定のsettings.yamlでcli_adapterをロード
load_adapter_with() {
    local settings_file="$1"
    export CLI_ADAPTER_SETTINGS="$settings_file"
    source "${PROJECT_ROOT}/lib/cli_adapter.sh"
}

# =============================================================================
# get_cli_type テスト
# =============================================================================

# --- 正常系 ---

@test "get_cli_type: cliセクションなし → codex (後方互換)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "codex" ]
}

@test "get_cli_type: claude only設定 → claude" {
    load_adapter_with "${TEST_TMP}/settings_claude_only.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: mixed設定 shogun → claude" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "claude" ]
}

@test "get_cli_type: mixed設定 ashigaru5 → codex" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "ashigaru5")
    [ "$result" = "codex" ]
}

@test "get_cli_type: mixed設定 ashigaru1 → claude (個別設定)" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: 文字列形式 ashigaru5 → codex" {
    load_adapter_with "${TEST_TMP}/settings_string_agents.yaml"
    result=$(get_cli_type "ashigaru5")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 未定義agent → default継承" {
    load_adapter_with "${TEST_TMP}/settings_codex_default.yaml"
    result=$(get_cli_type "ashigaru3")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 空agent_id → codex" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "")
    [ "$result" = "codex" ]
}

# --- 全ashigaru パターン ---

@test "get_cli_type: mixed設定 ashigaru1-6全パターン" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    [ "$(get_cli_type ashigaru1)" = "claude" ]
    [ "$(get_cli_type ashigaru2)" = "claude" ]
    [ "$(get_cli_type ashigaru3)" = "claude" ]
    [ "$(get_cli_type ashigaru4)" = "claude" ]
    [ "$(get_cli_type ashigaru5)" = "codex" ]
    [ "$(get_cli_type ashigaru6)" = "codex" ]
}

# --- エラー系 ---

@test "get_cli_type: 不正CLI名 → codex フォールバック" {
    load_adapter_with "${TEST_TMP}/settings_invalid_cli.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 不正default → codex フォールバック" {
    load_adapter_with "${TEST_TMP}/settings_invalid_cli.yaml"
    result=$(get_cli_type "karo")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 空YAMLファイル → codex" {
    load_adapter_with "${TEST_TMP}/settings_empty.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "codex" ]
}

@test "get_cli_type: YAML構文エラー → codex" {
    load_adapter_with "${TEST_TMP}/settings_broken.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 存在しないファイル → codex" {
    load_adapter_with "/nonexistent/path/settings.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "codex" ]
}

# =============================================================================
# build_cli_command テスト
# =============================================================================

@test "build_cli_command: claude + model → claude --model opus --dangerously-skip-permissions" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "shogun")
    [ "$result" = "claude --model opus --dangerously-skip-permissions" ]
}

@test "build_cli_command: codex + default model → codex --model o3 ..." {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "ashigaru5")
    [ "$result" = "codex --model o3 --search --dangerously-bypass-approvals-and-sandbox --no-alt-screen" ]
}

@test "build_cli_command: cliセクションなし → codex フォールバック" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(build_cli_command "ashigaru1")
    [[ "$result" == codex*--dangerously-bypass-approvals-and-sandbox* ]]
}

@test "build_cli_command: settings読取失敗 → codex フォールバック" {
    load_adapter_with "/nonexistent/settings.yaml"
    result=$(build_cli_command "ashigaru1")
    [[ "$result" == codex*--dangerously-bypass-approvals-and-sandbox* ]]
}

# =============================================================================
# get_instruction_file テスト
# =============================================================================

@test "get_instruction_file: shogun + claude → instructions/shogun.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "shogun")
    [ "$result" = "instructions/shogun.md" ]
}

@test "get_instruction_file: karo + claude → instructions/karo.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "karo")
    [ "$result" = "instructions/karo.md" ]
}

@test "get_instruction_file: ashigaru1 + claude → instructions/ashigaru.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "ashigaru1")
    [ "$result" = "instructions/ashigaru.md" ]
}

@test "get_instruction_file: ashigaru5 + codex → instructions/generated/codex-ashigaru.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "ashigaru5")
    [ "$result" = "instructions/generated/codex-ashigaru.md" ]
}

@test "get_instruction_file: cli_type引数で明示指定 (codex)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_instruction_file "shogun" "codex")
    [ "$result" = "instructions/generated/codex-shogun.md" ]
}

@test "get_instruction_file: 全CLI × 全role組み合わせ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # claude
    [ "$(get_instruction_file shogun claude)" = "instructions/shogun.md" ]
    [ "$(get_instruction_file karo claude)" = "instructions/karo.md" ]
    [ "$(get_instruction_file ashigaru1 claude)" = "instructions/ashigaru.md" ]
    # codex
    [ "$(get_instruction_file shogun codex)" = "instructions/generated/codex-shogun.md" ]
    [ "$(get_instruction_file karo codex)" = "instructions/generated/codex-karo.md" ]
    [ "$(get_instruction_file ashigaru3 codex)" = "instructions/generated/codex-ashigaru.md" ]
}

@test "get_instruction_file: 不明なagent_id → 空文字 + return 1" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run get_instruction_file "unknown_agent"
    [ "$status" -eq 1 ]
}

# =============================================================================
# validate_cli_availability テスト
# =============================================================================

@test "validate_cli_availability: claude → 0 (インストール済み)" {
    command -v claude >/dev/null 2>&1 || skip "claude not installed (CI environment)"
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability "claude"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: 不正CLI名 → 1 + エラーメッセージ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability "invalid_type"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown CLI type"* ]]
}

@test "validate_cli_availability: 空文字 → 1" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability ""
    [ "$status" -eq 1 ]
}

@test "validate_cli_availability: codex mock (PATH操作)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # モックcodexコマンドを作成
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/codex"
    chmod +x "${TEST_TMP}/bin/codex"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "codex"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: codex未インストール → 1 + エラーメッセージ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # PATHからcodexを除外（空PATHは危険なのでminimal PATHを設定）
    PATH="/usr/bin:/bin" run validate_cli_availability "codex"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Codex CLI not found"* ]]
}

# =============================================================================
# get_agent_model テスト
# =============================================================================

@test "get_agent_model: cliセクションなし shogun → o3 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "shogun")
    [ "$result" = "o3" ]
}

@test "get_agent_model: cliセクションなし karo → o3 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "karo")
    [ "$result" = "o3" ]
}

@test "get_agent_model: cliセクションなし ashigaru1 → o3 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "ashigaru1")
    [ "$result" = "o3" ]
}

@test "get_agent_model: cliセクションなし ashigaru5 → o3 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "ashigaru5")
    [ "$result" = "o3" ]
}

@test "get_agent_model: YAML指定 ashigaru1 → haiku (オーバーライド)" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "ashigaru1")
    [ "$result" = "haiku" ]
}

@test "get_agent_model: modelsセクションから取得 karo → sonnet" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "karo")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: codexエージェントのmodel ashigaru5 → gpt-5" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "ashigaru5")
    [ "$result" = "gpt-5" ]
}

@test "get_agent_model: 未知agent → o3 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "unknown_agent")
    [ "$result" = "o3" ]
}

# =============================================================================
# get_model_display_name テスト
# =============================================================================

@test "get_model_display_name: Sonnet + thinking:true → Sonnet+T" {
    cat > "${TEST_TMP}/settings_display.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: claude-sonnet-4-6
      thinking: true
YAML
    load_adapter_with "${TEST_TMP}/settings_display.yaml"
    result=$(get_model_display_name "ashigaru1")
    [ "$result" = "Sonnet+T" ]
}

@test "get_model_display_name: Opus + thinking:true → Opus+T" {
    cat > "${TEST_TMP}/settings_display.yaml" << 'YAML'
cli:
  default: claude
  agents:
    gunshi:
      type: claude
      model: claude-opus-4-6
      thinking: true
YAML
    load_adapter_with "${TEST_TMP}/settings_display.yaml"
    result=$(get_model_display_name "gunshi")
    [ "$result" = "Opus+T" ]
}

@test "get_model_display_name: Haiku + thinking:false → Haiku" {
    cat > "${TEST_TMP}/settings_display.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru2:
      type: claude
      model: claude-haiku-4-5-20251001
      thinking: false
YAML
    load_adapter_with "${TEST_TMP}/settings_display.yaml"
    result=$(get_model_display_name "ashigaru2")
    [ "$result" = "Haiku" ]
}

@test "get_model_display_name: Sonnet + thinking未設定 → Sonnet (no +T)" {
    cat > "${TEST_TMP}/settings_display.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru3:
      type: claude
      model: claude-sonnet-4-6
YAML
    load_adapter_with "${TEST_TMP}/settings_display.yaml"
    result=$(get_model_display_name "ashigaru3")
    [ "$result" = "Sonnet" ]
}

@test "get_model_display_name: Codex Spark → Spark (thinking無関係)" {
    cat > "${TEST_TMP}/settings_display.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru4:
      type: codex
      model: gpt-5.3-codex-spark
YAML
    load_adapter_with "${TEST_TMP}/settings_display.yaml"
    result=$(get_model_display_name "ashigaru4")
    [ "$result" = "Spark" ]
}

@test "get_model_display_name: Codex 5.3 → Codex" {
    cat > "${TEST_TMP}/settings_display.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru5:
      type: codex
      model: gpt-5.3-codex
YAML
    load_adapter_with "${TEST_TMP}/settings_display.yaml"
    result=$(get_model_display_name "ashigaru5")
    [ "$result" = "Codex" ]
}

@test "get_model_display_name: 全モデル × thinking組み合わせ" {
    cat > "${TEST_TMP}/settings_display_all.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: claude-sonnet-4-6
      thinking: true
    ashigaru2:
      type: claude
      model: claude-opus-4-6
      thinking: false
    ashigaru3:
      type: claude
      model: claude-haiku-4-5-20251001
      thinking: true
    ashigaru4:
      type: codex
      model: gpt-5.3-codex-spark
    ashigaru5:
      type: codex
      model: gpt-5.3-codex
YAML
    load_adapter_with "${TEST_TMP}/settings_display_all.yaml"
    [ "$(get_model_display_name ashigaru1)" = "Sonnet+T" ]
    [ "$(get_model_display_name ashigaru2)" = "Opus" ]
    [ "$(get_model_display_name ashigaru3)" = "Haiku+T" ]
    [ "$(get_model_display_name ashigaru4)" = "Spark" ]
    [ "$(get_model_display_name ashigaru5)" = "Codex" ]
}

# =============================================================================
# build_cli_command Thinking制御テスト
# =============================================================================

@test "build_cli_command: thinking:true → MAX_THINKING_TOKENS=0 なし" {
    cat > "${TEST_TMP}/settings_thinking.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: claude-sonnet-4-6
      thinking: true
YAML
    load_adapter_with "${TEST_TMP}/settings_thinking.yaml"
    result=$(build_cli_command "ashigaru1")
    [ "$result" = "claude --model claude-sonnet-4-6 --dangerously-skip-permissions" ]
}

@test "build_cli_command: thinking:false → MAX_THINKING_TOKENS=0 prefix" {
    cat > "${TEST_TMP}/settings_thinking.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: claude-sonnet-4-6
      thinking: false
YAML
    load_adapter_with "${TEST_TMP}/settings_thinking.yaml"
    result=$(build_cli_command "ashigaru1")
    [ "$result" = "MAX_THINKING_TOKENS=0 claude --model claude-sonnet-4-6 --dangerously-skip-permissions" ]
}

@test "build_cli_command: thinking未設定 → MAX_THINKING_TOKENS=0 なし (デフォルトThinking ON)" {
    cat > "${TEST_TMP}/settings_thinking.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: claude-sonnet-4-6
YAML
    load_adapter_with "${TEST_TMP}/settings_thinking.yaml"
    result=$(build_cli_command "ashigaru1")
    [ "$result" = "claude --model claude-sonnet-4-6 --dangerously-skip-permissions" ]
}

@test "build_cli_command: codex + thinking:false → MAX_THINKING_TOKENS=0 なし (Codexには無関係)" {
    cat > "${TEST_TMP}/settings_thinking.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru5:
      type: codex
      model: gpt-5.3-codex
      thinking: false
YAML
    load_adapter_with "${TEST_TMP}/settings_thinking.yaml"
    result=$(build_cli_command "ashigaru5")
    [[ "$result" != MAX_THINKING_TOKENS* ]]
    [[ "$result" == codex* ]]
}
