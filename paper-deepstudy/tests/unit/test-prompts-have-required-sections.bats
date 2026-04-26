#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

required_in_prompt=(
  "## Role"
  "## Inputs"
  "## Output"
  "## Instructions"
)

check_prompt() {
  local f=$1
  for s in "${required_in_prompt[@]}"; do
    grep -qF "$s" "$f" || return 1
  done
}

@test "paper-profiler.md has all required sections" {
  run check_prompt prompts/paper-profiler.md
  [ "$status" -eq 0 ]
}

@test "problem-framer.md has required sections" {
  run check_prompt prompts/problem-framer.md
  [ "$status" -eq 0 ]
}

@test "formalizer.md has required sections" {
  run check_prompt prompts/formalizer.md
  [ "$status" -eq 0 ]
}

@test "method-analyst.md has required sections" {
  run check_prompt prompts/method-analyst.md
  [ "$status" -eq 0 ]
}

@test "experiment-critic.md has required sections" {
  run check_prompt prompts/experiment-critic.md
  [ "$status" -eq 0 ]
}

@test "prior-work-historian.md has required sections" {
  run check_prompt prompts/prior-work-historian.md
  [ "$status" -eq 0 ]
}

@test "figure-interpreter.md has required sections" {
  run check_prompt prompts/figure-interpreter.md
  [ "$status" -eq 0 ]
}

@test "reviewer-synthesizer.md has required sections" {
  run check_prompt prompts/reviewer-synthesizer.md
  [ "$status" -eq 0 ]
}

@test "notes-writer.md has required sections" {
  run check_prompt prompts/notes-writer.md
  [ "$status" -eq 0 ]
}

@test "title-generator.md has required sections" {
  run check_prompt prompts/title-generator.md
  [ "$status" -eq 0 ]
}

@test "xhs-renderer.md has required sections" {
  run check_prompt prompts/xhs-renderer.md
  [ "$status" -eq 0 ]
}

@test "wechat-renderer.md has required sections" {
  run check_prompt prompts/wechat-renderer.md
  [ "$status" -eq 0 ]
}

@test "study-deep SKILL.md has YAML frontmatter with name" {
  head -5 skills/study-deep/SKILL.md | grep -qF 'name: study-deep'
}

@test "study-deep SKILL.md mentions paper-profiler dispatch" {
  grep -qF 'paper-profiler' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md mentions all 6 Stage 1 sub-agents" {
  for s in problem-framer formalizer method-analyst experiment-critic prior-work-historian figure-interpreter; do
    grep -qF "$s" skills/study-deep/SKILL.md || return 1
  done
}

@test "study-deep SKILL.md has Stage 2 section" {
  grep -qF '## Stage 2: Review generation' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md mentions reviewer-synthesizer dispatch" {
  grep -qF 'reviewer-synthesizer' skills/study-deep/SKILL.md
}
