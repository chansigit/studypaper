#!/usr/bin/env bats
# tests/behavior/test-golden-string-database.bats
#
# Behavior-invariant test against the committed golden snapshot at
# examples/string-database-2025/. Unlike the structural tests in tests/unit/,
# this file pins *content-level invariants* that should hold on any future
# regeneration of this example with a real LLM. When prompts drift in a way
# that breaks these invariants, this test catches it.
#
# How to refresh the golden snapshot (manual, requires Claude Code + the
# real STRING 2025 PDF):
#   1. /paperstudio:study https://www.biorxiv.org/content/10.1101/2024.11.05.621741v2
#   2. cp -r ~/claude-papers/papers/string-database-2025/{analysis,review.md,reproduce-check.md,notes} examples/string-database-2025/
#   3. bats tests/behavior/   # if any assertion fails, either the regression
#                              is real (fix the prompt) or the invariant is
#                              outdated (loosen / replace the assertion).

EXAMPLE_DIR="${BATS_TEST_DIRNAME}/../../../examples/string-database-2025"

# ---------------------------------------------------------------------------
# Paper profile (analysis/00-paper-profile.md)
# ---------------------------------------------------------------------------

@test "golden profile: frontmatter has all required keys" {
  f="$EXAMPLE_DIR/analysis/00-paper-profile.md"
  for key in slug title paper_type domain difficulty claims_summary key_baselines_detected domain_packs_selected; do
    grep -qE "^${key}:" "$f" || { echo "missing key: $key"; return 1; }
  done
}

@test "golden profile: claims_summary has at least 3 bullet entries" {
  f="$EXAMPLE_DIR/analysis/00-paper-profile.md"
  count=$(awk '/^claims_summary:/{flag=1; next} flag && /^[a-z_]+:/{flag=0} flag && /^  - /{n++} END{print n+0}' "$f")
  [ "$count" -ge 3 ]
}

@test "golden profile: domain field has known value (catches free-form drift)" {
  f="$EXAMPLE_DIR/analysis/00-paper-profile.md"
  domain=$(grep -E '^domain:' "$f" | head -1 | sed 's/^domain:[[:space:]]*//')
  case "$domain" in
    ml-pure|single-cell|protein-structure|protein-function|genomics|drug-discovery|medical-imaging|cs-bio) ;;
    *) echo "unexpected domain value: $domain"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Review (review.md)
# ---------------------------------------------------------------------------

@test "golden review: has Summary, Significance, Strengths sections" {
  f="$EXAMPLE_DIR/review.md"
  for h in "## Summary" "## Significance" "## Strengths"; do
    grep -qF "$h" "$f" || { echo "missing heading: $h"; return 1; }
  done
}

@test "golden review: has weaknesses or questions section (any of the 3 names)" {
  f="$EXAMPLE_DIR/review.md"
  grep -qE "^## (Weaknesses|Questions|Concerns)" "$f"
}

@test "golden review: Strengths section has at least 3 bullets" {
  f="$EXAMPLE_DIR/review.md"
  n=$(awk '/^## Strengths/{flag=1; next} flag && /^## /{flag=0} flag && /^- /{n++} END{print n+0}' "$f")
  [ "$n" -ge 3 ]
}

@test "golden review: Reviewer + Last updated metadata lines present" {
  f="$EXAMPLE_DIR/review.md"
  grep -qE '^\*\*Reviewer:\*\*' "$f"
  grep -qE '^\*\*Last updated:\*\*' "$f"
}

# ---------------------------------------------------------------------------
# Reproduce-check (reproduce-check.md) — the most consistency-sensitive file
# ---------------------------------------------------------------------------

@test "golden reproduce-check: overall_score is one of {green, yellow, red}" {
  f="$EXAMPLE_DIR/reproduce-check.md"
  score=$(grep -E '^overall_score:' "$f" | head -1 | sed 's/^overall_score:[[:space:]]*//')
  [[ "$score" == "green" || "$score" == "yellow" || "$score" == "red" ]]
}

@test "golden reproduce-check: lookup-table consistency (fails>=2 => red)" {
  f="$EXAMPLE_DIR/reproduce-check.md"
  fails=$(grep -E '^fails_count:' "$f" | head -1 | sed 's/^fails_count:[[:space:]]*//')
  score=$(grep -E '^overall_score:' "$f" | head -1 | sed 's/^overall_score:[[:space:]]*//')
  if [ "${fails:-0}" -ge 2 ]; then
    [ "$score" = "red" ] || { echo "fails=$fails but score=$score (expected red)"; return 1; }
  fi
}

@test "golden reproduce-check: status counts add up to checked_dimensions" {
  f="$EXAMPLE_DIR/reproduce-check.md"
  checked=$(grep -E '^checked_dimensions:' "$f" | head -1 | sed 's/^checked_dimensions:[[:space:]]*//')
  fails=$(grep -E '^fails_count:' "$f" | head -1 | sed 's/^fails_count:[[:space:]]*//')
  partials=$(grep -E '^partials_count:' "$f" | head -1 | sed 's/^partials_count:[[:space:]]*//')
  # We don't have a pass_count field; verify fails+partials <= checked.
  total=$(( ${fails:-0} + ${partials:-0} ))
  [ "$total" -le "${checked:-0}" ]
}

@test "golden reproduce-check: 7 dimension rows in summary table" {
  f="$EXAMPLE_DIR/reproduce-check.md"
  # Count table rows that look like "| <Dimension> | <status> |", excluding header & separator.
  n=$(awk '/^\| Dimension \|/{flag=1; next} /^\|---/{next} flag && /^\| /{n++} flag && /^$/{flag=0} END{print n+0}' "$f")
  [ "$n" -eq 7 ]
}

# ---------------------------------------------------------------------------
# Notes (xhs + wechat)
# ---------------------------------------------------------------------------

@test "golden xhs.md: frontmatter has title + figures" {
  f="$EXAMPLE_DIR/notes/xhs.md"
  grep -qE '^title:' "$f"
  grep -qE '^figures:' "$f"
}

@test "golden xhs.md: exactly 1 inline figure embed" {
  f="$EXAMPLE_DIR/notes/xhs.md"
  n=$(grep -cE '^!\[[^]]*\]\([^)]+\)' "$f" || true)
  [ "$n" -eq 1 ]
}

@test "golden xhs.md: figure path is paper-folder-relative (no leaked /Users/, file://, http://)" {
  f="$EXAMPLE_DIR/notes/xhs.md"
  ! grep -qE '\((/Users/|file://|https?://)' "$f"
}

@test "golden wechat.md: required Chinese H2 sections present" {
  f="$EXAMPLE_DIR/notes/wechat.md"
  for h in "## 背景" "## 核心 idea" "## 方法" "## 实验" "## 一句话总结"; do
    grep -qF "$h" "$f" || { echo "missing heading: $h"; return 1; }
  done
}

@test "golden wechat.md: 2 to 3 inline figure embeds" {
  f="$EXAMPLE_DIR/notes/wechat.md"
  n=$(grep -cE '^!\[[^]]*\]\([^)]+\)' "$f" || true)
  [ "$n" -ge 2 ] && [ "$n" -le 3 ]
}

# ---------------------------------------------------------------------------
# v0.6.0 forward-compat invariants — optional today, required after the
# golden snapshot is regenerated under v0.6.0+. They detect "the LLM produced
# a verdict but used a non-enum value" without forcing the legacy snapshot
# to have the field.
#
# Expiry guard: when the golden's provenance line shows v0.6.0 or later, the
# `skip`s flip to hard failures via the explicit "must be present" assertion
# at the bottom of this section. If the snapshot is regenerated and the new
# fields are missing, the test fails loudly instead of skipping silently.
# ---------------------------------------------------------------------------

golden_provenance_version() {
  # Returns the major.minor.patch from the line-1 provenance comment of the
  # golden review.md, or empty if not parseable.
  head -1 "$EXAMPLE_DIR/review.md" | sed -nE 's/.*paperstudio v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}

golden_is_v060_or_later() {
  local v
  v=$(golden_provenance_version)
  [ -n "$v" ] || return 1
  # Compare via sort -V; if v sorts at-or-after 0.6.0, return true.
  [ "$(printf '%s\n%s\n' "$v" "0.6.0" | sort -V | head -1)" = "0.6.0" ]
}

@test "golden review (forward-compat): verdict frontmatter present and in enum, OR golden is pre-v0.6.0" {
  f="$EXAMPLE_DIR/review.md"
  if golden_is_v060_or_later; then
    grep -qE '^verdict:' "$f" || { echo "golden is v0.6.0+ but verdict frontmatter missing"; return 1; }
    val=$(grep -E '^verdict:' "$f" | head -1 | sed -E 's/^verdict:[[:space:]]*//; s/[[:space:]]*$//')
    case "$val" in
      strong_accept|accept|weak_accept|borderline|weak_reject|reject|strong_reject) ;;
      *) echo "verdict=$val not in enum"; return 1 ;;
    esac
  else
    if grep -qE '^verdict:' "$f"; then
      val=$(grep -E '^verdict:' "$f" | head -1 | sed -E 's/^verdict:[[:space:]]*//; s/[[:space:]]*$//')
      case "$val" in
        strong_accept|accept|weak_accept|borderline|weak_reject|reject|strong_reject) ;;
        *) echo "verdict=$val not in enum"; return 1 ;;
      esac
    else
      skip "golden is pre-v0.6.0 ($(golden_provenance_version)); verdict frontmatter not yet expected"
    fi
  fi
}

@test "golden review (forward-compat): confidence frontmatter present and in enum, OR golden is pre-v0.6.0" {
  f="$EXAMPLE_DIR/review.md"
  if golden_is_v060_or_later; then
    grep -qE '^confidence:' "$f" || { echo "golden is v0.6.0+ but confidence frontmatter missing"; return 1; }
    val=$(grep -E '^confidence:' "$f" | head -1 | sed -E 's/^confidence:[[:space:]]*//; s/[[:space:]]*$//')
    [[ "$val" =~ ^(low|medium|high)$ ]] || { echo "confidence=$val invalid"; return 1; }
  else
    if grep -qE '^confidence:' "$f"; then
      val=$(grep -E '^confidence:' "$f" | head -1 | sed -E 's/^confidence:[[:space:]]*//; s/[[:space:]]*$//')
      [[ "$val" =~ ^(low|medium|high)$ ]] || { echo "confidence=$val invalid"; return 1; }
    else
      skip "golden is pre-v0.6.0 ($(golden_provenance_version)); confidence frontmatter not yet expected"
    fi
  fi
}

@test "golden coherence (forward-compat): _coherence.md present with valid severity, OR golden is pre-v0.6.0" {
  f="$EXAMPLE_DIR/analysis/_coherence.md"
  if golden_is_v060_or_later; then
    [ -f "$f" ] || { echo "golden is v0.6.0+ but analysis/_coherence.md missing"; return 1; }
    val=$(grep -E '^severity:' "$f" | head -1 | sed -E 's/^severity:[[:space:]]*//; s/[[:space:]]*$//')
    [[ "$val" =~ ^(none|low|medium|high)$ ]] || { echo "severity=$val invalid"; return 1; }
  else
    if [ -f "$f" ]; then
      val=$(grep -E '^severity:' "$f" | head -1 | sed -E 's/^severity:[[:space:]]*//; s/[[:space:]]*$//')
      [[ "$val" =~ ^(none|low|medium|high)$ ]] || { echo "severity=$val invalid"; return 1; }
    else
      skip "golden is pre-v0.6.0 ($(golden_provenance_version)); _coherence.md not yet expected"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Cross-cutting: every artifact has provenance + the validator agrees
# ---------------------------------------------------------------------------

@test "golden suite: every committed artifact has line-1 provenance comment" {
  bad=0
  for f in "$EXAMPLE_DIR"/analysis/*.md "$EXAMPLE_DIR"/review.md "$EXAMPLE_DIR"/reproduce-check.md "$EXAMPLE_DIR"/notes/*.md "$EXAMPLE_DIR"/review-rounds/*.md "$EXAMPLE_DIR"/compares/*.md "$EXAMPLE_DIR"/deep-dives/*.md; do
    [ -f "$f" ] || continue
    if ! head -1 "$f" | grep -qE '^<!-- generated: .+ by .+ \(paperstudio v.+\)( \[.+\])? -->$'; then
      echo "no provenance: $f"
      bad=$((bad+1))
    fi
  done
  [ "$bad" -eq 0 ]
}
