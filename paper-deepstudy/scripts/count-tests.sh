#!/usr/bin/env bash
# scripts/count-tests.sh — count bats + node test cases in this plugin.
# Usage:
#   scripts/count-tests.sh                  # human format
#   scripts/count-tests.sh --badge-format   # just the integer total

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

# Bats: count `@test "..."` lines across all .bats files
bats_count=0
if [ -d tests/unit ]; then
  bats_count=$(grep -hE '^@test ' tests/unit/*.bats 2>/dev/null | wc -l | tr -d ' ')
fi

# Node: count `console.log\(.*passed.*\)` markers — each test file emits one
# "<helper>: all tests passed" line per pass. We approximate one-per-file.
node_count=0
if [ -d tests/unit ]; then
  node_count=$(ls tests/unit/test-*.cjs 2>/dev/null | wc -l | tr -d ' ')
fi

total=$((bats_count + node_count))

if [ "${1:-}" = "--badge-format" ]; then
  echo "$total"
else
  echo "$bats_count bats + $node_count node = $total total"
fi
