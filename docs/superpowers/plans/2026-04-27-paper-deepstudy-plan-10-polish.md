# paper-deepstudy Plan 10: Final-polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收尾 superpowers:code-reviewer 在 1949373 上 holistic review 留给 Plan 10 的 important + minor 项 —— I8/I9/I10 + M11/M12/M14/M15/M16/M19/M20。

**Architecture:** 全部是 prompt / skill / script / README / spec 的小改 + bats 静态断言。无新文件。

**Tech Stack:** Markdown + Bash + Bats。无新依赖。

**修复条目:**

| 编号 | Bug | 修法 |
|---|---|---|
| I8 | `commands/study.md` 的 argument-hint 没列 `--paper`,但 study-deep 实现支持 `/paper:study --paper <slug>` | study.md 加 `--paper`,USAGE 段写明语义 + bats |
| I9 | README EN line 123 + 中文 line 275 把 DOI 列在 `/paper:add-prior-work` 接受类型里,但 skill 实际不解析 DOI | 删 README 两处 DOI 字样 + 在 add-prior-work skill 顶部加 `<!-- DOI not yet supported, see roadmap -->` 注释 |
| I10 | `title-generator.md` 的 `STYLE_FILTER` 未规定 set 时是 5 个同 style 还是混合 | prompt 加显式规则 "如果 set 则全部 5 个用该 style" + bats |
| M11 | `verify-prereqs.sh` 的 glob 把 marketplace 名硬编码为 `claude-paper`,用其它 marketplace 名安装 claude-paper 的用户会失败 | glob 放宽到 `*/claude-paper/*/skills/study/SKILL.md` |
| M12 | 6 个 skill 用 `ls -td ~/claude-papers/papers/*/ \| head -1` 自动选最近 paper —— 是 most-recently-modified,不是 most-recently-studied,会有惊讶 | 在 chat-printed 输出里加一行警告 "Targeting <slug> (most recently modified). Pass --paper to override." |
| M14 | `study-deep/SKILL.md:373` 的 user-facing final summary 含 "Plan 2 ✓ for /paper:review-round; Plan 3a ✓ ..." 内部 release tracking,泄漏到用户看的输出 | 删该括号注 |
| M15 | README "/paper:compare BERT --lang zh" 例子里 `BERT` 看起来像 slug,新用户复制粘贴会撞 abort 路径 | 改成 arxiv URL 或 already-studied slug |
| M16 | WebFetch budget 只是 prompt 文本嘱咐,无强制机制 | 把 "WebFetch budget 由 sub-Agent self-enforce" 写进 spec §10 已知软失败 |
| M19 | `paper-deepstudy/README.md:139` 例子链接 `../examples/...` 在 marketplace 安装后渲染会 404 | 改成 GitHub 绝对 URL 或 fallback 提示 |
| M20 | spec §9 的 subagent roster 表没有 `reproduce-checker` 一行(Plan 3c 加的) | 加一行 |

6 task,每 task 一个 commit。

---

## File Structure

```
paper-deepstudy/
├── commands/
│   └── study.md                                  (modified — Task 1: I8)
├── prompts/
│   └── title-generator.md                        (modified — Task 3: I10)
├── skills/
│   ├── study-deep/SKILL.md                       (modified — Task 5: M14)
│   ├── add-prior-work/SKILL.md                   (modified — Task 2: I9 comment)
│   ├── refine-notes/SKILL.md                     (modified — Task 4: M12)
│   ├── retitle/SKILL.md                          (modified — Task 4: M12)
│   ├── reselect-figures/SKILL.md                 (modified — Task 4: M12)
│   ├── review-round/SKILL.md                     (modified — Task 4: M12)
│   ├── deep-dive/SKILL.md                        (modified — Task 4: M12)
│   ├── compare/SKILL.md                          (modified — Task 4: M12)
│   └── reproduce-check/SKILL.md                  (modified — Task 4: M12)
├── scripts/
│   └── verify-prereqs.sh                         (modified — Task 4: M11)
├── tests/
│   └── unit/
│       └── test-prompts-have-required-sections.bats   (modified — append assertions)
└── README.md                                     (modified — Task 6: M19)

README.md                                          (modified — Task 2: I9 + Task 5: M15)
docs/superpowers/specs/2026-04-26-paper-deepstudy-design.md  (modified — Task 6: M16 + M20)
```

---

## Pre-flight

Branch `feat/plan-10-polish` 已从 post-Plan-9 main 长出。`cd paper-deepstudy && npm run test:unit` 通过(153 bats + 4 node + integration smoke pass)。

---

### Task 1: I8 — `/paper:study --paper` flag clarity

**Files:**
- Modify: `paper-deepstudy/commands/study.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "study.md argument-hint documents --paper flag" {
  grep -qF -- '--paper' paper-deepstudy/commands/study.md
}
```

(Adjust path if test setup() cd's elsewhere — verify by reading the test file's setup().)

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/commands/study.md`**

Find line 4: `argument-hint: "<pdf-path-or-url> [--yes] [--force]"`

Change to: `argument-hint: "<pdf-path-or-url> [--paper <slug>] [--yes] [--force]"`

In the body of the command (the prose explaining flags), add a paragraph:

```
**`--paper <slug>`** *(advanced)*: skip the auto-download / parse step (Stage 0.2) and operate on an existing paper folder at `~/claude-papers/papers/<slug>/`. Useful when the paper folder was created some other way (e.g. via `claude-paper:study` directly, or from a backup). When `--paper` is set, you do NOT need to pass `<pdf-path-or-url>`.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/study.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): /paper:study argument-hint documents --paper flag (Plan 10 I8)"
```

---

### Task 2: I9 — remove DOI claim, add roadmap note

**Files:**
- Modify: `README.md`
- Modify: `paper-deepstudy/skills/add-prior-work/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "add-prior-work skill is honest about DOI not being supported" {
  ! grep -qF '/ DOI' README.md
  grep -qF 'DOI not yet supported' paper-deepstudy/skills/add-prior-work/SKILL.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `README.md`**

Two occurrences of `/ DOI` (EN line 123, 中文 line 275). Replace each:

OLD (EN line 123): `Append a missed prior-work entry (arXiv URL / BibTeX / DOI)`
NEW: `Append a missed prior-work entry (arXiv URL / BibTeX)`

OLD (中文 line 275): `增补一条先前工作(arXiv URL / BibTeX / DOI)`
NEW: `增补一条先前工作(arXiv URL / BibTeX)`

- [ ] **Step 4: Edit `paper-deepstudy/skills/add-prior-work/SKILL.md`**

Near the top (after the YAML frontmatter, before the first `##` heading), add a note:

```
> **Roadmap note:** DOI inputs (e.g. `10.1093/nar/gkae1113`) are not yet supported. The current implementation falls back to "free-text" parsing for DOIs which produces poor results. Use the arXiv URL or BibTeX form instead. *DOI not yet supported* — tracking issue in spec §11.
```

- [ ] **Step 5: Verify pass**

- [ ] **Step 6: Commit**

```bash
git add README.md paper-deepstudy/skills/add-prior-work/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "docs(paper-deepstudy): drop DOI claim until /paper:add-prior-work actually supports it (Plan 10 I9)"
```

---

### Task 3: I10 — title-generator STYLE_FILTER unambiguous

**Files:**
- Modify: `paper-deepstudy/prompts/title-generator.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "title-generator.md disambiguates STYLE_FILTER behavior" {
  grep -qF 'all 5 candidates use that style' paper-deepstudy/prompts/title-generator.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/prompts/title-generator.md`**

Find line 12: `STYLE_FILTER (optional): one of \`hook | literal | question | numbers | contrast\`. If absent, generate one of each style.`

Append (same line or new bullet):
```
If `STYLE_FILTER` is set, **all 5 candidates use that style** (5 different angles of the same style, e.g. 5 different hook openers). If absent, generate one of each style (one hook, one literal, one question, one numbers, one contrast).
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/title-generator.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): title-generator STYLE_FILTER behavior unambiguous (Plan 10 I10)"
```

---

### Task 4: M11 + M12 — verify-prereqs glob relax + auto-detect warning

**Files:**
- Modify: `paper-deepstudy/scripts/verify-prereqs.sh`
- Modify: `paper-deepstudy/skills/refine-notes/SKILL.md`
- Modify: `paper-deepstudy/skills/retitle/SKILL.md`
- Modify: `paper-deepstudy/skills/reselect-figures/SKILL.md`
- Modify: `paper-deepstudy/skills/review-round/SKILL.md`
- Modify: `paper-deepstudy/skills/deep-dive/SKILL.md`
- Modify: `paper-deepstudy/skills/compare/SKILL.md`
- Modify: `paper-deepstudy/skills/reproduce-check/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "verify-prereqs.sh glob does not hardcode marketplace name" {
  ! grep -qE '\$HOME/\.claude/plugins/cache/claude-paper/claude-paper/' paper-deepstudy/scripts/verify-prereqs.sh
  grep -qE '\$HOME/\.claude/plugins/cache/\*/claude-paper/' paper-deepstudy/scripts/verify-prereqs.sh
}

@test "skills with most-recent-paper auto-detect warn the user" {
  for f in paper-deepstudy/skills/refine-notes/SKILL.md \
           paper-deepstudy/skills/retitle/SKILL.md \
           paper-deepstudy/skills/reselect-figures/SKILL.md \
           paper-deepstudy/skills/review-round/SKILL.md \
           paper-deepstudy/skills/deep-dive/SKILL.md \
           paper-deepstudy/skills/compare/SKILL.md \
           paper-deepstudy/skills/reproduce-check/SKILL.md; do
    grep -qF 'most recently modified' "$f" || { echo "FAIL: $f missing warning"; return 1; }
  done
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/scripts/verify-prereqs.sh` line 7**

OLD:
```
CLAUDE_PAPER_GLOB="$HOME/.claude/plugins/cache/claude-paper/claude-paper/*/skills/study/SKILL.md"
```

NEW:
```
# Glob is intentionally permissive: claude-paper may be installed under any
# marketplace name (default: claude-paper, but users can re-add it under any name).
CLAUDE_PAPER_GLOB="$HOME/.claude/plugins/cache/*/claude-paper/*/skills/study/SKILL.md"
```

- [ ] **Step 4: Edit each of the 7 skills**

In every skill that has the `ls -td ~/claude-papers/papers/*/ | head -1` auto-detect logic (refine-notes, retitle, reselect-figures, review-round, deep-dive, compare, reproduce-check), find the section where `--paper` is unset and the auto-detect runs. Right after the auto-detect, add a chat-printed warning.

For example, in `paper-deepstudy/skills/refine-notes/SKILL.md`, find the section where `PAPER_DIR` is computed for the no-`--paper` case. Add a chat-printed line:

```
After resolving `PAPER_DIR`, if `--paper` was not specified, print to chat:

> ⚠ Targeting `<slug>` (most recently modified paper folder). Pass `--paper <slug>` to override.

(Use the actual slug, not the literal `<slug>`.)
```

(Adjust the wording per skill — the goal: the user MUST see in chat which paper was auto-selected, so accidental retargeting doesn't go silent. NO emoji per spec §6 rule —— use a plain `Warning:` prefix or similar.)

Actually, re-reading: *the project rule is "no emoji in user-facing notes"* but chat output is short and an ASCII `Warning:` prefix is fine. Use:

```
Warning: targeting `<slug>` (most recently modified paper folder). Pass `--paper <slug>` to override.
```

- [ ] **Step 5: Verify pass**

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/scripts/verify-prereqs.sh paper-deepstudy/skills/refine-notes/SKILL.md paper-deepstudy/skills/retitle/SKILL.md paper-deepstudy/skills/reselect-figures/SKILL.md paper-deepstudy/skills/review-round/SKILL.md paper-deepstudy/skills/deep-dive/SKILL.md paper-deepstudy/skills/compare/SKILL.md paper-deepstudy/skills/reproduce-check/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): relax verify-prereqs glob + warn on auto-detected paper (Plan 10 M11+M12)"
```

---

### Task 5: M14 + M15 — strip plan-numbered final-summary leak + fix BERT example

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`
- Modify: `README.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "study-deep final summary does not leak Plan-numbered marketing" {
  ! grep -qF 'Plan 2 ✓' paper-deepstudy/skills/study-deep/SKILL.md
  ! grep -qF 'Plan 3a ✓' paper-deepstudy/skills/study-deep/SKILL.md
}

@test "README /paper:compare example uses a real arxiv slug, not bare BERT" {
  ! grep -qF '/paper:compare BERT --lang zh' README.md
  grep -qE '/paper:compare attention-is-all-you-need' README.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/skills/study-deep/SKILL.md`**

Find line 373 (or thereabouts) — the final-summary template that prints to user. It contains:
```
(These commands ship in: Plan 2 ✓ for /paper:review-round; Plan 3a ✓ ...; Plan 3c for /paper:reproduce-check.)
```

Delete that entire parenthetical line. The user does not need internal release tracking.

- [ ] **Step 4: Edit `README.md`**

Find both EN and 中文 occurrences of `/paper:compare BERT --lang zh`. Replace with:
```
/paper:compare attention-is-all-you-need --lang zh
```

(`attention-is-all-you-need` is the canonical demo paper used elsewhere in the README and matches the example in `paper-deepstudy/README.md`.)

- [ ] **Step 5: Verify pass**

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md README.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "polish: strip Plan-numbered leak from study-deep + fix /paper:compare README example (Plan 10 M14+M15)"
```

---

### Task 6: M19 + M20 + M16 — small doc/spec consistency

**Files:**
- Modify: `paper-deepstudy/README.md`
- Modify: `docs/superpowers/specs/2026-04-26-paper-deepstudy-design.md`

- [ ] **Step 1: Edit `paper-deepstudy/README.md`** (M19)

Find the Examples section (around line 135-141 — the parenthetical mentions "Examples are at the repo root, not inside the plugin install"). Improve the link text so it works post-install:

OLD:
```
- [`examples/string-database-2025/`](../examples/string-database-2025/) — full pipeline on "The STRING database in 2025" ...

(Examples are at the repo root, not inside the plugin install. Browse the folder on GitHub or after cloning the repo.)
```

NEW:
```
- [`examples/string-database-2025/`](../examples/string-database-2025/) — or browse on GitHub: [github.com/chansigit/studypaper/tree/main/examples/string-database-2025](https://github.com/chansigit/studypaper/tree/main/examples/string-database-2025) — full pipeline on "The STRING database in 2025" ...

(Examples live at the repo root, not inside the marketplace plugin install. Use the GitHub link above when reading this README from a marketplace cache.)
```

- [ ] **Step 2: Edit `docs/superpowers/specs/2026-04-26-paper-deepstudy-design.md`** (M20)

Find spec §9 "Sub-Agent Roster" table. Add a row for `reproduce-checker` (the Plan 3c addition):

```
| reproduce-checker | reproduce-check | Audit reproducibility across 7 dimensions; verify GitHub URLs via WebFetch | Yes (≤6) |
```

Position it sensibly — likely after `compare-agent` since both are extension agents.

- [ ] **Step 3: Edit spec §10 "Risks & Open questions"** (M16)

Add a known soft-failure mode under "Known limitations" (or wherever defensive enumerations live):

```
**WebFetch budgets are advisory, not enforced.** Each prompt that allows WebFetch declares a numeric cap (e.g. "≤6 fetches" in `reproduce-checker`), but enforcement is by sub-Agent self-discipline. A sub-Agent that ignores the cap will not be stopped by the orchestrator. Spec §11 tracks central-budget enforcement as a future polish.
```

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/README.md docs/superpowers/specs/2026-04-26-paper-deepstudy-design.md
git commit -m "docs: paper-deepstudy README post-install link + spec §9 reproduce-checker row + §10 WebFetch budget note (Plan 10 M19+M20+M16)"
```

---

## Self-Review checklist

- [ ] `cd paper-deepstudy && npm run test:unit` 通过(bats grew by ~6).
- [ ] `tests/integration/test-end-to-end.sh` 通过.
- [ ] `commands/study.md` argument-hint 含 `--paper`.
- [ ] `paper-deepstudy/skills/add-prior-work/SKILL.md` 顶部有 "DOI not yet supported" 注。
- [ ] README 不再提 DOI、不再用 `BERT` 作 compare 示例。
- [ ] `verify-prereqs.sh` glob 不再硬编码 marketplace 名。
- [ ] 7 个 skill 都有 most-recently-modified 警告。
- [ ] `study-deep/SKILL.md` 最终 summary 不再含 Plan 编号。
- [ ] spec §9 多 reproduce-checker 一行;§10 加 WebFetch budget note。
- [ ] No Claude co-author on any commit.

---

## Out of scope (deferred indefinitely)

- M13 (trailing-slash sed convergence): bash 是 forgiving 的,实际未观测到失败;改 7 个 skill 的回报不大。
- M17 (`source.md` template `<!-- N/A -->` 示例缺):notes-writer prompt 已规定;模板不再加 noise。
- M18 (Last updated bats 加固):Plan 9 的 Task 4 已加 prompt 断言,模板字段被 review-writer 覆写。
