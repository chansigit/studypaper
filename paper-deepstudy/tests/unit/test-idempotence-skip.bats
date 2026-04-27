#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "Per-dispatch idempotence rule lists all three cases" {
  for case in 'exists and `--force` is not set' 'exists and `--force` is set' 'does not exist'; do
    grep -qF "$case" skills/study-deep/SKILL.md || { echo "missing case: $case"; return 1; }
  done
}

@test "Per-dispatch idempotence rule names all 6 dispatch sites" {
  for site in '0.4' '1.2' '2.1' '3.1' '3.2' '3.4'; do
    grep -qF "$site" skills/study-deep/SKILL.md || { echo "missing site: $site"; return 1; }
  done
}

@test "Per-dispatch idempotence rule mentions backing up to .bak.NN" {
  grep -qF '.bak.NN' skills/study-deep/SKILL.md
}

@test "Idempotence rule's --force backup uses smallest non-existent NN" {
  grep -qF "smallest non-existent integer" skills/study-deep/SKILL.md
}

@test "Skipped dispatches still count as completed in final summary" {
  grep -qF 'Skipped dispatches still count' skills/study-deep/SKILL.md
}
