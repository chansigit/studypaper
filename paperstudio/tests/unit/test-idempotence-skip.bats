#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  # Idempotence rules live in either study-deep/SKILL.md (legacy) or
  # _shared/dispatch-rules.md (since the v0.5.2 SKILL.md refactor that
  # extracted shared dispatch boilerplate). Tests accept either.
  RULES_FILES="skills/study-deep/SKILL.md skills/_shared/dispatch-rules.md"
}

# Helper: returns 0 if string is found in any file in $RULES_FILES.
rules_contain() {
  local needle="$1"
  for f in $RULES_FILES; do
    grep -qF "$needle" "$f" && return 0
  done
  return 1
}

@test "Per-dispatch idempotence rule lists all three cases" {
  for case in 'exists' 'force' 'does not exist'; do
    rules_contain "$case" || { echo "missing case: $case"; return 1; }
  done
}

@test "Per-dispatch idempotence rule names all 6 dispatch sites" {
  for site in '0.4' '1.2' '2.1' '3.1' '3.2' '3.4'; do
    grep -qF "$site" skills/study-deep/SKILL.md || { echo "missing site: $site"; return 1; }
  done
}

@test "Per-dispatch idempotence rule mentions backing up to .bak.NN" {
  rules_contain '.bak.NN'
}

@test "Idempotence rule's --force backup uses smallest non-existent NN" {
  rules_contain "smallest non-existent integer"
}

@test "Skipped dispatches still count as completed in final summary" {
  rules_contain 'Skipped dispatches still count'
}
