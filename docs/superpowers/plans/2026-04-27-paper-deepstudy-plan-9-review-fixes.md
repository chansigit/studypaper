# paper-deepstudy Plan 9: Review-fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 superpowers:code-reviewer 在 1949373 上对整个仓库做的 holistic review 暴露的真问题 —— 2 个 ship-blocker(C1+C2)和 5 个 important(I3-I7)。Important 8/9/10 + 全部 Minor 移到下一轮 polish。

**Architecture:** 全部是 prompt / skill / script / README 的小改 + bats 静态断言。无新文件、无新 skill。一个 task 一个 commit。

**Tech Stack:** Markdown + Bash + Node + Bats。无新依赖。

**修复条目:**

| 编号 | Bug | 来源 | 修复 |
|---|---|---|---|
| C1 | `study-deep` SKILL.md 的 `allowed-tools` 缺 `Skill`,但 Stage 0.2 用 Skill tool 调 `claude-paper:study` —— 严格执行 allow-list 时新装用户 `/paper:study` 第一步即 block | reviewer | `allowed-tools` 加 `Skill` + bats 断言 |
| C2 | 顶层 `README.md` 把 review-rounds / deep-dives / compares / reproduce-check 列在 `/paper:study` 12 件产物里(实际是单独命令产出)。中文 mirror 同问题。 | reviewer | 重写 EN + 中文 "What you get" section,核心 12 件 + 单列扩展 |
| I3 | `reviewer-synthesizer` + `review-writer` 也有 fabricated-date bug,example `review.md:4` 写 `Last updated: 2026-04-25` 是假的 | reviewer + example | 两个 prompt 加 runtime ISO8601 mandate + bats |
| I4 | study-deep SKILL.md line 63 + 362 写 `/paper:rerun-<stage>`,实际命令是 `/paper:rerun-stage <stage>` | reviewer | sed 替换两处 + bats 断言 |
| I5 | 示例 `examples/.../reproduce-check.md` `overall_score: yellow` 但 `fails_count: 3` 应 `red`(Plan 6 修之前的旧样本) | reviewer | 手改 frontmatter + 一行解释 |
| I6 | `slugify-objection.cjs` 把 CJK 全 strip,导致 `/paper:deep-dive "推导"` → `untitled.md` | reviewer | CJK 输入 fallback 加 6-char hash 后缀 + node 测试 |
| I7 | `examples/.../notes/{xhs,wechat}.md` 嵌的是 `/Users/chensijie/...` 绝对路径,GitHub 上图全坏。renderer 设计也错(Stage 3.3 写 "absolute paths") | reviewer | study-deep Stage 3.3 改 "paper-folder-relative",renderer prompts 同步改,example 手改 |

7 task,每 task 一个 commit。

---

## File Structure

```
paper-deepstudy/
├── skills/
│   └── study-deep/SKILL.md                  (modified — C1 line 5, I4 line 63+362, I7 line 295)
├── prompts/
│   ├── reviewer-synthesizer.md              (modified — I3)
│   ├── review-writer.md                     (modified — I3)
│   ├── xhs-renderer.md                      (modified — I7)
│   └── wechat-renderer.md                   (modified — I7)
├── scripts/
│   └── slugify-objection.cjs                (modified — I6)
├── tests/
│   └── unit/
│       ├── test-prompts-have-required-sections.bats  (modified — append assertions for C1, I3, I4)
│       └── test-slugify-objection.cjs       (modified — add CJK test cases for I6)

README.md                                     (modified — C2 EN + 中文)

examples/string-database-2025/
├── reproduce-check.md                        (modified — I5)
└── notes/
    ├── xhs.md                                (modified — I7 paths)
    └── wechat.md                             (modified — I7 paths)
```

---

## Pre-flight

Branch `feat/plan-9-review-fixes` 已从 post-Plan-8 main 长出。`cd paper-deepstudy && npm run test:unit` 通过(146 bats + 4 node + integration smoke pass)。

---

### Task 1: C1 — study-deep allowed-tools 加 Skill

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "study-deep SKILL.md allowed-tools includes Skill tool" {
  grep -qE '^allowed-tools:.*\bSkill\b' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Verify fail**

```bash
cd paper-deepstudy && bats tests/unit/test-prompts-have-required-sections.bats
```

- [ ] **Step 3: Edit `paper-deepstudy/skills/study-deep/SKILL.md` line 5**

OLD:
```
allowed-tools: Bash, Read, Write, Edit, Agent
```

NEW:
```
allowed-tools: Bash, Read, Write, Edit, Agent, Skill
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): study-deep allowed-tools includes Skill (Plan 9 C1)"
```

---

### Task 2: I4 — study-deep SKILL fix `/paper:rerun-<stage>` 命令名

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "study-deep SKILL.md uses correct rerun-stage command name" {
  ! grep -qE '/paper:rerun-<stage>' skills/study-deep/SKILL.md
  grep -qE '/paper:rerun-stage <stage>' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/skills/study-deep/SKILL.md`**

Two occurrences of `/paper:rerun-<stage>` (line 63 — inside the flag-dispatch description; line 362 — the user-facing final-summary chat text). Replace both:

```bash
sed -i.bak 's|/paper:rerun-<stage>|/paper:rerun-stage <stage>|g' paper-deepstudy/skills/study-deep/SKILL.md
rm paper-deepstudy/skills/study-deep/SKILL.md.bak
```

(Verify no other occurrences remain via `grep -nE '/paper:rerun-<stage>' paper-deepstudy/skills/study-deep/SKILL.md` — should return nothing.)

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): study-deep uses correct /paper:rerun-stage command name (Plan 9 I4)"
```

---

### Task 3: C2 — 顶层 README "What you get" 修正

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read `paper-deepstudy/README.md` "What you get (12 outputs)" section** (lines 96-119) — that's the canonical 12-output list. Use it as the source of truth.

- [ ] **Step 2: Edit `README.md` EN section "What you get"**

The current "twelve artifacts" block lists `review-rounds/`, `deep-dives/`, `compares/`, `reproduce-check.md` —— remove these; they belong in a separate "additional artifacts via extension commands" block.

Replace the block at `README.md` "Every `/paper:study` produces twelve artifacts under …" with:

```markdown
Every `/paper:study` produces these artifacts under `~/claude-papers/papers/<slug>/`:

```text
analysis/
  00-paper-profile.md       paper type · domain · difficulty (YAML frontmatter)
  01-problem.md             problem statement and framing
  02-formalization.md       math: notation, loss, constraints
  03-method-deep.md         method with rationale + alternatives considered
  04-experiments.md         experiment critique (not just description)
  05-prior-work.md          chronological timeline + comparison
  06-figures.md             per-figure interpretation + scoring
review.md                   academic-reviewer-style verdict (Strengths / Weaknesses / Score)
notes/
  source.md                 unified Chinese source (single point of truth)
  titles.md                 5+5 candidate titles
  xhs.md                    Xiaohongshu rendering (~1000 chars, 1 figure)
  wechat.md                 WeChat rendering (~3000 chars, 2-3 figures)
```

The remaining workspace artifacts are produced by **extension commands**, not by `/paper:study`:

| Command | Artifact |
|---|---|
| `/paper:review-round` | `review-rounds/round-NN-<title>.md` (one file per round) |
| `/paper:deep-dive`    | `deep-dives/<topic-slug>.md` |
| `/paper:compare`      | `compares/vs-<other-slug>.md` |
| `/paper:reproduce-check` | `reproduce-check.md` |

Every file is regeneratable. Every mutation backs up to `<file>.bak.NN`. Nothing is destructive.
```

- [ ] **Step 3: Edit `README.md` 中文 section 同步修改**

Mirror in 中文 section: keep only the 12 actual `/paper:study` outputs, then add separate 表格 for extension command artifacts.

- [ ] **Step 4: Adjust the "twenty minutes" pitch (`README.md` line ~18 + line ~32 + line ~179)**

Currently the EN opener implies reproducibility audit is part of the single-command "twenty minutes". Change "one reproducibility audit, one set of social-media notes" → "and a set of social-media notes ready to ship" (drop the audit from the single-command claim — it's a separate command). Mirror in 中文.

Specifically the EN paragraph in section "## English":
```
It is a Claude Code plugin that turns any ML or computational-biology paper (PDF or arXiv URL) into a complete, navigable research workspace — one analysis directory, one reviewer-style verdict, one reproducibility audit, one set of social-media notes ready to ship. From a single command. In about twenty minutes.
```

Change to:
```
It is a Claude Code plugin that turns any ML or computational-biology paper (PDF or arXiv URL) into a complete, navigable research workspace — a structured analysis directory, a reviewer-style verdict, and bilingual social-media notes — from one command, in about twenty minutes. Run extension commands (adversarial review, deep-dive, head-to-head compare, reproducibility audit) on top.
```

Mirror in 中文 section.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: clarify /paper:study produces 12 outputs, extensions add more (Plan 9 C2)"
```

---

### Task 4: I3 — reviewer-synthesizer + review-writer + review.md template runtime ISO8601

**Files:**
- Modify: `paper-deepstudy/prompts/reviewer-synthesizer.md`
- Modify: `paper-deepstudy/prompts/review-writer.md`
- Modify: `paper-deepstudy/templates/review.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "reviewer-synthesizer.md mandates runtime Last-updated date" {
  grep -qF 'runtime ISO8601' prompts/reviewer-synthesizer.md
  grep -qF 'do NOT fabricate' prompts/reviewer-synthesizer.md
}

@test "review-writer.md mandates runtime Last-updated date" {
  grep -qF 'runtime ISO8601' prompts/review-writer.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/prompts/reviewer-synthesizer.md`**

Find the Output section (the part describing what to write into `review.md`). Append a paragraph after the existing output description:

```
**About the `Last updated` field:** must be the runtime ISO8601 UTC date (e.g. `2026-04-27`). Use the current date at the moment of generation. Do NOT fabricate a date, do NOT use a plan-doc date, do NOT use a template-default. If you cannot determine the current date, leave it as `<runtime-date>` and let the orchestrator fill it in.
```

- [ ] **Step 4: Edit `paper-deepstudy/prompts/review-writer.md`**

`review-writer` is the post-review-round agent that **edits** `review.md` to add new accepted weaknesses. When it touches `review.md`, it must update `Last updated`. Find the existing section that describes the edit (likely "Modify the Weaknesses table" or similar) and append:

```
**Refresh `Last updated`:** every time you edit `review.md`, also update the `**Last updated:** <date>` line at the top to the runtime ISO8601 UTC date. Do NOT fabricate.
```

- [ ] **Step 5: Edit `paper-deepstudy/templates/review.md` line 4**

Change `**Last updated:** <date>` to `**Last updated:** <runtime-date>` so the placeholder is unambiguous about being orchestrator-filled (consistent with `<runtime-timestamp>` in compare/reproduce-check templates).

- [ ] **Step 6: Verify pass**

- [ ] **Step 7: Commit**

```bash
git add paper-deepstudy/prompts/reviewer-synthesizer.md paper-deepstudy/prompts/review-writer.md paper-deepstudy/templates/review.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): reviewer-synthesizer + review-writer mandate runtime Last-updated (Plan 9 I3)"
```

---

### Task 5: I6 — slugify-objection 对 CJK 输入做 fallback

**Files:**
- Modify: `paper-deepstudy/scripts/slugify-objection.cjs`
- Modify: `paper-deepstudy/tests/unit/test-slugify-objection.cjs`

- [ ] **Step 1: Append failing test cases**

Add test cases at the end of `paper-deepstudy/tests/unit/test-slugify-objection.cjs`:

```javascript
// Plan 9 I6: CJK-only input should not collapse to "untitled" — must produce
// a stable, distinguishable slug. Two different CJK inputs must produce
// different slugs.
const slug1 = slugifyObjection('对比学习损失推导');
const slug2 = slugifyObjection('注意力机制的推导');
assert(slug1 !== 'untitled', `CJK input "对比学习损失推导" should not slug to "untitled", got "${slug1}"`);
assert(slug2 !== 'untitled', `CJK input "注意力机制的推导" should not slug to "untitled", got "${slug2}"`);
assert(slug1 !== slug2, `Different CJK inputs must produce different slugs, got "${slug1}" === "${slug2}"`);
// CJK-only slug should match the documented form: cjk- followed by 6 hex chars
assert(/^cjk-[a-f0-9]{6}$/.test(slug1), `CJK-only slug should match /^cjk-[a-f0-9]{6}$/, got "${slug1}"`);
console.log('  ✓ CJK input produces stable distinguishable slug');
```

(Inspect the existing test file's pattern — it's likely a sequence of `assert(slugifyObjection(...) === 'expected', '...')` calls. Follow the same pattern. The above `assert` may need to be replaced with the existing helper.)

- [ ] **Step 2: Verify fail**

```bash
cd paper-deepstudy && node tests/unit/test-slugify-objection.cjs
```

- [ ] **Step 3: Edit `paper-deepstudy/scripts/slugify-objection.cjs`**

At the bottom of the function (just before `if (slug.length === 0) return 'untitled';`), insert a CJK-fallback branch:

```javascript
  // CJK fallback: if all ASCII has been stripped, derive a stable hash slug
  // from the original text so multi-CJK inputs don't all collide on 'untitled'.
  if (slug.length === 0) {
    // Detect: did the input have any CJK / non-ASCII content worth preserving?
    const hasCJK = /[一-鿿㐀-䶿豈-﫿぀-ゟ゠-ヿ]/.test(text);
    if (hasCJK) {
      // 6-char hex hash of the input text (deterministic, collision-resistant
      // enough for filenames, no new deps).
      const crypto = require('node:crypto');
      const hash = crypto.createHash('sha1').update(text).digest('hex').slice(0, 6);
      return `cjk-${hash}`;
    }
    return 'untitled';
  }
  return slug;
```

(Replace the existing `if (slug.length === 0) return 'untitled';` with the above block.)

- [ ] **Step 4: Verify pass**

```bash
cd paper-deepstudy && node tests/unit/test-slugify-objection.cjs
```

Existing test cases should still pass; new CJK cases pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/scripts/slugify-objection.cjs paper-deepstudy/tests/unit/test-slugify-objection.cjs
git commit -m "fix(paper-deepstudy): slugify-objection CJK fallback prevents 'untitled' collision (Plan 9 I6)"
```

---

### Task 6: I7 — figure paths 改用 paper-folder-relative

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`
- Modify: `paper-deepstudy/prompts/xhs-renderer.md`
- Modify: `paper-deepstudy/prompts/wechat-renderer.md`
- Modify: `examples/string-database-2025/notes/xhs.md`
- Modify: `examples/string-database-2025/notes/wechat.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

**Rationale:** the renderers currently get absolute paths (`/Users/.../images/page_1_img_1.jpeg`). Those leak the author's home directory into committed examples and break the moment a user clones the repo or syncs the paper folder. The right invariant: figure paths are **relative to the paper folder** (`images/page_1_img_1.jpeg`), and any tooling that needs an absolute path joins it with `$PAPER_DIR` itself.

- [ ] **Step 1: Append failing test**

```bash
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
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/skills/study-deep/SKILL.md` Stage 3.3**

Find the line at `SKILL.md:295` that reads:
```
Capture each as JSON; transform to absolute paths under `$IMAGES_DIR`. Set:
```

Replace with:
```
Capture each as JSON; keep them as **paper-folder-relative paths** (e.g. `images/page_1_img_1.jpeg`, NOT `$IMAGES_DIR/page_1_img_1.jpeg`). The renderer prompts then embed those paths directly so committed/shared notes don't leak the author's home directory. Set:
```

- [ ] **Step 4: Edit `paper-deepstudy/prompts/xhs-renderer.md`**

Locate the paragraph where `FIGURE_PATHS` (or equivalent) is described. Append:

```
**Figure paths must be paper-folder-relative** — e.g. `images/page_1_img_1.jpeg`, NOT `/Users/.../page_1_img_1.jpeg` and NOT `file:///...`. The frontmatter `figures:` list and the inline `![...](...)` must both use the relative form. This is what makes the notes portable when the paper folder is shared/committed.
```

- [ ] **Step 5: Edit `paper-deepstudy/prompts/wechat-renderer.md` same way**

- [ ] **Step 6: Hand-fix `examples/string-database-2025/notes/xhs.md`**

Replace every `/Users/chensijie/claude-papers/papers/string-database-2025/images/` with `images/`, both in the `figures:` frontmatter and in inline `![](...)` markdown.

- [ ] **Step 7: Hand-fix `examples/string-database-2025/notes/wechat.md`**

Same. Also strip any `file://` prefixes — `![](images/page_1_img_1.jpeg)`.

- [ ] **Step 8: Verify pass**

```bash
cd paper-deepstudy && npm run test:unit
# Verify by grep'ing the example to confirm no absolute paths leak:
! grep -rE '/Users/|file://' examples/string-database-2025/notes/
```

- [ ] **Step 9: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/prompts/xhs-renderer.md paper-deepstudy/prompts/wechat-renderer.md examples/string-database-2025/notes/xhs.md examples/string-database-2025/notes/wechat.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): figure paths are paper-folder-relative (Plan 9 I7)"
```

---

### Task 7: I5 — example reproduce-check.md 修正 overall_score

**Files:**
- Modify: `examples/string-database-2025/reproduce-check.md`

- [ ] **Step 1: Edit frontmatter**

Currently:
```yaml
overall_score: yellow
fails_count: 3
partials_count: 3
```

Per `prompts/reproduce-checker.md` lookup table, `fails_count ≥ 2` means `red` regardless of partials_count. Change `overall_score: yellow` → `overall_score: red`.

If there's body text near the score that says "yellow", update it accordingly. Add a one-line note at the bottom of the file (italic) noting:

```
*Note: this example was generated before Plan 6 fixed the reproduce-checker scoring rubric and was hand-corrected post-hoc to match the current lookup table (fails_count ≥ 2 → red).*
```

- [ ] **Step 2: Commit**

```bash
git add examples/string-database-2025/reproduce-check.md
git commit -m "fix(examples): string-database reproduce-check overall_score corrected to red (Plan 9 I5)"
```

---

## Self-Review checklist (Plan 9 完成后跑一遍)

- [ ] `cd paper-deepstudy && npm run test:unit` 通过(bats grew by 6, +3 node test cases for slugify CJK).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` 通过(no file moves).
- [ ] `study-deep/SKILL.md` allowed-tools 含 `Skill`,无 `/paper:rerun-<stage>`,figure-path 描述用 "paper-folder-relative"。
- [ ] `reviewer-synthesizer.md` + `review-writer.md` 含 "runtime ISO8601" 字样。
- [ ] 顶层 `README.md` 不再把 review-rounds/deep-dives/compares/reproduce-check 列在 12-outputs 块。
- [ ] `examples/string-database-2025/notes/{xhs,wechat}.md` 不含 `/Users/` 或 `file://`。
- [ ] `examples/string-database-2025/reproduce-check.md` `overall_score: red`。
- [ ] No Claude co-author on any commit.

---

## Out of scope for Plan 9 (deferred to Plan 10 polish)

- I8: `study.md` argument-hint vs study-deep dispatch table 对齐
- I9: `/paper:add-prior-work` DOI 支持(实现或删宣传)
- I10: `title-generator.md` `STYLE_FILTER` 歧义
- M11: `verify-prereqs.sh` 硬编码 marketplace 名
- M12: 自动 detect most-recent-paper 不够确定
- M13-M20: trailing slash, plan-numbered output 泄漏, /paper:compare BERT 例子, WebFetch 预算未强制, source.md `<!-- N/A -->` 缺示例, Last-updated bats 加固, paper-deepstudy/README.md 链接, spec drift。
