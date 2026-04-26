#!/usr/bin/env bats

@test "plugin.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('paper-deepstudy/.claude-plugin/plugin.json'))"
  [ "$status" -eq 0 ]
}

@test "PLUGIN.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('paper-deepstudy/PLUGIN.json'))"
  [ "$status" -eq 0 ]
}

@test "package.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('paper-deepstudy/package.json'))"
  [ "$status" -eq 0 ]
}

@test "verify-prereqs.sh exists and is executable" {
  [ -x paper-deepstudy/scripts/verify-prereqs.sh ]
}

@test "verify-prereqs.sh succeeds when all deps present" {
  run paper-deepstudy/scripts/verify-prereqs.sh
  [ "$status" -eq 0 ]
}
