#!/usr/bin/env bash
# lib/agent_status.sh — エージェント稼働状態検出の共有ライブラリ
#
# 提供関数:
#   agent_is_busy_check <pane_target>   → 0=busy, 1=idle, 2=pane不在
#   get_pane_state_label <pane_target>  → "稼働中" / "待機中" / "不在"
#
# 使用例:
#   source lib/agent_status.sh
#   agent_is_busy_check "multiagent:agents.0"
#   state=$(get_pane_state_label "multiagent:agents.3")

# agent_is_busy_check <pane_target>
# tmux paneの末尾5行からCLI固有のidle/busyパターンを検出する。
# Returns: 0=busy, 1=idle, 2=pane不在
#
# Detection strategy (Codex-primary):
#   1. Idle checks: Codex '? for shortcuts' / 'context left' prompts
#   2. Text-based busy markers: spinner keywords in bottom 5 lines
#   3. Fallback: default to idle
agent_is_busy_check() {
    local pane_target="$1"
    local pane_tail
    # Only check the bottom 5 lines. Old busy markers linger in scroll-back
    # and cause false-busy if we scan too many lines.
    pane_tail=$(timeout 2 tmux capture-pane -t "$pane_target" -p 2>/dev/null | tail -5)

    # Pane doesn't exist or empty capture
    if [[ -z "$pane_tail" ]]; then
        return 2
    fi

    # ── Idle checks ──
    # Codex idle prompt (primary)
    if echo "$pane_tail" | grep -qE '(\? for shortcuts|context left)'; then
        return 1
    fi

    # ── Text-based busy markers (bottom 5 lines) ──
    if echo "$pane_tail" | grep -qiF 'background terminal running'; then
        return 0
    fi
    if echo "$pane_tail" | grep -qiE '(Working|Thinking|Planning|Sending|task is in progress|Compacting conversation|thought for|思考中|考え中|計画中|送信中|処理中|実行中)'; then
        return 0
    fi

    return 1  # idle (default)
}

# get_pane_state_label <pane_target>
# 人間が読めるラベルを返す。
get_pane_state_label() {
    local pane_target="$1"
    agent_is_busy_check "$pane_target"
    local rc=$?
    case $rc in
        0) echo "稼働中" ;;
        1) echo "待機中" ;;
        2) echo "不在" ;;
    esac
}
