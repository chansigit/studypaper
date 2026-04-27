#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  TEST_PAPER_DIR="$(mktemp -d)"
  export TEST_PAPER_DIR
  # Mock plugin manifest so log-dispatch can read version
  export CLAUDE_PLUGIN_ROOT="$BATS_TEST_DIRNAME/../.."
}

teardown() {
  [ -n "$TEST_PAPER_DIR" ] && rm -rf "$TEST_PAPER_DIR"
}

@test "log_dispatch writes one JSONL line to .deepstudy/run.jsonl" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch reviewer-synthesizer review.md ok
  [ -f "$TEST_PAPER_DIR/.deepstudy/run.jsonl" ]
  line_count=$(wc -l < "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  [ "$line_count" -eq 1 ]
}

@test "log_dispatch JSONL line has required fields" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch reviewer-synthesizer review.md ok 1234
  line=$(cat "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  [[ "$line" == *'"ts":'* ]]
  [[ "$line" == *'"subagent":"reviewer-synthesizer"'* ]]
  [[ "$line" == *'"output":"review.md"'* ]]
  [[ "$line" == *'"status":"ok"'* ]]
  [[ "$line" == *'"duration_ms":1234'* ]]
  [[ "$line" == *'"plugin_version":'* ]]
}

@test "log_dispatch is JSON-valid (parseable by node)" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch reviewer-synthesizer review.md ok
  node -e "JSON.parse(require('fs').readFileSync('$TEST_PAPER_DIR/.deepstudy/run.jsonl','utf8').trim())"
}

@test "log_dispatch creates .deepstudy dir if missing" {
  source scripts/lib/log-dispatch.sh
  [ ! -d "$TEST_PAPER_DIR/.deepstudy" ]
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo bar ok
  [ -d "$TEST_PAPER_DIR/.deepstudy" ]
}

@test "log_dispatch appends, not overwrites, on second call" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo a.md ok
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch bar b.md failed
  line_count=$(wc -l < "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  [ "$line_count" -eq 2 ]
}

@test "log_dispatch skips silently when PAPER_DEEPSTUDY_NO_RUN_LOG=1" {
  source scripts/lib/log-dispatch.sh
  PAPER_DEEPSTUDY_NO_RUN_LOG=1 PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo a.md ok
  [ ! -f "$TEST_PAPER_DIR/.deepstudy/run.jsonl" ]
}

@test "log_dispatch never errors when PAPER_DIR is unset" {
  source scripts/lib/log-dispatch.sh
  unset PAPER_DIR
  run log_dispatch foo bar ok
  [ "$status" -eq 0 ]
}

@test "log_dispatch never errors when output dir is unwritable" {
  source scripts/lib/log-dispatch.sh
  chmod -w "$TEST_PAPER_DIR"
  run bash -c "source scripts/lib/log-dispatch.sh && PAPER_DIR='$TEST_PAPER_DIR' log_dispatch foo bar ok"
  chmod +w "$TEST_PAPER_DIR"
  [ "$status" -eq 0 ]
}

@test "log_dispatch ts is ISO8601 UTC second-precision" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo a.md ok
  line=$(cat "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  ts=$(echo "$line" | sed -nE 's/.*"ts":"([^"]+)".*/\1/p')
  # Pattern: YYYY-MM-DDTHH:MM:SSZ
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
