#!/usr/bin/env bash
set -euo pipefail

# Resolve to plugin root: tests/integration/ -> tests/ -> paperstudio/
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

# 1a. Plan 2, Plan 3b, and Plan 3c prompts exist
for p in defense-agent judge-agent review-writer deep-dive-agent compare-agent reproduce-checker; do
  if [ ! -f "$ROOT/prompts/$p.md" ]; then
    echo "FAIL: Plan 2/3b/3c prompt file missing: $ROOT/prompts/$p.md"; fail=1
  fi
done


# 2. All template files referenced by the skill exist
for t in templates/analysis/00-paper-profile.md templates/analysis/01-problem.md templates/analysis/02-formalization.md templates/analysis/03-method-deep.md templates/analysis/04-experiments.md templates/analysis/05-prior-work.md templates/analysis/06-figures.md templates/review.md templates/review-round.md templates/deep-dive.md templates/compare.md templates/reproduce-check.md templates/notes/source.md templates/notes/titles.md templates/notes/xhs.md templates/notes/wechat.md; do
  if [ ! -f "$ROOT/$t" ]; then
    echo "FAIL: template missing: $ROOT/$t"; fail=1
  fi
done

# 3. select-figures script exists and is executable
if [ ! -x "$ROOT/scripts/select-figures.cjs" ]; then
  echo "FAIL: select-figures.cjs missing or not executable"; fail=1
fi

# 3a. next-round-number script exists and is executable
if [ ! -x "$ROOT/scripts/next-round-number.cjs" ]; then
  echo "FAIL: next-round-number.cjs missing or not executable"; fail=1
fi

# 3b. parse-judge-output and slugify-objection helpers exist and are executable
for helper in parse-judge-output slugify-objection; do
  if [ ! -x "$ROOT/scripts/$helper.cjs" ]; then
    echo "FAIL: $helper.cjs missing or not executable"; fail=1
  fi
done

# 4. verify-prereqs script exists and is executable
if [ ! -x "$ROOT/scripts/verify-prereqs.sh" ]; then
  echo "FAIL: verify-prereqs.sh missing or not executable"; fail=1
fi

# 5. Domain packs exist
for d in ml-pure single-cell protein-structure protein-function genomics drug-discovery medical-imaging _template; do
  if [ ! -f "$ROOT/domain-packs/$d.md" ]; then
    echo "FAIL: domain pack missing: $d.md"; fail=1
  fi
done

# 6. Commands exist
for c in study rerun-stage review-round refine-notes retitle reselect-figures deep-dive compare add-prior-work reproduce-check; do
  if [ ! -f "$ROOT/commands/$c.md" ]; then
    echo "FAIL: command missing: $c.md"; fail=1
  fi
done

# 7. review-round skill exists
if [ ! -f "$ROOT/skills/review-round/SKILL.md" ]; then
  echo "FAIL: review-round SKILL.md missing"; fail=1
fi
if ! grep -qF 'defense-agent' "$ROOT/skills/review-round/SKILL.md" 2>/dev/null; then
  echo "FAIL: review-round SKILL.md does not mention defense-agent dispatch"; fail=1
fi

# 8. Plan 3a + 3b + 3c skills exist
for s in refine-notes retitle reselect-figures deep-dive compare add-prior-work reproduce-check; do
  if [ ! -f "$ROOT/skills/$s/SKILL.md" ]; then
    echo "FAIL: skill $s missing"; fail=1
  fi
done

if [ $fail -ne 0 ]; then
  echo "Integration smoke test: FAILED"; exit 1
fi

echo ""
echo "=== Schema validation against examples/ ==="
PLUGIN_ROOT="$(pwd)"
EXAMPLES_DIR="$(cd ../examples/string-database-2025 && pwd)"
SCHEMA_FAILURES=0
for pair in \
  "analysis/00-paper-profile.md:paper-profile" \
  "review.md:review" \
  "review-rounds/round-01-string-baseline-comparison.md:review-round" \
  "deep-dives/the-fava-co-expression-integration.md:deep-dive" \
  "compares/vs-attention-is-all-you-need.md:compare" \
  "reproduce-check.md:reproduce-check" \
  "notes/xhs.md:xhs" \
  "notes/wechat.md:wechat"; do
  rel="${pair%%:*}"
  type="${pair##*:}"
  if bash "$PLUGIN_ROOT/scripts/lib/validate-artifact.sh" "$EXAMPLES_DIR/$rel" "$type" >/dev/null 2>&1; then
    echo "  ✓ $rel ($type)"
  else
    echo "  ✗ $rel ($type)"
    bash "$PLUGIN_ROOT/scripts/lib/validate-artifact.sh" "$EXAMPLES_DIR/$rel" "$type" 2>&1 | sed 's/^/      /'
    SCHEMA_FAILURES=$((SCHEMA_FAILURES + 1))
  fi
done

if [ $SCHEMA_FAILURES -ne 0 ]; then
  echo ""
  echo "ERROR: $SCHEMA_FAILURES schema validation failure(s)"
  exit 1
fi

# Behavior assertions over the golden snapshot — content invariants beyond schema.
# Pinned in tests/behavior/test-golden-string-database.bats. See that file's
# header for how to refresh the snapshot when prompt changes are intentional.
if command -v bats >/dev/null 2>&1; then
  echo ""
  echo "=== Behavior assertions (golden snapshot) ==="
  if ! bats "$PLUGIN_ROOT/tests/behavior/" 2>&1 | tail -3; then
    echo "ERROR: golden behavior assertions failed"
    exit 1
  fi
else
  echo ""
  echo "(skipping behavior assertions: bats not in PATH)"
fi

echo "Integration smoke test: PASSED"
