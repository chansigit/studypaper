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
| problem-framer | `$ANALYSIS_DIR/01-problem.md` | `templates/analysis/01-problem.md` | — |
| formalizer | `$ANALYSIS_DIR/02-formalization.md` | `templates/analysis/02-formalization.md` | — |
| method-analyst | `$ANALYSIS_DIR/03-method-deep.md` | `templates/analysis/03-method-deep.md` | DOMAIN_PACKS |
| experiment-critic | `$ANALYSIS_DIR/04-experiments.md` | `templates/analysis/04-experiments.md` | DOMAIN_PACKS |
| prior-work-historian | `$ANALYSIS_DIR/05-prior-work.md` | `templates/analysis/05-prior-work.md` | DOMAIN_PACKS, WEBFETCH allowed |
| figure-interpreter | `$ANALYSIS_DIR/06-figures.md` | `templates/analysis/06-figures.md` | IMAGES_DIR |

### 1.3 Collect results

After all six return, verify each expected output file exists. For any that did not produce a file, write a placeholder:

```
echo '<!-- FAILED: <reason from sub-Agent error> -->' > $OUTPUT_PATH
```

Record failures in a `STAGE1_FAILURES` list for the final summary.

---

## Stages 2 & 3

(Continued in subsequent skill content; see Tasks 19, 20 in the implementation plan — they extend this file.)
