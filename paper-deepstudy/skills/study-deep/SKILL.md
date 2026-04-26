---
name: study-deep
description: Use when the user wants to deep-study a paper (PDF or URL) for ML or computational biology. Produces analysis/, review.md, and Chinese xhs/wechat notes. Layers on top of claude-paper:study.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: study-deep workflow

Invoke with a PDF path or arXiv URL. Optional flags:
- `--yes`: skip Stage 0 confirmation prompt (auto-accept profile).
- `--force`: re-run all stages, backing up existing outputs.

---

## Stage 0: Bootstrap & Profile

### 0.1 Verify prerequisites

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/verify-prereqs.sh
```

If exit ≠ 0, abort with the script's error message.

### 0.2 Run claude-paper:study (baseline)

Invoke the claude-paper study skill on the input. After completion, the paper folder lives at `~/claude-papers/papers/<slug>/` containing at least `meta.json`, `summary.md`, `paper.pdf`, and `images/`. Resolve `<slug>` from `meta.json` produced by claude-paper.

If the paper folder does not exist after running claude-paper:study, abort with: "claude-paper:study did not produce expected outputs at ~/claude-papers/papers/<slug>/".

### 0.3 Compute paths

Set these environment-style variables (use them in subsequent dispatches):

- `PAPER_DIR=~/claude-papers/papers/<slug>`
- `META_JSON=$PAPER_DIR/meta.json`
- `PAPER_TEXT=$PAPER_DIR/summary.md` *(claude-paper:study writes the extracted text into summary.md or a similar file; confirm and use the actual extracted-text file)*
- `IMAGES_DIR=$PAPER_DIR/images`
- `ANALYSIS_DIR=$PAPER_DIR/analysis` (mkdir if absent)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

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

In **one message**, issue six parallel Agent tool calls. Each gets paper text + profile path + output path + template path. Two get domain packs (`method-analyst`, `experiment-critic`); one is encouraged to use them (`prior-work-historian`); three do not (`problem-framer`, `formalizer`, `figure-interpreter`).

For each sub-Agent:

```
Agent(
  description: "<role short name>",
  subagent_type: "general-purpose",
  prompt: <contents of prompts/<role>.md> + concrete inputs.
)
```

Concrete dispatch table:

| Sub-Agent | OUTPUT_PATH | TEMPLATE_PATH | Extra inputs |
|---|---|---|---|
| problem-framer | `$ANALYSIS_DIR/01-problem.md` | `$PLUGIN_ROOT/templates/analysis/01-problem.md` | — |
| formalizer | `$ANALYSIS_DIR/02-formalization.md` | `$PLUGIN_ROOT/templates/analysis/02-formalization.md` | — |
| method-analyst | `$ANALYSIS_DIR/03-method-deep.md` | `$PLUGIN_ROOT/templates/analysis/03-method-deep.md` | DOMAIN_PACKS |
| experiment-critic | `$ANALYSIS_DIR/04-experiments.md` | `$PLUGIN_ROOT/templates/analysis/04-experiments.md` | DOMAIN_PACKS |
| prior-work-historian | `$ANALYSIS_DIR/05-prior-work.md` | `$PLUGIN_ROOT/templates/analysis/05-prior-work.md` | DOMAIN_PACKS, WEBFETCH allowed |
| figure-interpreter | `$ANALYSIS_DIR/06-figures.md` | `$PLUGIN_ROOT/templates/analysis/06-figures.md` | IMAGES_DIR |

### 1.3 Collect results

After all six return, verify each expected output file exists. For any that did not produce a file, write a placeholder:

```
echo '<!-- FAILED: <reason from sub-Agent error> -->' > $OUTPUT_PATH
```

Record failures in a `STAGE1_FAILURES` list for the final summary.

---

## Stage 2: Review generation

### 2.1 Dispatch reviewer-synthesizer

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

After Stage 3 completes, print a summary to chat:

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

If anything failed, retry that stage with /paper:rerun-<stage>.

Available refinements:
  /paper:review-round       — adversarial review
  /paper:refine-notes [xhs|wechat]
  /paper:deep-dive <topic>
  /paper:compare <other-paper>
  /paper:reselect-figures
  /paper:retitle [xhs|wechat]
  /paper:add-prior-work <ref>
  /paper:reproduce-check
  (These commands ship in Plans 2 and 3.)
```
