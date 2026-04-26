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
