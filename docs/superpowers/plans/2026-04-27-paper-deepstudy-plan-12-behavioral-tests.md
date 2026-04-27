# paper-deepstudy Plan 12: Phase B — Behavioral Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase B 给 plugin 加真正的行为级测试 —— 不再仅仅 grep prompt 文本是否包含某些字符串,而是验证产物文件 *实际上* 满足契约(必需 frontmatter keys、必需 H2、provenance 头、不含禁止内容)。同时把现有的 4 个 node helper 测试扩充到边界 case,让真正会出问题的输入也被覆盖。

**Architecture:** 用一个新的 `scripts/lib/validate-artifact.sh` 作为 schema-验证 harness;一个新的 bats 文件把它跑在已 commit 的 `examples/string-database-2025/` 真实产物上;扩充 4 个现有的 node 测试加 14 个新的边界 case;集成 smoke test 也调用 validate harness。Phase B 后的 188 → ~225 测试。

**Tech Stack:** Bash + Bats + Node。无新外部依赖。复用 Phase A 已加的 provenance line 作为 schema 锚点(Plan 11 让所有产物文件 line 1 都有 `<!-- generated: ... -->`,Plan 12 把它升级成 *被验证* 的契约)。

**Phase B 之后的边界:** 不引入 LLM 真实 dispatch 测试(成本高,不在 v1 范围)。Schema 验证基于已 commit 的 examples/,不实时跑 sub-Agent。

**任务条目:**

| # | Task | 内容 | Effort |
|---|---|---|---|
| 1 | `scripts/lib/validate-artifact.sh` + bats(验证 harness 自身有 ~10 个测试) | 1.5h |
| 2 | `tests/unit/test-schema-validation.bats` 用 harness 跑 8 个 example artifact | 1h |
| 3 | `test-slugify-objection.cjs` 加 6 个边界 case(emoji-only / surrogate / RTL / mixed / >40 / consecutive whitespace) | 0.5h |
| 4 | `test-parse-judge-output.cjs` 加 5 个边界 case(yml / YAML / no-fence / multi-doc / fence-extra-text) | 0.5h |
| 5 | `test-select-figures.cjs` 加 4 个边界 case(string importance / missing field / multi-line caption / empty input) | 0.5h |
| 6 | wire validate-artifact 进 integration smoke + 删除死 fixture `tiny-paper` | 0.5h |

6 task,每 task 一个 commit。预期总实施时间 ~4.5 小时。

---

## File Structure

```
paper-deepstudy/
├── scripts/
│   └── lib/
│       └── validate-artifact.sh             (NEW — Task 1)
├── tests/
│   ├── unit/
│   │   ├── test-validate-artifact.bats      (NEW — Task 1, harness self-test)
│   │   ├── test-schema-validation.bats      (NEW — Task 2, runs harness on examples/)
│   │   ├── test-slugify-objection.cjs       (modified — Task 3)
│   │   ├── test-parse-judge-output.cjs      (modified — Task 4)
│   │   └── test-select-figures.cjs          (modified — Task 5)
│   ├── integration/
│   │   └── test-end-to-end.sh               (modified — Task 6)
│   └── fixtures/
│       └── tiny-paper/                      (DELETED — Task 6, dead since Plan 1)
```

无新外部依赖,无 prompt / template / skill 改动 —— 这是纯测试增强。

---

## Pre-flight

Branch `feat/plan-12-behavioral-tests` 已从 post-Plan-11 main(48e964b)长出。`cd paper-deepstudy && npm run test:unit` 通过(188 bats + 4 node + integration smoke pass)。

Plan 11 加的 provenance line 是 Plan 12 schema 验证的核心锚点。所有 examples/ 下的产物文件都是 Plan-7 时期生成的,**还没有 provenance line**。所以 Plan 12 Task 2 在跑 schema 验证之前要 *人工* 给 examples/ 的 8 个文件补上 provenance 头(见 Task 2 Step 0)。

---

### Task 1: scripts/lib/validate-artifact.sh + bats

**Files:**
- Create: `paper-deepstudy/scripts/lib/validate-artifact.sh`
- Create: `paper-deepstudy/tests/unit/test-validate-artifact.bats`

**Helper 契约:**

```
validate-artifact.sh <file> <artifact-type>
```

`<artifact-type>` ∈ `paper-profile`、`review`、`review-round`、`deep-dive`、`compare`、`reproduce-check`、`xhs`、`wechat`、`source`、`titles`、`analysis-01-problem`、`analysis-02-formalization`、`analysis-03-method`、`analysis-04-experiments`、`analysis-05-prior-work`、`analysis-06-figures`(16 种)。

**每种 artifact 的 schema 包括 4 类断言:**

1. **Provenance 必需** — line 1 匹配 `^<!-- generated: .* by .* (paper-deepstudy v.*) -->$`(占位符或填好的 timestamp 都允许).
2. **Frontmatter 必需 keys** — 如果 artifact 有 YAML frontmatter,断言指定的 keys 出现.
3. **必需 H2 headings** — 文件包含每个必需的 H2.
4. **禁止内容** — 文件不含某些 banned pattern(例如 fabricated date 占位符 `<runtime-date>` 没被替换、`/Users/` 绝对路径、Plan 编号泄漏 `Plan 2 ✓` 等).

返回:
- 退出 0:全部断言通过.
- 退出 1:任一断言失败,stderr 打印失败原因.
- 退出 2:未知 artifact-type.

**16 种 schema 定义(Task 1 Step 4 实现):**

| Type | Frontmatter keys | H2 headings | 禁止内容 |
|---|---|---|---|
| paper-profile | `paper_type`, `domain`, `difficulty`, `domain_packs_selected` | (none, just frontmatter + body) | `<runtime-timestamp>`(未填) |
| review | (no frontmatter) | `Strengths`, `Weaknesses`, `Score` | `<runtime-timestamp>`, `Plan 2 ✓` |
| review-round | `slug`, `round`, `verdict` | `Objection`, `Defense`, `Judge verdict` | `<runtime-timestamp>` |
| deep-dive | `slug`, `topic`, `created_at`, `language` | (5 H2 already in template) | `<runtime-timestamp>`, `/Users/` |
| compare | `this_paper`, `other_paper`, `created_at`, `language` | `Problem`, `Formalization`, `Method`, `Experiments`, `Strengths and weaknesses`, `When to use which` | `<runtime-timestamp>`, `Strengths and Weaknesses`(大写 W,Plan 8 C2),`Summary`(Plan 8 C3) |
| reproduce-check | `slug`, `overall_score`, `fails_count`, `partials_count`, `checked_dimensions` | `Data`, `Code`, `Hyperparameters`, `Random seeds`, `Hardware`, `Evaluation scripts`, `Wet-lab protocol` | `<runtime-timestamp>` |
| xhs | `title`, `figures` | (no H2 required, body is 小红书 prose) | `<runtime-timestamp>`, `/Users/`, `file://` |
| wechat | `title`, `figures` | (similar) | `<runtime-timestamp>`, `/Users/`, `file://` |
| source | (frontmatter optional) | `背景`, `贡献`, `方法`, `实验`(中文 H2,notes-writer prompt 要求的) | `<runtime-timestamp>` |
| titles | `xhs`, `wechat`(两个 list) | (no H2 required) | `<runtime-timestamp>` |
| analysis-01-problem ~ analysis-06-figures | (per-template) | (per-template) | `<runtime-timestamp>` |

详细 schema 在实现时根据每个模板的实际内容确定。这张表给方向。

- [ ] **Step 1: 写 failing bats `tests/unit/test-validate-artifact.bats`**

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  TMPDIR_T="$(mktemp -d)"
  export TMPDIR_T
}

teardown() {
  [ -n "$TMPDIR_T" ] && rm -rf "$TMPDIR_T"
}

# ---------- happy path ----------

@test "validate-artifact: review with all required H2 + provenance passes" {
  cat > "$TMPDIR_T/review.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by reviewer-synthesizer (paper-deepstudy v0.1.0) -->

# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/review.md" review
  [ "$status" -eq 0 ]
}

@test "validate-artifact: compare with all 6 H2 + provenance passes" {
  cat > "$TMPDIR_T/c.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by compare-agent (paper-deepstudy v0.1.0) -->
---
this_paper: foo
other_paper: bar
created_at: 2026-04-27T12:00:00Z
language: english
---

# Compare: foo vs bar

## Problem
x

## Formalization
y

## Method
z

## Experiments
w

## Strengths and weaknesses
| a | b | c |

## When to use which
v
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/c.md" compare
  [ "$status" -eq 0 ]
}

# ---------- failure: missing provenance ----------

@test "validate-artifact: file with no provenance line 1 fails with code 1" {
  cat > "$TMPDIR_T/r.md" <<'EOF'
# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/r.md" review
  [ "$status" -eq 1 ]
  [[ "$output" == *"provenance"* ]] || [[ "$output" == *"generated:"* ]]
}

# ---------- failure: missing required H2 ----------

@test "validate-artifact: review missing Score H2 fails" {
  cat > "$TMPDIR_T/r.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by reviewer-synthesizer (paper-deepstudy v0.1.0) -->

# Review

## Strengths
foo

## Weaknesses
bar
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/r.md" review
  [ "$status" -eq 1 ]
  [[ "$output" == *"Score"* ]]
}

# ---------- failure: banned content ----------

@test "validate-artifact: compare with capitalized 'Strengths and Weaknesses' fails (C2 regression guard)" {
  cat > "$TMPDIR_T/c.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by compare-agent (paper-deepstudy v0.1.0) -->
---
this_paper: foo
other_paper: bar
created_at: 2026-04-27T12:00:00Z
language: english
---

# Compare: foo vs bar

## Problem
x

## Formalization
y

## Method
z

## Experiments
w

## Strengths and Weaknesses
| a | b | c |

## When to use which
v
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/c.md" compare
  [ "$status" -eq 1 ]
}

@test "validate-artifact: xhs with absolute /Users/ figure path fails (Plan 9 I7 regression guard)" {
  cat > "$TMPDIR_T/xhs.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by xhs-renderer (paper-deepstudy v0.1.0) -->
---
title: foo
figures:
  - /Users/me/foo.jpeg
---

正文。
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/xhs.md" xhs
  [ "$status" -eq 1 ]
  [[ "$output" == *"/Users/"* ]] || [[ "$output" == *"absolute"* ]]
}

@test "validate-artifact: review with unfilled <runtime-timestamp> placeholder fails (R3/C1 regression guard)" {
  cat > "$TMPDIR_T/r.md" <<'EOF'
<!-- generated: <runtime-timestamp> by reviewer-synthesizer (paper-deepstudy v0.1.0) -->

# Review

## Strengths
foo

## Weaknesses
bar

## Score
8/10
EOF
  # The provenance line itself uses placeholder <runtime-timestamp>; this means
  # the LLM did not fill in. validate-artifact treats this as a failure.
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/r.md" review
  [ "$status" -eq 1 ]
  [[ "$output" == *"runtime-timestamp"* ]] || [[ "$output" == *"placeholder"* ]]
}

# ---------- failure: missing frontmatter key ----------

@test "validate-artifact: paper-profile missing 'domain' key fails" {
  cat > "$TMPDIR_T/p.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by paper-profiler (paper-deepstudy v0.1.0) -->
---
paper_type: architecture
difficulty: advanced
domain_packs_selected: [ml-pure]
---

# Profile
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/p.md" paper-profile
  [ "$status" -eq 1 ]
  [[ "$output" == *"domain"* ]]
}

# ---------- unknown artifact type ----------

@test "validate-artifact: unknown artifact-type returns code 2" {
  cat > "$TMPDIR_T/x.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by foo (paper-deepstudy v0.1.0) -->
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/x.md" not-a-real-type
  [ "$status" -eq 2 ]
}

# ---------- nonexistent file ----------

@test "validate-artifact: nonexistent file returns code 1" {
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/nope.md" review
  [ "$status" -eq 1 ]
}

# ---------- reproduce-check lookup-table consistency ----------

@test "validate-artifact: reproduce-check with fails_count >= 2 but score yellow fails (R2 regression guard)" {
  cat > "$TMPDIR_T/rc.md" <<'EOF'
<!-- generated: 2026-04-27T12:00:00Z by reproduce-checker (paper-deepstudy v0.1.0) -->
---
slug: foo
overall_score: yellow
fails_count: 3
partials_count: 1
checked_dimensions: 7
---

# Reproducibility check

## Data
✗

## Code
✗

## Hyperparameters
✗

## Random seeds
partial

## Hardware
✓

## Evaluation scripts
✓

## Wet-lab protocol
N/A
EOF
  run bash scripts/lib/validate-artifact.sh "$TMPDIR_T/rc.md" reproduce-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"fails_count"* ]] || [[ "$output" == *"red"* ]]
}
```

(总计 ~10 个 happy-path + failure-mode + edge-case 测试.)

- [ ] **Step 2: Verify fail.**

```bash
cd paper-deepstudy && bats tests/unit/test-validate-artifact.bats
```

预期 ~10 fail.

- [ ] **Step 3: 写 helper `paper-deepstudy/scripts/lib/validate-artifact.sh`**

```bash
#!/usr/bin/env bash
# scripts/lib/validate-artifact.sh — schema-validate a paper-deepstudy artifact file.
#
# Usage:
#   validate-artifact.sh <file> <artifact-type>
#
# Artifact types:
#   paper-profile, review, review-round, deep-dive, compare, reproduce-check,
#   xhs, wechat, source, titles,
#   analysis-01-problem, analysis-02-formalization, analysis-03-method,
#   analysis-04-experiments, analysis-05-prior-work, analysis-06-figures
#
# Exit codes:
#   0 — all assertions pass
#   1 — at least one assertion failed (stderr lists failures)
#   2 — unknown artifact-type

set -euo pipefail

FILE="${1:-}"
TYPE="${2:-}"

if [ -z "$FILE" ] || [ -z "$TYPE" ]; then
  echo "Usage: validate-artifact.sh <file> <artifact-type>" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "Error: file not found: $FILE" >&2
  exit 1
fi

# Track failures; print all then exit
FAILS=()

fail() {
  FAILS+=("$1")
}

check_provenance() {
  local line1
  line1=$(head -1 "$FILE")
  if ! [[ "$line1" =~ ^\<!--\ generated:\ .+\ by\ .+\ \(paper-deepstudy\ v.+\)\ --\>$ ]]; then
    fail "missing or malformed provenance line at line 1 (got: $line1)"
    return
  fi
  # Disallow unfilled <runtime-timestamp> placeholder
  if [[ "$line1" == *"<runtime-timestamp>"* ]]; then
    fail "provenance line still contains <runtime-timestamp> placeholder (LLM did not fill in)"
  fi
}

check_required_h2() {
  local heading="$1"
  if ! grep -qE "^## $heading\$|^## $heading[ ]+\$" "$FILE"; then
    fail "missing required H2 heading: '## $heading'"
  fi
}

check_required_fm_key() {
  local key="$1"
  # Frontmatter keys are matched anywhere in the file (loose match)
  if ! grep -qE "^$key:" "$FILE"; then
    fail "missing required frontmatter key: '$key:'"
  fi
}

check_no_pattern() {
  local pat="$1"
  local label="$2"
  if grep -qF "$pat" "$FILE"; then
    fail "banned content found ($label): '$pat'"
  fi
}

# --- Always check provenance ---
check_provenance

# --- Per-type checks ---
case "$TYPE" in
  paper-profile)
    check_required_fm_key paper_type
    check_required_fm_key domain
    check_required_fm_key difficulty
    check_required_fm_key domain_packs_selected
    ;;
  review)
    check_required_h2 Strengths
    check_required_h2 Weaknesses
    check_required_h2 Score
    check_no_pattern "Plan 2 ✓" "plan-numbered leak"
    check_no_pattern "Plan 3a ✓" "plan-numbered leak"
    ;;
  review-round)
    check_required_fm_key slug
    check_required_fm_key round
    check_required_fm_key verdict
    check_required_h2 Objection
    check_required_h2 Defense
    ;;
  deep-dive)
    check_required_fm_key slug
    check_required_fm_key topic
    check_required_fm_key created_at
    check_required_fm_key language
    check_no_pattern "/Users/" "absolute path leak"
    ;;
  compare)
    check_required_fm_key this_paper
    check_required_fm_key other_paper
    check_required_fm_key created_at
    check_required_fm_key language
    check_required_h2 Problem
    check_required_h2 Formalization
    check_required_h2 Method
    check_required_h2 Experiments
    check_required_h2 "Strengths and weaknesses"
    check_required_h2 "When to use which"
    check_no_pattern "## Strengths and Weaknesses" "C2 capitalization regression"
    check_no_pattern "## Summary" "C3 extra section regression"
    ;;
  reproduce-check)
    check_required_fm_key slug
    check_required_fm_key overall_score
    check_required_fm_key fails_count
    check_required_fm_key partials_count
    check_required_fm_key checked_dimensions
    check_required_h2 Data
    check_required_h2 Code
    check_required_h2 Hyperparameters
    check_required_h2 "Random seeds"
    check_required_h2 Hardware
    check_required_h2 "Evaluation scripts"
    check_required_h2 "Wet-lab protocol"
    # Lookup-table consistency: fails_count >= 2 must be red
    fails_count=$(grep -E '^fails_count:' "$FILE" | head -1 | sed 's/^fails_count:[[:space:]]*//')
    overall=$(grep -E '^overall_score:' "$FILE" | head -1 | sed 's/^overall_score:[[:space:]]*//')
    if [ -n "$fails_count" ] && [ "$fails_count" -ge 2 ] && [ "$overall" != "red" ]; then
      fail "lookup-table violation: fails_count=$fails_count >= 2 must imply overall_score=red, got '$overall' (R2 regression)"
    fi
    ;;
  xhs|wechat)
    check_required_fm_key title
    check_required_fm_key figures
    check_no_pattern "/Users/" "absolute path leak (I7 regression)"
    check_no_pattern "file://" "file:// scheme leak (I7 regression)"
    ;;
  source)
    # source.md is in Chinese; H2s are 中文. notes-writer mandates these.
    if ! grep -qE '^## (背景|Background)' "$FILE"; then
      fail "source.md missing 背景/Background H2"
    fi
    ;;
  titles)
    check_required_fm_key xhs
    check_required_fm_key wechat
    ;;
  analysis-01-problem)
    # template line 1 is provenance; line 2 expects to be H1 or empty then H1.
    # No specific frontmatter required.
    if ! grep -qE '^# ' "$FILE"; then
      fail "missing H1 heading"
    fi
    ;;
  analysis-02-formalization)
    check_required_h2 Notation
    ;;
  analysis-03-method)
    check_required_h2 Components
    ;;
  analysis-04-experiments)
    check_required_h2 Critique
    ;;
  analysis-05-prior-work)
    check_required_h2 Timeline
    ;;
  analysis-06-figures)
    # 06-figures has frontmatter (per Plan 1 figure-interpreter)
    # We don't enforce a specific schema here yet — Phase B can be more loose
    if ! grep -qE '^# ' "$FILE"; then
      fail "missing H1 heading"
    fi
    ;;
  *)
    echo "Error: unknown artifact-type '$TYPE'" >&2
    exit 2
    ;;
esac

# --- Report ---
if [ ${#FAILS[@]} -eq 0 ]; then
  exit 0
fi

echo "validate-artifact: $FILE ($TYPE) — ${#FAILS[@]} failure(s):" >&2
for f in "${FAILS[@]}"; do
  echo "  - $f" >&2
done
exit 1
```

`chmod +x scripts/lib/validate-artifact.sh`.

- [ ] **Step 4: Verify pass** — 10/10 bats pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/scripts/lib/validate-artifact.sh \
        paper-deepstudy/tests/unit/test-validate-artifact.bats
git commit -m "feat(paper-deepstudy): scripts/lib/validate-artifact.sh — schema validation harness for 16 artifact types (Plan 12 T1)"
```

---

### Task 2: tests/unit/test-schema-validation.bats — run harness on examples/

**Files:**
- Modify: 8 files under `examples/string-database-2025/` 加 provenance line(以前生成时还没有 Phase A)
- Create: `paper-deepstudy/tests/unit/test-schema-validation.bats`

**Background:** `examples/string-database-2025/` 的 8 个产物文件是 Plan 7 时期生成的,**早于** Plan 11(provenance line 还没引入)。Phase B 把它们当作 schema 验证的 golden fixture,所以要先给每个文件 line 1 加上 provenance 注释(用 `Plan 7 retrofit` 作为 timestamp 标识符,因为是事后回填,不是实际生成时间戳)。

- [ ] **Step 0(prep): retrofit provenance to 8 example files**

为以下 8 个文件 prepend 一行 provenance(line 1)。用作者明确的"this is a retrofit"timestamp。以 review.md 为例:

```bash
# Before (line 1):
# **Last updated:** 2026-04-25

# After (lines 1-2):
<!-- generated: 2026-04-25T00:00:00Z by reviewer-synthesizer (paper-deepstudy v0.1.0) [Plan 7 retrofit] -->
**Last updated:** 2026-04-25
```

具体每个文件:

| File | Author |
|---|---|
| examples/string-database-2025/analysis/00-paper-profile.md | paper-profiler |
| examples/string-database-2025/review.md | reviewer-synthesizer |
| examples/string-database-2025/review-rounds/round-01-string-baseline-comparison.md | review-round-orchestrator |
| examples/string-database-2025/deep-dives/the-fava-co-expression-integration.md | deep-dive-agent |
| examples/string-database-2025/compares/vs-attention-is-all-you-need.md | compare-agent |
| examples/string-database-2025/reproduce-check.md | reproduce-checker |
| examples/string-database-2025/notes/xhs.md | xhs-renderer |
| examples/string-database-2025/notes/wechat.md | wechat-renderer |

每个文件 line 1 加:

```html
<!-- generated: <retrofit-timestamp>Z by <author> (paper-deepstudy v0.1.0) [Plan 7 retrofit] -->
```

`<retrofit-timestamp>` 用文件的 git first-commit timestamp 或一个保守值(如 `2026-04-25T00:00:00`)。

- [ ] **Step 1: 写 failing bats `tests/unit/test-schema-validation.bats`**

```bash
#!/usr/bin/env bats

setup() {
  # Note: setup() cd's to paper-deepstudy/, but examples/ are at repo root.
  # So examples paths are ../examples/...
  cd "$BATS_TEST_DIRNAME/../.."
  REPO_ROOT="$(cd .. && pwd)"
  export REPO_ROOT
}

@test "examples/string-database-2025/analysis/00-paper-profile.md passes paper-profile schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/analysis/00-paper-profile.md" \
    paper-profile
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/review.md passes review schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/review.md" \
    review
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/review-rounds/round-01.md passes review-round schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/review-rounds/round-01-string-baseline-comparison.md" \
    review-round
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/deep-dives/...md passes deep-dive schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/deep-dives/the-fava-co-expression-integration.md" \
    deep-dive
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/compares/vs-...md passes compare schema" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/compares/vs-attention-is-all-you-need.md" \
    compare
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/reproduce-check.md passes reproduce-check schema (post-Plan-9 fix)" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/reproduce-check.md" \
    reproduce-check
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/notes/xhs.md passes xhs schema (post-Plan-9 path fix)" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/notes/xhs.md" \
    xhs
  [ "$status" -eq 0 ]
}

@test "examples/string-database-2025/notes/wechat.md passes wechat schema (post-Plan-9 path fix)" {
  run bash scripts/lib/validate-artifact.sh \
    "$REPO_ROOT/examples/string-database-2025/notes/wechat.md" \
    wechat
  [ "$status" -eq 0 ]
}
```

8 tests, one per artifact in the example set.

- [ ] **Step 2: Verify fail.**

如果 Step 0 的 retrofit 没做完,这 8 tests 会 fail(provenance 缺失)。Step 0 完成后,有的可能还会因为其它 schema 不一致而 fail —— 那就 *修* example 文件让它合规(因为现在我们已经定义了契约,example 必须满足)。

- [ ] **Step 3: 让 8 tests pass**

跑测试,看哪个失败。常见预期失败:
- `compare` 检查 banned `## Strengths and Weaknesses`(Plan 8 C2)—— example 是 Plan 8 *之前*生成的,可能含大写。修 example 对应行。
- `reproduce-check` 检查 fails_count >= 2 → red(Plan 6 R2)—— Plan 9 I5 已经修过,应该 pass。
- `xhs/wechat` 检查 `/Users/` 和 `file://` —— Plan 9 I7 已修过,应该 pass。

每个失败:**修 example 文件**(不是修 helper),直到 8/8 pass。

- [ ] **Step 4: Commit**

```bash
git add examples/string-database-2025/ \
        paper-deepstudy/tests/unit/test-schema-validation.bats
git commit -m "feat(paper-deepstudy): schema validation runs against examples/ — provenance retrofit + 8 schema tests (Plan 12 T2)"
```

---

### Task 3: test-slugify-objection.cjs — 6 边界 case

**Files:**
- Modify: `paper-deepstudy/tests/unit/test-slugify-objection.cjs`

现有测试覆盖:基础 ASCII、空、CJK fallback。

新增 6 个 case:

```javascript
// --- Plan 12 T3: edge cases ---

// 1. emoji-only input → CJK fallback or untitled (no ASCII to keep)
{
  const out = slugifyObjection('🎉🚀💡');
  console.assert(out !== '', `emoji-only should not be empty, got "${out}"`);
  console.assert(/^cjk-[a-f0-9]{6}$|^untitled$/.test(out),
    `emoji-only should fall back to cjk-<hash> or untitled, got "${out}"`);
  console.log('  ✓ emoji-only input handled');
}

// 2. surrogate pair (some emoji are encoded as surrogate pairs in JS strings)
{
  const out1 = slugifyObjection('💯foo bar');
  const out2 = slugifyObjection('foo bar');
  console.assert(out1 === out2 || out1.startsWith('foo'),
    `surrogate-pair prefix should not destroy ASCII content; got "${out1}"`);
  console.log('  ✓ surrogate-pair input handled');
}

// 3. RTL Hebrew
{
  const out = slugifyObjection('שלום עולם');
  // No ASCII; should NOT be untitled (we treat any non-ASCII as worth hashing)
  // Currently the CJK regex doesn't match Hebrew. So it falls to 'untitled'.
  // That's a known limitation — assert and document.
  console.assert(out === 'untitled' || /^cjk-/.test(out),
    `RTL Hebrew either untitled or hashed; got "${out}"`);
  console.log('  ✓ RTL Hebrew input handled (currently falls to untitled — known limitation)');
}

// 4. mixed ASCII + CJK — ASCII portion wins
{
  const out = slugifyObjection('attention 推导 mechanism');
  console.assert(out.includes('attention') && out.includes('mechanism'),
    `mixed should preserve ASCII words; got "${out}"`);
  console.assert(!out.includes('cjk-'), `mixed has ASCII so should not fall to cjk-hash; got "${out}"`);
  console.log('  ✓ mixed ASCII + CJK input handled');
}

// 5. very long input (>40 chars) — should cap at 40
{
  const out = slugifyObjection('this is a really really really really really really long objection text exceeding the cap');
  console.assert(out.length <= 40, `slug should cap at 40 chars; got length ${out.length}: "${out}"`);
  console.assert(!out.endsWith('-'), `slug should not end with dash; got "${out}"`);
  console.log('  ✓ very long input capped at 40');
}

// 6. consecutive whitespace and dashes
{
  const out = slugifyObjection('foo --- bar    baz');
  console.assert(!out.includes('--'), `consecutive dashes should be collapsed; got "${out}"`);
  console.assert(out === 'foo-bar-baz', `expected "foo-bar-baz", got "${out}"`);
  console.log('  ✓ consecutive whitespace/dashes collapsed');
}
```

- [ ] **Step 1: 把上面 6 个 case 追加到 test-slugify-objection.cjs 末尾(在 `if (require.main === module)` 之前).**

- [ ] **Step 2: 跑 `node tests/unit/test-slugify-objection.cjs`. 任何失败 = helper 实现缺陷.**

预期:case 3(RTL Hebrew)的注释说明它现在 fallback 到 `untitled`,这是 known limitation,不阻塞。其它都应该 pass。

如果有意外失败,**优先修 helper(scripts/slugify-objection.cjs)而不是 weaken 测试**。

- [ ] **Step 3: Commit**

```bash
git add paper-deepstudy/tests/unit/test-slugify-objection.cjs paper-deepstudy/scripts/slugify-objection.cjs
git commit -m "test(paper-deepstudy): slugify-objection edge cases — emoji, surrogate, RTL, mixed, length cap, consecutive whitespace (Plan 12 T3)"
```

---

### Task 4: test-parse-judge-output.cjs — 5 边界 case

**Files:**
- Modify: `paper-deepstudy/tests/unit/test-parse-judge-output.cjs`
- Possibly modify: `paper-deepstudy/scripts/parse-judge-output.cjs`(收紧 regex 接受更多 fence 形式)

现有测试覆盖基础情形。

新增 5 个 case:

```javascript
// --- Plan 12 T4: edge cases ---

// 1. ```yml lowercase short form
{
  const input = `
The judge says...
\`\`\`yml
verdict: holds
reasoning: clean argument.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'holds', `yml fence: expected verdict=holds, got "${out.verdict}"`);
  console.log('  ✓ ```yml fence accepted');
}

// 2. ```YAML uppercase
{
  const input = `
\`\`\`YAML
verdict: rejects
reasoning: bad logic.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'rejects', `YAML fence: expected rejects, got "${out.verdict}"`);
  console.log('  ✓ ```YAML fence accepted');
}

// 3. fence with extra trailing text (e.g. "```yaml linenums=...")
{
  const input = `
\`\`\`yaml linenums="1"
verdict: holds
reasoning: ok.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'holds', `fence-with-attrs: expected holds, got "${out.verdict}"`);
  console.log('  ✓ ```yaml with attrs accepted');
}

// 4. multi-doc YAML (--- separator)
{
  const input = `
\`\`\`yaml
---
verdict: partially_holds
reasoning: nuanced.
---
extra:
  - irrelevant
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'partially_holds',
    `multi-doc: expected partially_holds (first doc), got "${out.verdict}"`);
  console.log('  ✓ multi-doc YAML — first doc taken');
}

// 5. no fence at all (raw YAML in chat) — should fall back to partially_holds gracefully
{
  const input = `
verdict: holds
reasoning: ok.
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'partially_holds',
    `no-fence: expected partially_holds fallback, got "${out.verdict}"`);
  console.log('  ✓ no-fence falls back to partially_holds');
}
```

- [ ] **Step 1: 追加到 test-parse-judge-output.cjs.**

- [ ] **Step 2: 跑测试.**

预期 case 1, 2, 3 可能失败,因为现有 regex `/^\`\`\`yaml\s*$/im`(per spec) 只接受小写 yaml 严格形式。Case 1 (`yml`) 和 case 2 (`YAML`) 不会匹配。Case 3 (`yaml linenums=...`) 也不匹配。

- [ ] **Step 3: 收紧 helper regex**

修改 `scripts/parse-judge-output.cjs` 的 fence regex,接受:
- ` ```yaml `(原始)
- ` ```yml `(简短)
- ` ```YAML `(大写)
- ` ```yaml followed by anything `(带 attrs)

实现:换 regex 为 `/^\`\`\`(?:y[am]l?|YAML)(?:\s+.*)?\s*$/im`。

或者更宽松:`/^\`\`\`(?:[yY][aA]?[mM][lL]?)(?:\s+.*)?\s*$/im`。

具体写法看现有 helper。重点:case 1+2+3 pass,case 4+5 行为不变(case 4 应该取第一个 doc;case 5 现在 fallback,继续 fallback)。

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/tests/unit/test-parse-judge-output.cjs paper-deepstudy/scripts/parse-judge-output.cjs
git commit -m "fix(paper-deepstudy): parse-judge-output accepts yml/YAML/fence-with-attrs + multi-doc + no-fence fallback (Plan 12 T4)"
```

---

### Task 5: test-select-figures.cjs — 4 边界 case

**Files:**
- Modify: `paper-deepstudy/tests/unit/test-select-figures.cjs`
- Possibly modify: `paper-deepstudy/scripts/select-figures.cjs`

现有测试只有 1 个 console.log。先看 helper 长啥样、API 是什么,再添 case。

新增 4 个 case:

```javascript
// --- Plan 12 T5: edge cases ---

// 1. importance as string "0.7" instead of number 0.7
{
  const md = `
# Figures

## Figure 1
- importance: "0.9"
- caption: First figure
- path: images/page_1_img_1.jpeg

## Figure 2
- importance: "0.3"
- caption: Second figure
- path: images/page_2_img_1.jpeg
`;
  const out = selectFigures(md, 1);
  console.assert(out.length === 1, `expected 1 figure, got ${out.length}`);
  console.assert(out[0].path.includes('page_1'),
    `string importance "0.9" should win over "0.3"; got ${JSON.stringify(out)}`);
  console.log('  ✓ string importance values handled');
}

// 2. missing importance field on one figure — should treat as 0 / skip
{
  const md = `
# Figures

## Figure 1
- caption: No importance
- path: images/page_1_img_1.jpeg

## Figure 2
- importance: 0.5
- caption: Has importance
- path: images/page_2_img_1.jpeg
`;
  const out = selectFigures(md, 1);
  console.assert(out.length === 1 && out[0].path.includes('page_2'),
    `missing-importance figure should not be top pick; got ${JSON.stringify(out)}`);
  console.log('  ✓ missing importance field handled');
}

// 3. multi-line caption
{
  const md = `
# Figures

## Figure 1
- importance: 0.9
- caption: This is a multi-line
  caption that wraps onto a second line
- path: images/page_1_img_1.jpeg
`;
  const out = selectFigures(md, 1);
  console.assert(out.length === 1, `expected 1 figure, got ${out.length}`);
  console.log('  ✓ multi-line caption handled');
}

// 4. empty input
{
  const md = '';
  const out = selectFigures(md, 1);
  console.assert(Array.isArray(out) && out.length === 0,
    `empty input should return [], got ${JSON.stringify(out)}`);
  console.log('  ✓ empty input returns []');
}
```

(具体 API 形式可能要根据 select-figures.cjs 的实际 export 调整 —— 看 helper 如何 parse 6-figures.md 文件再写。)

- [ ] **Step 1: 读 select-figures.cjs,理解输入/输出 API.**

- [ ] **Step 2: 追加 4 个 case,根据实际 API 调整签名.**

- [ ] **Step 3: 跑,修任何 helper 缺陷.**

如果 case 1(string importance)失败,在 helper 里加 `Number(value)` 强转。如果 case 2(missing field)失败,加 default 0。Case 3 + 4 通常 helper 已经处理 OK,如果失败修。

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/tests/unit/test-select-figures.cjs paper-deepstudy/scripts/select-figures.cjs
git commit -m "test(paper-deepstudy): select-figures edge cases — string importance, missing field, multi-line caption, empty input (Plan 12 T5)"
```

---

### Task 6: integration smoke 集成 + 删除死 fixture

**Files:**
- Modify: `paper-deepstudy/tests/integration/test-end-to-end.sh`
- Delete: `paper-deepstudy/tests/fixtures/tiny-paper/` (整个目录)

`tiny-paper` fixture 自 Plan 1 起没人引用(grep 已证实),删之。

integration smoke 现在只做文件存在性检查;增加一段:对 examples/ 跑 validate-artifact.sh,确保 schema 验证在集成层也工作。

- [ ] **Step 1: 删除 tiny-paper 目录**

```bash
rm -rf paper-deepstudy/tests/fixtures/tiny-paper/
```

- [ ] **Step 2: 编辑 `paper-deepstudy/tests/integration/test-end-to-end.sh`**

在已有的检查后加一段:

```bash
echo ""
echo "=== Schema validation against examples/ ==="
EXAMPLES_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)/examples/string-database-2025"
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
```

(根据现有 `test-end-to-end.sh` 的代码风格调整变量名;如果 `$PLUGIN_ROOT` 还没在脚本里定义,就在脚本顶部加 `PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"`.)

- [ ] **Step 3: 跑 integration smoke,确保通过**

```bash
bash paper-deepstudy/tests/integration/test-end-to-end.sh
```

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/tests/integration/test-end-to-end.sh \
        paper-deepstudy/tests/fixtures/
git commit -m "test(paper-deepstudy): wire validate-artifact into integration smoke + delete dead tiny-paper fixture (Plan 12 T6)"
```

---

## Self-Review checklist

- [ ] `cd paper-deepstudy && npm run test:unit` 通过.
  - 预期 bats: 188 → 188 + 10(T1)+ 8(T2)= 206.
  - 预期 node: 4 / 4(同 4 个文件,但每个文件内 console.assert 加多了).
- [ ] `tests/integration/test-end-to-end.sh` 通过(含 8 个 schema 验证).
- [ ] `scripts/lib/validate-artifact.sh` 存在并可执行.
- [ ] 8 个 example 文件都有 line 1 provenance(post-retrofit).
- [ ] `tests/fixtures/tiny-paper/` 已删.
- [ ] No Claude co-author on any commit.

---

## What Plan 12 deliberately does NOT do

(For Plan 13+ scope.)

- **不做 idempotence 行为模拟测试** —— 需要先有 `scripts/lib/backup-with-rotation.sh`(Plan 13 T1).
- **不模拟真实 sub-Agent dispatch** —— 成本高,v1 不做.
- **不做 fixture-based "完整跑通一遍"测试** —— `examples/string-database-2025/` 已经是检查点;Plan 12 把它升级成断言锚点.
- **不修 examples/ 之外的旧文件** —— 历史归档(plan docs 等)不应有 provenance.

---

## Live verification (post-implementation, optional)

```bash
# 1. Run a full test suite — expect 206 bats + 4 node + integration pass
cd paper-deepstudy && npm run test:unit
bash tests/integration/test-end-to-end.sh

# 2. Inject a regression and confirm schema validation catches it
sed -i.bak 's|## Strengths and weaknesses|## Strengths and Weaknesses|' \
  ../examples/string-database-2025/compares/vs-attention-is-all-you-need.md
bash tests/integration/test-end-to-end.sh   # should fail with C2 message
mv ../examples/string-database-2025/compares/vs-attention-is-all-you-need.md.bak \
   ../examples/string-database-2025/compares/vs-attention-is-all-you-need.md
```

可选 —— 静态测试已经验证 helper.
