#!/usr/bin/env bats

# Ensure tests run from the plugin root regardless of where bats was invoked.
setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

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
  run check_pack domain-packs/_template.md
  [ "$status" -eq 0 ]
}

@test "ml-pure.md has required sections" {
  run check_pack domain-packs/ml-pure.md
  [ "$status" -eq 0 ]
}

@test "single-cell.md has required sections" {
  run check_pack domain-packs/single-cell.md
  [ "$status" -eq 0 ]
}

@test "protein-structure.md has required sections" {
  run check_pack domain-packs/protein-structure.md
  [ "$status" -eq 0 ]
}

@test "protein-function.md has required sections" {
  run check_pack domain-packs/protein-function.md
  [ "$status" -eq 0 ]
}

@test "genomics.md has required sections" {
  run check_pack domain-packs/genomics.md
  [ "$status" -eq 0 ]
}

@test "drug-discovery.md has required sections" {
  run check_pack domain-packs/drug-discovery.md
  [ "$status" -eq 0 ]
}

@test "medical-imaging.md has required sections" {
  run check_pack domain-packs/medical-imaging.md
  [ "$status" -eq 0 ]
}

@test "paper-profiler prompt mentions all 7 domain packs in AVAILABLE_PACKS examples" {
  for pack in ml-pure single-cell protein-structure protein-function genomics drug-discovery medical-imaging; do
    grep -qF "$pack" prompts/paper-profiler.md || { echo "missing pack reference: $pack"; return 1; }
  done
}
