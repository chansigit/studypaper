---
name: study-deep
description: Use when the user wants to deep-study a paper (PDF or URL) for ML or computational biology. Produces analysis/, review.md, and Chinese xhs/wechat notes. Layers on top of claude-paper:study.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent, Skill
---

# paperstudio: study-deep workflow

## Hard rules (non-negotiable, enforced by tests)

These apply to **every** Agent dispatch in this skill. Stage-local exceptions must be stated inline with a one-line "why".

1. **Provenance** — every output line 1: `<!-- generated: <ts> by <agent> (paperstudio v<ver>) -->`
2. **Idempotence** — `OUTPUT_PATH` exists + no `--force` ⇒ skip; exists + `--force` ⇒ `cp $f $f.bak.NN` first, then dispatch.
3. **Log** — after every dispatch (success or fail), call `log_dispatch <subagent> <output-path> <ok|failed>`. Never on a skip.
4. **Paths** — paper root is `${PAPERS_ROOT}`, resolved once from `${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}`. Never hard-code `~/claude-papers/papers/` in writes.
5. **Failure** — Agent failure: log `failed`, do NOT delete partial output, do NOT auto-retry, surface the actionable rerun command, continue independent stages.
6. **Chat language** — reply in the user's invocation language. Artifact language is governed by `--lang` (Rule 4 of `_shared/dispatch-rules.md`).

Full text + rationale: see [`paperstudio/skills/_shared/dispatch-rules.md`](../_shared/dispatch-rules.md).

---

## Invocation

Invoke with a PDF path or arXiv URL. Optional flags:
- `--yes`: skip Stage 0 confirmation prompt (auto-accept profile).
- `--force`: re-run all stages, backing up existing outputs.
- `--lang en`: render Stage 3 outputs (`notes/source.md`, `notes/titles.md`, `notes/xhs.md`, `notes/wechat.md`) in English. Default is 中文.

## Paper root

Outputs land under a configurable paper root, defaulting to `~/claude-papers/papers/`. Override by exporting `CLAUDE_PAPERS_ROOT=/some/other/dir` in the user's shell environment (or `.envrc` etc.). This skill resolves the root once at start:

```bash
PAPERS_ROOT="${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}"
mkdir -p "$PAPERS_ROOT"
```

All subsequent path expressions in this document use `${PAPERS_ROOT}` to mean that root. The shorthand `~/claude-papers/papers/` shown in user-facing messages is the default-case display string — when `CLAUDE_PAPERS_ROOT` is set, substitute the override in any path you print or write.

## Flag dispatch

This skill is invoked by `/paperstudio:study <pdf-or-url> [flags]` and `/paperstudio:rerun-stage <stage> [flags]`. The flags below control which stages run and how outputs are handled. The orchestrator MUST honor all four flags as specified.

### `--paper <slug>`

If set, skip Stage 0.2 (claude-paper:study invocation) and skip Stage 0.3 path resolution. Set `PAPER_DIR=${PAPERS_ROOT}/<slug>` directly. Verify `$PAPER_DIR/meta.json` exists; abort if not.

If `--paper` is **not** set, the orchestrator either runs Stage 0.2 (for `/paperstudio:study`) or auto-detects the most recent paper folder via `ls -td ${PAPERS_ROOT}/*/ | head -1` (for `/paperstudio:rerun-stage`).

### `--only <stage>` (used by `/paperstudio:rerun-stage`)

`<stage>` is one of `profile | analysis | review | notes`. When set:

| `--only` value | Skip stages | Run stages |
|---|---|---|
| `profile` | Stage 1, 2, 3 | Stage 0 only (paper-profiler dispatch). The orchestrator backs up the existing `00-paper-profile.md` first. |
| `analysis` | Stage 0.4, 0.5, 2, 3 | Stage 1 only (six parallel analysis sub-Agents). Stage 0.1–0.3.1 still runs to set up paths. Existing analysis files 01–06 are backed up first. |
| `review` | Stage 0.4, 0.5, 1, 3 | Stage 2 only (reviewer-synthesizer). Existing `review.md` backed up. **Note:** this discards any edits made by `/paperstudio:review-round`. The orchestrator MUST warn the user before proceeding. |
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

See **Hard rules §2 + Rule 2** in `_shared/dispatch-rules.md`. Stage-specific note: `--yes` is study-deep–only and only affects Stage 0.5's user-confirmation prompt — it is independent of `--force` / `--only`.

### 0.1 Verify prerequisites

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/verify-prereqs.sh
```

If exit ≠ 0, abort with the script's error message.

### 0.2 Resolve user input → PDF URL or path

Before dispatching `claude-paper:study`, resolve the user's argument into a downloadable PDF URL or a local path. Three input shapes are supported:

1. **Local path** (starts with `/`, `~`, or `./`): pass through unchanged.
2. **URL** (starts with `http://` or `https://`): run it through the URL normalizer to convert known paper-host pages into direct PDF URLs (bioRxiv / medRxiv / OpenReview / ACL Anthology / HuggingFace papers / arXiv abs). Unknown hosts pass through unchanged.
3. **Free-text title / query** (anything else): run an arXiv title search and ask the user to pick a result.

```bash
RAW="<user-input>"

if [[ "$RAW" =~ ^(/|~|\./) ]]; then
  RESOLVED="$RAW"   # local path
elif [[ "$RAW" =~ ^https?:// ]]; then
  RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/normalize-paper-url.sh" "$RAW")
  if [[ "$RESOLVED" != "$RAW" ]]; then
    echo "Normalized URL: $RAW → $RESOLVED"
  fi
else
  # Title search via arXiv
  echo "No URL or path detected — searching arXiv for: \"$RAW\""
  results=$("${CLAUDE_PLUGIN_ROOT}/scripts/search-arxiv.sh" "$RAW" 5) || {
    echo "No arXiv results, or arXiv API unreachable. Pass a PDF path / URL instead, or refine the query."
    exit 1
  }
  # Display results (TSV: id, year, authors, title, pdf_url) numbered 1..5.
  echo "Top arXiv results:"
  echo "$results" | awk -F'\t' '{ printf "  [%d] %s (%s) — %s\n      %s\n", NR, $4, $2, $3, $5 }'

  if [[ "$YES_FLAG" == "1" ]]; then
    pick=1
    echo "(--yes set; auto-picking [1].)"
  else
    # Prompt the user for a number 1..5 (or 'cancel'). The orchestrator does
    # this via chat — do NOT block on `read` from stdin; ask in chat and wait
    # for the user's reply. The user may also paste a different URL or path,
    # in which case treat the reply as a new $RAW and re-enter Stage 0.2.
    #
    # Phrase the prompt in the user's invocation language (中/英). For example:
    #   English: "Pick a result [1-5], or 'cancel': "
    #   中文:    "请选择 [1-5],或输入 'cancel' 取消:"
    pick=<user choice>
  fi

  if [[ "$pick" == "cancel" ]]; then
    echo "Cancelled."
    exit 0
  fi
  RESOLVED=$(echo "$results" | awk -F'\t' -v n="$pick" 'NR==n {print $5}')
  if [[ -z "$RESOLVED" ]]; then
    echo "Invalid selection: $pick. Aborting."
    exit 1
  fi
  echo "Selected: $RESOLVED"
fi
```

Then invoke `claude-paper:study` with `$RESOLVED`. Use the Skill tool directly; do not proxy this through a generic Agent or shell command:

```
Skill(skill: "claude-paper:study", args: "$RESOLVED")
```

`claude-paper:study` will download / parse the PDF and produce a paper folder under `~/claude-papers/papers/<slug>/`. The slug is auto-derived from the paper title.

After the Skill returns, locate the new paper folder. The most reliable way is to take the most recently modified subdirectory:

```bash
PAPER_DIR=$(ls -td ${PAPERS_ROOT}/*/ 2>/dev/null | head -1 | sed 's:/$::')
```

Verify required outputs exist:
- `$PAPER_DIR/meta.json`
- `$PAPER_DIR/paper.pdf`
- `$PAPER_DIR/summary.md` (claude-paper's curated summary, not the full text — Stage 0.3.1 extracts the full text via pdftotext)
- `$PAPER_DIR/images/` (may be empty if pdftotext-style extraction fails; report and continue)

If any of these are missing, abort with: `"claude-paper:study did not produce expected outputs at $PAPER_DIR. Check the claude-paper plugin's installation and try /paperstudio:study again."`

Read `$PAPER_DIR/meta.json` and confirm its `slug` field matches the basename of `$PAPER_DIR`. If they disagree, prefer the `meta.json` slug (and adjust `PAPER_DIR` accordingly).

### 0.3 Compute paths

Set these environment-style variables (use them in subsequent dispatches):

- `PAPER_DIR=${PAPERS_ROOT}/<slug>`
- `META_JSON=$PAPER_DIR/meta.json`
- `PAPER_PDF=$PAPER_DIR/paper.pdf`
- `PAPER_TEXT=$PAPER_DIR/paper.txt` (extracted from `paper.pdf` — see Stage 0.3.1 below)
- `IMAGES_DIR=$PAPER_DIR/images`
- `ANALYSIS_DIR=$PAPER_DIR/analysis` (mkdir if absent)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

Source the log-dispatch helper for recording all sub-Agent dispatches:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
PLUGIN_VERSION=$(grep -m1 '"version"' $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/')
```

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

### 0.4 Resolve paper folder and dispatch paper-profiler

**Resolve target paper folder**

Source the shared helper and resolve which paper folder this invocation targets:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
# After: $PAPER_DIR, $PAPER_SLUG, $PAPER_AUTODETECTED are set.
# If $PAPER_AUTODETECTED is "true", the helper already printed a warning to stderr.
```

If `resolve_paper` returns non-zero, abort with the helper's stderr message.

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
    PLUGIN_VERSION=$PLUGIN_VERSION
)
```

Wait for completion. Log the dispatch:

```bash
log_dispatch paper-profiler analysis/00-paper-profile.md ok
```

If the agent produced a FAILED placeholder:

```bash
log_dispatch paper-profiler analysis/00-paper-profile.md failed
```

Read `$ANALYSIS_DIR/00-paper-profile.md` and parse its YAML frontmatter.

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

In **one message**, issue six parallel Agent tool calls. The dispatch table below is authoritative for what each sub-Agent receives. All six get `PAPER_TEXT`, `OUTPUT_PATH`, `TEMPLATE_PATH`, and `PLUGIN_VERSION`. Most also receive `PROFILE_PATH` (`figure-interpreter` does not — it works directly from `PAPER_TEXT` + `IMAGES_DIR`). Extras vary: `method-analyst` and `experiment-critic` get `DOMAIN_PACKS`; `prior-work-historian` gets `DOMAIN_PACKS` and is allowed up to 5 WebFetch calls; `figure-interpreter` gets `IMAGES_DIR`.

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

After all six return, verify each expected output file exists. Log each dispatch:

```bash
log_dispatch problem-framer analysis/01-problem.md ok
log_dispatch formalizer analysis/02-formalization.md ok
log_dispatch method-analyst analysis/03-method-deep.md ok
log_dispatch experiment-critic analysis/04-experiments.md ok
log_dispatch prior-work-historian analysis/05-prior-work.md ok
log_dispatch figure-interpreter analysis/06-figures.md ok
```

For any that did not produce a file, write a placeholder and log as failed:

```
echo '<!-- FAILED: <reason from sub-Agent error> -->' > $OUTPUT_PATH
log_dispatch <subagent-name> analysis/<NN-name>.md failed
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
    PLUGIN_VERSION=$PLUGIN_VERSION
)
```

Wait for completion.

```bash
log_dispatch reviewer-synthesizer review.md ok
```

### 2.2 Verify

If `$PAPER_DIR/review.md` does not exist, write `<!-- FAILED: reviewer-synthesizer did not produce output -->`, log the failure, and record in `STAGE2_FAILURES`:

```bash
log_dispatch reviewer-synthesizer review.md failed
```

Otherwise, proceed.

## Stage 3: Notes generation

Stage 3 has two sequential sub-stages then two parallel renderers.

**Language flag**: parse `--lang` from the user's invocation. Set `LANG_FLAG=zh` (default) or `LANG_FLAG=en`. All four Stage 3 sub-Agents (notes-writer, title-generator, xhs-renderer, wechat-renderer) receive `LANG=$LANG_FLAG` as a prompt input. Their prompts already contain the directive: `Output language: 中文 by default. Switch to English ONLY if user explicitly passes lang=en.`

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
    PLUGIN_VERSION=$PLUGIN_VERSION
    LANG=$LANG_FLAG
)
```

Create `$PAPER_DIR/notes/` first if absent.

After completion:

```bash
log_dispatch notes-writer notes/source.md ok
```

If failed: `log_dispatch notes-writer notes/source.md failed`

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
    PLUGIN_VERSION=$PLUGIN_VERSION
    LANG=$LANG_FLAG
)
```

After completion:

```bash
log_dispatch title-generator notes/titles.md ok
```

If failed: `log_dispatch title-generator notes/titles.md failed`

### 3.3 Pick figures

Run:

```bash
node $PLUGIN_ROOT/scripts/select-figures.cjs $ANALYSIS_DIR/06-figures.md 1
node $PLUGIN_ROOT/scripts/select-figures.cjs $ANALYSIS_DIR/06-figures.md 3
```

Capture each as JSON; keep them as **paper-folder-relative paths** (e.g. `images/page_1_img_1.jpeg`, NOT `$IMAGES_DIR/page_1_img_1.jpeg`). The renderer prompts then embed those paths directly so committed/shared notes don't leak the author's home directory. Set:
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
    PLUGIN_VERSION=$PLUGIN_VERSION
    LANG=$LANG_FLAG
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
    PLUGIN_VERSION=$PLUGIN_VERSION
    LANG=$LANG_FLAG
)
```

After both complete:

```bash
log_dispatch xhs-renderer notes/xhs.md ok
log_dispatch wechat-renderer notes/wechat.md ok
```

If either failed:

```bash
log_dispatch xhs-renderer notes/xhs.md failed
log_dispatch wechat-renderer notes/wechat.md failed
```

### 3.5 Verify outputs

Each of `notes/{source,titles,xhs,wechat}.md` must exist. Missing ones get `<!-- FAILED: ... -->` placeholders and are recorded in `STAGE3_FAILURES`.

---

## Final summary

After Stage 3 completes, print a summary to chat. The structure (sections, file list, refinement command list) stays as below, but the headings and prose should be translated into the user's invocation language; only the file paths and command names stay verbatim.

```
✓ paperstudio complete for <slug>

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

If anything failed, retry that stage with /paperstudio:rerun-stage <stage>.

Available refinements:
  /paperstudio:review-round       — adversarial review
  /paperstudio:refine-notes [xhs|wechat]
  /paperstudio:deep-dive <topic>
  /paperstudio:compare <other-paper>
  /paperstudio:reselect-figures
  /paperstudio:retitle [xhs|wechat]
  /paperstudio:add-prior-work <ref>
  /paperstudio:reproduce-check
```
