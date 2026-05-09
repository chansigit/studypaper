#!/usr/bin/env bash
# scripts/lib/log-dispatch.sh — append a single JSONL line per sub-Agent dispatch.
#
# Usage:
#   source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
#   log_dispatch <subagent> <output_path> <status> [duration_ms]
#
# Behavior:
#   - Appends one JSONL line to $PAPER_DIR/.deepstudy/run.jsonl
#   - Returns 0 silently on any failure (must never break the caller)
#   - Skips writing if $PAPER_DEEPSTUDY_NO_RUN_LOG is "1"
#   - Auto-creates the .deepstudy/ subdirectory
#
# Schema:
#   {"ts":"<iso8601-utc>","subagent":"...","output":"...","status":"ok|failed|skipped",
#    "duration_ms":<int-or-null>,"plugin_version":"..."}
#
# Privacy:
#   Records ONLY metadata (subagent name, output filename, status).
#   No paper content, no user input, no chat history.

log_dispatch() {
  # Honor opt-out
  if [ "${PAPER_DEEPSTUDY_NO_RUN_LOG:-0}" = "1" ]; then
    return 0
  fi

  # Required env / args
  local paper_dir="${PAPER_DIR:-}"
  if [ -z "$paper_dir" ] || [ ! -d "$paper_dir" ]; then
    return 0  # silent — never break caller
  fi

  local subagent="${1:-unknown}"
  local output="${2:-}"
  local status="${3:-ok}"
  local duration_ms="${4:-}"

  # JSON-escape arbitrary string fields. Inputs in callers today are
  # always literal subagent / artifact names (safe ASCII), but if a future
  # caller passes anything user-derived (paper title, error message), this
  # prevents a backslash or double-quote from corrupting the JSONL line.
  json_escape() {
    # Replace \ with \\, then " with \"; preserve everything else verbatim.
    # Tab and newline are also encoded so a multi-line caller string can't
    # split a single JSONL record into two.
    printf '%s' "$1" \
      | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
            -e 's/\t/\\t/g' \
      | tr '\n' '\1' | sed 's/\x01/\\n/g'
  }
  subagent=$(json_escape "$subagent")
  output=$(json_escape "$output")
  status=$(json_escape "$status")

  # Compose plugin_version from manifest, fallback "?"
  local plugin_version="?"
  local manifest="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
  if [ -f "$manifest" ]; then
    plugin_version=$(grep -m1 '"version"' "$manifest" 2>/dev/null \
      | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/' || echo "?")
  fi

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Compose JSONL line. duration_ms is omitted (not null) if absent.
  local line
  if [ -n "$duration_ms" ]; then
    line=$(printf '{"ts":"%s","subagent":"%s","output":"%s","status":"%s","duration_ms":%s,"plugin_version":"%s"}' \
      "$ts" "$subagent" "$output" "$status" "$duration_ms" "$plugin_version")
  else
    line=$(printf '{"ts":"%s","subagent":"%s","output":"%s","status":"%s","plugin_version":"%s"}' \
      "$ts" "$subagent" "$output" "$status" "$plugin_version")
  fi

  # Ensure .deepstudy dir exists; ignore mkdir failure (caller will get nothing logged)
  mkdir -p "$paper_dir/.deepstudy" 2>/dev/null || return 0

  # Append; ignore append failure
  echo "$line" >> "$paper_dir/.deepstudy/run.jsonl" 2>/dev/null || return 0

  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cat >&2 <<'EOF'
log-dispatch.sh — must be sourced, not executed directly.

Usage in a skill:
  source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
  log_dispatch <subagent> <output_path> <status> [duration_ms]
EOF
  exit 1
fi
