#!/usr/bin/env bats

# Ensure tests run from the plugin root regardless of where bats was invoked.
setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "plugin.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('.claude-plugin/plugin.json'))"
  [ "$status" -eq 0 ]
}

@test "package.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('package.json'))"
  [ "$status" -eq 0 ]
}

@test "verify-prereqs.sh exists and is executable" {
  [ -x scripts/verify-prereqs.sh ]
}

@test "verify-prereqs.sh succeeds when all deps present" {
  run scripts/verify-prereqs.sh
  [ "$status" -eq 0 ]
}
