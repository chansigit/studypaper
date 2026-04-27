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

@test "study-deep SKILL.md has Stage 3 section" {
  grep -qF '## Stage 3: Notes generation' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md mentions all 4 Stage 3 sub-agents" {
  for s in notes-writer title-generator xhs-renderer wechat-renderer; do
    grep -qF "$s" skills/study-deep/SKILL.md || return 1
  done
}

@test "study-deep SKILL.md mentions select-figures.cjs" {
  grep -qF 'select-figures.cjs' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md documents --force flag" {
  grep -qF -e '--force' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md documents --yes flag" {
  grep -qF -e '--yes' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md describes skip-existing default" {
  grep -qiF 'skip' skills/study-deep/SKILL.md && \
    grep -qF '.bak.' skills/study-deep/SKILL.md
}

@test "defense-agent.md has required sections" {
  run check_prompt prompts/defense-agent.md
  [ "$status" -eq 0 ]
}

@test "judge-agent.md has required sections" {
  run check_prompt prompts/judge-agent.md
  [ "$status" -eq 0 ]
}

@test "review-writer.md has required sections" {
  run check_prompt prompts/review-writer.md
  [ "$status" -eq 0 ]
}

@test "review-round SKILL.md has YAML frontmatter with name" {
  head -5 skills/review-round/SKILL.md | grep -qF 'name: review-round'
}

@test "review-round SKILL.md describes the 7-step flow" {
  for s in defense-agent judge-agent review-writer next-round-number.cjs; do
    grep -qF "$s" skills/review-round/SKILL.md || { echo "missing reference: $s"; return 1; }
  done
}

@test "review-round SKILL.md mentions --sequential flag" {
  grep -qF -e '--sequential' skills/review-round/SKILL.md
}

@test "review-round SKILL.md mentions --paper flag" {
  grep -qF -e '--paper' skills/review-round/SKILL.md
}

@test "refine-notes SKILL.md has YAML frontmatter with name" {
  head -5 skills/refine-notes/SKILL.md | grep -qF 'name: refine-notes'
}

@test "refine-notes SKILL.md mentions xhs-renderer and wechat-renderer dispatch" {
  grep -qF 'xhs-renderer' skills/refine-notes/SKILL.md
  grep -qF 'wechat-renderer' skills/refine-notes/SKILL.md
}

@test "refine-notes SKILL.md describes .bak. backup convention" {
  grep -qF '.bak.' skills/refine-notes/SKILL.md
}

@test "retitle SKILL.md has YAML frontmatter with name" {
  head -5 skills/retitle/SKILL.md | grep -qF 'name: retitle'
}

@test "retitle SKILL.md mentions title-generator dispatch" {
  grep -qF 'title-generator' skills/retitle/SKILL.md
}

@test "retitle SKILL.md describes history archival" {
  grep -qF 'history' skills/retitle/SKILL.md
}

@test "reselect-figures SKILL.md has YAML frontmatter with name" {
  head -5 skills/reselect-figures/SKILL.md | grep -qF 'name: reselect-figures'
}

@test "reselect-figures SKILL.md mentions xhs-renderer and wechat-renderer dispatch" {
  grep -qF 'xhs-renderer' skills/reselect-figures/SKILL.md
  grep -qF 'wechat-renderer' skills/reselect-figures/SKILL.md
}

@test "reselect-figures SKILL.md mentions figure-interpreter for --reinterpret" {
  grep -qF 'figure-interpreter' skills/reselect-figures/SKILL.md
}
