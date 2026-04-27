#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  # Create a temp papers root for this test, populated from fixtures
  TEST_PAPERS_ROOT="$(mktemp -d)"
  cp -r tests/fixtures/mock-papers/. "$TEST_PAPERS_ROOT/"
  # Force deterministic mtime ordering: gamma newest, beta middle, alpha oldest
  touch -t 202001010000 "$TEST_PAPERS_ROOT/alpha"
  touch -t 202101010000 "$TEST_PAPERS_ROOT/beta"
  touch -t 202201010000 "$TEST_PAPERS_ROOT/gamma"
  export TEST_PAPERS_ROOT
}

teardown() {
  [ -n "$TEST_PAPERS_ROOT" ] && rm -rf "$TEST_PAPERS_ROOT"
}

@test "resolve_paper sets PAPER_DIR and PAPER_SLUG when --paper is given" {
  source scripts/lib/resolve-paper.sh
  resolve_paper --paper alpha --papers-root "$TEST_PAPERS_ROOT"
  [ "$PAPER_SLUG" = "alpha" ]
  [ "$PAPER_DIR" = "$TEST_PAPERS_ROOT/alpha" ]
  [ "$PAPER_AUTODETECTED" = "false" ]
}

@test "resolve_paper picks most recently modified when --paper is absent" {
  source scripts/lib/resolve-paper.sh
  resolve_paper --papers-root "$TEST_PAPERS_ROOT"
  [ "$PAPER_SLUG" = "gamma" ]
  [ "$PAPER_AUTODETECTED" = "true" ]
}

@test "resolve_paper warns to stderr on auto-detect" {
  source scripts/lib/resolve-paper.sh
  run bash -c "source scripts/lib/resolve-paper.sh && resolve_paper --papers-root '$TEST_PAPERS_ROOT' 2>&1 1>/dev/null"
  [[ "$output" == *"most recently modified"* ]]
  [[ "$output" == *"Pass --paper"* ]]
}

@test "resolve_paper does NOT warn when --paper is given" {
  source scripts/lib/resolve-paper.sh
  run bash -c "source scripts/lib/resolve-paper.sh && resolve_paper --paper alpha --papers-root '$TEST_PAPERS_ROOT' 2>&1 1>/dev/null"
  [[ "$output" != *"most recently modified"* ]]
}

@test "resolve_paper errors with exit 2 when --paper points to nonexistent slug" {
  source scripts/lib/resolve-paper.sh
  run resolve_paper --paper nonexistent --papers-root "$TEST_PAPERS_ROOT"
  [ "$status" -eq 2 ]
}

@test "resolve_paper errors with exit 3 when papers-root is empty" {
  source scripts/lib/resolve-paper.sh
  EMPTY_ROOT="$(mktemp -d)"
  run resolve_paper --papers-root "$EMPTY_ROOT"
  [ "$status" -eq 3 ]
  rm -rf "$EMPTY_ROOT"
}

@test "resolve_paper strips trailing slash from --paper" {
  source scripts/lib/resolve-paper.sh
  resolve_paper --paper "alpha/" --papers-root "$TEST_PAPERS_ROOT"
  [ "$PAPER_SLUG" = "alpha" ]
  [ "$PAPER_DIR" = "$TEST_PAPERS_ROOT/alpha" ]
}

@test "resolve_paper honors CLAUDE_PAPERS_ROOT env when --papers-root is absent" {
  source scripts/lib/resolve-paper.sh
  CLAUDE_PAPERS_ROOT="$TEST_PAPERS_ROOT" resolve_paper --paper beta
  [ "$PAPER_SLUG" = "beta" ]
}
