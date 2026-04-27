#!/usr/bin/env bats

setup() {
  # setup() cd's to paper-deepstudy/; examples/ are at repo root (one level up).
  cd "$BATS_TEST_DIRNAME/../.."
  REPO_ROOT="$(cd .. && pwd)"
  export REPO_ROOT
}

@test "examples/string-database-2025/analysis/00-paper-profile.md passes paper-profile schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/analysis/00-paper-profile.md" \
    paper-profile
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/review.md passes review schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/review.md" \
    review
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/review-rounds/round-01.md passes review-round schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/review-rounds/round-01-string-baseline-comparison.md" \
    review-round
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/deep-dives/...md passes deep-dive schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/deep-dives/the-fava-co-expression-integration.md" \
    deep-dive
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/compares/vs-...md passes compare schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/compares/vs-attention-is-all-you-need.md" \
    compare
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/reproduce-check.md passes reproduce-check schema (post-Plan-9 fix)" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/reproduce-check.md" \
    reproduce-check
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/notes/xhs.md passes xhs schema (post-Plan-9 path fix)" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/notes/xhs.md" \
    xhs
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/notes/wechat.md passes wechat schema (post-Plan-9 path fix)" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/notes/wechat.md" \
    wechat
  [ "$status" -eq 0 ]
}
