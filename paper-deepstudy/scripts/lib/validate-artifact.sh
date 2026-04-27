#!/usr/bin/env bash
# scripts/lib/validate-artifact.sh — schema-validate a paper-deepstudy artifact file.
#
# Usage:
#   validate-artifact.sh <file> <artifact-type>
#
# Artifact types:
#   paper-profile, review, review-round, deep-dive, compare, reproduce-check,
#   xhs, wechat, source, titles,
#   analysis-01-problem, analysis-02-formalization, analysis-03-method,
#   analysis-04-experiments, analysis-05-prior-work, analysis-06-figures
#
# Exit codes:
#   0 — all assertions pass
#   1 — at least one assertion failed (stderr lists failures)
#   2 — unknown artifact-type

set -euo pipefail

FILE="${1:-}"
TYPE="${2:-}"

if [ -z "$FILE" ] || [ -z "$TYPE" ]; then
  echo "Usage: validate-artifact.sh <file> <artifact-type>" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "Error: file not found: $FILE" >&2
  exit 1
fi

# Track failures; print all then exit
FAILS=()

fail() {
  FAILS+=("$1")
}

check_provenance() {
  local line1
  line1=$(head -1 "$FILE")
  # Relaxed regex: allow optional annotation like [Plan 7 retrofit] after the closing paren.
  # Pattern: <!-- generated: <timestamp> by <author> (paper-deepstudy v<version>)[ optional annotation] -->
  # Using grep -E because bash [[ =~ ]] does not handle parentheses and brackets well without escaping.
  if ! echo "$line1" | grep -qE '^<!-- generated: .+ by .+ \(paper-deepstudy v.+\)( \[.+\])? -->$'; then
    fail "missing or malformed provenance line at line 1 (got: $line1)"
    return
  fi
  # Disallow unfilled <runtime-timestamp> placeholder
  if echo "$line1" | grep -qF '<runtime-timestamp>'; then
    fail "provenance line still contains <runtime-timestamp> placeholder (LLM did not fill in)"
  fi
}

check_required_h2() {
  local heading="$1"
  if ! grep -qE "^## ${heading}[[:space:]]*$" "$FILE"; then
    fail "missing required H2 heading: '## $heading'"
  fi
}

check_required_fm_key() {
  local key="$1"
  # Frontmatter keys are matched anywhere in the file (loose match)
  if ! grep -qE "^${key}:" "$FILE"; then
    fail "missing required frontmatter key: '${key}:'"
  fi
}

check_no_pattern() {
  local pat="$1"
  local label="$2"
  if grep -qF "$pat" "$FILE"; then
    fail "banned content found ($label): '$pat'"
  fi
}

# --- Always check provenance ---
check_provenance

# --- Per-type checks ---
case "$TYPE" in
  paper-profile)
    check_required_fm_key paper_type
    check_required_fm_key domain
    check_required_fm_key difficulty
    check_required_fm_key domain_packs_selected
    ;;
  review)
    check_required_h2 Strengths
    check_required_h2 Weaknesses
    check_required_h2 Score
    check_no_pattern "Plan 2 ✓" "plan-numbered leak"
    check_no_pattern "Plan 3a ✓" "plan-numbered leak"
    ;;
  review-round)
    check_required_fm_key slug
    check_required_fm_key round
    check_required_fm_key verdict
    check_required_h2 Objection
    check_required_h2 Defense
    ;;
  deep-dive)
    check_required_fm_key slug
    check_required_fm_key topic
    check_required_fm_key created_at
    check_required_fm_key language
    check_no_pattern "/Users/" "absolute path leak"
    ;;
  compare)
    check_required_fm_key this_paper
    check_required_fm_key other_paper
    check_required_fm_key created_at
    check_required_fm_key language
    check_required_h2 Problem
    check_required_h2 Formalization
    check_required_h2 Method
    check_required_h2 Experiments
    check_required_h2 "Strengths and weaknesses"
    check_required_h2 "When to use which"
    check_no_pattern "## Strengths and Weaknesses" "C2 capitalization regression"
    check_no_pattern "## Summary" "C3 extra section regression"
    ;;
  reproduce-check)
    check_required_fm_key slug
    check_required_fm_key overall_score
    check_required_fm_key fails_count
    check_required_fm_key partials_count
    check_required_fm_key checked_dimensions
    check_required_h2 Data
    check_required_h2 Code
    check_required_h2 Hyperparameters
    check_required_h2 "Random seeds"
    check_required_h2 Hardware
    check_required_h2 "Evaluation scripts"
    check_required_h2 "Wet-lab protocol"
    # Lookup-table consistency: fails_count >= 2 must be red
    fails_count=$(grep -E '^fails_count:' "$FILE" | head -1 | sed 's/^fails_count:[[:space:]]*//')
    overall=$(grep -E '^overall_score:' "$FILE" | head -1 | sed 's/^overall_score:[[:space:]]*//')
    if [ -n "$fails_count" ] && [ "$fails_count" -ge 2 ] 2>/dev/null && [ "$overall" != "red" ]; then
      fail "lookup-table violation: fails_count=$fails_count >= 2 must imply overall_score=red, got '$overall' (R2 regression)"
    fi
    ;;
  xhs|wechat)
    check_required_fm_key title
    check_required_fm_key figures
    check_no_pattern "/Users/" "absolute path leak (I7 regression)"
    check_no_pattern "file://" "file:// scheme leak (I7 regression)"
    ;;
  source)
    # source.md is the notes-writer output; per prompt template it uses numbered H2s.
    # The template has sections: "## 1. ...", "## 2. ...", etc.
    # We check for the presence of at least section 1 to confirm structure is valid.
    if ! grep -qE '^## [0-9]+\.' "$FILE"; then
      fail "source.md missing numbered H2 sections (## 1. ... form)"
    fi
    ;;
  titles)
    check_required_fm_key xhs
    check_required_fm_key wechat
    ;;
  analysis-01-problem)
    # template expects an H1 heading
    if ! grep -qE '^# ' "$FILE"; then
      fail "missing H1 heading"
    fi
    ;;
  analysis-02-formalization)
    check_required_h2 Notation
    ;;
  analysis-03-method)
    check_required_h2 Components
    ;;
  analysis-04-experiments)
    check_required_h2 Critique
    ;;
  analysis-05-prior-work)
    check_required_h2 Timeline
    ;;
  analysis-06-figures)
    # 06-figures has frontmatter (per Plan 1 figure-interpreter)
    if ! grep -qE '^# ' "$FILE"; then
      fail "missing H1 heading"
    fi
    ;;
  *)
    echo "Error: unknown artifact-type '$TYPE'" >&2
    exit 2
    ;;
esac

# --- Report ---
if [ ${#FAILS[@]} -eq 0 ]; then
  exit 0
fi

echo "validate-artifact: $FILE ($TYPE) — ${#FAILS[@]} failure(s):" >&2
for f in "${FAILS[@]}"; do
  echo "  - $f" >&2
done
exit 1
