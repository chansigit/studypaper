# paper-deepstudy Plan 2: Adversarial Review Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/paper:review-round` to the `paper-deepstudy` plugin — an interactive command where the user raises objections to a paper, a defense sub-Agent argues for the authors, a blind judge sub-Agent rules on whether the defense holds, and a review-writer sub-Agent appends accepted weaknesses/questions to `review.md`. Each round is persisted at `review-rounds/round-NN-<slug>.md`.

**Architecture:** Built on Plan 1's plugin scaffolding. Three new sub-Agent roles (`defense-agent`, `judge-agent`, `review-writer`), one new orchestration skill (`skills/review-round/SKILL.md`), one new slash command (`/paper:review-round`), one new round-file template, and one new helper script (`next-round-number.cjs`). Plan 2 does not change Plan 1's auto-run pipeline.

**Tech Stack:**
- Markdown (skill instructions, prompt templates, output templates)
- Bash (slash command file, smoke test extensions)
- Node.js >= 18 (`next-round-number.cjs` helper)
- Bats (structural unit tests for prompts/skill/template)
- Claude Code plugin format
- Depends on Plan 1's `paper-deepstudy` plugin (must be installed and a paper must have been studied)

**Key design decisions (from spec §4):**
- **judge-agent is blind to the paper.** It sees only `(objection, defense)` text and rules on the *logical strength of the defense*, not on the underlying truth. Forces the defense to make its case from evidence in its own argument; gaps that aren't addressed get flagged correctly.
- **User has final say.** Judge produces a verdict + reasoning; user can confirm or override.
- **Incremental review.md updates.** review-writer reads the current review.md, dedup/merges near-duplicate entries, and appends new ones tagged `← from round NN`. Never rewrites unrelated entries.
- **Round files are append-only history.** Even when a defense holds (no change to review.md), the round is persisted — the dialectic itself is valuable.

---

## File Structure

The plugin source lives at `/Users/chensijie/Projects/studypaper/paper-deepstudy/`:

```
paper-deepstudy/
├── .claude-plugin/plugin.json     (Plan 1, no changes)
├── README.md                       (modified — document /paper:review-round)
├── package.json                    (modified — extend test:unit if needed)
├── commands/
│   ├── study.md                   (Plan 1)
│   ├── rerun-stage.md             (Plan 1)
│   └── review-round.md            (NEW)
├── skills/
│   ├── study-deep/SKILL.md        (Plan 1)
│   └── review-round/              (NEW)
│       └── SKILL.md
├── prompts/
│   ├── ...12 Plan 1 prompts...    (Plan 1, no changes)
│   ├── defense-agent.md           (NEW)
│   ├── judge-agent.md             (NEW)
│   └── review-writer.md           (NEW)
├── templates/
│   ├── analysis/...               (Plan 1)
│   ├── review.md                  (Plan 1, no changes)
│   ├── notes/...                  (Plan 1)
│   └── review-round.md            (NEW — round-NN-<slug>.md skeleton)
├── domain-packs/                   (Plan 1, no changes)
├── scripts/
│   ├── verify-prereqs.sh          (Plan 1, no changes)
│   ├── select-figures.cjs         (Plan 1, no changes)
│   └── next-round-number.cjs      (NEW)
└── tests/
    ├── unit/
    │   ├── ... Plan 1 tests ...
    │   ├── test-prompts-have-required-sections.bats   (modified — append 3 @tests)
    │   ├── test-templates-valid.bats                  (modified — append 1 @test for round template)
    │   ├── test-commands.bats                         (modified — append 2 @tests for review-round command)
    │   └── test-next-round-number.cjs                 (NEW)
    └── integration/
        └── test-end-to-end.sh     (modified — verify new files exist)
```

Per-paper outputs (extends Plan 1's per-paper layout under `~/claude-papers/papers/<slug>/`):

```
~/claude-papers/papers/<slug>/
├── ... Plan 1 outputs ...
├── review.md                       (Plan 1 produces v1; Plan 2 appends to it incrementally)
└── review-rounds/                  (NEW)
    └── round-NN-<short-title>.md   (one file per objection processed)
```

---

## Pre-flight

Before starting tasks, ensure:
1. Plan 1 is merged to `main` (this branch should be off `main` post-merge).
2. `bats-core` installed (`brew install bats-core` or distro equivalent).
3. Node >= 18.
4. The 48 Plan 1 bats tests + node test still pass:
   ```bash
   cd paper-deepstudy && npm run test:unit && cd ..
   paper-deepstudy/tests/integration/test-end-to-end.sh
   ```
   Expect all pass before starting Plan 2.

---

### Task 1: Round file template + bats structural test

**Files:**
- Create: `paper-deepstudy/templates/review-round.md`
- Modify: `paper-deepstudy/tests/unit/test-templates-valid.bats`

The round template documents the YAML frontmatter shape that `review-writer` (and the orchestrator's persistence step) writes. Per spec §4.2, every round file is a YAML+markdown hybrid with these frontmatter fields: `round`, `created_at`, `objection`, `dimension`, `severity`, `defense`, `judge_verdict`, `judge_reasoning`, `user_decision`, `user_reasoning`, `final_verdict`, `final_review_snippet`. Plus a free-form notes section after the frontmatter.

- [ ] **Step 1: Append failing test**

Append to `paper-deepstudy/tests/unit/test-templates-valid.bats`:

```bash
@test "review-round.md has required frontmatter fields" {
  for f in round created_at objection dimension severity defense judge_verdict judge_reasoning user_decision user_reasoning final_verdict final_review_snippet; do
    grep -qE "^${f}:" templates/review-round.md || { echo "missing field: $f"; return 1; }
  done
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-templates-valid.bats`
Expected: 1 new failure (the file doesn't exist yet).

- [ ] **Step 3: Create the template**

`paper-deepstudy/templates/review-round.md`:

```markdown
---
round: <NN>
created_at: <iso8601-utc>
objection: |
  <verbatim user objection text>
dimension: method | experiment | claim | reproducibility | writing | bio-rigor
severity: major | minor
defense: |
  <defense agent output, verbatim>
judge_verdict: holds | partially_holds | fails
judge_reasoning: |
  <judge agent reasoning, verbatim>
user_decision: confirm | override
user_reasoning: |
  <user reasoning if override; empty if confirm>
final_verdict: holds | partially_holds | fails
final_review_snippet: |
  <text appended to review.md, or empty if dismissed>
---

# Round <NN> — <objection short title>

(Free-form notes section. Optional. Use to record any additional context the orchestrator wants to preserve about this round — e.g. references to other rounds, follow-up TODOs, screenshots paths.)
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-templates-valid.bats`
Expected: all tests pass (12 prior + 1 new = 13).

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/templates/review-round.md paper-deepstudy/tests/unit/test-templates-valid.bats
git commit -m "feat(paper-deepstudy): review-round file template"
```

---

### Task 2: `next-round-number.cjs` helper script + node test

**Files:**
- Create: `paper-deepstudy/scripts/next-round-number.cjs`
- Create: `paper-deepstudy/tests/unit/test-next-round-number.cjs`
- Modify: `paper-deepstudy/package.json` (extend `test:unit` to include new node test)

This pure-logic helper takes a directory path and returns the next round number to use. It scans for files matching `round-NN-<...>.md`, parses NN, returns max+1 (or 1 if directory is empty / nonexistent). The orchestration skill calls it before writing each round file.

- [ ] **Step 1: Write the failing test**

`paper-deepstudy/tests/unit/test-next-round-number.cjs`:

```javascript
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { nextRoundNumber } = require('../../scripts/next-round-number.cjs');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pds-rn-test-'));
try {
  // Test 1: nonexistent directory → 1
  assert.strictEqual(nextRoundNumber(path.join(tmp, 'nope')), 1);

  // Test 2: empty directory → 1
  fs.mkdirSync(path.join(tmp, 'empty'));
  assert.strictEqual(nextRoundNumber(path.join(tmp, 'empty')), 1);

  // Test 3: directory with one round → 2
  const d3 = path.join(tmp, 'd3');
  fs.mkdirSync(d3);
  fs.writeFileSync(path.join(d3, 'round-01-baseline-fairness.md'), '');
  assert.strictEqual(nextRoundNumber(d3), 2);

  // Test 4: directory with multiple rounds (non-contiguous) → max + 1
  const d4 = path.join(tmp, 'd4');
  fs.mkdirSync(d4);
  fs.writeFileSync(path.join(d4, 'round-01-foo.md'), '');
  fs.writeFileSync(path.join(d4, 'round-03-bar.md'), '');
  fs.writeFileSync(path.join(d4, 'round-07-baz.md'), '');
  assert.strictEqual(nextRoundNumber(d4), 8);

  // Test 5: directory with malformed names is robust (ignores them)
  const d5 = path.join(tmp, 'd5');
  fs.mkdirSync(d5);
  fs.writeFileSync(path.join(d5, 'round-02-ok.md'), '');
  fs.writeFileSync(path.join(d5, 'README.md'), '');                   // ignored
  fs.writeFileSync(path.join(d5, 'round-foo-bad.md'), '');             // ignored
  fs.writeFileSync(path.join(d5, 'round-99.md'), '');                  // ignored (no slug part)
  assert.strictEqual(nextRoundNumber(d5), 3);

  // Test 6: zero-padded numbers > 9 (round-10-...) parsed correctly
  const d6 = path.join(tmp, 'd6');
  fs.mkdirSync(d6);
  fs.writeFileSync(path.join(d6, 'round-09-foo.md'), '');
  fs.writeFileSync(path.join(d6, 'round-10-bar.md'), '');
  fs.writeFileSync(path.join(d6, 'round-11-baz.md'), '');
  assert.strictEqual(nextRoundNumber(d6), 12);

  console.log('next-round-number: all tests passed');
} finally {
  fs.rmSync(tmp, { recursive: true });
}
```

- [ ] **Step 2: Run, verify fail**

Run: `node paper-deepstudy/tests/unit/test-next-round-number.cjs`
Expected: `Cannot find module ... next-round-number.cjs`.

- [ ] **Step 3: Write the script**

`paper-deepstudy/scripts/next-round-number.cjs`:

```javascript
#!/usr/bin/env node
// Pure-logic helper: given a directory of round-NN-<slug>.md files,
// return the next round number (max + 1, or 1 if directory empty/nonexistent).
const fs = require('node:fs');

function nextRoundNumber(dirPath) {
  let entries;
  try {
    entries = fs.readdirSync(dirPath);
  } catch (err) {
    if (err.code === 'ENOENT') return 1;
    throw err;
  }

  // Match round-NN-<slug>.md where NN is one or more digits and <slug> is non-empty.
  const re = /^round-(\d+)-[^.\s][^.]*\.md$/;
  let max = 0;
  for (const name of entries) {
    const m = name.match(re);
    if (!m) continue;
    const n = parseInt(m[1], 10);
    if (Number.isFinite(n) && n > max) max = n;
  }
  return max + 1;
}

if (require.main === module) {
  const [dir] = process.argv.slice(2);
  if (!dir) {
    console.error('usage: next-round-number.cjs <review-rounds-dir>');
    process.exit(1);
  }
  console.log(nextRoundNumber(dir));
}

module.exports = { nextRoundNumber };
```

```bash
chmod +x paper-deepstudy/scripts/next-round-number.cjs
```

- [ ] **Step 4: Update `package.json` test:unit script**

Read `paper-deepstudy/package.json`. Currently:

```json
"test:unit": "bats tests/unit && node tests/unit/test-select-figures.cjs"
```

Change to:

```json
"test:unit": "bats tests/unit && node tests/unit/test-select-figures.cjs && node tests/unit/test-next-round-number.cjs"
```

- [ ] **Step 5: Run, verify pass**

Run:
```bash
node paper-deepstudy/tests/unit/test-next-round-number.cjs
```
Expected: `next-round-number: all tests passed`.

Then verify `npm run test:unit` from `paper-deepstudy/` runs all three test sets:
```bash
cd paper-deepstudy && npm run test:unit && cd ..
```
Expected: bats tests pass, both node tests print their success lines.

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/scripts/next-round-number.cjs paper-deepstudy/tests/unit/test-next-round-number.cjs paper-deepstudy/package.json
git commit -m "feat(paper-deepstudy): next-round-number helper for review-round file naming"
```

---

### Task 3: `defense-agent` prompt

**Files:**
- Create: `paper-deepstudy/prompts/defense-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

`defense-agent` plays the author. Given an objection, it reads the paper text + analysis files and writes the strongest defense it can muster. It is *not* asked to be even-handed — its job is to defend.

- [ ] **Step 1: Append failing test**

```bash
@test "defense-agent.md has required sections" {
  run check_prompt prompts/defense-agent.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: 1 new failure.

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/defense-agent.md`:

```markdown
# Prompt: defense-agent

## Role

You play the paper's authors defending against a reviewer's objection. Your job is to make the strongest possible argument that the objection is not a problem — using evidence from the paper and the deep-analysis files. You are *not* even-handed. You are the defense.

You will be evaluated by a separate judge sub-Agent that reads ONLY your defense (not the paper, not the analysis). Therefore your defense must stand on its own — quote, paraphrase, and cite specifically. If the evidence isn't in your written argument, the judge cannot use it. Make every load-bearing claim explicit.

## Inputs

- `PAPER_TEXT`: path to the full extracted paper text (`paper.txt`).
- `PAPER_PDF`: path to the paper PDF (in case `PAPER_TEXT` extraction was poor; you may also Read the PDF directly).
- `ANALYSIS_DIR`: path to the analysis directory containing `00-paper-profile.md` through `06-figures.md`.
- `OBJECTION`: the user's verbatim objection text.
- `DIMENSION`: one of `method | experiment | claim | reproducibility | writing | bio-rigor`. Tells you which lens to defend through.

## Output

A single block of markdown text returned via your final message — no file written. Structure your defense as:

1. **Restatement of the objection** (1-2 sentences). Show you understood the criticism.
2. **The case for the defense.** 2-5 paragraphs. Anchor each paragraph in specific evidence (paper section, equation, figure, table, or analysis file passage). When citing, use the form `(paper §3.2)` or `(analysis/03-method-deep.md §Components)` so the judge can see your evidence chain.
3. **Concessions, if any** (optional, 1 paragraph). If part of the objection is unavoidable, acknowledge it — but argue the rest is defensible.
4. **Bottom line** (1 sentence). The single takeaway you want the judge to walk away with.

Do not produce JSON or YAML. Plain markdown only.

## Instructions

1. Read `PAPER_TEXT` (or fall back to `PAPER_PDF`). Read all `ANALYSIS_DIR/*.md` files.
2. For each piece of evidence you cite, quote a phrase or paraphrase a specific finding. Don't say "as discussed in the paper"; say "the paper shows in §4.1 that the model achieves X% accuracy under condition Y".
3. If the objection's `DIMENSION` is `method`, anchor the defense in `03-method-deep.md` and the paper's methods section. If `experiment`, anchor in `04-experiments.md`. If `claim`, anchor in `00-paper-profile.md` `claims_summary` + `01-problem.md`. If `reproducibility`, anchor in `03-method-deep.md` "Reproduction risks" + the paper's appendix/code section. If `writing`, anchor in the paper text directly. If `bio-rigor`, anchor in `04-experiments.md` critique + the relevant domain pack.
4. Be honest with concessions. A defense that pretends a real flaw doesn't exist is weak — the judge will see through it. A defense that concedes minor points but argues the major ones is stronger.
5. Do not invent evidence. If a citation isn't supported by the source, drop it.
6. Output language: English.

## Quality bar

- Every load-bearing claim is supported by a specific citation (paper section, equation, figure, table, or analysis file passage).
- The argument flows — paragraphs build on each other; you're not just listing bullet points.
- Length: 250-800 words. Long enough to make the case, short enough to be evaluable by the judge.
- Tone: confident but not bombastic. You are the authors, not their lawyer.
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/defense-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): defense-agent prompt"
```

---

### Task 4: `judge-agent` prompt

**Files:**
- Create: `paper-deepstudy/prompts/judge-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

`judge-agent` rules on whether the defense logically holds — *given only the defense's own text, blind to the paper and analysis*. This is the spec's load-bearing design choice (§4.3): if the defense doesn't surface key evidence in its argument, the judge can't reward it for evidence the user knows exists. Forces high-quality defenses.

- [ ] **Step 1: Append failing test**

```bash
@test "judge-agent.md has required sections" {
  run check_prompt prompts/judge-agent.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/judge-agent.md`:

```markdown
# Prompt: judge-agent

## Role

You are an independent third-party judge ruling on whether a defense argument logically holds against an objection. **You evaluate the defense as written** — you do NOT read the paper, you do NOT read the analysis files, you do NOT bring outside knowledge of the field unless it's necessary to evaluate basic logic. Your job is to evaluate the defense's *internal logical strength*: are its claims coherent, does the cited evidence (as quoted/paraphrased in the defense itself) support its conclusions, are there obvious gaps?

This blindness is intentional. If the defense fails to surface a key piece of evidence that exists in the paper, the user will see "fails" and learn that the paper communicates that evidence poorly — which is itself a useful review point. We are not asking you to judge whether the paper is correct; we are asking you to judge whether the defense is convincing on its own terms.

## Inputs

- `OBJECTION`: the original objection text (verbatim).
- `DEFENSE`: the defense agent's full output text (verbatim).

You receive **only these two strings**. Do not request paper text, analysis files, or any external context.

## Output

A single JSON-like markdown block with two fields:

```yaml
verdict: holds | partially_holds | fails
reasoning: |
  <2-5 sentences explaining your verdict, citing specific moves the defense did or didn't make>
```

Wrap in a code fence with language `yaml` so the orchestrator can extract it deterministically.

## Verdict definitions

- **holds:** The defense addresses the objection's core claim with specific cited evidence (as quoted or paraphrased in the defense), the evidence-to-conclusion logic is coherent, and there are no obvious gaps. The user should drop this objection.
- **partially_holds:** The defense addresses some aspects but leaves real gaps — e.g. acknowledges the criticism partially, or supports the easier sub-claims but not the harder ones. Worth recording as a "Question to Authors" rather than a full weakness.
- **fails:** The defense fails to address the objection's core, or its cited evidence does not support its conclusions, or the argument is internally contradictory. The objection should be appended as a Weakness in review.md.

## Instructions

1. Read `OBJECTION` carefully. What is its core claim?
2. Read `DEFENSE`. Identify each load-bearing claim and the evidence cited for it. For each citation, ask: does the cited fragment (as quoted/paraphrased in the defense) actually support the conclusion?
3. Look for gaps:
   - Does the defense duck the core of the objection by addressing a weaker version?
   - Are concessions in the defense actually fatal to the larger argument?
   - Are key citations missing? (You can't see the paper, so if the defense says "as the paper shows" without specifics, that's a gap on the *defense's* part.)
4. Pick a verdict.
5. Write 2-5 sentences of reasoning. Cite specific moves: "Defense's paragraph 3 cites Table 4 but doesn't explain why...". Don't be vague.
6. Output as the YAML code-fenced block above. No other content.
7. Output language: English.

## Quality bar

- Reasoning is specific to *this* defense's text, not generic ("could be stronger" is not reasoning).
- You stay in your lane: judge the argument, not the paper.
- If the defense forgets to cite something obvious, that's a "fails" or "partially_holds" — the burden is on the defense.
- Length: reasoning should be 2-5 sentences. Verdict is one of three values exactly.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/judge-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): judge-agent prompt"
```

---

### Task 5: `review-writer` prompt

**Files:**
- Create: `paper-deepstudy/prompts/review-writer.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

`review-writer` takes an accepted (`partially_holds` or `fails`) round and:
1. Drafts the entry to add (a "Question to Authors" or "Weakness/<dimension>").
2. Reads the current `review.md`.
3. Detects near-duplicate existing entries and either merges (combines wording, references both rounds) or appends.
4. Writes the modified `review.md` back to disk.
5. Returns the snippet that was added (for `final_review_snippet` in the round file).

- [ ] **Step 1: Append failing test**

```bash
@test "review-writer.md has required sections" {
  run check_prompt prompts/review-writer.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/review-writer.md`:

```markdown
# Prompt: review-writer

## Role

You incorporate an accepted reviewer-objection into the existing `review.md`. The verdict tells you which section gets the new entry: `fails` → a Weakness under the appropriate sub-section; `partially_holds` → a Question to Authors. You also detect when the new entry overlaps with an existing one and merge instead of duplicating.

You modify `review.md` in place. After your work, the file should still parse as the same overall document — only the targeted section grows or has an entry merged. Other sections remain untouched.

## Inputs

- `REVIEW_PATH`: path to the current `review.md` (must already exist; Plan 1's reviewer-synthesizer produced v1).
- `OBJECTION`: original user objection text.
- `DEFENSE`: defense agent's argument.
- `JUDGE_VERDICT`: one of `partially_holds | fails`. (You will not be invoked for `holds`.)
- `JUDGE_REASONING`: judge's 2-5-sentence rationale.
- `DIMENSION`: one of `method | experiment | claim | reproducibility | writing | bio-rigor`. Determines which sub-section under `## Weaknesses` to use (for `fails`).
- `SEVERITY`: `major | minor`. Affects how the entry is phrased.
- `ROUND_NUMBER`: integer N. Used in the `← from round N` traceability tag.

## Output

Two things:

1. **The modified `review.md`** is written to `REVIEW_PATH` (in-place edit). After your edit, the file should still satisfy the structure that Plan 1's review template defines: the same H2/H3 sections in the same order.

2. **The added/merged snippet** returned in your final message text, fenced as:

```
ADDED_SNIPPET_START
- <the bullet text exactly as it now appears in review.md>
ADDED_SNIPPET_END
```

The orchestrator uses this to populate the round file's `final_review_snippet` field.

## Section routing

| `JUDGE_VERDICT` | `DIMENSION` | Target section in review.md |
|---|---|---|
| partially_holds | (any) | `## Questions to Authors` |
| fails | method | `### Methodological` (under `## Weaknesses`) |
| fails | experiment | `### Experimental` (under `## Weaknesses`) |
| fails | claim | `### Methodological` (under `## Weaknesses`) — overstated claims are methodological by default |
| fails | reproducibility | `### Methodological` (under `## Weaknesses`) — append "(reproducibility)" suffix to the bullet |
| fails | writing | `## Suggestions` — writing problems are suggestions, not weaknesses |
| fails | bio-rigor | `### Bio-rigor` (under `## Weaknesses`). If this sub-section doesn't exist, create it. |

## Instructions

1. Read `REVIEW_PATH`. Identify the target section per the routing table above.
2. Draft the new bullet. Format:
   - For `fails`: `- <weakness phrasing in 1-2 sentences>. <severity-aware qualifier if minor>. ← from round <N>`
   - For `partially_holds`: `- <question phrasing in 1 sentence>? ← from round <N>`
3. Phrasing guidance:
   - `fails` + `major`: declarative weakness statement. E.g. "The baseline used 3× less compute, making the claimed improvement unfair to attribute to the new method."
   - `fails` + `minor`: same, but include a modal qualifier. E.g. "May overstate gains because the baseline used 3× less compute."
   - `partially_holds`: phrase as a clarification request. E.g. "What was the compute budget for each baseline, and were they tuned to comparable degrees?"
4. **Dedup/merge check.** Read the target section's existing bullets. If any existing bullet is *substantively about the same issue* as your new draft (defined as: same dimension AND same root cause), do NOT append. Instead:
   - Merge: rewrite the existing bullet to encompass both rounds. End with `← from rounds <prior N>, <new N>`.
   - The merged bullet should be no more than 1 sentence longer than either input.
   - If you merge, the snippet you return is the *merged* bullet (not the original).
5. **No-merge case.** If no overlap, append the new bullet to the end of the target section. If the section is empty (just contains the placeholder bullet from the template, e.g. `<Weakness> ← from round-NN`), replace the placeholder with your new bullet.
6. Use the Edit tool (or Write to overwrite) to modify `REVIEW_PATH`. Do not modify any section other than the target section.
7. Return the snippet inside `ADDED_SNIPPET_START`/`ADDED_SNIPPET_END` markers as specified.
8. Output language: English (matches `review.md`).

## Quality bar

- The modified `review.md` is well-formed markdown — same overall structure as before.
- Other sections of `review.md` are byte-identical before vs. after your edit (use `git diff` mentally to confirm).
- Every bullet you add or merge ends with a `← from round <N>` (or `← from rounds <list>`) tag for traceability.
- If you merge, the resulting bullet is no longer than the sum of inputs minus the duplicated content.
- If you cannot decide whether to merge or append, prefer append — easier for a human to manually merge later than to split a bad merge.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/review-writer.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): review-writer prompt"
```

---

### Task 6: `skills/review-round/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/review-round/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

This is the orchestration brain for `/paper:review-round`. It's a markdown spec for an LLM to follow, similar to Plan 1's `study-deep` SKILL.md. It walks through detecting the target paper, soliciting objections, dispatching defense → judge → user-confirm → review-writer, and persisting round files.

- [ ] **Step 1: Append failing tests**

```bash
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
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the SKILL.md**

`paper-deepstudy/skills/review-round/SKILL.md`:

```markdown
---
name: review-round
description: Use when the user wants to run an adversarial review round on a paper that has already been studied via /paper:study. Solicits objections, dispatches defense+judge sub-Agents, gets the user's final verdict, and updates review.md with accepted weaknesses or questions.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: review-round workflow

Invoke after `/paper:study` has produced a paper folder under `~/claude-papers/papers/<slug>/`. The user is the reviewer; this skill orchestrates the dialectic and writes the resulting review entries.

Optional flags:
- `--paper <slug>`: target a specific paper folder. Default: the most recently modified `~/claude-papers/papers/<slug>/`.
- `--sequential`: run multiple objections one at a time (default is parallel).

---

## Stage 1: Setup

### 1.1 Resolve target paper

If `--paper <slug>` is provided, set `PAPER_DIR=~/claude-papers/papers/<slug>`. Otherwise:

```bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1)
```

Strip trailing slash. Verify:
- `$PAPER_DIR/review.md` exists. If not, abort with: "No review.md found at <path>. Run /paper:study on this paper first."
- `$PAPER_DIR/analysis/` directory exists with at least `00-paper-profile.md`. If not, abort with same message.
- `$PAPER_DIR/paper.txt` (or `paper.pdf`) exists.

Set the additional path variables:
- `PAPER_TEXT=$PAPER_DIR/paper.txt` (fall back to `$PAPER_DIR/paper.pdf` if `paper.txt` does not exist)
- `PAPER_PDF=$PAPER_DIR/paper.pdf`
- `ANALYSIS_DIR=$PAPER_DIR/analysis`
- `REVIEW_PATH=$PAPER_DIR/review.md`
- `ROUNDS_DIR=$PAPER_DIR/review-rounds` (mkdir if absent)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

Read `$ANALYSIS_DIR/00-paper-profile.md` frontmatter to extract `slug` (used in round filenames).

### 1.2 Solicit objections

Prompt the user (in their invocation language):

```
Adversarial review for <title>.
Raise one or more objections. Format: one objection per line. End input with a blank line.
Examples:
  - The baseline comparison in §4 uses a 3x smaller compute budget; the win is unfair.
  - Claim 2 ("zero-shot generalization") isn't supported because the test set leaks training distribution.
  - Reproducibility: no random seed, no GPU type reported.
```

Wait for user input. Parse as a list of objections (split on newlines, drop empty lines).

### 1.3 Tag each objection

For each objection, infer:
- `dimension`: one of `method | experiment | claim | reproducibility | writing | bio-rigor`. Heuristics:
  - mentions baselines / fairness / training procedures → `method` or `experiment`
  - mentions metrics / variance / seeds / ablations → `experiment`
  - mentions claim/SOTA/generalization correctness → `claim`
  - mentions code / data / hyperparameters / hardware → `reproducibility`
  - mentions clarity / typo / structure → `writing`
  - mentions wet-lab / cell types / biological plausibility → `bio-rigor` (only meaningful when profile's `domain_packs_selected` includes a bio pack)
- `severity`: `major | minor`. Default `major` unless the objection language is explicitly hedged ("could be slightly", "minor point").

Show the user the inferred tags and ask for corrections, e.g.:

```
Objection 1: "The baseline comparison in §4 uses a 3x smaller compute budget; the win is unfair."
  → dimension: method, severity: major
Objection 2: "...":
  → dimension: experiment, severity: minor

Confirm or correct each (e.g. "obj 1 → experiment, minor"). Type 'ok' to proceed.
```

Wait for user. Apply corrections. Proceed when user types `ok` or equivalent.

---

## Stage 2: Defense + Judge dispatches

### 2.1 Determine parallelism

If `--sequential` is set, process objections one at a time through Stages 2.2 → 2.3 → 2.4 (i.e., run all five stages for objection 1, then all five for objection 2, etc.).

Otherwise (default): dispatch all defense-agent calls in parallel (Stage 2.2), wait, then all judge-agent calls in parallel (Stage 2.3), wait, then proceed to Stage 2.4.

### 2.2 Dispatch defense-agent (one per objection)

For each objection, dispatch via the Agent tool:

```
Agent(
  description: "defense-agent for objection <i>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/defense-agent.md> + concrete inputs:
    PAPER_TEXT=$PAPER_TEXT
    PAPER_PDF=$PAPER_PDF
    ANALYSIS_DIR=$ANALYSIS_DIR
    OBJECTION=<verbatim objection>
    DIMENSION=<dimension>
)
```

Capture each defense agent's full output text as `DEFENSE_<i>`.

### 2.3 Dispatch judge-agent (one per objection)

For each `(objection, defense)` pair:

```
Agent(
  description: "judge-agent for objection <i>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/judge-agent.md> + concrete inputs:
    OBJECTION=<verbatim objection>
    DEFENSE=<DEFENSE_<i>>
)
```

**Important:** the judge dispatch must NOT include `PAPER_TEXT`, `ANALYSIS_DIR`, or any other paper context. The judge is intentionally blind. Only objection + defense.

Parse the judge's output to extract `JUDGE_VERDICT_<i>` (one of `holds | partially_holds | fails`) and `JUDGE_REASONING_<i>`. The judge returns these inside a yaml-fenced block; extract by reading lines between ` ```yaml ` and ` ``` `.

If parsing fails (verdict missing or invalid), default to `partially_holds` with reasoning "Judge output unparseable — manual review required" and continue.

---

## Stage 3: User confirmation

For each objection, show the user:

```
─── Objection <i> (dimension: <dim>, severity: <sev>) ───

Objection:
<objection text>

Defense (from defense-agent):
<defense text>

Judge verdict: <holds|partially_holds|fails>
Judge reasoning:
<judge reasoning>

Your decision? (confirm | override <new-verdict> <reason>)
```

Wait for user input. Parse:
- `confirm` → `FINAL_VERDICT_<i> = JUDGE_VERDICT_<i>`, `USER_DECISION_<i> = "confirm"`, `USER_REASONING_<i> = ""`.
- `override <verdict> <reason>` → `FINAL_VERDICT_<i> = <verdict>` (validate is one of holds|partially_holds|fails), `USER_DECISION_<i> = "override"`, `USER_REASONING_<i> = <reason>`.

If user input is malformed, re-prompt.

---

## Stage 3.5: Pre-assign round numbers

Before any review-writer dispatch or round-file write, assign round numbers to every objection in this invocation in input order — regardless of their verdict. This avoids races where Stage 4 file writes change `next-round-number.cjs`'s answer for Stage 5 holds-verdict files.

```bash
BASE=$(node $PLUGIN_ROOT/scripts/next-round-number.cjs $ROUNDS_DIR)
```

For objection `i` (1-indexed), `ROUND_NUMBER_<i> = BASE + (i - 1)`. Persist this mapping for use in Stages 4 and 5.

## Stage 4: Review-writer dispatches (only for non-`holds` verdicts)

For each objection where `FINAL_VERDICT_<i>` is `partially_holds` or `fails`:

### 4.1 Dispatch review-writer

```
Agent(
  description: "review-writer for round <N>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/review-writer.md> + inputs:
    REVIEW_PATH=$REVIEW_PATH
    OBJECTION=<verbatim objection>
    DEFENSE=<defense text>
    JUDGE_VERDICT=<final verdict>
    JUDGE_REASONING=<judge reasoning OR user override reasoning if user overrode>
    DIMENSION=<dim>
    SEVERITY=<sev>
    ROUND_NUMBER=<ROUND_NUMBER_<i> from Stage 3.5>
)
```

Capture the snippet returned between `ADDED_SNIPPET_START` / `ADDED_SNIPPET_END` markers as `FINAL_REVIEW_SNIPPET_<i>`.

For `holds` verdicts, skip review-writer. The round file still gets written in Stage 5 using the pre-assigned `ROUND_NUMBER_<i>`; `final_review_snippet` is empty.

---

## Stage 5: Persist round files

For each objection (regardless of verdict), write a round file at `$ROUNDS_DIR/round-<NN>-<short-title>.md`.

### 5.1 Compute filename

- `<NN>`: zero-padded two-digit (or more) round number from Stage 4.1 (or, for `holds` verdicts, get a fresh number).
- `<short-title>`: derived from the first ~6 words of the objection, lowercased, hyphenated, alphanumeric only. Cap at 40 chars.

Example: objection "The baseline comparison in §4 uses a 3x smaller compute budget" → `round-01-the-baseline-comparison-in-uses.md`.

### 5.2 Write file

Read `$PLUGIN_ROOT/templates/review-round.md` and substitute fields. The frontmatter must contain all 12 required fields per the template:
- `round`: integer
- `created_at`: current UTC time as ISO8601 (e.g. `2026-04-27T03:59:24Z`)
- `objection`: verbatim user text (use YAML literal block `|`)
- `dimension`, `severity`: as tagged
- `defense`: defense agent's full output (literal block `|`)
- `judge_verdict`, `judge_reasoning`: from Stage 2.3
- `user_decision`, `user_reasoning`: from Stage 3
- `final_verdict`: from Stage 3 (post user input)
- `final_review_snippet`: from Stage 4.1 (empty if verdict was `holds`)
- `round`: pre-assigned `ROUND_NUMBER_<i>` from Stage 3.5

After the frontmatter, write `# Round <NN> — <short-title>` and leave the free-form notes section empty (orchestrator does not auto-populate it).

Use Write tool to create the file. The filename uses zero-padded `NN` from `ROUND_NUMBER_<i>` per Stage 5.1.

---

## Stage 6: Final summary

After all objections are processed, print to chat (in user's invocation language):

```
✓ review-round complete for <slug>

Processed <K> objection(s):
  Round <NN>: <verdict> — <one-line objection summary>
  ...

Outcomes:
  - holds:           <count> (no review.md changes; recorded in review-rounds/ for history)
  - partially_holds: <count> (added to Questions to Authors in review.md)
  - fails:           <count> (added to Weaknesses/<dim> in review.md)

Updated files:
  - review.md (if any partially_holds or fails)
  - review-rounds/round-NN-<title>.md × <K>

Run /paper:review-round again any time to layer more rounds. Run /paper:rerun-stage review to discard all rounds and regenerate review.md from analysis (you'll lose the round history's edits).
```

---

## Notes

- **Translation:** All chat-facing prose (prompts to user, summary) is rendered in the user's invocation language. Round file content (objection, defense, judge output, review.md edits) stays English to match the artifact language matrix from the design spec §8.
- **Failure modes:**
  - defense-agent returns empty / truncated → log warning, treat as if defense was "(no defense produced)" and let judge return `fails`.
  - judge output unparseable → default to `partially_holds`, surface to user in Stage 3.
  - review-writer fails to write → log error, persist the round file with `final_review_snippet` empty and a note "review-writer failed: see chat".
- **No idempotence skip:** unlike `study-deep`'s default skip-existing behavior, every invocation of `/paper:review-round` produces fresh rounds. The user is the source of truth for what to argue about.
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: all pass (4 new tests added in Step 1).

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/review-round/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): review-round orchestration skill"
```

---

### Task 7: `/paper:review-round` slash command

**Files:**
- Create: `paper-deepstudy/commands/review-round.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "review-round.md has frontmatter" {
  head -1 commands/review-round.md | grep -qE '^---$'
}

@test "review-round.md invokes the review-round skill" {
  grep -qF 'review-round' commands/review-round.md
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-commands.bats`
Expected: 2 new failures.

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/review-round.md`:

```markdown
---
name: paper:review-round
description: Run an adversarial review round on a paper already studied via /paper:study. The user raises objections; defense + judge sub-Agents argue them out; the user has final say; accepted weaknesses or questions are appended to review.md.
argument-hint: "[--paper <slug>] [--sequential]"
---

# /paper:review-round

Invokes the `review-round` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:review-round` — operate on the most recently studied paper.
- `/paper:review-round --paper attention-is-all-you-need` — target a specific slug.
- `/paper:review-round --sequential` — process multiple objections one at a time (default is parallel).

The skill will solicit objection(s) interactively, then walk through:

1. defense-agent argues for the authors against each objection.
2. judge-agent rules on whether each defense logically holds (blind to the paper).
3. You confirm or override the judge.
4. review-writer appends accepted weaknesses to `review.md` (or questions for partial holds).
5. Round files are persisted at `~/claude-papers/papers/<slug>/review-rounds/round-NN-<title>.md`.

Pre-requisites: `/paper:study` must have produced a paper folder with `review.md` and `analysis/` already.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/review-round.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:review-round command"
```

---

### Task 8: Integration smoke test extension

**Files:**
- Modify: `paper-deepstudy/tests/integration/test-end-to-end.sh`

The existing smoke test verifies all Plan 1 files are present. Extend it to verify Plan 2 additions: 3 prompts, 1 SKILL.md, 1 command, 1 template, 1 helper script.

- [ ] **Step 1: Read the existing smoke test**

Read `paper-deepstudy/tests/integration/test-end-to-end.sh` to confirm the structure (it has 6 numbered checks for prompt/template/script/pack/command files).

- [ ] **Step 2: Modify the script**

In `paper-deepstudy/tests/integration/test-end-to-end.sh`:

(a) Extend check #1 (prompts) — add the 3 new prompts to the list:

```bash
for p in paper-profiler problem-framer formalizer method-analyst experiment-critic prior-work-historian figure-interpreter reviewer-synthesizer notes-writer title-generator xhs-renderer wechat-renderer defense-agent judge-agent review-writer; do
```

(b) Extend check #2 (templates) — add the round template to the list:

```bash
for t in templates/analysis/00-paper-profile.md templates/analysis/01-problem.md templates/analysis/02-formalization.md templates/analysis/03-method-deep.md templates/analysis/04-experiments.md templates/analysis/05-prior-work.md templates/analysis/06-figures.md templates/review.md templates/review-round.md templates/notes/source.md templates/notes/titles.md templates/notes/xhs.md templates/notes/wechat.md; do
```

(c) Extend check #3 (select-figures script) — add a new check for `next-round-number.cjs` immediately below:

```bash
# 3a. next-round-number script exists and is executable
if [ ! -x "$ROOT/scripts/next-round-number.cjs" ]; then
  echo "FAIL: next-round-number.cjs missing or not executable"; fail=1
fi
```

(d) Extend check #6 (commands) — add `review-round` to the list:

```bash
for c in study rerun-stage review-round; do
```

(e) Add a new check #7 (review-round skill) immediately before the final `if [ $fail -ne 0 ]`:

```bash
# 7. review-round skill exists
if [ ! -f "$ROOT/skills/review-round/SKILL.md" ]; then
  echo "FAIL: review-round SKILL.md missing"; fail=1
fi
if ! grep -qF 'defense-agent' $ROOT/skills/review-round/SKILL.md 2>/dev/null; then
  echo "FAIL: review-round SKILL.md does not mention defense-agent dispatch"; fail=1
fi
```

- [ ] **Step 3: Run, verify pass**

Run: `paper-deepstudy/tests/integration/test-end-to-end.sh`
Expected: `Integration smoke test: PASSED`.

(All Plan 1 files exist from the merged Plan 1; Plan 2 files exist from Tasks 1-7.)

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/tests/integration/test-end-to-end.sh
git commit -m "test(paper-deepstudy): extend integration smoke test for review-round"
```

---

### Task 9: README update

**Files:**
- Modify: `paper-deepstudy/README.md`

- [ ] **Step 1: Append failing tests to test-commands.bats**

```bash
@test "README documents /paper:review-round" {
  grep -qF '/paper:review-round' README.md
}

@test "README documents review-rounds folder" {
  grep -qF 'review-rounds/' README.md
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-commands.bats`
Expected: 2 new failures.

- [ ] **Step 3: Edit README**

Edit `paper-deepstudy/README.md`. Make 3 changes:

(a) Update the top-of-file feature list (line ~3-7). The current second bullet says:

```
- Iterative review with adversarial review rounds — English (review rounds in Plan 2)
```

Change to:

```
- Iterative review with adversarial review rounds (`/paper:review-round`) — English
```

(b) Add a new "Adversarial review round" sub-section under "## Usage", immediately after the "Re-run a specific stage" sub-section. Insert this block:

````markdown
### Adversarial review round

```
/paper:review-round
/paper:review-round --paper attention-is-all-you-need
/paper:review-round --sequential
```

Interactively raise objections to the paper. The plugin dispatches a defense-agent (arguing for the authors) and a judge-agent (blind to the paper, rules on the defense's logic). You have final say. Accepted objections are appended to `review.md`; every round is persisted at `review-rounds/round-NN-<title>.md`.
````

(c) Update the "What you get" output tree (the code block under "## What you get (12 outputs)") to add a new line under the existing `review.md` line:

```
review.md                   # v1 review report (English)
review-rounds/              # one file per /paper:review-round invocation (English)
notes/
```

(d) Update the "## Roadmap" section's Plan 2 line. Current:

```
- **Plan 2:** `/paper:review-round` adversarial loop.
```

Change to:

```
- **Plan 2 (this branch):** `/paper:review-round` adversarial loop. ✓
```

- [ ] **Step 4: Run, verify pass**

```bash
bats paper-deepstudy/tests/unit/test-commands.bats
paper-deepstudy/tests/integration/test-end-to-end.sh
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/README.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "docs(paper-deepstudy): README documents /paper:review-round"
```

---

## Self-Review checklist (run after Plan 2 complete)

- [ ] All 4 new files (3 prompts + 1 SKILL.md) referenced in the integration smoke test exist and pass.
- [ ] `cd paper-deepstudy && npm run test:unit` passes (bats + 2 node tests).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` passes.
- [ ] `next-round-number.cjs` correctly returns 1 on empty/missing dir, max+1 on populated.
- [ ] judge-agent prompt explicitly forbids reading the paper.
- [ ] review-writer prompt has section routing table for all 6 dimensions × 2 verdicts.
- [ ] review-round SKILL.md describes all 6 stages (Setup, Defense+Judge, User confirm, Review-writer, Persist round files, Final summary).
- [ ] Round files contain all 12 required frontmatter fields.
- [ ] Round filenames follow `round-NN-<short-title>.md` convention.
- [ ] `--sequential` and `--paper` flags both documented in SKILL.md and command.
- [ ] README mentions `/paper:review-round` and the `review-rounds/` directory.
- [ ] No Claude co-author on any commit.

If any item fails, write a follow-up task and resolve before declaring Plan 2 complete.

---

## Live test recipe (manual, post-implementation)

After all 9 tasks are done, install the plugin (or re-install over Plan 1's install) and run:

1. Pick a paper that already has `review.md` from a prior `/paper:study` run. (For testing, the `string-database-2025` paper folder used in Plan 1's dry-run is suitable, though Plan 1's review.md from that dry-run only exists if the user manually ran the orchestration; if not, run `/paper:study` first on a small paper.)

2. Invoke: `/paper:review-round`

3. Verify the orchestrator prompts for objections. Provide 2-3 specific objections, e.g.:
   - "The compute comparison with prior work doesn't account for hyperparameter tuning."
   - "Missing reproducibility info: no random seed reported."
   - "Claim 1 in the abstract is overstated relative to the experiments in §4."

4. Walk through the 5 stages. Observe:
   - defense-agent produces a multi-paragraph defense citing paper sections.
   - judge-agent verdict is one of `holds | partially_holds | fails` with 2-5 sentence reasoning.
   - User-facing prompt for confirmation shows objection / defense / verdict / reasoning clearly.
   - For `partially_holds` or `fails`, review.md gets a new bullet in the right section, ending with `← from round NN`.
   - Round file at `review-rounds/round-NN-<title>.md` contains all 12 frontmatter fields populated.

5. Run a second invocation of `/paper:review-round` with an objection that overlaps with a previous accepted one. Verify review-writer merges (combines wording, ends with `← from rounds N1, N2`) instead of duplicating.

6. Run a third invocation with an objection that ends in `holds`. Verify the round file is created (with `final_review_snippet` empty) but `review.md` is byte-identical to before.

If any step diverges from expected behavior, file as a follow-up issue against Plan 2 — not a blocker for declaring Plan 2 complete since the static contract tests pass.
