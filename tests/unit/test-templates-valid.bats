#!/usr/bin/env bats

@test "00-paper-profile.md has YAML frontmatter" {
  head -1 paper-deepstudy/templates/analysis/00-paper-profile.md | grep -qE '^---$'
}

@test "01-problem.md exists with H1 heading" {
  grep -qE '^# ' paper-deepstudy/templates/analysis/01-problem.md
}

@test "02-formalization.md has Notation section" {
  grep -qF '## Notation' paper-deepstudy/templates/analysis/02-formalization.md
}

@test "03-method-deep.md has Components section" {
  grep -qF '## Components' paper-deepstudy/templates/analysis/03-method-deep.md
}

@test "04-experiments.md has Critique section" {
  grep -qF '## Critique' paper-deepstudy/templates/analysis/04-experiments.md
}

@test "05-prior-work.md has Timeline section" {
  grep -qF '## Timeline' paper-deepstudy/templates/analysis/05-prior-work.md
}

@test "06-figures.md has frontmatter for scoring" {
  head -1 paper-deepstudy/templates/analysis/06-figures.md | grep -qE '^---$'
}
