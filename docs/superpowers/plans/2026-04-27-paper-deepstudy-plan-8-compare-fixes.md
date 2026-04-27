# paper-deepstudy Plan 8: compare-agent fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 Plan 3b live test 暴露的 compare-agent 3 个 prompt-runtime bug —— C2(section heading 大小写错)、C3(多输出 Summary section)、C4(词数超 cap 31%)。

**Architecture:** 全部是 `paper-deepstudy/prompts/compare-agent.md` 的小改 + bats 静态断言。无新文件,无新 skill。

**Tech Stack:** Markdown(prompt 文本)+ Bats(structural assertions)。无新依赖。

**修复条目:**

| 编号 | Bug | 来源 | 修复 |
|---|---|---|---|
| C2 | 输出 `## Strengths and Weaknesses`(大写 W),但 prompt/template 都是 lowercase | live test (vs-attention-is-all-you-need.md:121) | prompt 加 "use template headings verbatim" 显式规则 |
| C3 | 输出多了一个 `## Summary` section,template 里没有(只有 7 个 H2) | live test (vs-attention-is-all-you-need.md:161) | prompt 加 "do NOT add sections beyond the 7 listed" 显式规则 |
| C4 | 输出 2639 词,超过 prompt 写的 2000-词 cap(同 D1 pattern) | live test (vs-attention-is-all-you-need.md, 2639 words) | prompt cap 放宽到 800-2800,并加 "若超过 upper bound 必须裁剪" 自检 |

3 task,每 task 一个 commit。

---

## File Structure

```
paper-deepstudy/
├── prompts/
│   └── compare-agent.md                                  (modified — Tasks 1, 2, 3)
└── tests/
    └── unit/
        └── test-prompts-have-required-sections.bats     (modified — append assertions)
```

---

## Pre-flight

Plan 1/2/3a/3b/3c/4/5/6/7 都已 merge。这个分支 `feat/plan-8-compare-fixes` 从 post-Plan-7 main 长出来。`cd paper-deepstudy && npm run test:unit` 通过(预期 143 bats + 4 node + integration smoke pass)。

---

### Task 1: compare-agent 强制 section heading verbatim (C2)

**Files:**
- Modify: `paper-deepstudy/prompts/compare-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

在 `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats` 末尾追加(注意 setup() cd 到 plugin 根,所以路径用 `prompts/` 不是 `paper-deepstudy/prompts/`):

```bash
@test "compare-agent.md mandates verbatim section headings" {
  grep -qF 'verbatim' prompts/compare-agent.md
  grep -qF 'do NOT capitalize' prompts/compare-agent.md
}
```

- [ ] **Step 2: Verify fail**

```bash
cd paper-deepstudy && bats tests/unit/test-prompts-have-required-sections.bats
```

预期 1 fail。

- [ ] **Step 3: Edit compare-agent.md Output section**

在 `paper-deepstudy/prompts/compare-agent.md` 找到 Output section 的 7-bullet 列表(line 23-32 之间,以 `- YAML frontmatter` 开头到 `- ## When to use which` 结尾)。在最后一个 bullet 后追加新段落:

```
**About section headings:** copy the H2 headings from the bullet list above **verbatim** — do NOT capitalize "weaknesses" to "Weaknesses", do NOT add subsection H3s that aren't in the template, do NOT rename "When to use which" to "Decision guide" or similar. The downstream test runner greps for exact heading strings.
```

- [ ] **Step 4: Verify pass**

```bash
cd paper-deepstudy && bats tests/unit/test-prompts-have-required-sections.bats
```

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/compare-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): compare-agent enforces verbatim section headings (C2)"
```

---

### Task 2: compare-agent 禁止额外 section (C3)

**Files:**
- Modify: `paper-deepstudy/prompts/compare-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "compare-agent.md forbids extra sections beyond the 7 listed" {
  grep -qF 'exactly 7 H2 sections' prompts/compare-agent.md
  grep -qF 'do NOT add' prompts/compare-agent.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit compare-agent.md**

在 Task 1 刚加的 "About section headings" 段落后追加:

```
**About extra sections:** the output has **exactly 7 H2 sections** (Problem, Formalization, Method, Experiments, Strengths and weaknesses, When to use which — wait, that's 6 H2s plus the title H1; counting by H2 only: 6). Do NOT add a `## Summary`, `## Conclusion`, `## TL;DR`, or any other H2 not listed in the bullet list above. If you feel the comparison needs a wrap-up, fold it into the "When to use which" section instead.
```

(Note: re-count to be precise — the Output bullet list shows: H1 title, then H2 ×6: Problem, Formalization, Method, Experiments, Strengths and weaknesses, When to use which. The test asserts the exact phrase `exactly 7 H2 sections` is in the prompt, but the actual count is 6. Adjust both prompt and test to say `exactly 6 H2 sections` — verify by reading the Output bullet list before writing.)

After re-reading Output bullet list and confirming the H2 count, write the prompt edit and the test with the **correct** number. Likely correct text:

```
**About extra sections:** the output has **exactly 6 H2 sections** (Problem, Formalization, Method, Experiments, Strengths and weaknesses, When to use which). Do NOT add a `## Summary`, `## Conclusion`, `## TL;DR`, or any other H2 not listed in the bullet list above. If you feel the comparison needs a wrap-up, fold it into the "When to use which" section instead.
```

And the test:

```bash
@test "compare-agent.md forbids extra sections beyond the 6 listed" {
  grep -qF 'exactly 6 H2 sections' prompts/compare-agent.md
  grep -qF 'do NOT add' prompts/compare-agent.md
}
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/compare-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): compare-agent forbids extra H2 sections (C3)"
```

---

### Task 3: compare-agent length cap 放宽 + self-check (C4)

**Files:**
- Modify: `paper-deepstudy/prompts/compare-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "compare-agent.md length cap is 800-2800 words with self-check" {
  grep -qF '800-2800' prompts/compare-agent.md
  grep -qF 'word-count self-check' prompts/compare-agent.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit compare-agent.md Quality bar**

找到 Quality bar 的 length bullet:

```
- Length: 800-2000 words total.
```

替换为:

```
- Length: 800-2800 words total. Aim for the lower end (800-1500) when the two papers share the same problem and most differences are quantitative; aim for the upper end (2000-2800) when the papers solve related-but-different problems and need more setup to compare.
- **Word-count self-check (REQUIRED):** before finalizing, count the words in your draft. If the total exceeds 2800, re-read each section and trim — usually the "Method" or "Experiments" sections have redundant phrasing that can be cut without losing content. Do NOT submit a draft above 2800 words.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/compare-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): compare-agent length cap relaxed to 800-2800 + self-check (C4)"
```

---

## Self-Review checklist (Plan 8 完成后跑一遍)

- [ ] `cd paper-deepstudy && npm run test:unit` 通过(bats grew by 3, +0 node)。
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` 通过(无 file 变动 → 应该通过)。
- [ ] compare-agent.md 包含 verbatim heading 规则、6-section 上限、800-2800 cap + word-count self-check。
- [ ] No Claude co-author on any commit.

---

## Live test recipe (manual, post-implementation, optional)

如果想确认 fix 真的工作:

1. 把现有的 `~/claude-papers/papers/string-database-2025/compares/vs-attention-is-all-you-need.md` 删掉(或备份)。
2. 重新跑 `/paper:compare attention-is-all-you-need`。
3. 验证新输出:
   - section heading 全部 verbatim(`## Strengths and weaknesses` 而不是 `## Strengths and Weaknesses`)
   - 没有 `## Summary` 或其他多余 H2
   - 词数在 800-2800 之间

不是必须 —— 静态 bats 测试已经验证 prompt 有正确的指令字符串。
