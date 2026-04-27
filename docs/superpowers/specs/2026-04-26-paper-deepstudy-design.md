# paper-deepstudy: Design Spec

**Date:** 2026-04-26
**Status:** Draft, pending user approval
**Target users:** ML / computational-biology paper readers who want depth beyond what `claude-paper:study` produces.

---

## 1. Purpose & Scope

### 1.1 What this skill does

A Claude Code plugin that turns a paper (PDF or URL) into a multi-layered study artifact set:

1. **Deep analysis** (English) — six structured deliverables covering problem framing, formal definition, methodology, experiments, prior-work timeline, and figure interpretation.
2. **Review report** (English) — a critical review using a hybrid ML + computational-biology reviewer standard, producible iteratively through an adversarial review loop.
3. **Social-media learning notes** (Chinese) — one unified source plus two platform-specific renderings (Xiaohongshu ~1k chars, WeChat ~3k chars), generated from the same content origin.

### 1.2 Why a new plugin (not a fork of `claude-paper:study`)

The existing `claude-paper:study` covers basic summarization, mental models, and runnable demos. The user's needs go beyond:

- Formal problem definition not in current outputs.
- Prior-work timeline / lineage missing.
- Method analysis lacks design rationale and counterfactuals.
- Experiments are not critiqued.
- No domain awareness for computational biology.
- No reader-perspective outputs (reviewer / social-media learner).

A separate plugin avoids modifying third-party code and preserves upgrade safety. We *depend on* `claude-paper:study` to produce baseline artifacts (PDF parse → `meta.json`, `summary.md`, `images/`), then layer our outputs on top of the same paper folder.

### 1.3 Out of scope (YAGNI)

- Generic export-to-clipboard / publish-to-platform helpers.
- Standalone bio-rigor command (subsumed by reviewer's hybrid standard).
- Re-implementing PDF parsing or image extraction.
- Auto-translation between languages (each artifact has a fixed language; switching is deliberate).
- Bibliography management.
- Interactive web UI (separate concern).

---

## 2. Plugin Identity & Layout

### 2.1 Plugin

- **Name:** `paper-deepstudy`
- **Type:** Claude Code plugin (`.claude-plugin/plugin.json`)
- **Dependencies:** `claude-paper:study` (called as a sub-process for baseline artifacts)

### 2.2 Plugin source tree (proposed)

```
paper-deepstudy/
├── .claude-plugin/plugin.json
├── PLUGIN.json
├── README.md
├── package.json                     # if any node deps for orchestration
├── commands/
│   ├── study.md                     # /paper:study
│   ├── review-round.md              # /paper:review-round
│   ├── refine-notes.md              # /paper:refine-notes
│   ├── deep-dive.md                 # /paper:deep-dive
│   ├── compare.md                   # /paper:compare
│   ├── reselect-figures.md          # /paper:reselect-figures
│   ├── retitle.md                   # /paper:retitle
│   ├── add-prior-work.md            # /paper:add-prior-work
│   ├── reproduce-check.md           # /paper:reproduce-check
│   └── rerun-stage.md               # /paper:rerun-<stage>
├── skills/
│   ├── study-deep/SKILL.md          # main auto-run pipeline
│   ├── review-round/SKILL.md
│   ├── refine-notes/SKILL.md
│   ├── deep-dive/SKILL.md
│   ├── compare/SKILL.md
│   ├── reselect-figures/SKILL.md
│   ├── retitle/SKILL.md
│   ├── add-prior-work/SKILL.md
│   └── reproduce-check/SKILL.md
├── prompts/                         # subagent prompt templates
│   ├── paper-profiler.md
│   ├── problem-framer.md
│   ├── formalizer.md
│   ├── method-analyst.md
│   ├── experiment-critic.md
│   ├── prior-work-historian.md
│   ├── figure-interpreter.md
│   ├── reviewer-synthesizer.md
│   ├── notes-writer.md
│   ├── title-generator.md
│   ├── xhs-renderer.md
│   ├── wechat-renderer.md
│   ├── defense-agent.md
│   ├── judge-agent.md
│   ├── review-writer.md
│   ├── deep-dive-agent.md
│   ├── compare-agent.md
│   └── reproduce-checker.md
├── domain-packs/
│   ├── ml-pure.md
│   ├── single-cell.md
│   ├── protein-structure.md
│   ├── protein-function.md
│   ├── genomics.md
│   ├── drug-discovery.md
│   ├── medical-imaging.md
│   └── _template.md
├── templates/                       # output skeletons
│   ├── analysis/
│   │   ├── 00-paper-profile.md
│   │   ├── 01-problem.md
│   │   ├── 02-formalization.md
│   │   ├── 03-method-deep.md
│   │   ├── 04-experiments.md
│   │   ├── 05-prior-work.md
│   │   └── 06-figures.md
│   ├── review.md
│   ├── review-round.md
│   ├── notes-source.md
│   ├── notes-titles.md
│   ├── notes-xhs.md
│   ├── notes-wechat.md
│   ├── deep-dive.md
│   ├── compare.md
│   └── reproduce-check.md
└── scripts/
    ├── orchestrate.cjs              # main pipeline orchestrator (optional)
    └── select-figures.cjs           # figure picker by interpreter score
```

### 2.3 Per-paper output layout (extends `claude-paper:study`'s convention)

```
~/claude-papers/papers/<slug>/
├── paper.pdf                        # from claude-paper:study
├── meta.json                        # from claude-paper:study
├── README.md                        # from claude-paper:study (kept)
├── summary.md                       # from claude-paper:study (kept)
├── insights.md                      # from claude-paper:study (kept)
├── method.md                        # from claude-paper:study (kept)
├── qa.md                            # from claude-paper:study (kept)
├── mental-model.md                  # from claude-paper:study (kept)
├── reflection.md                    # from claude-paper:study (kept, optional)
├── code/                            # from claude-paper:study
├── images/                          # from claude-paper:study
│
├── analysis/                        # NEW (English)
│   ├── 00-paper-profile.md
│   ├── 01-problem.md
│   ├── 02-formalization.md
│   ├── 03-method-deep.md
│   ├── 04-experiments.md
│   ├── 05-prior-work.md
│   └── 06-figures.md
│
├── review.md                        # NEW (English; incrementally updated)
├── review-rounds/                   # NEW (English)
│   └── round-NN-<slug>.md
│
├── notes/                           # NEW (Chinese)
│   ├── source.md
│   ├── titles.md
│   ├── xhs.md
│   └── wechat.md
│
├── deep-dives/                      # NEW (language follows user)
│   └── <topic-slug>.md
├── compares/                        # NEW (English by default)
│   └── vs-<other-slug>.md
└── reproduce-check.md               # NEW (English)
```

Backups: any file rewritten by a `refine-*` or `re*` operation is copied to `<file>.bak.NN` first, where `NN` is monotonically increasing per file.

---

## 3. Auto-run Pipeline (`/paper:study <pdf|url>`)

Four stages. Within a stage, subagents may run in parallel; stages run sequentially.

### Stage 0 — Bootstrap & Profile

1. **Bootstrap:** Invoke `claude-paper:study` on the input. After completion, ensure `meta.json`, `summary.md`, and `images/` exist under `~/claude-papers/papers/<slug>/`. If `claude-paper:study` is not installed, abort with a clear install hint.
2. **Profile pass:** Run `paper-profiler` subagent → `analysis/00-paper-profile.md`.

`paper-profiler` produces these fields (YAML frontmatter + prose):

```yaml
---
slug: <slug>
title: <title from meta>
paper_type: theory | architecture | empirical | system | survey | dataset
domain: ml-pure | ml-bio-hybrid | cs-bio | wet-lab-heavy
bio_subfield: single-cell | protein-structure | protein-function | genomics |
              drug-discovery | medical-imaging | none
difficulty: beginner | intermediate | advanced | highly-theoretical
domain_packs_selected: [ml-pure, single-cell]   # zero or more
key_baselines_detected: [scVI, Geneformer, ...]
claims_summary:
  - <claim 1, one sentence>
  - <claim 2>
  - ...
---
```

After Stage 0, the orchestrator presents the detected profile to the user and asks for confirmation or correction (the most likely correction is `domain_packs_selected`). The user's reply gates Stage 1. If the user accepts, Stage 1 starts immediately; if the user corrects fields, the profile file is updated, then Stage 1 starts. A `--yes` flag on `/paper:study` skips this confirmation and proceeds with the auto-detected profile, recording this fact in the final summary.

### Stage 1 — Deep Analysis (six subagents in parallel)

| Subagent | Output | Inputs |
|---|---|---|
| `problem-framer` | `analysis/01-problem.md` | paper full text + profile |
| `formalizer` | `analysis/02-formalization.md` | paper full text + profile |
| `method-analyst` | `analysis/03-method-deep.md` | paper full text + profile + selected domain packs |
| `experiment-critic` | `analysis/04-experiments.md` | paper full text + profile + selected domain packs |
| `prior-work-historian` | `analysis/05-prior-work.md` | paper full text + profile + selected domain packs (may use WebFetch for cited works) |
| `figure-interpreter` | `analysis/06-figures.md` | paper full text + `images/` listing + per-image caption |

Each subagent is dispatched via the Agent tool with `subagent_type: general-purpose`. Each receives the paths it needs (no large context preloading) and writes its output file directly. Each is independent — they do not read each other's outputs.

Failure of any one Stage 1 subagent does not block the others. A failure writes `<!-- FAILED: <reason> -->` to the expected output path. The orchestrator records failures and reports them at the end.

### Stage 2 — Review Generation

`reviewer-synthesizer` subagent reads the full `analysis/*.md` set + selected domain packs + the review template. Produces `review.md` v1 (English) with sections:

- **Summary** (1 paragraph, neutral)
- **Significance** (why this matters in field)
- **Strengths** (3–7 bullets)
- **Weaknesses**
  - *Methodological*
  - *Experimental*
  - *Bio-rigor* (only when `domain_packs_selected` includes a bio pack)
- **Questions to Authors**
- **Suggestions**
- **Score** (1–10)
- **Confidence** (1–5)

`reviewer-synthesizer` does **not** re-read the paper. If a needed fact is missing from `analysis/*.md`, this is treated as a Stage 1 gap and surfaced to the user (suggestion: rerun the relevant Stage 1 subagent).

### Stage 3 — Notes Generation

Three steps in order, with the last two parallel:

1. `notes-writer` subagent reads `analysis/*.md` + figure scores → produces `notes/source.md` (Chinese, transcribe perspective, math translated to plain language). Fixed structure:
   1. 一句话讲清楚这篇 paper 在干嘛
   2. 它要解决的问题是什么(背景 + 痛点)
   3. 现有方案为什么不够 / 为什么这个问题难
   4. 这篇的核心 idea
   5. 方法是怎么 work 的
   6. 实验结果(挑 1-2 个最能说明问题的指标 + 数字)
   7. 它和前人工作的关系
   8. 局限 / 没解决的问题
   9. 一句话总结 take-away
   Sections without enough material get `<!-- N/A: <reason> -->`.

2. `title-generator` reads `source.md` → produces `notes/titles.md` with two groups of 5 candidates (xhs / wechat). Each candidate annotated with style label (hook / literal / question / numbers / contrast).

3. `xhs-renderer` and `wechat-renderer` run in parallel, both reading `source.md` + `titles.md` + figure scores. Renderer rules:

| Field | xhs.md | wechat.md |
|---|---|---|
| Length | ~1000 chars (hard cap 1300) | ~3000 chars (hard cap 4000) |
| Paragraphs | short (1–3 sentences) | long allowed |
| Subheadings | required, short | required, may be longer |
| Formulas | translated to plain language | 1–2 key formulas allowed, each followed by plain-language explanation |
| Figures embedded | 1 (highest-scored: usually architecture or main result) | 2–3 (architecture / pipeline / key result) |
| References | none | up to 3 key references with links |
| Title | first candidate from titles.md (rest kept as alts in file footer comment) | same |
| CTA | none | none |
| Emoji | none | none |

### Final summary to user

After Stage 3, the orchestrator prints to chat:
- Paper profile (type / domain / difficulty / packs used).
- Output paths produced.
- Any subagent failures + how to retry (`/paper:rerun-<stage>`).
- The 8 available refinement commands as a hint.

### Idempotence & re-runs

Re-running `/paper:study` on an already-studied paper:
- **Default:** Skip stages whose outputs already exist (per-file granularity).
- `--force`: Backup existing outputs (`.bak.NN`) and rerun all stages.
- `/paper:rerun-<stage>` (where stage ∈ `profile | analysis | review | notes`): Backup + rerun a specific stage.

---

## 4. Adversarial Review Loop (`/paper:review-round`)

### 4.1 Flow

```
[1] User raises one or more objections.
[2] Orchestrator parses each, tagging:
    - dimension ∈ {method, experiment, claim, reproducibility, writing, bio-rigor}
    - severity  ∈ {major, minor}
    User may correct tags before proceeding.
[3] For each objection, dispatch defense-agent
    (sees: paper full text + analysis/*.md + objection)
    → returns defense text.
[4] For each (objection, defense) pair, dispatch judge-agent
    (sees ONLY: objection + defense — does NOT see paper, does NOT see analysis)
    → returns verdict ∈ {holds, partially_holds, fails} + reasoning.
[5] Present (objection, defense, verdict, reasoning) to user.
    User decision: confirm | override (with reason).
[6] Branch on final verdict:
    - holds          → record only; do not modify review.md
    - partially_holds → review-writer drafts a caveat/clarification entry,
                        appends to review.md "Questions to Authors" section
    - fails          → review-writer drafts a weakness entry,
                        appends to review.md "Weaknesses/<dimension>" section
[7] Persist round-NN-<slug>.md.
```

By default, multiple objections in a single invocation run in parallel. `--sequential` flag forces serial.

### 4.2 round-NN-\<slug\>.md schema

```yaml
---
round: NN
created_at: <iso8601>
objection: |
  <verbatim user text>
dimension: method | experiment | claim | reproducibility | writing | bio-rigor
severity: major | minor
defense: |
  <defense agent output>
judge_verdict: holds | partially_holds | fails
judge_reasoning: |
  <judge agent output>
user_decision: confirm | override
user_reasoning: |
  <user text if override>
final_verdict: holds | partially_holds | fails
final_review_snippet: |
  <text appended to review.md, or empty if dismissed>
---

# Round NN — <objection short title>

(Free-form notes section if needed)
```

### 4.3 Why judge-agent is blind to the paper

The judge evaluates the **logical strength of the defense as written**, not the underlying truth. If the defense omits a key piece of evidence that exists in the paper, judge ruling `fails` is correct — it surfaces a real writing problem (the paper did not communicate that evidence well enough). The author/defender's job is to argue from the paper; if the argument is weak, the review reflects that.

### 4.4 Incremental updates to review.md

`review-writer` always reads the current `review.md` before writing. Tasks:
- Append new entries under the correct section.
- Each entry tagged with `← from round NN` for traceability.
- Detect and merge near-duplicates with existing entries (combine, do not append).
- Never rewrite or remove an entry that is not from the same round being processed.

---

## 5. Notes Refinement Loop (`/paper:refine-notes [xhs|wechat]`)

### 5.1 Interaction model

```
User: /paper:refine-notes xhs
Orchestrator: [shows current notes/xhs.md]
              Suggested edit categories:
              - rewrite a paragraph (specify which)
              - regenerate title
              - re-translate formula(s)
              - shorten / expand
              - swap embedded figure
              - other (free-form)
User: <free-form instruction>
Orchestrator: dispatches xhs-renderer (or wechat-renderer) with edit context;
              shows diff; asks "OK or refine again?"
Loop until user signals done.
```

### 5.2 source.md vs renderer separation

Refining `xhs.md` or `wechat.md` does **not** modify `source.md`. The renderer is downstream of source.

If the orchestrator detects that user's instruction is content-level (introducing a fact not in source, correcting a misunderstanding), it asks: "This sounds like a change to the underlying notes content. Update `source.md` and re-render both platforms?" User confirms before any change to source.

### 5.3 Backups

Each refine cycle that mutates `xhs.md` / `wechat.md` first writes `.bak.NN` (per-file monotonic).

---

## 6. Other Commands

### 6.1 `/paper:deep-dive <topic>`
- Dispatch `deep-dive-agent` with paper full text + relevant `analysis/*.md` + topic.
- Output: `deep-dives/<topic-slug>.md`. Sections: what topic is / how paper handles it / math or algorithm detail / how others have approached / takeaway.
- Topic slug derived from topic; collisions resolved by `-2`, `-3`, …

### 6.2 `/paper:compare <other-paper>`
- `<other-paper>` accepts: `~/claude-papers/papers/<slug>` path, PDF path, or URL.
- If the other paper has not been studied yet, run `/paper:study` on it first (auto, no prompt).
- Dispatch `compare-agent` with both papers' analysis sets.
- Output: `compares/vs-<other-slug>.md`. Sections: problem / formalization / method / experiments / strengths / when-to-use-which.
- Default language: English. `--lang zh` switches to Chinese.

### 6.3 `/paper:reselect-figures`
- Show all images from `images/` with `figure-interpreter` importance scores and captions.
- User multi-selects per platform (xhs needs 1, wechat needs 2–3).
- Re-render `xhs.md` / `wechat.md` with new figure choices (renderer only, no `figure-interpreter` re-run).
- Flag `--reinterpret` re-runs `figure-interpreter` first.

### 6.4 `/paper:retitle [xhs|wechat]`
- Dispatch `title-generator` with optional `--style` filter; produces 5 fresh candidates.
- User selects one; rewrite target file's title; previous title moved to `titles.md` history section.

### 6.5 `/paper:add-prior-work <ref>`
- `<ref>` accepts: BibTeX, arXiv URL, or "author + year + one-line description".
- Dispatch `prior-work-historian` to fetch info (WebFetch if URL), place it in timeline, update comparison table.
- After update, the orchestrator checks whether existing `review.md` weaknesses about prior-work coverage are now affected; if yes, suggests `/paper:review-round` to revisit.

### 6.6 `/paper:reproduce-check`
- Dispatch `reproduce-checker`. Dimensions: data availability, code availability, hyperparameters, seeds, hardware, evaluation scripts, wet-lab protocol (if applicable).
- Output: `reproduce-check.md`. Each dimension: ✓ / ✗ / partial + evidence (page or link).
- If serious issues found, suggest `/paper:review-round` to add reproducibility weaknesses to review.

### 6.7 Common conventions

- All commands check `~/claude-papers/papers/<slug>/` exists; if not, prompt `/paper:study` first.
- All commands dispatch subagents for the heavy work; orchestrator handles I/O and user dialog.
- All commands are idempotent; rerunning overwrites with `.bak.NN` backup of the prior version.

---

## 7. Domain Awareness

### 7.1 Static domain packs

Plain-text knowledge files in `domain-packs/`. Each pack covers:
- Core problems in the subfield.
- Key baselines (1-line description each).
- Common datasets / benchmarks (with task definition and rough scale).
- Standard evaluation metrics with caveats.
- Reviewer checklist for the subfield (the questions a domain reviewer would ask).

Initial packs: `ml-pure`, `single-cell`, `protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`. Adding a new pack means dropping a markdown file conforming to `_template.md`.

### 7.2 Selection at runtime

`paper-profiler` selects zero or more packs into `domain_packs_selected`. Selection signals:
- `meta.json` keywords / venue.
- Abstract keyword matches against pack-level signal phrases.
- Citations to known baselines from packs.

Multiple packs can be active simultaneously (e.g. `single-cell` + `ml-pure`). User confirms or overrides after Stage 0.

### 7.3 Injection downstream

Selected packs are injected into prompts for:
- `method-analyst` (for design-choice critique).
- `experiment-critic` (for benchmarks / metrics judgment).
- `prior-work-historian` (for canonical baselines and lineage).
- `reviewer-synthesizer` (for the bio-rigor weakness section).

If no pack matches → fallback to `ml-pure` only; reviewer skips bio-rigor section.

---

## 8. Language Strategy

| Artifact | Language | Rationale |
|---|---|---|
| `analysis/*.md` | English | Academic alignment; consumed by reviewer downstream |
| `review.md`, `review-rounds/*.md` | English | Reviewer convention; defense / judge in same language |
| `notes/source.md` | Chinese | Source for two Chinese renderings — no double translation |
| `notes/xhs.md`, `notes/wechat.md`, `notes/titles.md` | Chinese | Platform-native |
| `deep-dives/*.md` | Follows user's invocation language | Flexible by intent |
| `compares/*.md` | English (default), `--lang zh` for Chinese | Multi-paper comparisons typically span English literature |
| `reproduce-check.md` | English | Cross-references review |

The orchestrator's chat replies always follow the user's language, regardless of the artifact being modified.

---

## 9. Subagent Roster

| Subagent | Triggered by | Reads | Writes | Notes |
|---|---|---|---|---|
| paper-profiler | Stage 0 | meta.json + paper text | `analysis/00-paper-profile.md` | Independent |
| problem-framer | Stage 1 | paper text + profile | `analysis/01-problem.md` | Independent |
| formalizer | Stage 1 | paper text + profile | `analysis/02-formalization.md` | Independent |
| method-analyst | Stage 1 | paper text + profile + packs | `analysis/03-method-deep.md` | Independent |
| experiment-critic | Stage 1 | paper text + profile + packs | `analysis/04-experiments.md` | Independent |
| prior-work-historian | Stage 1 / `/paper:add-prior-work` | paper text + profile + packs (+ WebFetch) | `analysis/05-prior-work.md` | Independent |
| figure-interpreter | Stage 1 / `/paper:reselect-figures --reinterpret` | paper text + image listing + captions | `analysis/06-figures.md` (with importance scores) | Independent |
| reviewer-synthesizer | Stage 2 | all `analysis/*.md` + packs + template | `review.md` v1 | Does NOT read paper text |
| notes-writer | Stage 3 | all `analysis/*.md` + figure scores | `notes/source.md` | Does NOT read paper text |
| title-generator | Stage 3 / `/paper:retitle` | `notes/source.md` | `notes/titles.md` | |
| xhs-renderer | Stage 3 / `/paper:refine-notes xhs` | `source.md` + `titles.md` + selected figures | `notes/xhs.md` | |
| wechat-renderer | Stage 3 / `/paper:refine-notes wechat` | same | `notes/wechat.md` | |
| defense-agent | `/paper:review-round` | paper text + analysis + objection | defense prose (returned to orchestrator) | Argues as author |
| judge-agent | `/paper:review-round` | objection + defense ONLY | verdict + reasoning | Strictly blind to paper |
| review-writer | `/paper:review-round` | objection + defense + verdict + current `review.md` | appended entries to `review.md` | Dedupes / merges with existing entries |
| deep-dive-agent | `/paper:deep-dive` | paper text + topic + relevant analysis | `deep-dives/<topic>.md` | Independent |
| compare-agent | `/paper:compare` | both papers' analysis sets | `compares/vs-<other>.md` | Independent |
| reproduce-checker | `/paper:reproduce-check` | paper text + analysis + WebFetch (GitHub) | `reproduce-check.md` | Independent |

All subagents are dispatched via the Agent tool with `subagent_type: general-purpose`. The plugin does not register custom agent types.

---

## 10. Failure Handling

- **claude-paper:study not installed:** Stage 0 aborts with installation hint.
- **PDF parse failure:** Stage 0 aborts; user retries with a different PDF or path.
- **Single Stage 1 subagent failure:** Write `<!-- FAILED: <reason> -->` placeholder; continue other subagents; report at end; user can rerun via `/paper:rerun-analysis --only <name>`.
- **Stage 2 / 3 input gap (analysis incomplete):** Synthesizer notes the gap inline and continues with what's available. Final summary tells the user to backfill the gap.
- **WebFetch rate-limit / failure (prior-work-historian, reproduce-checker):** degrade gracefully with a `<!-- could not fetch <ref>: <reason> -->` note.
- **User Ctrl-C mid-pipeline:** Whatever has been written to disk is preserved. User can resume by re-running `/paper:study` (skips completed files).

**Known soft-failure — WebFetch budgets are advisory, not enforced.** Each prompt that allows WebFetch declares a numeric cap (e.g. "≤6 fetches" in `reproduce-checker`), but enforcement is by sub-Agent self-discipline. A sub-Agent that ignores the cap will not be stopped by the orchestrator. Spec §11 tracks central-budget enforcement as a future polish.

---

## 11. Open Questions for Implementation Plan

These do not block design approval but the implementation plan should resolve them:

1. Slug derivation for `<other-paper>` in `compare`: reuse `claude-paper:study`'s slug logic, or compute independently?
2. WebFetch usage budget: a hard cap per paper to avoid runaway?
3. Backup retention: keep all `.bak.NN` forever, or rotate after N?
4. Should `paper-profiler`'s prompt to user (confirm domain packs) be auto-skip if invoked non-interactively (e.g. inside a script)?
5. Schema versioning for the YAML frontmatter blocks (in case fields evolve).

---

## 12. Acceptance Criteria

The skill is considered complete when:

1. `/paper:study <pdf|url>` end-to-end produces 12 auto-run artifacts — 7 analysis files (`00`–`06`), `review.md` v1, and 4 notes files (`source.md`, `titles.md`, `xhs.md`, `wechat.md`) — for at least one pure-ML paper and one comp-bio paper.
2. `/paper:review-round` produces a `round-NN-<slug>.md` with all schema fields populated and updates `review.md` correctly for each of the three verdict branches (holds / partially_holds / fails) at least once.
3. `/paper:refine-notes xhs` and `/paper:refine-notes wechat` each round-trip a user instruction into an updated rendering with a `.bak.NN` of the prior version, without touching `source.md`.
4. The remaining commands (`deep-dive`, `compare`, `reselect-figures`, `retitle`, `add-prior-work`, `reproduce-check`) each produce their declared output file and respect the `~/claude-papers/papers/<slug>/` precondition.
5. At least 2 domain packs (`single-cell`, `protein-structure`) are populated and exercised end-to-end against representative papers.
6. All chat-facing replies follow user's invocation language; all artifacts follow their declared language matrix (Section 8).
7. Subagent failures degrade gracefully per Section 10 (placeholder written, pipeline continues, end-of-run summary lists failures).
