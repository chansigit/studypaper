#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "study.md exists with frontmatter" {
  head -1 commands/study.md | grep -qE '^---$'
}

@test "study.md invokes the study-deep skill" {
  grep -qF 'study-deep' commands/study.md
}
