# Codex完結化 移行計画書

## 概要

multi-agent-shogunをClaude Code前提からOpenAI Codex CLI完結の機構にカスタムするための監査結果と修正計画。

現状: CLAUDE.mdを正本（Single Source of Truth）とし、build_instructions.shでAGENTS.md等を自動生成するマルチCLI対応アーキテクチャ。Claude Code固有の機能に深く依存している箇所が多数存在する。

目標: AGENTS.mdを正本に反転し、Codex CLI単独で全機能が動作する構成にする。

---

## 1. Claude Code依存の全箇所一覧

### カテゴリA: 正本ファイル構造（CLAUDE.md中心設計）

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `CLAUDE.md` | 現在の正本。Session Start手順、通信プロトコル、全ルールの原典 | **致命的** |
| `AGENTS.md` | CLAUDE.mdからsed変換で自動生成。二次データ扱い | **致命的** |
| `scripts/build_instructions.sh` | CLAUDE.md→AGENTS.md変換ロジック（generate_agents_md関数） | **致命的** |
| `.github/copilot-instructions.md` | CLAUDE.mdから自動生成 | 低（Codex不要） |
| `agents/default/system.md` | CLAUDE.mdから自動生成（Kimi用） | 低（Codex不要） |

### カテゴリB: Stop Hook（Claude Code固有機能）

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `scripts/stop_hook_inbox.sh` | Claude Code Stop Hookでturn終了時にinbox未読を検出しブロック | **高** |
| `.claude/settings.json` | Stop Hookの登録、permissions deny list、spinnerVerbs | **高** |
| `instructions/cli_specific/claude_tools.md` | Stop Hook説明、/clearプロトコル、Compaction Recovery手順 | 中 |

### カテゴリC: /clear vs /new（セッションリセット）

| ファイル | 依存箇所 | 影響度 |
|----------|----------|--------|
| `CLAUDE.md` | `/clear Recovery`セクション、Redo Protocol、Escalation Phase 3 | **高** |
| `scripts/inbox_watcher.sh` | `send_cli_command()`内の`/clear`→`/new`変換ロジック | 既に対応済み |
| `instructions/common/protocol.md` | `clear_command`→コンテキストリセットの説明 | 中 |
| `instructions/common/task_flow.md` | Batch Processing Protocol内の`/new or /clear`参照 | 低 |

### カテゴリD: MCP（Memory MCPへの依存）

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `CLAUDE.md` | Session Start Step 2: `mcp__memory__read_graph` | **高** |
| `instructions/cli_specific/claude_tools.md` | Memory MCP使用ガイド（create_entities, add_observations） | 中 |
| `instructions/cli_specific/codex_tools.md` | 「No Memory MCP equivalent」と明記済み | 対応済み |
| `instructions/roles/*.md` | shogun/karo/gunshiの回復手順でmcp__memory参照 | **高** |

### カテゴリE: Claude Codeツール名参照

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `CLAUDE.md` L149 | `use Edit tool`（inbox処理プロトコル） | 低（Codexにも同等機能あり） |
| `CLAUDE.md` L185 | `Claude Code rejects Write/Edit on unread files` | 低 |
| `instructions/cli_specific/claude_tools.md` | Read/Write/Edit/Bash/Glob/Grep/Task/WebFetch/WebSearch | 中 |
| `instructions/common/forbidden_actions.md` | `F003: Use Task agents` | 低 |

### カテゴリF: tmux + send-keys連携

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `scripts/inbox_watcher.sh` | tmux send-keysによるnudge配信、CLI種別判定 | 既にMulti-CLI対応済み |
| `lib/agent_status.sh` | Claude Code `❯` プロンプト検出、`esc to` ステータスバー検出 | **高** |
| `shutsujin_departure.sh` | CLI起動コマンド構築、tmuxセッション作成 | 既にMulti-CLI対応済み |
| `scripts/switch_cli.sh` | ランタイムCLI切り替え | 既にMulti-CLI対応済み |

### カテゴリG: agent_is_busy検出

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `lib/agent_status.sh` | Claude Code: `❯`プロンプト検出、`esc to interrupt`ステータスバー | **高** |
| | Codex: `? for shortcuts`、`context left`検出 | 既にCodex対応あり |
| `scripts/inbox_watcher.sh` | `agent_has_self_watch()`: Claude Codeのみself-watchサポート | 中 |

### カテゴリH: CLI Adapter（マルチCLI抽象化層）

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `lib/cli_adapter.sh` | デフォルトフォールバック全て`"claude"` | **高** |
| | `build_cli_command()`: claude→`--dangerously-skip-permissions` | 中 |
| | `can_model_switch()`: claude="full", codex="limited" | 低 |
| | `get_startup_prompt()`: codex用プロンプトあり、claude=空 | 既にCodex対応 |

### カテゴリI: 指示書ビルドシステム

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `scripts/build_instructions.sh` | claude用をベースにcodex/copilot/kimi版を生成 | **高** |
| `instructions/generated/*.md` | 自動生成ファイル。claude版/codex版の両方が存在 | 中 |
| `instructions/cli_specific/codex_tools.md` | Codex固有ツール・制約の説明（既に充実） | 対応済み |

### カテゴリJ: テスト

| ファイル | 依存内容 | 影響度 |
|----------|----------|--------|
| `tests/e2e/e2e_codex_startup.bats` | Codex起動テスト（既存） | 対応済み |
| `tests/e2e/mock_behaviors/claude_behavior.sh` | Claude Codeモック | 低 |
| `tests/e2e/mock_behaviors/codex_behavior.sh` | Codexモック（既存） | 対応済み |
| `tests/unit/test_cli_adapter.bats` | CLI Adapterのユニットテスト | 修正必要 |

---

## 2. 修正計画（フェーズ別）

### Phase 1: 正本の反転（AGENTS.md → 正本化）

**目的**: CLAUDE.mdを正本ではなくAGENTS.mdを正本にし、ビルド方向を逆転する。

#### 1.1 AGENTS.mdを正本に昇格
- 現在のAGENTS.md（Codex向け自動生成版）の内容を確認・精査
- Claude Code固有の残存（Memory MCP参照等）を除去
- `/clear` → `/new`への統一（現在は既にsed変換済みだが、正本として明示化）

#### 1.2 build_instructions.shの方向を逆転
- **現在**: CLAUDE.md → sed → AGENTS.md
- **変更後**: AGENTS.md → sed → CLAUDE.md（互換維持のため生成は残す。不要なら削除）
- もしくはCLAUDE.md生成を廃止し、AGENTS.md一本化

#### 1.3 CLAUDE.md の取り扱い
- 選択肢A: 削除してAGENTS.mdに一本化（Codex完結）
- 選択肢B: AGENTS.md正本 → CLAUDE.mdを自動生成（Claude Code互換維持）
- **推奨**: 選択肢A（Codex完結がゴールなので）

### Phase 2: Stop Hook代替メカニズム

**目的**: Claude Code Stop Hookの機能をCodex CLIで再現する。

Stop Hookの2つの機能:
1. **タスク完了検出** → karoへの自動通知
2. **inbox未読ブロック** → idle前にinboxを強制処理

#### 2.1 タスク完了検出の代替
- **案A**: inbox_watcher.shのtimeout周期でcapture-paneを監視し、完了パターンを検出
- **案B**: Codex ashigaruのinstructions内で「完了時は必ずinbox_writeでkaroに通知」を強化（現在も指示あり）
- **推奨**: 案B（capture-paneは信頼性が低い。指示書の強化が低コスト）

#### 2.2 inbox未読ブロックの代替
- **案A**: inbox_watcher.shのnudge間隔を短縮し、idle検出→即nudge
- **案B**: Codexの「MANDATORY Post-Task Inbox Check」指示を強化
- **案C**: `codex exec`モードを使い、タスク完了→新invocation→inbox処理のサイクルにする
- **推奨**: 案A+B併用（nudgeベースの配信 + 指示書強化）

#### 2.3 `.claude/settings.json`の整理
- Stop Hook登録を削除（Codexでは不要）
- permissions deny list → AGENTS.md内のDestructive Operation Safetyで担保
- spinnerVerbs → Codexには該当機能なし。削除or別用途

### Phase 3: Memory MCP代替

**目的**: `mcp__memory__read_graph`への依存を排除する。

#### 3.1 Session Start手順の簡素化
- **現在**: Step 2で`mcp__memory__read_graph`を呼び出し（shogun/karo/gunshi）
- **変更**: Step 2を「AGENTS.md + queue/YAMLファイルから状態復元」に置換
- Memory MCPで保存していた情報（preferences, rules, lessons）は:
  - `config/settings.yaml`に設定値として統合
  - `context/`ディレクトリにプロジェクト知識としてファイル化
  - `AGENTS.md`内にルール・制約として直接記載

#### 3.2 MCP設定の整理
- Codexは`~/.codex/config.toml`でMCPサーバーを設定可能
- Memory MCPが必要な場合はCodexのMCP経由で利用可能（ただしCodex完結を目指すなら不要）
- **推奨**: MCP依存を排除し、ファイルベースの永続化に完全移行

### Phase 4: agent_is_busy検出の最適化

**目的**: Claude Code固有のプロンプト検出を除去し、Codex検出を強化する。

#### 4.1 lib/agent_status.shの修正
- Claude Code `❯`プロンプト検出 → 削除or残存（互換）
- Claude Code `esc to interrupt`ステータスバー → 削除or残存
- Codex `? for shortcuts` / `context left` → メイン検出として強化
- Codex busyパターンの追加検証が必要（`Thinking`, `Sending`等のCodex版確認）

#### 4.2 agent_has_self_watchの扱い
- 現在「Claude Codeのみself-watchサポート」
- Codex完結ならself-watch概念自体が不要 → 関数をno-opにするか削除

### Phase 5: CLI Adapterのデフォルト変更

**目的**: フォールバックをclaude→codexに変更。

#### 5.1 lib/cli_adapter.shの修正
- `get_cli_type()`: フォールバック `"claude"` → `"codex"`
- `build_cli_command()`: デフォルトcase `"claude --dangerously-skip-permissions"` → `"codex --search --dangerously-bypass-approvals-and-sandbox --no-alt-screen"`
- `validate_cli_availability()`: デフォルトチェック対象をcodexに
- `get_agent_model()`: Claude固有モデル名（opus/sonnet/haiku）→ Codex互換モデル名

#### 5.2 shutsujin_departure.shの修正
- Claude Code起動待ち検出（`bypass permissions`文字列検出）→ Codex起動検出に変更
- ヘルプテキスト・コメント中の「Claude Code」参照を「Codex CLI」に更新
- デフォルトCLIコマンド構築のフォールバックをcodexに

### Phase 6: 指示書テンプレート再構成

**目的**: Codex版指示書をメインにし、ビルドシステムを簡素化。

#### 6.1 テンプレート構造
- `instructions/roles/*.md` → 変更不要（CLI非依存の役割定義）
- `instructions/common/*.md` → Claude Code固有参照の除去
  - `protocol.md`: `Claude Code rejects Write/Edit on unread files` → Codex表現に
  - `forbidden_actions.md`: `Use Task agents` → Codex文脈での同等制約
- `instructions/cli_specific/codex_tools.md` → メインツール説明として維持

#### 6.2 ビルドシステムの簡素化
- AGENTS.md → 直接編集可能な正本に（自動生成を廃止）
- `instructions/generated/codex-*.md` → メイン指示書に昇格
- claude版/copilot版/kimi版 → 不要なら生成を廃止

### Phase 7: テスト更新

#### 7.1 ユニットテスト
- `tests/unit/test_cli_adapter.bats`: デフォルトCLI変更に伴うテスト修正
- `tests/unit/test_stop_hook.bats`: Stop Hook廃止なら削除
- `tests/unit/test_send_wakeup.bats`: Claude固有パスの期待値修正

#### 7.2 E2Eテスト
- `tests/e2e/e2e_clear_recovery.bats`: `/clear`→`/new`への統一
- `tests/e2e/e2e_codex_startup.bats`: メインテストとして強化
- Claude固有E2Eテスト → 削除or skip

### Phase 8: 不要ファイルの整理

削除候補:
- `.claude/settings.json` → Codex完結なら不要
- `instructions/cli_specific/claude_tools.md` → 不要（正本がcodex_tools.md）
- `instructions/generated/shogun.md` etc. (claude版) → 不要
- `instructions/generated/copilot-*.md`, `instructions/generated/kimi-*.md` → Codex完結なら不要
- `tests/e2e/mock_behaviors/claude_behavior.sh` → 不要
- `.github/copilot-instructions.md` → 不要
- `agents/default/` (Kimi用) → 不要

残す候補:
- `lib/cli_adapter.sh` → codex固定でも他CLI復活時の拡張ポイントとして残す価値あり
- `scripts/inbox_watcher.sh` → Multi-CLI分岐はCodex固定でもリファクタリング後に残す

---

## 3. 優先順位と依存関係

```
Phase 1 (正本反転)
  ↓
Phase 2 (Stop Hook代替) ←→ Phase 3 (Memory MCP代替)
  ↓
Phase 4 (busy検出) + Phase 5 (CLI Adapter)
  ↓
Phase 6 (指示書再構成)
  ↓
Phase 7 (テスト) + Phase 8 (整理)
```

Phase 1が最も重要。正本がCLAUDE.mdのままだと、他の全変更がsed変換で上書きされるリスクがある。

---

## 4. リスク・注意点

1. **AGENTS.mdの32KiB制限**: Codex CLIの`project_doc_max_bytes`デフォルトは32KiB。現在のCLAUDE.mdは大きいため、AGENTS.mdに移行時にサイズ超過する可能性あり → `config.toml`で`project_doc_max_bytes = 65536`に設定する対策
2. **Codexの/newの挙動差異**: `/clear`（Claude Code）はCLAUDE.mdを再読み込みするが、`/new`（Codex）はAGENTS.mdを再読み込みする。挙動はほぼ同等だが、コンテキスト保持の範囲に差がある可能性
3. **Codexのmsg/5hレート制限**: Claude Codeのような無制限API利用はできない。8エージェント並列運用の場合、Pro契約でも制限にかかる可能性 → エージェント数の削減や、codex execモードでの効率化を検討
4. **Stop Hook不在の影響**: inbox未読ブロック機能がなくなるため、「タスク完了後にinboxを無視してidle」になるケースが増える → nudge配信の信頼性向上 + 指示書強化で対応
5. **tmux send-keysの安定性**: Codexの`--no-alt-screen`モードは概ね動作するが、suggestion UIの問題があり、inbox_watcher.shに既にworkaround（"x"入力 + C-u）が入っている

---

## 5. 作業量見積もり

| Phase | 修正ファイル数 | 新規ファイル | 削除ファイル |
|-------|---------------|-------------|-------------|
| Phase 1 | 3 | 0 | 0-1 |
| Phase 2 | 2-3 | 0 | 1 |
| Phase 3 | 4-5 | 0 | 0 |
| Phase 4 | 1-2 | 0 | 0 |
| Phase 5 | 2 | 0 | 0 |
| Phase 6 | 5-8 | 0 | 0 |
| Phase 7 | 4-6 | 0 | 2-3 |
| Phase 8 | 0 | 0 | 8-12 |
