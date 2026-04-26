#!/usr/bin/env bats

required_sections=(
  "# Pack:"
  "## Core problems"
  "## Key baselines"
  "## Common datasets"
  "## Standard metrics"
  "## Reviewer checklist"
)

check_pack() {
  local f=$1
  for s in "${required_sections[@]}"; do
    grep -qF "$s" "$f" || return 1
  done
}

@test "_template.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/_template.md
  [ "$status" -eq 0 ]
}

@test "ml-pure.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/ml-pure.md
  [ "$status" -eq 0 ]
}
