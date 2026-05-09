#!/usr/bin/env bash
# scripts/lib/validate-artifact.sh — schema-validate a paperstudio artifact file.
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
  # Pattern: <!-- generated: <timestamp> by <author> (paperstudio v<version>)[ optional annotation] -->
  # Using grep -E because bash [[ =~ ]] does not handle parentheses and brackets well without escaping.
  if ! echo "$line1" | grep -qE '^<!-- generated: .+ by .+ \(paperstudio v.+\)( \[.+\])? -->$'; then
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

# Optional-key + enum validator: if the frontmatter key is present, its value
# must match one of the supplied enum values. Absence is allowed (for legacy /
# in-flight artifacts).
# Count `^- ` bullets in the body region delimited by an H2 (or H3) heading
# and the next H2 (or end of file). Used by review count-consistency check.
count_bullets_under() {
  local heading_pattern="$1"  # full regex, e.g. '^## Strengths[[:space:]]*$'
  local stop_pattern="${2:-^## }"
  awk -v start="$heading_pattern" -v stop="$stop_pattern" '
    $0 ~ start { in_section=1; next }
    in_section && $0 ~ stop { in_section=0 }
    in_section && /^- / { n++ }
    END { print n+0 }
  ' "$FILE"
}

# Count bullets across ALL ### subsections inside a given H2.
count_bullets_under_h2_subsections() {
  local h2_pattern="$1"  # e.g. '^## Weaknesses[[:space:]]*$'
  awk -v start="$h2_pattern" '
    $0 ~ start { in_h2=1; next }
    in_h2 && /^## / { in_h2=0 }
    in_h2 && /^- / { n++ }
    END { print n+0 }
  ' "$FILE"
}

check_review_count_consistency() {
  # Only fires when the FM key is present.
  local declared body
  for spec in \
    "strengths_count|^## Strengths[[:space:]]*$|h2" \
    "weaknesses_count|^## Weaknesses[[:space:]]*$|h2_with_subs" \
    "open_questions_count|^## Questions to Authors[[:space:]]*$|h2"; do
    local key="${spec%%|*}"
    local rest="${spec#*|}"
    local heading="${rest%|*}"
    local mode="${rest##*|}"
    if grep -qE "^${key}:" "$FILE"; then
      declared=$(grep -E "^${key}:" "$FILE" | head -1 | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]*$//")
      case "$mode" in
        h2_with_subs) body=$(count_bullets_under_h2_subsections "$heading") ;;
        *) body=$(count_bullets_under "$heading") ;;
      esac
      if [ "$declared" != "$body" ]; then
        fail "frontmatter ${key}=${declared} but body has ${body} bullet(s) — review-writer must update the count after every edit"
      fi
    fi
  done
}

check_fm_enum_if_present() {
  local key="$1"; shift
  local enum=("$@")
  if grep -qE "^${key}:" "$FILE"; then
    local val
    val=$(grep -E "^${key}:" "$FILE" | head -1 | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]*$//")
    local ok=0
    for e in "${enum[@]}"; do [ "$val" = "$e" ] && ok=1 && break; done
    if [ "$ok" -eq 0 ]; then
      fail "frontmatter '${key}: ${val}' not in enum (${enum[*]})"
    fi
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
    # v0.6.0+ frontmatter. By default, enum-when-present (legacy v0.5.x review.md
    # without frontmatter still validates). Set PAPERSTUDIO_VALIDATE_STRICT=1 to
    # require the frontmatter keys outright — useful in CI on freshly regenerated
    # paper folders where missing frontmatter signals reviewer-synthesizer regression.
    check_fm_enum_if_present verdict \
      strong_accept accept weak_accept borderline weak_reject reject strong_reject
    check_fm_enum_if_present confidence low medium high
    if [ "${PAPERSTUDIO_VALIDATE_STRICT:-0}" = "1" ]; then
      check_required_fm_key verdict
      check_required_fm_key confidence
      check_required_fm_key review_round
      check_required_fm_key strengths_count
      check_required_fm_key weaknesses_count
      check_required_fm_key open_questions_count
    fi
    # Count-consistency: when the FM declares a count, the body must match.
    # Always runs — fires even in non-STRICT mode if the keys are present.
    check_review_count_consistency
    ;;
  review-round)
    # review-round stores objection/defense in frontmatter, not as H2 headings.
    # The template uses: round, objection, defense, judge_verdict, final_verdict.
    # 'verdict' is stored as final_verdict in the frontmatter.
    check_required_fm_key round
    check_required_fm_key objection
    check_required_fm_key defense
    check_required_fm_key judge_verdict
    check_required_fm_key final_verdict
    ;;
  deep-dive)
    # deep-dive template has no frontmatter; it uses H1 + 5 fixed H2 sections.
    check_required_h2 "What is this topic"
    check_required_h2 "How the paper handles it"
    check_required_h2 "Math or algorithm detail"
    check_required_h2 "How others have approached"
    check_required_h2 Takeaway
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
    check_required_h2 "Data availability"
    check_required_h2 "Code availability"
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
