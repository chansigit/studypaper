#!/usr/bin/env bats

# Ensure tests run from the plugin root regardless of where bats was invoked.
setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "00-paper-profile.md has YAML frontmatter" {
  head -1 templates/analysis/00-paper-profile.md | grep -qE '^---$'
}

@test "01-problem.md exists with H1 heading" {
  grep -qE '^# ' templates/analysis/01-problem.md
}

@test "02-formalization.md has Notation section" {
  grep -qF '## Notation' templates/analysis/02-formalization.md
}

@test "03-method-deep.md has Components section" {
  grep -qF '## Components' templates/analysis/03-method-deep.md
}

@test "04-experiments.md has Critique section" {
  grep -qF '## Critique' templates/analysis/04-experiments.md
}

@test "05-prior-work.md has Timeline section" {
  grep -qF '## Timeline' templates/analysis/05-prior-work.md
}

@test "06-figures.md has frontmatter for scoring" {
  head -1 templates/analysis/06-figures.md | grep -qE '^---$'
}

@test "review.md has Score section" {
  grep -qF '## Score' templates/review.md
}

@test "notes/source.md has 9 sections" {
  count=$(grep -cE '^## ' templates/notes/source.md)
  [ "$count" -eq 9 ]
}

@test "notes/titles.md has xhs and wechat groups" {
  grep -qF '## xhs' templates/notes/titles.md
  grep -qF '## wechat' templates/notes/titles.md
}

@test "notes/xhs.md has frontmatter with title" {
  head -3 templates/notes/xhs.md | grep -qF 'title:'
}

@test "notes/wechat.md has frontmatter with title" {
  head -3 templates/notes/wechat.md | grep -qF 'title:'
}

@test "review-round.md has required frontmatter fields" {
  for f in round created_at objection dimension severity defense judge_verdict judge_reasoning user_decision user_reasoning final_verdict final_review_snippet; do
    grep -qE "^${f}:" templates/review-round.md || { echo "missing field: $f"; return 1; }
  done
}

@test "deep-dive.md has 5 required H2 sections" {
  for s in 'What is this topic' 'How the paper handles it' 'Math or algorithm detail' 'How others have approached' 'Takeaway'; do
    grep -qF "## $s" templates/deep-dive.md || { echo "missing: $s"; return 1; }
  done
}

@test "compare.md has 6 required H2 sections" {
  for s in 'Problem' 'Formalization' 'Method' 'Experiments' 'Strengths and weaknesses' 'When to use which'; do
    grep -qF "## $s" templates/compare.md || { echo "missing: $s"; return 1; }
  done
}

@test "reproduce-check.md has 7 required dimension sections" {
  for s in 'Data availability' 'Code availability' 'Hyperparameters' 'Random seeds' 'Hardware' 'Evaluation scripts' 'Wet-lab protocol'; do
    grep -qF "## $s" templates/reproduce-check.md || { echo "missing: $s"; return 1; }
  done
}
