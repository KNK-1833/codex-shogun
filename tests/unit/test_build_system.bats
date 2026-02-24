#!/usr/bin/env bats
# test_build_system.bats — ビルドシステム（build_instructions.sh）ユニットテスト
#
# テスト構成:
#   - ビルド実行テスト: スクリプト正常終了、ディレクトリ生成
#   - ファイル生成テスト: codex各ロールの生成確認
#   - 内容検証テスト: 空でないこと、ロール名・CLI固有セクション含有
#   - AGENTS.md 存在テスト
#   - 冪等性テスト: 2回ビルドで差分なし

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export BUILD_SCRIPT="$PROJECT_ROOT/scripts/build_instructions.sh"
    export OUTPUT_DIR="$PROJECT_ROOT/instructions/generated"

    # パーツディレクトリの存在確認（前提条件）
    [ -d "$PROJECT_ROOT/instructions/roles" ] || return 1
    [ -d "$PROJECT_ROOT/instructions/common" ] || return 1
    [ -d "$PROJECT_ROOT/instructions/cli_specific" ] || return 1

    # ビルド実行（全テストの前に1回のみ）
    bash "$BUILD_SCRIPT" > /dev/null 2>&1 || true
}

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    BUILD_SCRIPT="$PROJECT_ROOT/scripts/build_instructions.sh"
    OUTPUT_DIR="$PROJECT_ROOT/instructions/generated"
}

# =============================================================================
# ビルド実行テスト
# =============================================================================

@test "build: build_instructions.sh exits with status 0" {
    run bash "$BUILD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "build: generated/ directory exists after build" {
    [ -d "$OUTPUT_DIR" ]
}

@test "build: generated/ contains at least 4 files" {
    local count
    count=$(find "$OUTPUT_DIR" -name "*.md" -type f | wc -l)
    [ "$count" -ge 4 ]
}

# =============================================================================
# ファイル生成テスト — Codex
# =============================================================================

@test "codex: codex-shogun.md generated" {
    [ -f "$OUTPUT_DIR/codex-shogun.md" ]
}

@test "codex: codex-karo.md generated" {
    [ -f "$OUTPUT_DIR/codex-karo.md" ]
}

@test "codex: codex-ashigaru.md generated" {
    [ -f "$OUTPUT_DIR/codex-ashigaru.md" ]
}

# =============================================================================
# 内容検証テスト — 空でないこと
# =============================================================================

@test "content: codex-shogun.md is not empty" {
    [ -s "$OUTPUT_DIR/codex-shogun.md" ]
}

@test "content: codex-karo.md is not empty" {
    [ -s "$OUTPUT_DIR/codex-karo.md" ]
}

@test "content: codex-ashigaru.md is not empty" {
    [ -s "$OUTPUT_DIR/codex-ashigaru.md" ]
}

# =============================================================================
# 内容検証テスト — ロール名含有
# =============================================================================

@test "content: codex-shogun.md contains shogun role reference" {
    grep -qi "shogun\|将軍" "$OUTPUT_DIR/codex-shogun.md"
}

@test "content: codex-karo.md contains karo role reference" {
    grep -qi "karo\|家老" "$OUTPUT_DIR/codex-karo.md"
}

@test "content: codex-ashigaru.md contains ashigaru role reference" {
    grep -qi "ashigaru\|足軽" "$OUTPUT_DIR/codex-ashigaru.md"
}

# =============================================================================
# 内容検証テスト — CLI固有セクション
# =============================================================================

@test "content: codex files contain Codex-specific content" {
    grep -qi "codex\|AGENTS.md\|Codex" "$OUTPUT_DIR/codex-shogun.md"
}

# =============================================================================
# AGENTS.md テスト
# =============================================================================

@test "agents: AGENTS.md exists" {
    [ -f "$PROJECT_ROOT/AGENTS.md" ]
}

@test "agents: AGENTS.md contains Codex-specific content" {
    [ -f "$PROJECT_ROOT/AGENTS.md" ] && grep -qi "codex\|agent" "$PROJECT_ROOT/AGENTS.md"
}

# =============================================================================
# Codex /clear → /new 変換テスト
# =============================================================================
# Codex CLIは/clearでセッション終了するため、AGENTS.mdおよびcodex-*.mdで
# /clearが命令として残存していないことを検証する。
# 比較表や変換説明の文脈での/clear言及はOK。

@test "codex-clear: AGENTS.md has no /clear Recovery section" {
    # /clear Recoveryは/new Recoveryに変換されるべき
    run grep -c "## /clear Recovery" "$PROJECT_ROOT/AGENTS.md"
    [ "$output" = "0" ]
}

@test "codex-clear: AGENTS.md has /new Recovery section" {
    grep -q "## /new Recovery" "$PROJECT_ROOT/AGENTS.md"
}

@test "codex-clear: AGENTS.md has no 'Forbidden after /clear'" {
    run grep -c "Forbidden after /clear" "$PROJECT_ROOT/AGENTS.md"
    [ "$output" = "0" ]
}

@test "codex-clear: AGENTS.md has no 'sends \`/clear\` + Enter via send-keys' (unconverted)" {
    # 変換済みは「sends /new + Enter」になっているべき
    run grep -c 'sends `/clear` + Enter via send-keys$' "$PROJECT_ROOT/AGENTS.md"
    [ "$output" = "0" ]
}

@test "codex-clear: AGENTS.md has no 'delivers \`/clear\` to the agent' (unconverted)" {
    # 変換済みは「delivers /new to the agent」になっているべき
    run grep -c 'delivers `/clear` to the agent →' "$PROJECT_ROOT/AGENTS.md"
    [ "$output" = "0" ]
}

@test "codex-clear: AGENTS.md has no '/clear wipes old context'" {
    run grep -c '`/clear` wipes old context' "$PROJECT_ROOT/AGENTS.md"
    [ "$output" = "0" ]
}

@test "codex-clear: codex-ashigaru.md has no bare '/clear' in escalation table" {
    # 比較表(codex_tools.md由来)以外で/clearが命令として現れないこと
    # エスカレーション行に「/clear sent」があればNG
    run grep -c '`/clear` sent (max once' "$OUTPUT_DIR/codex-ashigaru.md"
    [ "$output" = "0" ]
}

@test "codex-clear: codex-ashigaru.md protocol uses CLI-neutral context reset" {
    # protocol.mdのclear_command行がCLI中立表現になっていること
    grep -q "context reset command via send-keys" "$OUTPUT_DIR/codex-ashigaru.md"
}

@test "codex-clear: codex-karo.md has no bare '/clear' in redo protocol" {
    # Redo Protocolで「delivers /clear to the agent →」がそのまま残っていないこと
    run grep -c 'delivers `/clear` to the agent →' "$OUTPUT_DIR/codex-karo.md"
    [ "$output" = "0" ]
}

@test "codex-clear: codex-gunshi.md protocol uses CLI-neutral context reset" {
    grep -q "context reset command via send-keys" "$OUTPUT_DIR/codex-gunshi.md"
}

@test "codex-clear: codex-shogun.md protocol uses CLI-neutral context reset" {
    grep -q "context reset command via send-keys" "$OUTPUT_DIR/codex-shogun.md"
}

# =============================================================================
# 冪等性テスト
# =============================================================================

@test "idempotent: second build produces identical output" {
    # 1st build
    bash "$BUILD_SCRIPT" > /dev/null 2>&1
    local checksums_first
    checksums_first=$(find "$OUTPUT_DIR" -name "*.md" -type f -exec md5sum {} \; | sort)

    # 2nd build
    bash "$BUILD_SCRIPT" > /dev/null 2>&1
    local checksums_second
    checksums_second=$(find "$OUTPUT_DIR" -name "*.md" -type f -exec md5sum {} \; | sort)

    [ "$checksums_first" = "$checksums_second" ]
}
