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

@test "rerun-stage.md has frontmatter" {
  head -1 commands/rerun-stage.md | grep -qE '^---$'
}

@test "rerun-stage.md mentions all 4 stages" {
  for s in profile analysis review notes; do
    grep -qF "$s" commands/rerun-stage.md || return 1
  done
}

@test "README mentions live integration steps" {
  grep -qF 'Manual integration test' README.md
}

@test "README lists 12 expected outputs" {
  grep -qF '12 outputs' README.md
}

@test "review-round.md has frontmatter" {
  head -1 commands/review-round.md | grep -qE '^---$'
}

@test "review-round.md invokes the review-round skill" {
  grep -qF 'review-round' commands/review-round.md
}

@test "README documents /paper:review-round" {
  grep -qF '/paper:review-round' README.md
}

@test "README documents review-rounds folder" {
  grep -qF 'review-rounds/' README.md
}

@test "refine-notes.md has frontmatter" {
  head -1 commands/refine-notes.md | grep -qE '^---$'
}

@test "refine-notes.md mentions both platforms" {
  grep -qF 'xhs' commands/refine-notes.md
  grep -qF 'wechat' commands/refine-notes.md
}
