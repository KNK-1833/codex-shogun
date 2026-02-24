#!/usr/bin/env bash
# ============================================================
# Instruction File Build System
# ============================================================
# Combines instruction parts into complete instruction files
# for each role (Codex CLI only).
#
# AGENTS.md is the single source of truth (正本).
# This script generates per-role instruction files from parts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PARTS_DIR="$ROOT_DIR/instructions"
OUTPUT_DIR="$ROOT_DIR/instructions/generated"

mkdir -p "$OUTPUT_DIR"

echo "=== Instruction File Build System ==="
echo "Building instruction files..."

# ============================================================
# Helper function: Build a complete instruction file
# ============================================================
build_instruction_file() {
    local role="$1"
    local output_filename="codex-${role}.md"
    local output_path="$OUTPUT_DIR/$output_filename"
    local original_file="$ROOT_DIR/instructions/${role}.md"

    echo "Building: $output_filename (CLI: codex, Role: $role)"

    # Extract YAML front matter from original file
    if [ -f "$original_file" ]; then
        awk '/^---$/{if(++n==2) {print "---"; exit} if(n==1) next} n==1' "$original_file" > "$output_path"
        echo "" >> "$output_path"
    else
        # Minimal YAML front matter
        cat > "$output_path" <<EOFYAML
---
role: $role
version: "3.0"
cli_type: codex
---

EOFYAML
    fi

    # Append role-specific content
    cat "$PARTS_DIR/roles/${role}_role.md" >> "$output_path"

    # Append common sections
    echo "" >> "$output_path"
    cat "$PARTS_DIR/common/protocol.md" >> "$output_path"
    echo "" >> "$output_path"
    cat "$PARTS_DIR/common/task_flow.md" >> "$output_path"
    echo "" >> "$output_path"
    cat "$PARTS_DIR/common/forbidden_actions.md" >> "$output_path"

    # Append Codex-specific tools section
    echo "" >> "$output_path"
    cat "$PARTS_DIR/cli_specific/codex_tools.md" >> "$output_path"

    echo "  ✅ Created: $output_filename"
}

# Build Codex instruction files
build_instruction_file "shogun"
build_instruction_file "karo"
build_instruction_file "ashigaru"
build_instruction_file "gunshi"

echo ""
echo "=== Build Complete ==="
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Generated instruction files:"
ls -lh "$OUTPUT_DIR"/codex-*.md
