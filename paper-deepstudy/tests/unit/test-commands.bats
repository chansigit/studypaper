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

@test "retitle.md has frontmatter" {
  head -1 commands/retitle.md | grep -qE '^---$'
}

@test "retitle.md mentions style filter" {
  grep -qF -e '--style' commands/retitle.md
}

@test "reselect-figures.md has frontmatter" {
  head -1 commands/reselect-figures.md | grep -qE '^---$'
}

@test "reselect-figures.md mentions reinterpret flag" {
  grep -qF -e '--reinterpret' commands/reselect-figures.md
}

@test "README documents /paper:refine-notes" {
  grep -qF '/paper:refine-notes' README.md
}

@test "README documents /paper:retitle" {
  grep -qF '/paper:retitle' README.md
}

@test "README documents /paper:reselect-figures" {
  grep -qF '/paper:reselect-figures' README.md
}

@test "deep-dive.md has frontmatter" {
  head -1 commands/deep-dive.md | grep -qE '^---$'
}

@test "deep-dive.md mentions topic argument" {
  grep -qF '<topic>' commands/deep-dive.md
}

@test "compare.md has frontmatter" {
  head -1 commands/compare.md | grep -qE '^---$'
}

@test "compare.md mentions --lang flag" {
  grep -qF -e '--lang' commands/compare.md
}

@test "add-prior-work.md has frontmatter" {
  head -1 commands/add-prior-work.md | grep -qE '^---$'
}

@test "add-prior-work.md mentions BibTeX, arXiv URL, and free-text inputs" {
  for kind in 'BibTeX' 'arXiv' 'free-text'; do
    grep -qiF "$kind" commands/add-prior-work.md || { echo "missing kind: $kind"; return 1; }
  done
}

@test "README documents /paper:deep-dive" {
  grep -qF '/paper:deep-dive' README.md
}

@test "README documents /paper:compare" {
  grep -qF '/paper:compare' README.md
}

@test "README documents /paper:add-prior-work" {
  grep -qF '/paper:add-prior-work' README.md
}

@test "reproduce-check.md command has frontmatter" {
  head -1 commands/reproduce-check.md | grep -qE '^---$'
}

@test "reproduce-check.md command lists 7 dimensions" {
  for d in 'data' 'code' 'hyperparameters' 'seeds' 'hardware' 'evaluation' 'wet-lab'; do
    grep -qiF "$d" commands/reproduce-check.md || { echo "missing dimension: $d"; return 1; }
  done
}

@test "README documents /paper:reproduce-check" {
  grep -qF '/paper:reproduce-check' README.md
}

@test "README has Troubleshooting section" {
  grep -qF '## Troubleshooting' README.md
}
