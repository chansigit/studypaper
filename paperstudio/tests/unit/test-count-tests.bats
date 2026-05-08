#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "count-tests.sh runs and prints a total" {
  run bash scripts/count-tests.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats"* ]]
  [[ "$output" == *"node"* ]]
  [[ "$output" == *"total"* ]]
}

@test "count-tests.sh --badge-format prints just the integer total" {
  run bash scripts/count-tests.sh --badge-format
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "count-tests.sh integer is in the expected range (>= 100)" {
  total=$(bash scripts/count-tests.sh --badge-format)
  [ "$total" -ge 100 ]
}
