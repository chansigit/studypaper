#!/usr/bin/env bash
# scripts/lib/resolve-paper.sh — resolve which paper folder a skill should target.
#
# Source this file, then call:
#   resolve_paper [--paper <slug>] [--papers-root <dir>]
#
# After successful return, these vars are set in the calling shell:
#   PAPER_SLUG          — the slug (basename of paper folder)
#   PAPER_DIR           — absolute path to ~/claude-papers/papers/<slug>
#   PAPER_AUTODETECTED  — "true" if --paper was absent and we picked most-recent;
#                         "false" if --paper was explicit
#
# Exit codes (from `return`, since this is sourced):
#   0 — ok
#   2 — --paper points at a nonexistent slug
#   3 — no --paper and the papers-root is empty / nonexistent
#
# Default papers-root resolution order:
#   1. --papers-root flag (test override)
#   2. $CLAUDE_PAPERS_ROOT env var (test override)
#   3. $HOME/claude-papers/papers (production default)

resolve_paper() {
  local explicit_slug=""
  local papers_root="${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --paper)
        explicit_slug="${2:-}"
        shift 2
        ;;
      --papers-root)
        papers_root="${2:-}"
        shift 2
        ;;
      *)
        # Unknown flag — leave for the caller to handle (e.g., --force, --yes)
        shift
        ;;
    esac
  done

  # Strip trailing slash from explicit_slug if present
  explicit_slug="${explicit_slug%/}"

  if [ -n "$explicit_slug" ]; then
    if [ ! -d "$papers_root/$explicit_slug" ]; then
      echo "Error: --paper '$explicit_slug' not found under $papers_root" >&2
      return 2
    fi
    PAPER_SLUG="$explicit_slug"
    PAPER_DIR="$papers_root/$explicit_slug"
    PAPER_AUTODETECTED="false"
    return 0
  fi

  # No --paper — auto-detect most-recently-modified
  if [ ! -d "$papers_root" ]; then
    echo "Error: papers root '$papers_root' does not exist" >&2
    return 3
  fi

  local recent
  recent="$(ls -td "$papers_root"/*/ 2>/dev/null | head -1)"
  if [ -z "$recent" ]; then
    echo "Error: no paper folders found under $papers_root" >&2
    return 3
  fi

  PAPER_DIR="${recent%/}"
  PAPER_SLUG="$(basename "$PAPER_DIR")"
  PAPER_AUTODETECTED="true"
  echo "Warning: targeting '$PAPER_SLUG' (most recently modified paper folder under $papers_root). Pass --paper <slug> to override." >&2
  return 0
}

# When sourced, do nothing; when executed directly, print help.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cat >&2 <<'EOF'
resolve-paper.sh — must be sourced, not executed directly.

Usage in a skill:
  source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
  resolve_paper [--paper <slug>] [--papers-root <dir>]
  # After success, $PAPER_SLUG, $PAPER_DIR, $PAPER_AUTODETECTED are set.
EOF
  exit 1
fi
