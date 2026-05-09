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

@test "study-deep SKILL.md Stage 0.2 mentions Skill tool dispatch" {
  grep -qF 'Skill tool' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md Stage 0.2 describes slug discovery" {
  grep -qF 'ls -t' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md has Flag dispatch section" {
  grep -qF '## Flag dispatch' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md Flag dispatch covers all four flags" {
  for f in --only --paper --yes --force; do
    grep -qF -e "$f" skills/study-deep/SKILL.md || { echo "missing flag: $f"; return 1; }
  done
}

@test "study-deep SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/study-deep/SKILL.md
}

@test "review-round SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/review-round/SKILL.md
}

@test "refine-notes SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/refine-notes/SKILL.md
}

@test "retitle SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/retitle/SKILL.md
}

@test "reselect-figures SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/reselect-figures/SKILL.md
}

@test "deep-dive-agent.md has required sections" {
  run check_prompt prompts/deep-dive-agent.md
  [ "$status" -eq 0 ]
}

@test "compare-agent.md has required sections" {
  run check_prompt prompts/compare-agent.md
  [ "$status" -eq 0 ]
}

@test "deep-dive SKILL.md has YAML frontmatter with name" {
  head -5 skills/deep-dive/SKILL.md | grep -qF 'name: deep-dive'
}

@test "deep-dive SKILL.md mentions deep-dive-agent dispatch" {
  grep -qF 'deep-dive-agent' skills/deep-dive/SKILL.md
}

@test "deep-dive SKILL.md mentions slugify-objection.cjs for topic-slug" {
  grep -qF 'slugify-objection.cjs' skills/deep-dive/SKILL.md
}

@test "deep-dive SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/deep-dive/SKILL.md
}

@test "compare SKILL.md has YAML frontmatter with name" {
  head -5 skills/compare/SKILL.md | grep -qF 'name: compare'
}

@test "compare SKILL.md mentions compare-agent dispatch" {
  grep -qF 'compare-agent' skills/compare/SKILL.md
}

@test "compare SKILL.md handles all four input types for other-paper" {
  for kind in 'slug' 'paper folder path' 'PDF path' 'URL'; do
    grep -qF "$kind" skills/compare/SKILL.md || { echo "missing: $kind"; return 1; }
  done
}

@test "compare SKILL.md auto-studies the other paper when needed" {
  grep -qF 'auto-studies' skills/compare/SKILL.md
}

@test "compare SKILL.md mentions --lang flag handling" {
  grep -qF -e '--lang' skills/compare/SKILL.md
}

@test "compare SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/compare/SKILL.md
}

@test "add-prior-work SKILL.md has YAML frontmatter with name" {
  head -5 skills/add-prior-work/SKILL.md | grep -qF 'name: add-prior-work'
}

@test "add-prior-work SKILL.md reuses prior-work-historian prompt" {
  grep -qF 'prior-work-historian' skills/add-prior-work/SKILL.md
}

@test "add-prior-work SKILL.md backs up 05-prior-work.md before mutation" {
  grep -qF '.bak.' skills/add-prior-work/SKILL.md
}

@test "add-prior-work SKILL.md suggests /paperstudio:review-round when prior-work weaknesses might be affected" {
  grep -qF '/paperstudio:review-round' skills/add-prior-work/SKILL.md
}

@test "add-prior-work SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/add-prior-work/SKILL.md
}

@test "reproduce-checker.md has required sections" {
  run check_prompt prompts/reproduce-checker.md
  [ "$status" -eq 0 ]
}

@test "reproduce-check SKILL.md has YAML frontmatter with name" {
  head -5 skills/reproduce-check/SKILL.md | grep -qF 'name: reproduce-check'
}

@test "reproduce-check SKILL.md mentions reproduce-checker dispatch" {
  grep -qF 'reproduce-checker' skills/reproduce-check/SKILL.md
}

@test "reproduce-check SKILL.md mentions WebFetch budget" {
  grep -qF 'WebFetch' skills/reproduce-check/SKILL.md
  grep -qF 'cap 5' skills/reproduce-check/SKILL.md
}

@test "reproduce-check SKILL.md handles ml-pure -> wet-lab N/A branch" {
  grep -qF 'ml-pure' skills/reproduce-check/SKILL.md
  grep -qF 'N/A' skills/reproduce-check/SKILL.md
}

@test "reproduce-check SKILL.md suggests /paperstudio:review-round on serious issues" {
  grep -qF '/paperstudio:review-round' skills/reproduce-check/SKILL.md
}

@test "reproduce-check SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/reproduce-check/SKILL.md
}

@test "reproduce-checker.md mandates fails_count self-check" {
  grep -qF 'self-check' prompts/reproduce-checker.md
  grep -qF 'fails_count + partials_count' prompts/reproduce-checker.md
}

@test "reproduce-checker.md mandates runtime created_at, not fabricated" {
  grep -qF 'runtime ISO8601' prompts/reproduce-checker.md
}

@test "deep-dive-agent.md length cap is 600-2000 words" {
  grep -qF '600-2000' prompts/deep-dive-agent.md
}

@test "compare-agent.md mandates runtime created_at, not fabricated" {
  grep -qF 'runtime ISO8601' prompts/compare-agent.md
}

@test "compare-agent.md mandates verbatim section headings" {
  grep -qF 'verbatim' prompts/compare-agent.md
  grep -qF 'do NOT capitalize' prompts/compare-agent.md
}

@test "compare-agent.md forbids extra sections beyond the 6 listed" {
  grep -qF 'exactly 6 H2 sections' prompts/compare-agent.md
  grep -qF 'do NOT add' prompts/compare-agent.md
}

@test "compare-agent.md length cap is 800-2800 words with self-check" {
  grep -qF '800-2800' prompts/compare-agent.md
  grep -qF 'word-count self-check' prompts/compare-agent.md
}

@test "study-deep SKILL.md allowed-tools includes Skill tool" {
  grep -qE '^allowed-tools:.*\bSkill\b' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md uses correct rerun-stage command name" {
  ! grep -qE '/paperstudio:rerun-<stage>' skills/study-deep/SKILL.md
  grep -qE '/paperstudio:rerun-stage <stage>' skills/study-deep/SKILL.md
}

@test "reviewer-synthesizer.md mandates runtime Last-updated date" {
  grep -qF 'runtime ISO8601' prompts/reviewer-synthesizer.md
  grep -qF 'do NOT fabricate' prompts/reviewer-synthesizer.md
}

@test "review-writer.md mandates runtime Last-updated date" {
  grep -qF 'runtime ISO8601' prompts/review-writer.md
}

@test "study-deep SKILL.md uses paper-folder-relative figure paths" {
  grep -qF 'paper-folder-relative' skills/study-deep/SKILL.md
  ! grep -qF 'transform to absolute paths' skills/study-deep/SKILL.md
}

@test "xhs-renderer.md mandates paper-folder-relative figure paths" {
  grep -qF 'paper-folder-relative' prompts/xhs-renderer.md
}

@test "wechat-renderer.md mandates paper-folder-relative figure paths" {
  grep -qF 'paper-folder-relative' prompts/wechat-renderer.md
}

@test "study.md argument-hint documents --paper flag" {
  grep -qF -- '--paper' commands/study.md
}

@test "add-prior-work skill is honest about DOI not being supported" {
  ! grep -qF '/ DOI' ../README.md
  grep -qF 'DOI not yet supported' skills/add-prior-work/SKILL.md
}

@test "title-generator.md disambiguates STYLE_FILTER behavior" {
  grep -qF 'all 5 candidates use that style' prompts/title-generator.md
}

@test "verify-prereqs.sh glob does not hardcode marketplace name" {
  ! grep -qE '\$HOME/\.claude/plugins/cache/claude-paper/claude-paper/' scripts/verify-prereqs.sh
  grep -qE '\$HOME/\.claude/plugins/cache/\*/claude-paper/' scripts/verify-prereqs.sh
}

@test "study-deep final summary does not leak Plan-numbered marketing" {
  ! grep -qF 'Plan 2 ✓' skills/study-deep/SKILL.md
  ! grep -qF 'Plan 3a ✓' skills/study-deep/SKILL.md
}

@test "README /paperstudio:compare example uses a real arxiv slug, not bare BERT" {
  ! grep -qF '/paperstudio:compare BERT --lang zh' ../README.md
  grep -qE '/paperstudio:compare attention-is-all-you-need' ../README.md
}

@test "all 9 skills source the resolve-paper helper instead of inline auto-detect" {
  for f in skills/study-deep/SKILL.md \
           skills/refine-notes/SKILL.md \
           skills/retitle/SKILL.md \
           skills/reselect-figures/SKILL.md \
           skills/review-round/SKILL.md \
           skills/deep-dive/SKILL.md \
           skills/compare/SKILL.md \
           skills/add-prior-work/SKILL.md \
           skills/reproduce-check/SKILL.md; do
    grep -qE 'scripts/lib/resolve-paper\.sh' "$f" || { echo "FAIL: $f does not source resolve-paper.sh"; return 1; }
    grep -qF 'resolve_paper' "$f" || { echo "FAIL: $f does not call resolve_paper"; return 1; }
  done
}

@test "no skill still has inline ls -td papers auto-detect (post-Plan-11)" {
  # After Plan 11, only the helper has this idiom; skills delegate.
  for f in skills/refine-notes/SKILL.md \
           skills/retitle/SKILL.md \
           skills/reselect-figures/SKILL.md \
           skills/review-round/SKILL.md \
           skills/deep-dive/SKILL.md \
           skills/compare/SKILL.md \
           skills/add-prior-work/SKILL.md \
           skills/reproduce-check/SKILL.md; do
    if grep -qE 'ls -td.*claude-papers/papers/\*' "$f"; then
      echo "FAIL: $f still has inline auto-detect"
      return 1
    fi
  done
  # study-deep gets a free pass — its Stage 0.2 wraps claude-paper:study and may
  # need a different paper-folder discovery mechanism (most-recently-MODIFIED is
  # how it picks the freshly-created folder). Leave that as-is.
}

@test "Plan-10 'most recently modified' assertion now lives in helper, not skills" {
  grep -qF 'most recently modified' scripts/lib/resolve-paper.sh
}

@test "all dispatching skills source the log-dispatch helper" {
  for f in skills/study-deep/SKILL.md \
           skills/review-round/SKILL.md \
           skills/deep-dive/SKILL.md \
           skills/compare/SKILL.md \
           skills/add-prior-work/SKILL.md \
           skills/reproduce-check/SKILL.md \
           skills/refine-notes/SKILL.md \
           skills/retitle/SKILL.md \
           skills/reselect-figures/SKILL.md; do
    grep -qE 'scripts/lib/log-dispatch\.sh' "$f" || { echo "FAIL: $f does not source log-dispatch.sh"; return 1; }
    grep -qF 'log_dispatch' "$f" || { echo "FAIL: $f does not call log_dispatch"; return 1; }
  done
}

@test "study-deep logs dispatch for all 11 stage sub-Agents" {
  # study-deep dispatches: paper-profiler, problem-framer, formalizer, method-analyst,
  # experiment-critic, prior-work-historian, figure-interpreter, reviewer-synthesizer,
  # notes-writer, title-generator, xhs-renderer, wechat-renderer (12 total)
  for agent in paper-profiler problem-framer formalizer method-analyst \
               experiment-critic prior-work-historian figure-interpreter \
               reviewer-synthesizer notes-writer title-generator xhs-renderer \
               wechat-renderer; do
    grep -qE "log_dispatch[[:space:]]+$agent" skills/study-deep/SKILL.md \
      || { echo "FAIL: study-deep missing log_dispatch for $agent"; return 1; }
  done
}

@test "PAPER_DEEPSTUDY_NO_RUN_LOG documented in at least one user-facing place" {
  # Document the opt-out env var so users know how to disable logging
  grep -q 'PAPER_DEEPSTUDY_NO_RUN_LOG' README.md \
    || grep -q 'PAPER_DEEPSTUDY_NO_RUN_LOG' paperstudio/README.md
}

@test "all 17 sub-Agent prompts mandate provenance HTML comment" {
  for f in prompts/paper-profiler.md \
           prompts/problem-framer.md \
           prompts/formalizer.md \
           prompts/method-analyst.md \
           prompts/experiment-critic.md \
           prompts/prior-work-historian.md \
           prompts/figure-interpreter.md \
           prompts/analysis-coherence-checker.md \
           prompts/reviewer-synthesizer.md \
           prompts/review-writer.md \
           prompts/notes-writer.md \
           prompts/title-generator.md \
           prompts/xhs-renderer.md \
           prompts/wechat-renderer.md \
           prompts/deep-dive-agent.md \
           prompts/compare-agent.md \
           prompts/reproduce-checker.md; do
    grep -qF 'Generated-by header' "$f" \
      || grep -qF '<!-- generated:' "$f" \
      || { echo "FAIL: $f missing provenance directive"; return 1; }
  done
}

@test "all 16 templates have a provenance HTML comment placeholder" {
  for f in templates/analysis/00-paper-profile.md \
           templates/analysis/01-problem.md \
           templates/analysis/02-formalization.md \
           templates/analysis/03-method-deep.md \
           templates/analysis/04-experiments.md \
           templates/analysis/05-prior-work.md \
           templates/analysis/06-figures.md \
           templates/review.md \
           templates/review-round.md \
           templates/deep-dive.md \
           templates/compare.md \
           templates/reproduce-check.md \
           templates/notes/source.md \
           templates/notes/titles.md \
           templates/notes/xhs.md \
           templates/notes/wechat.md; do
    head -1 "$f" | grep -qE '^<!-- generated:' \
      || { echo "FAIL: $f missing provenance line on line 1"; return 1; }
  done
}

@test "review-round SKILL writes provenance line into round-NN file" {
  grep -qF '<!-- generated:' skills/review-round/SKILL.md
  grep -qF 'review-round-orchestrator' skills/review-round/SKILL.md
}
