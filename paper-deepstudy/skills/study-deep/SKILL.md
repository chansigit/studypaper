---
name: study-deep
description: Use when the user wants to deep-study a paper (PDF or URL) for ML or computational biology. Produces analysis/, review.md, and Chinese xhs/wechat notes. Layers on top of claude-paper:study.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent, Skill
---

# paper-deepstudy: study-deep workflow

Invoke with a PDF path or arXiv URL. Optional flags:
- `--yes`: skip Stage 0 confirmation prompt (auto-accept profile).
- `--force`: re-run all stages, backing up existing outputs.

## Flag dispatch

This skill is invoked by `/paper:study <pdf-or-url> [flags]` and `/paper:rerun-stage <stage> [flags]`. The flags below control which stages run and how outputs are handled. The orchestrator MUST honor all four flags as specified.

### `--paper <slug>`

If set, skip Stage 0.2 (claude-paper:study invocation) and skip Stage 0.3 path resolution. Set `PAPER_DIR=~/claude-papers/papers/<slug>` directly. Verify `$PAPER_DIR/meta.json` exists; abort if not.

If `--paper` is **not** set, the orchestrator either runs Stage 0.2 (for `/paper:study`) or auto-detects the most recent paper folder via `ls -td ~/claude-papers/papers/*/ | head -1` (for `/paper:rerun-stage`).

### `--only <stage>` (used by `/paper:rerun-stage`)

`<stage>` is one of `profile | analysis | review | notes`. When set:

| `--only` value | Skip stages | Run stages |
|---|---|---|
| `profile` | Stage 1, 2, 3 | Stage 0 only (paper-profiler dispatch). The orchestrator backs up the existing `00-paper-profile.md` first. |
| `analysis` | Stage 0.4, 0.5, 2, 3 | Stage 1 only (six parallel analysis sub-Agents). Stage 0.1–0.3.1 still runs to set up paths. Existing analysis files 01–06 are backed up first. |
| `review` | Stage 0.4, 0.5, 1, 3 | Stage 2 only (reviewer-synthesizer). Existing `review.md` backed up. **Note:** this discards any edits made by `/paper:review-round`. The orchestrator MUST warn the user before proceeding. |
| `notes` | Stage 0.4, 0.5, 1, 2 | Stage 3 only (notes-writer + title-generator + xhs/wechat renderers). Existing `notes/*.md` backed up. **Note:** this also overwrites `notes/source.md`, so any manual content edits to `source.md` are lost — refer to `refine-notes` skill for the source-vs-rendering split workflow. |

`--only` implies `--force` scoped to that stage's outputs (existing files are backed up to `<file>.bak.NN` before re-running).

### `--yes`

Skip the Stage 0.5 user-confirmation prompt for the auto-detected profile. Use the profile as-is. Record `--yes auto-accepted` in the final summary.

### `--force`

For each output file in any stage that runs: if the file exists, back it up to `<file>.bak.NN` (smallest non-existent integer ≥ 1) before re-running its sub-Agent. Without `--force`, existing output files are skipped (per the per-dispatch idempotence rule below).

### Conflict handling

- `--only` and `--paper` are independent and may be combined.
- `--only` implies `--force` scoped to the named stage; explicit `--force` on top is redundant but harmless.
- `--yes` is independent of `--only` / `--paper` / `--force`.

---

## Stage 0: Bootstrap & Profile

### Idempotence and re-runs

Default behavior (no flags): for each output file, if it already exists, skip the corresponding sub-Agent dispatch. Skipped files are reported in the final summary.

`--force`: for each output file that exists, copy it to `<file>.bak.NN` (where NN is the smallest non-existent integer ≥ 1) before re-running.

`--yes`: skip the Stage 0 confirmation prompt. Use the auto-detected profile.

`--only <stage>` (used by `/paper:rerun-stage <stage>`): rerun only the named stage (`profile | analysis | review | notes`), backing up its outputs first. Implemented as `--force` scoped to that stage's output paths.

### Per-dispatch idempotence rule

This rule applies uniformly to every Agent dispatch in Stages 0.4, 1.2, 2.1, 3.1, 3.2, and 3.4 below. Before issuing each Agent call:

- If `OUTPUT_PATH` exists and `--force` is not set, log `skipping <subagent> (output exists)` and do not dispatch.
- If `OUTPUT_PATH` exists and `--force` is set, copy `OUTPUT_PATH` to `OUTPUT_PATH.bak.NN` (smallest non-existent integer ≥ 1) first, then dispatch.
- If `OUTPUT_PATH` does not exist, dispatch normally.

Skipped dispatches still count as ✓ in the final summary (the existing file is the output).

### 0.1 Verify prerequisites

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/verify-prereqs.sh
```

If exit ≠ 0, abort with the script's error message.

### 0.2 Run claude-paper:study (baseline)

Invoke `claude-paper:study` via the Skill tool with the user's input as args:

```
Skill(skill: "claude-paper:study", args: "<user-input-pdf-path-or-url>")
```

`claude-paper:study` will download / parse the PDF and produce a paper folder under `~/claude-papers/papers/<slug>/`. The slug is auto-derived from the paper title.

After the Skill returns, locate the new paper folder. The most reliable way is to take the most recently modified subdirectory:

```bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
```

Verify required outputs exist:
- `$PAPER_DIR/meta.json`
- `$PAPER_DIR/paper.pdf`
- `$PAPER_DIR/summary.md` (claude-paper's curated summary, not the full text — Stage 0.3.1 extracts the full text via pdftotext)
- `$PAPER_DIR/images/` (may be empty if pdftotext-style extraction fails; report and continue)

If any of these are missing, abort with: `"claude-paper:study did not produce expected outputs at $PAPER_DIR. Check the claude-paper plugin's installation and try /paper:study again."`

Read `$PAPER_DIR/meta.json` and confirm its `slug` field matches the basename of `$PAPER_DIR`. If they disagree, prefer the `meta.json` slug (and adjust `PAPER_DIR` accordingly).

### 0.3 Compute paths

Set these environment-style variables (use them in subsequent dispatches):

- `PAPER_DIR=~/claude-papers/papers/<slug>`
- `META_JSON=$PAPER_DIR/meta.json`
- `PAPER_PDF=$PAPER_DIR/paper.pdf`
- `PAPER_TEXT=$PAPER_DIR/paper.txt` (extracted from `paper.pdf` — see Stage 0.3.1 below)
- `IMAGES_DIR=$PAPER_DIR/images`
- `ANALYSIS_DIR=$PAPER_DIR/analysis` (mkdir if absent)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

### 0.3.1 Extract full paper text

`claude-paper:study` does not persist the extracted full text to disk; only `paper.pdf` is reliably available. We need full text for Stage 1 sub-Agents.

If `$PAPER_TEXT` (i.e. `$PAPER_DIR/paper.txt`) does not already exist, run:

```bash
pdftotext -layout "$PAPER_PDF" "$PAPER_TEXT"
```

If `pdftotext` is not installed or the conversion fails:
- Fallback A: use `python3 -c "from pypdf import PdfReader; ..."` if `pypdf` is available (`claude-paper:study` requires `pymupdf` so `pypdf` may be installed too).
- Fallback B: pass `$PAPER_PDF` directly as `PAPER_TEXT` to sub-Agents — Claude Code's Read tool can read PDFs natively, so sub-Agents can read it. In this fallback, set `PAPER_TEXT=$PAPER_PDF`.

Record which path was used in the final summary (so users know to install `pdftotext` if they got the fallback path).

### 0.4 Dispatch paper-profiler

Read `prompts/paper-profiler.md`. Dispatch via the Agent tool:

```
Agent(
  description: "paper-profiler classifies the paper",
  subagent_type: "general-purpose",
  prompt: <contents of paper-profiler.md> + concrete inputs:
    META_JSON=$META_JSON
    PAPER_TEXT=$PAPER_TEXT
    OUTPUT_PATH=$ANALYSIS_DIR/00-paper-profile.md
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/analysis/00-paper-profile.md
    AVAILABLE_PACKS=ml-pure,single-cell  (list every file in $PLUGIN_ROOT/domain-packs/, excluding _template.md)
)
```

Wait for completion. Read `$ANALYSIS_DIR/00-paper-profile.md` and parse its YAML frontmatter.

### 0.5 Confirm with user

**Chat-facing prose:** Always reply to the user in the user's invocation language. The English/Chinese language matrix applies only to written artifacts (`analysis/`, `review.md`, `notes/`). The example block below stays English-shaped to show structure; translate the labels and prompt into the user's language at runtime.

If `--yes` flag is NOT set:

Show the user:

```
Paper profile detected:
  type: <paper_type>
  domain: <domain>
  bio_subfield: <bio_subfield>
  difficulty: <difficulty>
  domain_packs_selected: [<list>]

Confirm or correct (e.g. "switch domain_packs_selected to single-cell only")?
```

Wait for user response. If user says yes / confirm, proceed. If user requests changes, edit the frontmatter of `00-paper-profile.md` accordingly using the Edit tool, then proceed.

If `--yes` is set, skip this step and record in the final summary that auto-accept was used.

---

## Stage 1: Deep analysis (parallel)

### 1.1 Resolve domain pack paths

Take `domain_packs_selected` from the profile. For each, build path: `$PLUGIN_ROOT/domain-packs/<slug>.md`. Keep this list as `DOMAIN_PACKS`.

### 1.2 Dispatch six sub-Agents in parallel

**Skipped if `--only` is set and this stage is not the named stage.** See `## Flag dispatch` for full routing.

In **one message**, issue six parallel Agent tool calls. The dispatch table below is authoritative for what each sub-Agent receives. All six get `PAPER_TEXT`, `OUTPUT_PATH`, and `TEMPLATE_PATH`. Most also receive `PROFILE_PATH` (`figure-interpreter` does not — it works directly from `PAPER_TEXT` + `IMAGES_DIR`). Extras vary: `method-analyst` and `experiment-critic` get `DOMAIN_PACKS`; `prior-work-historian` gets `DOMAIN_PACKS` and is allowed up to 5 WebFetch calls; `figure-interpreter` gets `IMAGES_DIR`.

For each sub-Agent:

```
Agent(
  description: "<role short name>",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/<role>.md> + concrete inputs.
)
```

Concrete dispatch table:

| Sub-Agent | Inputs | OUTPUT_PATH | TEMPLATE_PATH |
|---|---|---|---|
| problem-framer | PAPER_TEXT, PROFILE_PATH | `$ANALYSIS_DIR/01-problem.md` | `$PLUGIN_ROOT/templates/analysis/01-problem.md` |
| formalizer | PAPER_TEXT, PROFILE_PATH | `$ANALYSIS_DIR/02-formalization.md` | `$PLUGIN_ROOT/templates/analysis/02-formalization.md` |
| method-analyst | PAPER_TEXT, PROFILE_PATH, DOMAIN_PACKS | `$ANALYSIS_DIR/03-method-deep.md` | `$PLUGIN_ROOT/templates/analysis/03-method-deep.md` |
| experiment-critic | PAPER_TEXT, PROFILE_PATH, DOMAIN_PACKS | `$ANALYSIS_DIR/04-experiments.md` | `$PLUGIN_ROOT/templates/analysis/04-experiments.md` |
| prior-work-historian | PAPER_TEXT, PROFILE_PATH, DOMAIN_PACKS (WebFetch allowed, cap 5) | `$ANALYSIS_DIR/05-prior-work.md` | `$PLUGIN_ROOT/templates/analysis/05-prior-work.md` |
| figure-interpreter | PAPER_TEXT, IMAGES_DIR | `$ANALYSIS_DIR/06-figures.md` | `$PLUGIN_ROOT/templates/analysis/06-figures.md` |

### 1.3 Collect results

After all six return, verify each expected output file exists. For any that did not produce a file, write a placeholder:

```
echo '<!-- FAILED: <reason from sub-Agent error> -->' > $OUTPUT_PATH
```

Record failures in a `STAGE1_FAILURES` list for the final summary.

---

## Stage 2: Review generation

### 2.1 Dispatch reviewer-synthesizer

**Skipped if `--only` is set and this stage is not the named stage.** See `## Flag dispatch` for full routing.

```
Agent(
  description: "reviewer-synthesizer drafts review.md v1",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/reviewer-synthesizer.md> + inputs:
    ANALYSIS_DIR=$ANALYSIS_DIR
    DOMAIN_PACKS=<list>
    OUTPUT_PATH=$PAPER_DIR/review.md
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/review.md
)
```

Wait for completion.

### 2.2 Verify

If `$PAPER_DIR/review.md` does not exist, write `<!-- FAILED: reviewer-synthesizer did not produce output -->` and record failure in `STAGE2_FAILURES`. Otherwise, proceed.

## Stage 3: Notes generation

Stage 3 has two sequential sub-stages then two parallel renderers.

### 3.1 Dispatch notes-writer (sequential, must finish first)

**Skipped if `--only` is set and this stage is not the named stage.** See `## Flag dispatch` for full routing.

```
Agent(
  description: "notes-writer drafts source.md",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/notes-writer.md> + inputs:
    ANALYSIS_DIR=$ANALYSIS_DIR
    OUTPUT_PATH=$PAPER_DIR/notes/source.md
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/source.md
)
```

Create `$PAPER_DIR/notes/` first if absent.

### 3.2 Dispatch title-generator

**Skipped if `--only` is set and this stage is not the named stage.** See `## Flag dispatch` for full routing.

```
Agent(
  description: "title-generator generates xhs and wechat titles",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/title-generator.md> + inputs:
    SOURCE_PATH=$PAPER_DIR/notes/source.md
    OUTPUT_PATH=$PAPER_DIR/notes/titles.md
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/titles.md
)
```

### 3.3 Pick figures

Run:

```bash
node $PLUGIN_ROOT/scripts/select-figures.cjs $ANALYSIS_DIR/06-figures.md 1
node $PLUGIN_ROOT/scripts/select-figures.cjs $ANALYSIS_DIR/06-figures.md 3
```

Capture each as JSON; transform to absolute paths under `$IMAGES_DIR`. Set:
- `XHS_FIGURES`: 1 path
- `WECHAT_FIGURES`: up to 3 paths

If `06-figures.md` is the FAILED placeholder, set both lists empty and record a failure note for the final summary.

### 3.4 Dispatch xhs-renderer + wechat-renderer in parallel

**Skipped if `--only` is set and this stage is not the named stage.** See `## Flag dispatch` for full routing.

Issue both Agent calls in one message:

```
Agent(  // xhs
  description: "xhs-renderer renders xhs.md",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/xhs-renderer.md> + inputs:
    SOURCE_PATH=$PAPER_DIR/notes/source.md
    TITLES_PATH=$PAPER_DIR/notes/titles.md
    OUTPUT_PATH=$PAPER_DIR/notes/xhs.md
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/xhs.md
    SELECTED_FIGURES=<XHS_FIGURES>
)

Agent(  // wechat
  description: "wechat-renderer renders wechat.md",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/wechat-renderer.md> + inputs:
    SOURCE_PATH=$PAPER_DIR/notes/source.md
    TITLES_PATH=$PAPER_DIR/notes/titles.md
    OUTPUT_PATH=$PAPER_DIR/notes/wechat.md
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/wechat.md
    SELECTED_FIGURES=<WECHAT_FIGURES>
)
```

### 3.5 Verify outputs

Each of `notes/{source,titles,xhs,wechat}.md` must exist. Missing ones get `<!-- FAILED: ... -->` placeholders and are recorded in `STAGE3_FAILURES`.

---

## Final summary

After Stage 3 completes, print a summary to chat. The structure (sections, file list, refinement command list) stays as below, but the headings and prose should be translated into the user's invocation language; only the file paths and command names stay verbatim.

```
✓ paper-deepstudy complete for <slug>

Profile: <paper_type> / <domain> / <difficulty>
Domain packs: <list>
Confirmation: <user_confirmed | --yes auto-accepted>

Outputs (under $PAPER_DIR):
  analysis/00-paper-profile.md ✓
  analysis/01-problem.md       <✓ or FAILED>
  analysis/02-formalization.md <✓ or FAILED>
  analysis/03-method-deep.md   <✓ or FAILED>
  analysis/04-experiments.md   <✓ or FAILED>
  analysis/05-prior-work.md    <✓ or FAILED>
  analysis/06-figures.md       <✓ or FAILED>
  review.md                     <✓ or FAILED>
  notes/source.md              <✓ or FAILED>
  notes/titles.md              <✓ or FAILED>
  notes/xhs.md                 <✓ or FAILED>
  notes/wechat.md              <✓ or FAILED>

If anything failed, retry that stage with /paper:rerun-stage <stage>.

Available refinements:
  /paper:review-round       — adversarial review
  /paper:refine-notes [xhs|wechat]
  /paper:deep-dive <topic>
  /paper:compare <other-paper>
  /paper:reselect-figures
  /paper:retitle [xhs|wechat]
  /paper:add-prior-work <ref>
  /paper:reproduce-check
  (These commands ship in: Plan 2 ✓ for /paper:review-round; Plan 3a ✓ for /paper:refine-notes, /paper:retitle, /paper:reselect-figures; Plan 3b for /paper:deep-dive, /paper:compare, /paper:add-prior-work; Plan 3c for /paper:reproduce-check.)
```
