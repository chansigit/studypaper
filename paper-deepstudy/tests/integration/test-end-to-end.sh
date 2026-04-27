#!/usr/bin/env bash
set -euo pipefail

# Resolve to plugin root: tests/integration/ -> tests/ -> paper-deepstudy/
cd "$(dirname "$0")/../.."

ROOT=.
SKILL=$ROOT/skills/study-deep/SKILL.md

fail=0

# 1. All prompt files referenced by the skill exist
for p in paper-profiler problem-framer formalizer method-analyst experiment-critic prior-work-historian figure-interpreter reviewer-synthesizer notes-writer title-generator xhs-renderer wechat-renderer; do
  if ! grep -qF "$p" $SKILL; then
    echo "FAIL: skill does not mention prompt $p"; fail=1
  fi
  if [ ! -f "$ROOT/prompts/$p.md" ]; then
    echo "FAIL: prompt file missing: $ROOT/prompts/$p.md"; fail=1
  fi
done

# 2. All template files referenced by the skill exist
for t in templates/analysis/00-paper-profile.md templates/analysis/01-problem.md templates/analysis/02-formalization.md templates/analysis/03-method-deep.md templates/analysis/04-experiments.md templates/analysis/05-prior-work.md templates/analysis/06-figures.md templates/review.md templates/notes/source.md templates/notes/titles.md templates/notes/xhs.md templates/notes/wechat.md; do
  if [ ! -f "$ROOT/$t" ]; then
    echo "FAIL: template missing: $ROOT/$t"; fail=1
  fi
done

# 3. select-figures script exists and is executable
if [ ! -x "$ROOT/scripts/select-figures.cjs" ]; then
  echo "FAIL: select-figures.cjs missing or not executable"; fail=1
fi

# 4. verify-prereqs script exists and is executable
if [ ! -x "$ROOT/scripts/verify-prereqs.sh" ]; then
  echo "FAIL: verify-prereqs.sh missing or not executable"; fail=1
fi

# 5. Domain packs exist
for d in ml-pure single-cell _template; do
  if [ ! -f "$ROOT/domain-packs/$d.md" ]; then
    echo "FAIL: domain pack missing: $d.md"; fail=1
  fi
done

# 6. Commands exist
for c in study rerun-stage; do
  if [ ! -f "$ROOT/commands/$c.md" ]; then
    echo "FAIL: command missing: $c.md"; fail=1
  fi
done

if [ $fail -ne 0 ]; then
  echo "Integration smoke test: FAILED"; exit 1
fi

echo "Integration smoke test: PASSED"
