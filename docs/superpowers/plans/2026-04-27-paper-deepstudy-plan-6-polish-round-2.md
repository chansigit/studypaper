# paper-deepstudy Plan 6: Polish Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 Plan 3b/3c live integration test 暴露的 4 个 prompt-runtime bug —— reproduce-checker 的 fails_count 数错(R1)+ overall_score 分类错(R2)+ created_at 日期 fabricated(R3),deep-dive-agent 的长度 cap 不准(D1)。

**Architecture:** 全部是对现有 `paper-deepstudy/prompts/*.md` 的小改 + bats 断言。无新文件,无新 skill。

**Tech Stack:** Markdown(prompt 文本)+ Bats(structural assertions)。无新依赖。

**修复条目:**

| 编号 | Bug | 来源 | 修复 |
|---|---|---|---|
| R1 | reproduce-checker 报告 fails_count: 3 但实际有 4 ✗(漏数 Hardware) | live test phase 3 | prompt 加 self-check 步骤 + bats 断言「prompt mentions count consistency check」 |
| R2 | reproduce-checker overall_score: yellow 但 4 fails ≥ 2 应该 red | live test phase 3 | prompt 把 scoring 规则做成显式 lookup table,而不是 step-7 散文 |
| R3 | reproduce-checker created_at 是 2026-04-25 fabricated date(实际今天 04-27) | live test phase 3 | prompt 强调 "use runtime ISO8601, NOT fabricated date" |
| D1 | deep-dive-agent 产出 1956 词,超过 prompt 写的 1500-词 cap | live test phase 1 | prompt 把 cap 放宽到 600-2000 词(实际质量好,1500 太紧) |

3 task,每 task 一个 commit。

---

## File Structure

```
paper-deepstudy/
├── prompts/
│   ├── reproduce-checker.md            (modified — Tasks 1, 2, 3)
│   └── deep-dive-agent.md              (modified — Task 4)
└── tests/
    └── unit/
        └── test-prompts-have-required-sections.bats   (modified — append assertions)
```

---

## Pre-flight

Plan 1/2/3a/3b/3c/4/5 都已 merge。这个分支从 post-Plan-3c main 长出来。`cd paper-deepstudy && npm run test:unit` 通过(预期 144 bats + 4 node + integration smoke pass)。

---

### Task 1: reproduce-checker 加 fails_count self-check (R1)

**Files:**
- Modify: `paper-deepstudy/prompts/reproduce-checker.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "reproduce-checker.md mandates fails_count self-check" {
  grep -qF 'self-check' paper-deepstudy/prompts/reproduce-checker.md
  grep -qF 'fails_count + partials_count' paper-deepstudy/prompts/reproduce-checker.md
}
```

(Note: this test runs from repo root because the bats file's setup() cd's to plugin root, so `paper-deepstudy/prompts/` becomes `prompts/` — verify by reading test file structure first. Most likely the path should be `prompts/reproduce-checker.md` not `paper-deepstudy/prompts/...`.)

After confirming the path style: rewrite the test using the correct relative path.

- [ ] **Step 2: Verify fail**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```

- [ ] **Step 3: Edit reproduce-checker.md Step 6**

Find the existing Step 6:

```
6. Compute `fails_count` (number of ✗) and `partials_count` (number of partial). Set `overall_score`:
   - `green` if 0 fails AND 0-1 partials
   - `yellow` if 0 fails AND 2-4 partials, or 1 fail
   - `red` if 2+ fails or 5+ partials
```

Replace with:

```
6. Compute the dimension counts and self-check, then derive `overall_score`:

   **Step 6a — count each dimension's status**
   Walk through all 7 dimensions (or 6 if Wet-lab is N/A). For each, classify the status as ✓, ✗, partial, or N/A. Count separately:
   - `pass_count` = number of ✓
   - `fails_count` = number of ✗
   - `partials_count` = number of `partial`
   - `na_count` = number of N/A

   **Step 6b — self-check (REQUIRED, do not skip)**
   Verify: `pass_count + fails_count + partials_count + na_count == checked_dimensions` (where `checked_dimensions` is 7 or 6 depending on Wet-lab applicability — actually the sum should equal **the total dimensions you wrote sections for**, including N/A ones; for ml-pure it's 7 sections total with one being N/A, otherwise 7 sections with all checked).

   If the equation does NOT balance, you miscounted a dimension. Re-walk the 7 sections, recount, and update the frontmatter values until the equation balances.

   **Step 6c — derive `overall_score` from a lookup table**

   Use this exact lookup (do NOT improvise):

   | `fails_count` | `partials_count` | `overall_score` |
   |---|---|---|
   | 0 | 0–1 | green |
   | 0 | 2–4 | yellow |
   | 1 | (any) | yellow |
   | 0 | ≥ 5 | red |
   | ≥ 2 | (any) | red |

   Concrete examples to verify your understanding:
   - 0 fails, 1 partial → green
   - 0 fails, 3 partials → yellow
   - 1 fail, 2 partials → yellow
   - 2 fails, 1 partial → **red** (because fails_count ≥ 2)
   - 4 fails, 3 partials → **red**
   - 0 fails, 5 partials → red
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/reproduce-checker.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): reproduce-checker self-check for fails_count + lookup-table for overall_score (R1+R2)"
```

---

### Task 2: reproduce-checker mandate runtime created_at (R3)

**Files:**
- Modify: `paper-deepstudy/prompts/reproduce-checker.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "reproduce-checker.md mandates runtime created_at, not fabricated" {
  grep -qF 'runtime ISO8601' prompts/reproduce-checker.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit reproduce-checker.md Output section**

Find the existing Output section's frontmatter description:

```
- YAML frontmatter (`slug`, `created_at`, `overall_score`, `checked_dimensions`, `fails_count`, `partials_count`)
```

Replace with:

```
- YAML frontmatter (`slug`, `created_at`, `overall_score`, `checked_dimensions`, `fails_count`, `partials_count`).

  **About `created_at`:** must be the runtime ISO8601 UTC timestamp (e.g. `2026-04-27T03:14:15Z`). Use the current timestamp at the moment of generation. Do NOT use a fabricated, plan-doc-derived, or template-default date. If you cannot determine the current time, leave it as `<runtime-timestamp>` and let the orchestrator fill it in.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/reproduce-checker.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): reproduce-checker mandates runtime created_at (R3)"
```

---

### Task 3: deep-dive-agent length cap 放宽 (D1)

**Files:**
- Modify: `paper-deepstudy/prompts/deep-dive-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "deep-dive-agent.md length cap is 600-2000 words" {
  grep -qF '600-2000' prompts/deep-dive-agent.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit deep-dive-agent.md**

Find the Quality bar bullet for length:

```
- Length: 600-1500 words total.
```

Replace with:

```
- Length: 600-2000 words total. Aim for the upper end (1500-2000) when the topic genuinely benefits from depth (math derivations, multi-method comparison, or non-obvious method-design rationale). Aim for the lower end (600-1000) for narrow topics that don't require extended treatment.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/deep-dive-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): deep-dive-agent length cap relaxed to 600-2000 (D1)"
```

---

## Self-Review checklist (Plan 6 完成后跑一遍)

- [ ] `cd paper-deepstudy && npm run test:unit` 通过(bats grew by 3, +0 node).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` 通过(无 file 变动 → 应该通过)。
- [ ] reproduce-checker.md 包含 self-check 步骤 + lookup table + runtime created_at 要求。
- [ ] deep-dive-agent.md length cap 改为 600-2000。
- [ ] No Claude co-author on any commit.

---

## Live test recipe (manual, post-implementation, optional)

如果想确认 fix 真的工作:

1. 把现有的 `~/claude-papers/papers/string-database-2025/reproduce-check.md` 删掉(或备份)。
2. 重新跑 reproduce-check —— 这次 prompt 已经加了 self-check 和 lookup table。
3. 验证新 reproduce-check.md:
   - `created_at` 是当前真实日期(2026-04-27 而不是 04-25)
   - `fails_count` 和实际 ✗ 数量匹配
   - `overall_score` 按 lookup table 推导(4 fails ≥ 2 → red)

不是必须 —— 静态 bats 测试已经验证 prompt 有正确的指令字符串。
