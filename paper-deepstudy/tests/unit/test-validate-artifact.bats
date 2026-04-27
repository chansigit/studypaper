#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  TMPDIR_T="$(mktemp -d)"
  export TMPDIR_T
}

teardown() {
  [ -n "$TMPDIR_T" ] && rm -rf "$TMPDIR_T"
}

# ---------- happy path ----------

@test "validate-artifact: review with all required H2 + provenance passes" {
  cat > "$TMPDIR_T/review.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by reviewer-synthesizer (paper-deepstudy v0.1.0) -->

# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/review.md" review
  [ "$status" -eq 0 ]
}

@test "validate-artifact: compare with all 6 H2 + provenance passes" {
  cat > "$TMPDIR_T/c.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by compare-agent (paper-deepstudy v0.1.0) -->
---
this_paper: foo
other_paper: bar
created_at: 2026-04-27T12:00:00Z
language: english
---

# Compare: foo vs bar

## Problem
x

## Formalization
y

## Method
z

## Experiments
w

## Strengths and weaknesses
| a | b | c |

## When to use which
v
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/c.md" compare
  [ "$status" -eq 0 ]
}

@test "validate-artifact: provenance with [Plan 7 retrofit] annotation passes (relaxed regex)" {
  cat > "$TMPDIR_T/review.md" <<'EOF'
<!-- generated: 2026-04-25T00:00:00Z by reviewer-synthesizer (paper-deepstudy v0.1.0) [Plan 7 retrofit] -->

# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/review.md" review
  [ "$status" -eq 0 ]
}

# ---------- failure: missing provenance ----------

@test "validate-artifact: file with no provenance line 1 fails with code 1" {
  cat > "$TMPDIR_T/r.md" <<'EOF'
# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/r.md" review
  [ "$status" -eq 1 ]
  [[ "$output" == *"provenance"* ]] || [[ "$output" == *"generated:"* ]]
}

# ---------- failure: missing required H2 ----------

@test "validate-artifact: review missing Score H2 fails" {
  cat > "$TMPDIR_T/r.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by reviewer-synthesizer (paper-deepstudy v0.1.0) -->

# Review

## Strengths
foo

## Weaknesses
bar
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/r.md" review
  [ "$status" -eq 1 ]
  [[ "$output" == *"Score"* ]]
}

# ---------- failure: banned content ----------

@test "validate-artifact: compare with capitalized 'Strengths and Weaknesses' fails (C2 regression guard)" {
  cat > "$TMPDIR_T/c.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by compare-agent (paper-deepstudy v0.1.0) -->
---
this_paper: foo
other_paper: bar
created_at: 2026-04-27T12:00:00Z
language: english
---

# Compare: foo vs bar

## Problem
x

## Formalization
y

## Method
z

## Experiments
w

## Strengths and Weaknesses
| a | b | c |

## When to use which
v
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/c.md" compare
  [ "$status" -eq 1 ]
}

@test "validate-artifact: xhs with absolute /Users/ figure path fails (Plan 9 I7 regression guard)" {
  cat > "$TMPDIR_T/xhs.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by xhs-renderer (paper-deepstudy v0.1.0) -->
---
title: foo
figures:
  - /Users/me/foo.jpeg
---

正文。
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/xhs.md" xhs
  [ "$status" -eq 1 ]
  [[ "$output" == *"/Users/"* ]] || [[ "$output" == *"absolute"* ]]
}

@test "validate-artifact: review with unfilled <runtime-timestamp> placeholder fails (R3/C1 regression guard)" {
  cat > "$TMPDIR_T/r.md" <<'EOF'
<!-- generated: <runtime-timestamp> by reviewer-synthesizer (paper-deepstudy v0.1.0) -->

# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  # The provenance line itself uses placeholder <runtime-timestamp>; this means
  # the LLM did not fill in. validate-artifact treats this as a failure.
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/r.md" review
  [ "$status" -eq 1 ]
  [[ "$output" == *"runtime-timestamp"* ]] || [[ "$output" == *"placeholder"* ]]
}

# ---------- failure: missing frontmatter key ----------

@test "validate-artifact: paper-profile missing 'domain' key fails" {
  cat > "$TMPDIR_T/p.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by paper-profiler (paper-deepstudy v0.1.0) -->
---
paper_type: architecture
difficulty: advanced
domain_packs_selected: [ml-pure]
---

# Profile
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/p.md" paper-profile
  [ "$status" -eq 1 ]
  [[ "$output" == *"domain"* ]]
}

# ---------- unknown artifact type ----------

@test "validate-artifact: unknown artifact-type returns code 2" {
  cat > "$TMPDIR_T/x.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by foo (paper-deepstudy v0.1.0) -->
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/x.md" not-a-real-type
  [ "$status" -eq 2 ]
}

# ---------- nonexistent file ----------

@test "validate-artifact: nonexistent file returns code 1" {
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/nope.md" review
  [ "$status" -eq 1 ]
}

# ---------- reproduce-check lookup-table consistency ----------

@test "validate-artifact: reproduce-check with fails_count >= 2 but score yellow fails (R2 regression guard)" {
  cat > "$TMPDIR_T/rc.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by reproduce-checker (paper-deepstudy v0.1.0) -->
---
slug: foo
overall_score: yellow
fails_count: 3
partials_count: 1
checked_dimensions: 7
---

# Reproducibility check

## Data
✗

## Code
✗

## Hyperparameters
✗

## Random seeds
partial

## Hardware
✓

## Evaluation scripts
✓

## Wet-lab protocol
N/A
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/rc.md" reproduce-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"fails_count"* ]] || [[ "$output" == *"red"* ]]
}
