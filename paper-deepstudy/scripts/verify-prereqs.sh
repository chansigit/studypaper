#!/usr/bin/env bash
# Verify prerequisites for paper-deepstudy.
# Exit codes: 0 ok, 1 missing claude-paper, 2 missing node, 3 missing python3.
set -euo pipefail

# 1. claude-paper plugin must be installed (look for its skill file)
CLAUDE_PAPER_GLOB="$HOME/.claude/plugins/cache/claude-paper/claude-paper/*/skills/study/SKILL.md"
if ! ls $CLAUDE_PAPER_GLOB > /dev/null 2>&1; then
  echo "ERROR: claude-paper:study plugin not found." >&2
  echo "Install via the Claude Code plugin marketplace before using paper-deepstudy." >&2
  exit 1
fi

# 2. node >= 18
if ! command -v node > /dev/null 2>&1; then
  echo "ERROR: node not found (need >= 18)." >&2
  exit 2
fi
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "ERROR: node version $NODE_MAJOR < 18." >&2
  exit 2
fi

# 3. python3 (used by claude-paper for image extraction; we depend on its outputs)
if ! command -v python3 > /dev/null 2>&1; then
  echo "ERROR: python3 not found." >&2
  exit 3
fi

echo "OK: prerequisites satisfied."
exit 0
