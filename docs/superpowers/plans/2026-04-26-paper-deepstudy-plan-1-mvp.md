# paper-deepstudy Plan 1: MVP Auto-run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `paper-deepstudy` plugin's MVP: a working `/paper:study <pdf|url>` command that produces 12 auto-run artifacts (7 analysis files, `review.md`, 4 notes files) for any ML or single-cell paper.

**Architecture:** A Claude Code plugin layered on top of `claude-paper:study`. A single skill `study-deep` orchestrates four sequential stages. Each stage dispatches one or more sub-Agents (via the Agent tool, `subagent_type: general-purpose`) loaded with a prompt template. Stage 1 runs six sub-Agents in parallel; Stage 3 runs two renderers in parallel. Outputs land under `~/claude-papers/papers/<slug>/` alongside `claude-paper:study`'s own outputs.

**Tech Stack:**
- Markdown (skill instructions, prompt templates, output templates)
- Bash (shell scripts, command files, prereq checks)
- Node.js >= 18 (small helper for figure scoring/selection)
- Claude Code plugin format (`.claude-plugin/plugin.json`, `commands/`, `skills/`)
- Depends on: `claude-paper:study` plugin (must be installed)

**Test paper fixture:**
- For unit checks: a synthetic minimal `meta.json` + tiny markdown stub (no actual PDF needed for static tests).
- For integration: `Attention Is All You Need` (arXiv 1706.03762) for ML-pure path; `scVI` (Lopez 2018, *Nature Methods*) or any small scRNA-seq paper for the single-cell path.

---

## File Structure

The plugin source lives at `/Users/chensijie/Projects/studypaper/paper-deepstudy/`.

> **Test paths convention:** Tests live inside the plugin under `paper-deepstudy/tests/` so they ship with the plugin. All bats file content uses paths relative to `paper-deepstudy/` (no `paper-deepstudy/` prefix). Each bats file includes a `setup()` that `cd`s to the plugin root using `$BATS_TEST_DIRNAME/../..` so tests pass regardless of the invoker's cwd. Bats invocations work both as `bats paper-deepstudy/tests/unit/<file>.bats` from the repo root and as `bats tests/unit/<file>.bats` from `paper-deepstudy/`.

```
paper-deepstudy/
├── .claude-plugin/plugin.json
├── README.md
├── .gitignore
├── package.json
├── commands/
│   ├── study.md                # /paper:study
│   └── rerun-stage.md          # /paper:rerun-<stage>
├── skills/
│   └── study-deep/
│       └── SKILL.md
├── prompts/
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
│   └── wechat-renderer.md
├── domain-packs/
│   ├── _template.md
│   ├── ml-pure.md
│   └── single-cell.md
├── templates/
│   ├── analysis/
│   │   ├── 00-paper-profile.md
│   │   ├── 01-problem.md
│   │   ├── 02-formalization.md
│   │   ├── 03-method-deep.md
│   │   ├── 04-experiments.md
│   │   ├── 05-prior-work.md
│   │   └── 06-figures.md
│   ├── review.md
│   └── notes/
│       ├── source.md
│       ├── titles.md
│       ├── xhs.md
│       └── wechat.md
├── scripts/
│   ├── verify-prereqs.sh
│   └── select-figures.cjs
└── tests/
    ├── fixtures/
    │   └── tiny-paper/         # synthetic for unit tests
    │       ├── meta.json
    │       └── paper.txt
    ├── unit/
    │   ├── test-prereqs.bats
    │   ├── test-prompts-have-required-sections.bats
    │   ├── test-templates-valid.bats
    │   └── test-select-figures.cjs
    └── integration/
        └── test-end-to-end.sh
```

**Per-paper outputs land at:** `~/claude-papers/papers/<slug>/` (extending what `claude-paper:study` writes).

**Responsibilities:**
- `commands/*.md` — slash command entry points (thin)
- `skills/study-deep/SKILL.md` — orchestration logic (the brain)
- `prompts/*.md` — one prompt template per sub-Agent role
- `domain-packs/*.md` — domain knowledge injected into select prompts
- `templates/**/*.md` — output skeletons each prompt fills in
- `scripts/select-figures.cjs` — pure logic for picking figures by score
- `tests/` — bats + node tests for the static and unit checks

---

## Pre-flight

Before starting tasks, ensure: `bats-core` installed (`brew install bats-core`), Node >= 18, `claude-paper:study` plugin already configured (the plan does not install it; the user already has it).

---

### Task 1: Plugin scaffolding

**Files:**
- Create: `paper-deepstudy/.claude-plugin/plugin.json`
- Create: `paper-deepstudy/README.md`
- Create: `paper-deepstudy/.gitignore`
- Create: `paper-deepstudy/package.json`

- [ ] **Step 1: Write a smoke test that the plugin manifest validates as JSON**

`paper-deepstudy/tests/unit/test-prereqs.bats` (paths inside the file are relative to `paper-deepstudy/`; the `setup()` block makes tests work from any cwd):

```bash
#!/usr/bin/env bats

# Ensure tests run from the plugin root regardless of where bats was invoked.
setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "plugin.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('.claude-plugin/plugin.json'))"
  [ "$status" -eq 0 ]
}

@test "package.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('package.json'))"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the test, verify it fails (files don't exist)**

Run: `cd /Users/chensijie/Projects/studypaper/paper-deepstudy && bats tests/unit/test-prereqs.bats`
Expected: 2 failures with "No such file or directory".

- [ ] **Step 3: Create the directory tree and manifests**

```bash
mkdir -p paper-deepstudy/{.claude-plugin,commands,skills/study-deep,prompts,domain-packs,templates/analysis,templates/notes,scripts}
mkdir -p paper-deepstudy/tests/{unit,integration,fixtures/tiny-paper}
```

`paper-deepstudy/.claude-plugin/plugin.json`:

```json
{
  "name": "paper-deepstudy",
  "version": "0.1.0",
  "description": "Deep paper study for ML and computational-biology papers. Layers on claude-paper:study to add deep analysis, iterative review, and Chinese notes for Xiaohongshu/WeChat.",
  "author": {"name": "Sijie Chen", "email": "chansigit@gmail.com"},
  "dependencies": ["claude-paper"]
}
```

`paper-deepstudy/README.md`:

```markdown
# paper-deepstudy

Deep paper study for ML and computational-biology papers. Layers on top of `claude-paper:study` to add:

- Deep analysis (problem framing, formal definition, methodology, experiments, prior-work timeline, figure interpretation) — English
- Iterative review with adversarial review rounds — English
- Chinese learning notes for Xiaohongshu / WeChat from a unified source

## Install (local dev)

```
# from this repo's root:
/plugin install ./paper-deepstudy
```

Requires `claude-paper:study` already installed.

## Usage

```
/paper:study <pdf-path-or-url>
```

Outputs land under `~/claude-papers/papers/<slug>/`. See `docs/superpowers/specs/2026-04-26-paper-deepstudy-design.md` for the full design.
```

`paper-deepstudy/.gitignore`:

```
node_modules/
*.bak.*
.DS_Store
```

`paper-deepstudy/package.json` (Task 17 will re-extend `test:unit` to also run the node test):

```json
{
  "name": "paper-deepstudy",
  "version": "0.1.0",
  "private": true,
  "type": "commonjs",
  "engines": { "node": ">=18" },
  "scripts": {
    "test:unit": "bats tests/unit"
  }
}
```

- [ ] **Step 4: Re-run tests, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prereqs.bats`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/.claude-plugin paper-deepstudy/README.md paper-deepstudy/.gitignore paper-deepstudy/package.json paper-deepstudy/tests/unit/test-prereqs.bats
git commit -m "feat(paper-deepstudy): plugin scaffolding"
```

---

### Task 2: Prereq verifier script

**Files:**
- Create: `paper-deepstudy/scripts/verify-prereqs.sh`
- Modify: `paper-deepstudy/tests/unit/test-prereqs.bats`

- [ ] **Step 1: Add the failing test**

Append to `paper-deepstudy/tests/unit/test-prereqs.bats` (paths relative to `paper-deepstudy/`):

```bash
@test "verify-prereqs.sh exists and is executable" {
  [ -x scripts/verify-prereqs.sh ]
}

@test "verify-prereqs.sh succeeds when all deps present" {
  run scripts/verify-prereqs.sh
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-prereqs.bats`
Expected: the two new tests fail.

- [ ] **Step 3: Create the script**

`paper-deepstudy/scripts/verify-prereqs.sh`:

```bash
#!/usr/bin/env bash
# Verify prerequisites for paper-deepstudy.
# Exit codes: 0 ok, 1 missing claude-paper, 2 missing node, 3 missing python3.
set -euo pipefail

# 1. claude-paper plugin must be installed (look for its skill file)
CLAUDE_PAPER_GLOB="$HOME/.claude/plugins/cache/claude-paper/claude-paper/*/skills/study/SKILL.md"
if ! ls $CLAUDE_PAPER_GLOB > /dev/null 2>&1; then
  echo "ERROR: claude-paper:study plugin not found." >&2
  echo "Install via the Claude Code plugin marketplace before using paper-deepstudy." >&2
  exit 1
fi

# 2. node >= 18
if ! command -v node > /dev/null 2>&1; then
  echo "ERROR: node not found (need >= 18)." >&2
  exit 2
fi
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "ERROR: node version $NODE_MAJOR < 18." >&2
  exit 2
fi

# 3. python3 (used by claude-paper for image extraction; we depend on its outputs)
if ! command -v python3 > /dev/null 2>&1; then
  echo "ERROR: python3 not found." >&2
  exit 3
fi

echo "OK: prerequisites satisfied."
exit 0
```

```bash
chmod +x paper-deepstudy/scripts/verify-prereqs.sh
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prereqs.bats`
Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/scripts/verify-prereqs.sh paper-deepstudy/tests/unit/test-prereqs.bats
git commit -m "feat(paper-deepstudy): prereq verification script"
```

---

### Task 3: Domain pack template + ml-pure pack

**Files:**
- Create: `paper-deepstudy/domain-packs/_template.md`
- Create: `paper-deepstudy/domain-packs/ml-pure.md`
- Create: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Write failing structural test**

`paper-deepstudy/tests/unit/test-domain-packs.bats` (paths relative to `paper-deepstudy/`; `setup()` cds to plugin root):

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

required_sections=(
  "# Pack:"
  "## Core problems"
  "## Key baselines"
  "## Common datasets"
  "## Standard metrics"
  "## Reviewer checklist"
)

check_pack() {
  local f=$1
  for s in "${required_sections[@]}"; do
    grep -qF "$s" "$f" || return 1
  done
}

@test "_template.md has required sections" {
  run check_pack domain-packs/_template.md
  [ "$status" -eq 0 ]
}

@test "ml-pure.md has required sections" {
  run check_pack domain-packs/ml-pure.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-domain-packs.bats`
Expected: 2 failures.

- [ ] **Step 3: Write `_template.md`**

`paper-deepstudy/domain-packs/_template.md`:

```markdown
# Pack: <NAME>

One-paragraph summary of what this subfield is and what kinds of papers belong in it.

## Core problems

- <Problem 1, one line>
- <Problem 2>

## Key baselines

- **<Baseline name>** (<year>): <one-line description; what it solves and how>
- ...

## Common datasets

- **<Dataset name>**: <task definition; rough scale (samples / size); standard split if any>
- ...

## Standard metrics

- **<Metric>**: <how computed; caveats / when it's misleading>
- ...

## Reviewer checklist

Questions a domain-aware reviewer would ask of any paper claiming progress in this area:

- [ ] <Question 1>
- [ ] <Question 2>
- ...
```

- [ ] **Step 4: Write `ml-pure.md`**

`paper-deepstudy/domain-packs/ml-pure.md`:

```markdown
# Pack: ml-pure

General machine-learning papers without a strong domain-specific component (NLP, CV, RL, generic deep learning). Use as a fallback or in combination with a more specific pack.

## Core problems

- Supervised classification / regression
- Self-supervised representation learning
- Generative modeling (text, image, multimodal)
- Sequence modeling
- Reinforcement learning / decision making

## Key baselines

- **Transformer** (2017): attention-based seq2seq backbone, displaced RNNs for long-range dependencies.
- **ResNet** (2015): residual connections, default vision backbone for many years.
- **BERT / GPT family**: pretrained-then-finetuned (BERT) vs autoregressive (GPT) — should be cited as baselines for any new LM.
- **CLIP**: contrastive image–text pretraining, default zero-shot vision baseline.
- **Diffusion models** (DDPM): generative baseline for continuous data.

## Common datasets

- **ImageNet-1k**: 1.28M training images, 1000 classes; classification standard.
- **GLUE / SuperGLUE**: NLU benchmark suite.
- **COCO**: object detection / captioning, 118k train images.
- **C4 / The Pile**: large pretraining corpora.

## Standard metrics

- **Accuracy / Top-k accuracy**: assumes balanced classes; report per-class breakdown when imbalanced.
- **AUROC**: misleading under heavy class imbalance — also report PR-AUC.
- **F1 / macro-F1**: prefer macro-F1 when class imbalance matters.
- **Perplexity**: language modeling; comparable only when same tokenizer & corpus.
- **FID / IS**: generative quality; FID is sensitive to feature extractor choice.

## Reviewer checklist

- [ ] Are baselines from the last 18 months included?
- [ ] Is the comparison fair (same training data, compute, hyperparameter budget)?
- [ ] Is variance reported across seeds (≥3)?
- [ ] Are ablations decisive — does each removed component clearly hurt?
- [ ] Are claims commensurate with evidence (no "SOTA" without head-to-head)?
- [ ] Are failure cases shown?
- [ ] Is compute / data scale reported reproducibly?
- [ ] Code & weights released, or release planned with a license?
```

- [ ] **Step 5: Run tests, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-domain-packs.bats`
Expected: 2 pass.

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/domain-packs/_template.md paper-deepstudy/domain-packs/ml-pure.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): domain pack template and ml-pure pack"
```

---

### Task 4: single-cell domain pack

**Files:**
- Create: `paper-deepstudy/domain-packs/single-cell.md`
- Modify: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Add failing test**

Append to `paper-deepstudy/tests/unit/test-domain-packs.bats`:

```bash
@test "single-cell.md has required sections" {
  run check_pack domain-packs/single-cell.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-domain-packs.bats`
Expected: 1 failure on the new test.

- [ ] **Step 3: Write the pack**

`paper-deepstudy/domain-packs/single-cell.md`:

```markdown
# Pack: single-cell

Papers about single-cell RNA sequencing (scRNA-seq), single-cell ATAC-seq, multi-omics, and foundation models for cellular data. Often paired with `ml-pure` when the contribution is methodological.

## Core problems

- Dimensionality reduction / latent embedding for sparse, high-dimensional gene-by-cell counts
- Batch effect correction (donor / experiment / platform)
- Cell-type annotation (supervised, unsupervised, transfer)
- Gene regulatory network inference
- Trajectory inference / pseudotime
- Multi-modal integration (RNA + ATAC + protein)
- Foundation models for cells (Geneformer / scGPT-style)

## Key baselines

- **Seurat** (Satija et al., 2015+): R toolkit, PCA + clustering + marker-based annotation.
- **Scanpy** (Wolf et al., 2018): Python equivalent, the de facto pipeline.
- **scVI** (Lopez et al., 2018, Nat Methods): VAE for counts; latent space + batch covariate; standard deep baseline.
- **Harmony** (Korsunsky et al., 2019, Nat Methods): batch correction in PCA space, fast and strong.
- **Geneformer** (Theodoris et al., 2023, Nature): transformer foundation model on Genecorpus-30M.
- **scGPT** (Cui et al., 2024, Nat Methods): generative foundation model for single-cell.
- **scFoundation** (Hao et al., 2024, Nat Methods): another foundation model with attention over genes.

## Common datasets

- **Tabula Sapiens / Tabula Muris**: cross-tissue scRNA atlases (human / mouse), 100k+ cells.
- **PBMC (10x Genomics)**: 3k / 10k peripheral blood mononuclear cells; the "MNIST of single-cell".
- **Human Cell Atlas (HCA)**: large multi-tissue reference.
- **Genecorpus-30M**: 30M cells used for Geneformer pretraining.
- **CELLxGENE**: hosted atlas with standardized metadata.

## Standard metrics

- **ASW (Average Silhouette Width)**: cluster compactness; biology-vs-batch separation.
- **iLISI / cLISI**: integration vs cell-type preservation; report both.
- **kBET**: batch-mixing test based on neighborhoods.
- **NMI / ARI** vs known cell-type labels: clustering agreement; sensitive to label resolution.
- **Top-k accuracy** for cell-type prediction: report per-cell-type breakdown — rare types are often where models fail.
- **Pearson correlation on imputed counts**: imputation; held-out gene comparison.

## Reviewer checklist

- [ ] Is scVI (or equivalent deep baseline) compared against?
- [ ] Are batch-effect / integration metrics reported (iLISI / kBET / ASW per batch)?
- [ ] Are rare cell types broken out, not just hidden in macro-averages?
- [ ] Was the test atlas held out at the donor or batch level (not random cell split)?
- [ ] Are cell-type labels from a defensible source (manual annotation by experts, not propagated from the same model)?
- [ ] Are claims tied to biology (specific marker genes, pathways) or only to embedding metrics?
- [ ] Is wet-lab validation (if any) at the level the claim requires? (e.g. perturbation prediction needs perturbation experiment)
- [ ] Is the data cleaning pipeline disclosed (filters on n_genes, mt%, doublet removal)?
- [ ] Is the model size / compute commensurate with claimed gains, vs simpler baselines?
- [ ] Are foundation-model claims backed by zero-shot or fair fine-tuning, not just held-out performance with leakage?
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-domain-packs.bats`
Expected: 3 pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/domain-packs/single-cell.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): single-cell domain pack"
```

---

### Task 5: Output templates — analysis files (7 files)

**Files:**
- Create: `paper-deepstudy/templates/analysis/00-paper-profile.md`
- Create: `paper-deepstudy/templates/analysis/01-problem.md`
- Create: `paper-deepstudy/templates/analysis/02-formalization.md`
- Create: `paper-deepstudy/templates/analysis/03-method-deep.md`
- Create: `paper-deepstudy/templates/analysis/04-experiments.md`
- Create: `paper-deepstudy/templates/analysis/05-prior-work.md`
- Create: `paper-deepstudy/templates/analysis/06-figures.md`
- Create: `paper-deepstudy/tests/unit/test-templates-valid.bats`

- [ ] **Step 1: Failing test for templates**

`paper-deepstudy/tests/unit/test-templates-valid.bats` (paths relative to `paper-deepstudy/`; `setup()` cds to plugin root):

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "00-paper-profile.md has YAML frontmatter" {
  head -1 templates/analysis/00-paper-profile.md | grep -qE '^---$'
}

@test "01-problem.md exists with H1 heading" {
  grep -qE '^# ' templates/analysis/01-problem.md
}

@test "02-formalization.md has Notation section" {
  grep -qF '## Notation' templates/analysis/02-formalization.md
}

@test "03-method-deep.md has Components section" {
  grep -qF '## Components' templates/analysis/03-method-deep.md
}

@test "04-experiments.md has Critique section" {
  grep -qF '## Critique' templates/analysis/04-experiments.md
}

@test "05-prior-work.md has Timeline section" {
  grep -qF '## Timeline' templates/analysis/05-prior-work.md
}

@test "06-figures.md has frontmatter for scoring" {
  head -1 templates/analysis/06-figures.md | grep -qE '^---$'
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-templates-valid.bats`
Expected: 7 failures.

- [ ] **Step 3: Write all 7 templates**

`templates/analysis/00-paper-profile.md`:

```markdown
---
slug: <slug>
title: <title>
paper_type: theory | architecture | empirical | system | survey | dataset
domain: ml-pure | ml-bio-hybrid | cs-bio | wet-lab-heavy
bio_subfield: single-cell | protein-structure | protein-function | genomics | drug-discovery | medical-imaging | none
difficulty: beginner | intermediate | advanced | highly-theoretical
domain_packs_selected:
  - ml-pure
key_baselines_detected:
  - <baseline>
claims_summary:
  - <claim 1>
---

# Paper Profile

## Why these tags

(One paragraph explaining the choice of `paper_type`, `domain`, and `bio_subfield`.)

## What to expect downstream

(One paragraph: which analyses will be most informative for this paper, which sections may be thin.)
```

`templates/analysis/01-problem.md`:

```markdown
# Problem Background and Framing

## Field-level context

(2-4 paragraphs: where this work sits, why the field cares, what was unsolved.)

## The specific problem this paper addresses

(1-2 paragraphs: the precise question being answered.)

## Why this problem is hard

(Bullet list of obstacles: data, compute, theoretical, biological.)

## Why prior approaches fall short

(Brief — saved for `05-prior-work.md`. Just a teaser of the gap.)
```

`templates/analysis/02-formalization.md`:

```markdown
# Formal Problem Definition

## Notation

| Symbol | Meaning | Domain |
|---|---|---|
| <x> | <input> | <space> |

## Inputs

(What the model / method takes in.)

## Outputs

(What it produces.)

## Objective / Loss

(Math, with each term explained.)

## Constraints / Assumptions

(Independence, distributional, computational, biological.)

## Evaluation protocol

(How performance is measured. Differs from training loss.)
```

`templates/analysis/03-method-deep.md`:

```markdown
# Method (Deep)

## High-level idea

(One paragraph in plain language.)

## Components

(For each module: name, what it does, why this design.)

### <Component 1>

- **What it does:** ...
- **Inputs:** ...
- **Outputs:** ...
- **Design rationale:** ...
- **Alternatives the authors could have chosen:** ...
- **Why those alternatives would be worse / different:** ...

## Algorithm flow

(Pseudocode or step-by-step, balanced with prose.)

## Hyperparameter sensitivity

(Which knobs matter, which are robust, with evidence from the paper if available.)

## Reproduction risks

(Things the paper does not specify clearly. What you'd have to guess.)
```

`templates/analysis/04-experiments.md`:

```markdown
# Experiments

## Setup

(Datasets, splits, metrics, baselines, compute.)

## Headline results

(The 1-3 numbers the authors lead with, with context.)

## Ablations

(What was ablated; which removals hurt; what was not ablated but should have been.)

## Critique

### Soundness
(Are the comparisons fair? Same data, same compute, same hyperparameter budget?)

### Coverage
(Are the right baselines included? Anything missing?)

### Statistical rigor
(Variance reported? Significance tests where needed?)

### Failure modes
(Where does the method break down? Acknowledged or hidden?)

### Negative results
(Anything reported as not working? Or only successes shown?)

## Bottom line

(One paragraph: do the experiments support the claims?)
```

`templates/analysis/05-prior-work.md`:

```markdown
# Prior Work

## Timeline

(Chronological list of the lineage leading to this paper. 5-15 entries. Each: year, paper, one-line contribution, relation to this paper.)

## Comparison table

| Method | Year | Approach | Strengths | Weaknesses | Relation to this paper |
|---|---|---|---|---|---|

## Lineage diagram (text)

```
<Earlier work A> ──┐
                    ├─→ <This paper>
<Earlier work B> ──┘
```

## What this paper inherits vs invents

(Two columns of bullets.)

## Notable omissions

(Citations the authors should have made but didn't.)
```

`templates/analysis/06-figures.md` (filenames are placeholders set at runtime by the figure-interpreter; real ones from `claude-paper:study` look like `page_3_img_1.png`):

```markdown
---
# `figures` is filled in by the figure-interpreter sub-Agent at runtime.
# Each entry's `file` is the basename of an image in $PAPER_DIR/images/.
# Real filenames from claude-paper:study look like `page_3_img_1.png`,
# not `figure-1.png` — the placeholders below are illustrative only.
figures:
  - file: <basename-from-images-dir>
    caption: "<caption>"
    importance: 0.0  # 0.0–1.0, set by interpreter
    role: architecture | pipeline | main-result | ablation | qualitative | other
  - file: <another-basename>
    caption: ""
    importance: 0.0
    role: other
---

# Figures

## Figure 1 — <short title>

(Plain-language explanation of what the figure shows. Why it matters. What to read off it.)

## Figure 2 — <short title>

...
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-templates-valid.bats`
Expected: 7 pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/templates/analysis paper-deepstudy/tests/unit/test-templates-valid.bats
git commit -m "feat(paper-deepstudy): analysis output templates"
```

---

### Task 6: Output templates — review + notes (5 files)

**Files:**
- Create: `paper-deepstudy/templates/review.md`
- Create: `paper-deepstudy/templates/notes/source.md`
- Create: `paper-deepstudy/templates/notes/titles.md`
- Create: `paper-deepstudy/templates/notes/xhs.md`
- Create: `paper-deepstudy/templates/notes/wechat.md`
- Modify: `paper-deepstudy/tests/unit/test-templates-valid.bats`

- [ ] **Step 1: Add failing tests**

Append to `paper-deepstudy/tests/unit/test-templates-valid.bats`:

```bash
@test "review.md has Score section" {
  grep -qF '## Score' templates/review.md
}

@test "notes/source.md has 9 sections" {
  count=$(grep -cE '^## ' templates/notes/source.md)
  [ "$count" -eq 9 ]
}

@test "notes/titles.md has xhs and wechat groups" {
  grep -qF '## xhs' templates/notes/titles.md
  grep -qF '## wechat' templates/notes/titles.md
}

@test "notes/xhs.md has frontmatter with title" {
  head -3 templates/notes/xhs.md | grep -qF 'title:'
}

@test "notes/wechat.md has frontmatter with title" {
  head -3 templates/notes/wechat.md | grep -qF 'title:'
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-templates-valid.bats`
Expected: 5 new failures.

- [ ] **Step 3: Write the 5 templates**

`templates/review.md`:

```markdown
# Review: <Paper Title>

**Reviewer:** paper-deepstudy (auto-generated v1; refined via /paper:review-round)
**Last updated:** <date>
**Domain packs applied:** <list>

## Summary

(Neutral 1-paragraph summary of the paper's contribution and approach.)

## Significance

(Why this matters in the field, both ML and biological if applicable.)

## Strengths

- <Strength 1> ← from initial analysis
- ...

## Weaknesses

### Methodological

- <Weakness> ← from round-NN

### Experimental

- <Weakness> ← from round-NN

### Bio-rigor

(Only present when a bio domain pack is active.)

- <Weakness> ← from round-NN

## Questions to Authors

- <Question> ← from round-NN

## Suggestions

- <Suggestion> ← from round-NN

## Score

**Soundness:** _ / 4
**Presentation:** _ / 4
**Contribution:** _ / 4
**Overall recommendation:** _ / 10

## Confidence

_ / 5
```

`templates/notes/source.md`:

```markdown
# 学习笔记原料

> 内部文件,中文,转述视角。两个 renderer 从这里取材。

## 1. 一句话讲清楚这篇 paper 在干嘛

## 2. 它要解决的问题是什么

## 3. 现有方案为什么不够

## 4. 这篇的核心 idea

## 5. 方法是怎么 work 的

## 6. 实验结果

## 7. 它和前人工作的关系

## 8. 局限 / 没解决的问题

## 9. 一句话总结 take-away
```

`templates/notes/titles.md`:

```markdown
# 标题候选

## xhs

1. <候选 1> — style: hook
2. <候选 2> — style: question
3. <候选 3> — style: numbers
4. <候选 4> — style: contrast
5. <候选 5> — style: literal

## wechat

1. <候选 1> — style: hook
2. <候选 2> — style: question
3. <候选 3> — style: numbers
4. <候选 4> — style: contrast
5. <候选 5> — style: literal

## history

(被替换过的旧标题归档于此。)
```

`templates/notes/xhs.md`:

```markdown
---
title: <title from titles.md item 1>
length_target: 1000
length_max: 1300
figures:
  - <figure-file>
---

# <title>

(Hook 段:1-3 句把读者抓住。)

## <小标题 1>

(短段。)

## <小标题 2>

(短段。)

<!-- alt titles:
2. ...
3. ...
-->
```

`templates/notes/wechat.md`:

```markdown
---
title: <title from titles.md item 1>
length_target: 3000
length_max: 4000
figures:
  - <figure-file-1>
  - <figure-file-2>
---

# <title>

(导语 1-2 段。)

## 背景

## 核心 idea

## 方法

## 实验

## 局限和未来

## 一句话总结

---

**参考文献**(最多 3 个)
- <ref 1>
- <ref 2>

<!-- alt titles:
2. ...
-->
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-templates-valid.bats`
Expected: all 12 pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/templates/review.md paper-deepstudy/templates/notes paper-deepstudy/tests/unit/test-templates-valid.bats
git commit -m "feat(paper-deepstudy): review and notes output templates"
```

---

### Task 7: Prompt — paper-profiler

**Files:**
- Create: `paper-deepstudy/prompts/paper-profiler.md`
- Create: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Failing test**

`paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats` (paths relative to `paper-deepstudy/`; `setup()` cds to plugin root):

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

required_in_prompt=(
  "## Role"
  "## Inputs"
  "## Output"
  "## Instructions"
)

check_prompt() {
  local f=$1
  for s in "${required_in_prompt[@]}"; do
    grep -qF "$s" "$f" || return 1
  done
}

@test "paper-profiler.md has all required sections" {
  run check_prompt prompts/paper-profiler.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: 1 fail.

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/paper-profiler.md`:

```markdown
# Prompt: paper-profiler

## Role

You classify a research paper along several axes so downstream sub-Agents can specialize. You are independent and do not coordinate with other sub-Agents.

## Inputs

You will be told two file paths:
- `META_JSON`: path to `meta.json` (from claude-paper:study), containing title, authors, abstract.
- `PAPER_TEXT`: path to the full text of the paper (markdown extracted by claude-paper:study).

You will also be given:
- `OUTPUT_PATH`: where to write `00-paper-profile.md`.
- `TEMPLATE_PATH`: path to the profile template; copy its frontmatter shape exactly.
- `AVAILABLE_PACKS`: list of available domain pack slugs (e.g. `ml-pure`, `single-cell`, `protein-structure`, ...).

## Output

A single markdown file at `OUTPUT_PATH`, conforming to `TEMPLATE_PATH`. It MUST start with YAML frontmatter containing:

- `slug` (string)
- `title` (string)
- `paper_type` (one of: theory, architecture, empirical, system, survey, dataset)
- `domain` (one of: ml-pure, ml-bio-hybrid, cs-bio, wet-lab-heavy)
- `bio_subfield` (one of the listed subfields, or `none`)
- `difficulty` (one of: beginner, intermediate, advanced, highly-theoretical)
- `domain_packs_selected` (list, drawn from `AVAILABLE_PACKS`; can be empty)
- `key_baselines_detected` (list of strings; empty list if none)
- `claims_summary` (list of 3-5 strings, each ≤ 30 words)

After the frontmatter, write two short prose sections (`## Why these tags`, `## What to expect downstream`) per the template.

## Instructions

1. Read `META_JSON` and `PAPER_TEXT`.
2. Decide the tags. Use these heuristics:
   - `paper_type`: theory papers prove things; architecture papers introduce a new model; empirical compare/study existing methods; system describes infrastructure; survey reviews; dataset introduces new data.
   - `domain`: pick `ml-pure` if no biological component; `ml-bio-hybrid` if biology drives the question and ML is the tool; `cs-bio` if both are first-class; `wet-lab-heavy` if wet experiments dominate.
   - `bio_subfield`: most-specific match. If none applies, use `none`.
   - `difficulty`: target reader is a new ML grad student; "advanced" means specialist knowledge needed.
3. `domain_packs_selected`: include `ml-pure` for any paper where ML methodology matters. Add the most specific bio pack if applicable. Up to 2 packs total.
4. `key_baselines_detected`: scan the paper for explicitly compared methods. List up to 8 by name as the paper writes them.
5. `claims_summary`: rephrase the paper's main claims in your own words; one claim per bullet.
6. Write the file to `OUTPUT_PATH`. Do not produce any other output.

## Quality bar

- Every frontmatter field present and from the allowed enum (where enums apply).
- Tag choice is defensible from the abstract alone — i.e. another reader could follow your reasoning in `## Why these tags`.
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: 1 pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/paper-profiler.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): paper-profiler prompt"
```

---

### Task 8: Prompt — problem-framer

**Files:**
- Create: `paper-deepstudy/prompts/problem-framer.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

Append to `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "problem-framer.md has required sections" {
  run check_prompt prompts/problem-framer.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: 1 new fail.

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/problem-framer.md`:

```markdown
# Prompt: problem-framer

## Role

You explain what problem the paper addresses, why the field cares, and why the problem is hard. You are independent of other sub-Agents and do not see their outputs.

## Inputs

- `PAPER_TEXT`: full paper text path.
- `PROFILE_PATH`: `analysis/00-paper-profile.md` path.
- `OUTPUT_PATH`: where to write `analysis/01-problem.md`.
- `TEMPLATE_PATH`: template skeleton path.

## Output

A markdown file at `OUTPUT_PATH` following `TEMPLATE_PATH`'s structure exactly:

- `## Field-level context` (2-4 paragraphs)
- `## The specific problem this paper addresses` (1-2 paragraphs)
- `## Why this problem is hard` (bullet list)
- `## Why prior approaches fall short` (brief, 3-6 bullets)

## Instructions

1. Read `PROFILE_PATH` first to understand what kind of paper this is. Use the `domain` and `bio_subfield` to set the right level of jargon (ml-pure → ML reader; ml-bio-hybrid → reader who knows both fields).
2. Read `PAPER_TEXT`, focusing on intro and related work.
3. Field-level context: name the parent problem, why it has been studied, what changed recently.
4. Specific problem: state precisely what this paper claims to solve. One sentence first, then 1-2 paragraphs of unpacking.
5. Why hard: enumerate obstacles. Be concrete: data scarcity, distribution shift, computational cost, theoretical barriers, biological measurement noise.
6. Why prior approaches fall short: 3-6 bullets, each naming a category of approach (not specific papers — that's prior-work-historian's job).
7. Avoid copying the abstract. Write in your own words.

## Quality bar

- A reader unfamiliar with the field can read this section and understand what the paper is about.
- No equations (those go to `02-formalization.md`).
- No specific paper citations (those go to `05-prior-work.md`).
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: 2 pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/problem-framer.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): problem-framer prompt"
```

---

### Task 9: Prompt — formalizer

**Files:**
- Create: `paper-deepstudy/prompts/formalizer.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "formalizer.md has required sections" {
  run check_prompt prompts/formalizer.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/formalizer.md`:

```markdown
# Prompt: formalizer

## Role

You extract and clarify the paper's formal problem definition: notation, inputs, outputs, objective, constraints, and evaluation protocol. You preserve the paper's mathematical content faithfully and explain it.

## Inputs

- `PAPER_TEXT`, `PROFILE_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.

## Output

`analysis/02-formalization.md` per the template. Sections:
- `## Notation` (markdown table: Symbol | Meaning | Domain)
- `## Inputs`
- `## Outputs`
- `## Objective / Loss` (LaTeX preserved in `$$` blocks; each term explained beneath)
- `## Constraints / Assumptions`
- `## Evaluation protocol`

## Instructions

1. Read the paper carefully. Find the methods section's central equations.
2. Build the Notation table. Every symbol used in any equation in this file must appear here. Each row: symbol (LaTeX in backticks), one-line meaning, domain (e.g. `ℝ^d`, `[0,1]`, `{0,1}^n`).
3. Inputs / Outputs: state precisely the data types in and out, including dimensions and any structure (sets, sequences, graphs).
4. Objective / Loss: write the loss with `$$ ... $$`. Below each equation, bullet each term and what it represents. If multiple losses exist (auxiliary, regularization), list separately and explain how they combine.
5. Constraints / Assumptions: independence assumptions, distributional assumptions, computational regimes (online/batch), biological assumptions (e.g. cells are i.i.d., gene expression is Poisson).
6. Evaluation protocol: how the trained model is evaluated, including any post-processing (calibration, top-k selection, threshold tuning).

## Quality bar

- All notation table entries appear in at least one equation or sentence in the same file.
- LaTeX renders without errors (no unbalanced braces).
- A reader who knows the field can re-derive the optimization target from this file alone.
- If the paper omits a formal definition (some empirical / system papers), say so explicitly and write what the implicit definition would be.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/formalizer.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): formalizer prompt"
```

---

### Task 10: Prompt — method-analyst

**Files:**
- Create: `paper-deepstudy/prompts/method-analyst.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "method-analyst.md has required sections" {
  run check_prompt prompts/method-analyst.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/method-analyst.md`:

```markdown
# Prompt: method-analyst

## Role

You analyze the method in depth, including each component's design rationale, alternatives the authors did not pick, and what could go wrong in reproduction.

## Inputs

- `PAPER_TEXT`, `PROFILE_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `DOMAIN_PACKS`: list of paths to domain pack files selected for this paper.

## Output

`analysis/03-method-deep.md` per the template:

- `## High-level idea` (1 paragraph plain language)
- `## Components` (one subsection per component; each with: what it does, inputs, outputs, design rationale, alternatives, why those alternatives would be different/worse)
- `## Algorithm flow` (pseudocode + prose)
- `## Hyperparameter sensitivity`
- `## Reproduction risks`

## Instructions

1. Read each `DOMAIN_PACKS` file briefly — these tell you what design choices are common in the field.
2. Read the paper's method section.
3. Decompose into components. For each:
   - Describe what it does in your own words.
   - Identify the design rationale: why did the authors pick this? What does it buy? Use evidence from the paper (ablation, intuition stated by authors, theoretical guarantee).
   - Alternatives: name 1-3 design choices the authors could have made instead (e.g. "could have used cross-attention instead of self-attention", "could have used Wasserstein instead of KL"). Use the domain pack's "Key baselines" for ideas.
   - Explain why those alternatives would lead to a different outcome.
4. Algorithm flow: pseudocode at the level of a textbook box; balance with prose so a reader can implement it.
5. Hyperparameter sensitivity: surface what the paper says about which knobs matter; if not discussed, mark unknown.
6. Reproduction risks: things the paper does NOT specify (random seed, exact hardware, hidden preprocessing). Be concrete.

## Quality bar

- Design rationale section answers "why this design choice?" not "what does this component do?"
- Alternatives are named, not vague ("could be different" is not an alternative).
- Pseudocode is implementable, not handwavy.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/method-analyst.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): method-analyst prompt"
```

---

### Task 11: Prompt — experiment-critic

**Files:**
- Create: `paper-deepstudy/prompts/experiment-critic.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "experiment-critic.md has required sections" {
  run check_prompt prompts/experiment-critic.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/experiment-critic.md`:

```markdown
# Prompt: experiment-critic

## Role

You audit the experimental section. Your output should answer: "do the experiments support the paper's claims?"

## Inputs

- `PAPER_TEXT`, `PROFILE_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `DOMAIN_PACKS`: paths to selected domain packs (use their reviewer checklists).

## Output

`analysis/04-experiments.md` with sections:
- `## Setup` (datasets, splits, metrics, baselines, compute)
- `## Headline results` (the numbers the authors lead with, in context)
- `## Ablations` (what was ablated, what wasn't)
- `## Critique` (subsections: Soundness, Coverage, Statistical rigor, Failure modes, Negative results)
- `## Bottom line` (one paragraph)

## Instructions

1. Read each domain pack's `## Reviewer checklist`. Apply each relevant question to this paper's experiments.
2. Setup: list datasets, splits, metrics, baselines, compute (GPU type / time / memory) factually.
3. Headline results: state the 1-3 numbers the abstract / intro highlight. Put them in context: relative improvement, absolute change, on what dataset.
4. Ablations: list what's ablated with one-line takeaways. Then list what should have been ablated but wasn't.
5. Critique:
   - **Soundness**: are baselines run with comparable compute / hyperparameter budget? Is the method's win attributable to its design or to extra training?
   - **Coverage**: does the comparison include current-generation baselines (within last 18 months)? If a key baseline from the domain pack is missing, name it.
   - **Statistical rigor**: variance across seeds reported? At least 3 seeds? Significance tests where claims hinge on small differences?
   - **Failure modes**: are these acknowledged? Or only successes shown?
   - **Negative results**: anything that didn't work?
6. Bottom line: integrate the above into one paragraph: do the experiments support the headline claims, with what caveats?

## Quality bar

- Critique is specific: "ResNet-50 baseline used a 3x smaller compute budget" rather than "baselines may be unfair".
- Domain pack checklist questions all addressed (or marked N/A with reason).
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/experiment-critic.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): experiment-critic prompt"
```

---

### Task 12: Prompt — prior-work-historian

**Files:**
- Create: `paper-deepstudy/prompts/prior-work-historian.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "prior-work-historian.md has required sections" {
  run check_prompt prompts/prior-work-historian.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/prior-work-historian.md`:

```markdown
# Prompt: prior-work-historian

## Role

You build a chronological lineage of the paper: what came before, what this paper inherits, what it invents, what it ignores.

## Inputs

- `PAPER_TEXT`, `PROFILE_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `DOMAIN_PACKS`: paths.
- `WEBFETCH`: optional. You may use WebFetch on cited works if needed for clarification, but only if the paper itself doesn't say enough. Cap: 5 fetches total.

## Output

`analysis/05-prior-work.md` with sections:
- `## Timeline` (chronological list)
- `## Comparison table` (markdown table: Method | Year | Approach | Strengths | Weaknesses | Relation to this paper)
- `## Lineage diagram (text)` (ASCII tree showing what fed into this paper)
- `## What this paper inherits vs invents` (two columns of bullets)
- `## Notable omissions` (citations the authors should have made but didn't)

## Instructions

1. Use the paper's related work + introduction to identify the lineage.
2. Cross-reference the domain pack's "Key baselines" — if any are missing from the paper's discussion, list them in `## Notable omissions`.
3. Timeline: 5-15 entries, year-sorted ascending. Each: year, paper short ID (e.g. "Vaswani et al. 2017 — Attention Is All You Need"), one-line contribution, one-line relation to this paper.
4. Comparison table: include 4-8 most relevant methods, including the current paper's method as the last row.
5. Lineage diagram: ASCII tree with arrows. Limit to 5-10 nodes to stay readable.
6. Inherits vs invents: be honest. Many "novel" papers reuse heavily.
7. Omissions: only list works whose absence is noteworthy. If none, say "None obvious."

## Quality bar

- Timeline entries are real papers (don't fabricate). If unsure, mark with `?` and explain.
- Comparison table cells are concrete (no vague "scales better"; say what scales how).
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/prior-work-historian.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): prior-work-historian prompt"
```

---

### Task 13: Prompt — figure-interpreter

**Files:**
- Create: `paper-deepstudy/prompts/figure-interpreter.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "figure-interpreter.md has required sections" {
  run check_prompt prompts/figure-interpreter.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/figure-interpreter.md`:

```markdown
# Prompt: figure-interpreter

## Role

You read every figure in the paper, write a caption-aware explanation, and assign each figure an importance score so downstream renderers can pick the best ones.

## Inputs

- `PAPER_TEXT`: full paper text (figure captions are inline).
- `IMAGES_DIR`: directory with extracted figure files (e.g. `images/figure-1.png`, ...). Filenames may be `figure-N.png` or arbitrary (e.g. `page3-img1.png`).
- `OUTPUT_PATH`: where to write `analysis/06-figures.md`.
- `TEMPLATE_PATH`: path to the figure template.

## Output

`analysis/06-figures.md`. YAML frontmatter `figures:` list with one entry per file in `IMAGES_DIR`. Each entry:
- `file` (basename only)
- `caption` (string; the paper's caption verbatim, or "" if none found)
- `importance` (float in [0.0, 1.0], 2 decimal places)
- `role` (one of: architecture, pipeline, main-result, ablation, qualitative, other)

After frontmatter, one `## Figure N` section per figure, in the same order as the frontmatter list. Each section: 2-4 sentences explaining what the figure shows, what to read off it, why it matters.

## Instructions

1. List files in `IMAGES_DIR`.
2. For each, find its caption in `PAPER_TEXT` by matching figure number. If filename has no number, infer from order or page context.
3. Score importance:
   - 1.0: the architecture diagram OR the headline-result figure
   - 0.7-0.9: a key ablation, key intuition diagram, or paper's lead qualitative example
   - 0.4-0.6: secondary results or supporting illustrations
   - 0.1-0.3: incidental, repetitive, or appendix-quality
   - 0.0: probably not a real figure (extracted artifact, decorative banner)
4. Pick `role` based on the figure's purpose.
5. Write the explanation: not a re-statement of the caption, but a "what this means" reading.

## Quality bar

- Importance scores are usable for picking 1 figure (xhs) and 2-3 figures (wechat). Exactly one figure should be ≥ 0.9 (the most important one).
- Caption field is verbatim text, not a paraphrase.
- Explanation tells a non-specialist why the figure matters.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/figure-interpreter.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): figure-interpreter prompt"
```

---

### Task 14: Prompt — reviewer-synthesizer

**Files:**
- Create: `paper-deepstudy/prompts/reviewer-synthesizer.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "reviewer-synthesizer.md has required sections" {
  run check_prompt prompts/reviewer-synthesizer.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the prompt**

`paper-deepstudy/prompts/reviewer-synthesizer.md`:

```markdown
# Prompt: reviewer-synthesizer

## Role

You write the v1 review report from the deep-analysis files. You apply hybrid ML + computational-biology reviewer standards. **You do not read the paper directly.** Everything you need is in the analysis files. If you find a needed fact missing, note the gap explicitly in your output.

## Inputs

- `ANALYSIS_DIR`: contains `00-paper-profile.md` through `06-figures.md`.
- `DOMAIN_PACKS`: paths to selected domain packs.
- `OUTPUT_PATH`: `review.md` path.
- `TEMPLATE_PATH`: review template path.

## Output

`review.md` per template:
- `## Summary` (neutral 1 paragraph)
- `## Significance` (why this matters)
- `## Strengths` (3-7 bullets)
- `## Weaknesses` with subsections: `### Methodological`, `### Experimental`, `### Bio-rigor` (only if a bio pack is in scope)
- `## Questions to Authors`
- `## Suggestions`
- `## Score` (Soundness / Presentation / Contribution / Overall)
- `## Confidence` (1-5)

Each individual entry under Strengths / Weaknesses / Questions / Suggestions ends with `← from initial analysis` (later rounds will append entries with `← from round-NN`).

## Instructions

1. Read all `ANALYSIS_DIR/*.md` files.
2. Read each domain pack's `## Reviewer checklist`. These are your checkpoints for what to weigh.
3. Summary: paraphrase from `00-paper-profile.md` `claims_summary` and `01-problem.md`.
4. Significance: from `01-problem.md` field-level context + `05-prior-work.md` lineage.
5. Strengths: 3-7 bullets. Each is concrete: cite specific design choices from `03-method-deep.md` or specific results from `04-experiments.md`. No generic "well-written".
6. Weaknesses:
   - **Methodological**: from `03-method-deep.md`'s alternatives, design rationale gaps, and reproduction risks.
   - **Experimental**: from `04-experiments.md`'s critique. Coverage gaps, soundness issues, missing variance.
   - **Bio-rigor**: only include section if profile's `domain` is one of `ml-bio-hybrid | cs-bio | wet-lab-heavy`. Use bio pack's checklist. If the analyses don't have material here, write "No bio-rigor concerns surfaced from analysis."
7. Questions to Authors: things you'd ask in a rebuttal — clarifications, missing baselines, statistical questions.
8. Suggestions: actionable improvements (orthogonal to weaknesses; positive framing).
9. Score: integer 1-10 overall, 1-4 sub-scores per ICLR convention. Be honest. Don't default to 5.
10. Confidence: 1 (not knowledgeable) to 5 (expert).

## Quality bar

- No bullet point references the paper directly; every claim is grounded in an analysis file. If you can't ground it, drop it.
- If a section in the analysis files is `<!-- FAILED: ... -->`, mention this gap in `## Suggestions` (e.g. "Re-run prior-work analysis; comparison with X is missing").
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/reviewer-synthesizer.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): reviewer-synthesizer prompt"
```

---

### Task 15: Prompts — notes-writer + title-generator

**Files:**
- Create: `paper-deepstudy/prompts/notes-writer.md`
- Create: `paper-deepstudy/prompts/title-generator.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing tests**

```bash
@test "notes-writer.md has required sections" {
  run check_prompt prompts/notes-writer.md
  [ "$status" -eq 0 ]
}

@test "title-generator.md has required sections" {
  run check_prompt prompts/title-generator.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write notes-writer prompt**

`paper-deepstudy/prompts/notes-writer.md`:

```markdown
# Prompt: notes-writer

## Role

You write a Chinese learning-notes source file that two later renderers (xhs / wechat) consume. You do **not** read the paper text directly; you read the analysis files. Style: 转述视角 ("作者提出..."), 公式尽量翻译为大白话, 不使用 emoji.

## Inputs

- `ANALYSIS_DIR`: paths to `00`-`06`.
- `OUTPUT_PATH`: `notes/source.md`.
- `TEMPLATE_PATH`: notes-source template.

## Output

`notes/source.md` with the 9 fixed sections (in Chinese):

1. 一句话讲清楚这篇 paper 在干嘛
2. 它要解决的问题是什么
3. 现有方案为什么不够
4. 这篇的核心 idea
5. 方法是怎么 work 的
6. 实验结果
7. 它和前人工作的关系
8. 局限 / 没解决的问题
9. 一句话总结 take-away

If a section has no material from analysis, write `<!-- N/A: <reason> -->` instead of fabricating content.

## Instructions

1. Read all analysis files.
2. Section 1: derive from `00-paper-profile.md` `claims_summary[0]` + `01-problem.md` specific-problem paragraph.
3. Section 2: from `01-problem.md` field-level context + specific problem.
4. Section 3: from `01-problem.md` "Why prior approaches fall short" + `05-prior-work.md` "Inherits vs invents".
5. Section 4: from `03-method-deep.md` "High-level idea" + key insight from `02-formalization.md`.
6. Section 5: from `03-method-deep.md` "Components" + "Algorithm flow". Translate equations to plain language; if a single formula is iconic, you may keep it but follow with a plain-language explanation.
7. Section 6: from `04-experiments.md` "Headline results" — pick the 1-2 most striking numbers.
8. Section 7: from `05-prior-work.md` lineage and inherits-vs-invents.
9. Section 8: from `04-experiments.md` "Critique" + `03-method-deep.md` "Reproduction risks".
10. Section 9: one sentence; capture the take-away a curious reader should walk away with.

## Quality bar

- Length: aim for 3000-4000 Chinese characters total.
- No emoji anywhere.
- 转述视角: use phrases like "作者提出 / 作者发现 / 这篇工作展示了" rather than "this paper proposes" or "我们提出".
- Plain language; specialist terms used only when the analysis files use them and they're load-bearing.
```

- [ ] **Step 4: Write title-generator prompt**

`paper-deepstudy/prompts/title-generator.md`:

```markdown
# Prompt: title-generator

## Role

You generate Chinese title candidates for both xhs (Xiaohongshu) and wechat (公众号) renderings. No emoji. 转述视角.

## Inputs

- `SOURCE_PATH`: `notes/source.md`.
- `OUTPUT_PATH`: `notes/titles.md`.
- `TEMPLATE_PATH`: titles template.
- `STYLE_FILTER` (optional): one of `hook | literal | question | numbers | contrast`. If absent, generate one of each style.

## Output

`notes/titles.md` with two groups (`## xhs` and `## wechat`), each a numbered list of 5 candidates. Each candidate ends with `— style: <hook|literal|question|numbers|contrast>`.

## Instructions

1. Read `SOURCE_PATH` to understand the paper.
2. xhs candidates: catchy, ≤ 22 Chinese characters; allowed styles:
   - **hook**: a curiosity-inducing tease ("这篇 paper 把 X 重新定义了")
   - **literal**: descriptive but tighter than the original title ("scVI:用 VAE 给单细胞建模型的开山之作")
   - **question**: poses a question the reader will want answered ("foundation model 真的适用于单细胞吗?")
   - **numbers**: lead with a striking number ("3000 万细胞预训练后,Geneformer 在零样本任务上 ...")
   - **contrast**: A vs B framing ("scVI vs Harmony:谁才是单细胞 batch correction 的标准答案?")
3. wechat candidates: more substantive, ≤ 32 Chinese characters; same style menu but more room for a sub-line.
4. Append `## history` section as an empty placeholder (used later when titles get retitled).

## Quality bar

- All 10 candidates are distinct in framing, not just rephrased.
- Each has a clearly assigned style.
- No emoji anywhere.
```

- [ ] **Step 5: Run, verify pass**

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/prompts/notes-writer.md paper-deepstudy/prompts/title-generator.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): notes-writer and title-generator prompts"
```

---

### Task 16: Prompts — xhs-renderer + wechat-renderer

**Files:**
- Create: `paper-deepstudy/prompts/xhs-renderer.md`
- Create: `paper-deepstudy/prompts/wechat-renderer.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Add failing tests**

```bash
@test "xhs-renderer.md has required sections" {
  run check_prompt prompts/xhs-renderer.md
  [ "$status" -eq 0 ]
}

@test "wechat-renderer.md has required sections" {
  run check_prompt prompts/wechat-renderer.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write xhs-renderer prompt**

`paper-deepstudy/prompts/xhs-renderer.md`:

```markdown
# Prompt: xhs-renderer

## Role

Render the source notes into a Xiaohongshu-style article. You consume `source.md`, `titles.md`, and a list of selected figure files. You do not modify `source.md`.

## Inputs

- `SOURCE_PATH`, `TITLES_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `SELECTED_FIGURES`: list of paths to 1 figure file (xhs uses 1).
- `EDIT_INSTRUCTION` (optional): user instruction during refinement, e.g. "shorten paragraph 3" or "regenerate with more concrete examples". When present, the existing `xhs.md` is also provided at `EXISTING_PATH`.

## Output

`notes/xhs.md` with frontmatter (title, length_target, length_max, figures) and body. Hard caps:
- Length: 1300 Chinese characters maximum (target 1000).
- Paragraphs: 1-3 sentences each.
- Subheadings: required, ≤ 12 chars each.
- Figures embedded: exactly 1.
- Formulas: none in raw form. Translate every equation to plain language.
- References: none.
- CTA: none.
- Emoji: none.

## Instructions

1. Read `SOURCE_PATH`, `TITLES_PATH`, optional `EXISTING_PATH`.
2. Pick title: take `titles.md` xhs item 1. Move other 4 xhs candidates into the file's footer comment as alts.
3. Structure:
   - Hook section (no heading, 1-3 sentences) — derived from source section 1 + 4 take-away.
   - 3-5 short subsections, each with a tight subheading and 1-3 short paragraphs.
   - Cover roughly: 问题 / 核心 idea / 方法关键点 / 结果 / 局限.
   - Embed the figure with `![<short caption>](<figure-path>)` after the most relevant subsection.
4. Length: count Chinese characters (excluding markdown syntax). Stop at 1300; aim for 1000.
5. If `EDIT_INSTRUCTION` is present, apply it minimally — change only what's needed.

## Quality bar

- Fits Xiaohongshu rhythm: short paragraphs, subheadings every ~150-200 chars.
- One figure clearly placed; not just appended at the end without context.
- No equations, no emoji, no CTA. Stay 转述视角.
```

- [ ] **Step 4: Write wechat-renderer prompt**

`paper-deepstudy/prompts/wechat-renderer.md`:

```markdown
# Prompt: wechat-renderer

## Role

Render the source notes into a WeChat 公众号-style article. Consume `source.md`, `titles.md`, and selected figures.

## Inputs

- `SOURCE_PATH`, `TITLES_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `SELECTED_FIGURES`: list of paths to 2-3 figure files.
- `EDIT_INSTRUCTION` and `EXISTING_PATH` (optional, same semantics as xhs).

## Output

`notes/wechat.md`:
- Length target: 3000 chars; max: 4000.
- Paragraphs: long allowed.
- Subheadings: required.
- Figures embedded: 2-3.
- Formulas: 1-2 key formulas allowed (in `$$ ... $$`), each followed by 1-2 sentences plain-language explanation.
- References: up to 3 key references with links at end.
- CTA: none.
- Emoji: none.

## Instructions

1. Read `SOURCE_PATH`, `TITLES_PATH`, optional `EXISTING_PATH`.
2. Pick title: `titles.md` wechat item 1. Move other 4 to footer comment.
3. Structure:
   - 导语 (1-2 paragraphs) — set the stage.
   - `## 背景` — from source sections 2-3.
   - `## 核心 idea` — from source section 4.
   - `## 方法` — from source section 5; may include 1-2 key formulas.
   - `## 实验` — from source section 6.
   - `## 局限和未来` — from source section 8.
   - `## 一句话总结` — from source section 9.
   - `**参考文献**` — up to 3 references with links if available from `05-prior-work.md`.
4. Embed figures at relevant points:
   - Architecture / pipeline figure goes in `## 方法`.
   - Main-result figure goes in `## 实验`.
   - Optional third figure in `## 核心 idea` or `## 背景`.
5. Length: 3000 target, 4000 hard cap.
6. If `EDIT_INSTRUCTION`, apply minimally.

## Quality bar

- Reads like a curated public-facing article, not a chunked source dump.
- Formulas always followed by plain-language explanation in the same paragraph.
- Figures embedded contextually, not appended.
- No emoji, no CTA. 转述视角.
```

- [ ] **Step 5: Run, verify pass**

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/prompts/xhs-renderer.md paper-deepstudy/prompts/wechat-renderer.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): xhs and wechat renderer prompts"
```

---

### Task 17: Figure-selection helper script

**Files:**
- Create: `paper-deepstudy/scripts/select-figures.cjs`
- Create: `paper-deepstudy/tests/unit/test-select-figures.cjs`
- Modify: `paper-deepstudy/package.json` (re-extend `test:unit`)

- [ ] **Step 1: Write the failing node test**

`paper-deepstudy/tests/unit/test-select-figures.cjs` (`require()` paths are relative to this file's location):

```javascript
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { selectFigures } = require('../../scripts/select-figures.cjs');

// Create a temp dir with a fake 06-figures.md
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pds-test-'));
try {
  const figuresMd = `---
figures:
  - file: figure-1.png
    caption: "Architecture overview"
    importance: 0.95
    role: architecture
  - file: figure-2.png
    caption: "Main results"
    importance: 0.85
    role: main-result
  - file: figure-3.png
    caption: "Ablation"
    importance: 0.6
    role: ablation
  - file: figure-4.png
    caption: "Decorative"
    importance: 0.1
    role: other
---

# Figures
`;
  fs.writeFileSync(path.join(tmp, '06-figures.md'), figuresMd);

  // Test xhs (1 figure): should pick the highest-importance one
  const xhsPicks = selectFigures(path.join(tmp, '06-figures.md'), 1);
  assert.deepEqual(xhsPicks.map(p => p.file), ['figure-1.png']);

  // Test wechat (3 figures): should pick top-3 by importance
  const wechatPicks = selectFigures(path.join(tmp, '06-figures.md'), 3);
  assert.deepEqual(wechatPicks.map(p => p.file), ['figure-1.png', 'figure-2.png', 'figure-3.png']);

  // Test wechat with only 2 high-importance: should pick what's available, dedup low
  const figuresMd2 = `---
figures:
  - file: f1.png
    caption: ""
    importance: 0.9
    role: architecture
  - file: f2.png
    caption: ""
    importance: 0.8
    role: main-result
---
`;
  fs.writeFileSync(path.join(tmp, 'few-figs.md'), figuresMd2);
  const fewPicks = selectFigures(path.join(tmp, 'few-figs.md'), 3);
  assert.deepEqual(fewPicks.map(p => p.file), ['f1.png', 'f2.png']);

  // Test bad path: throws
  assert.throws(() => selectFigures('/no/such/file', 1));

  console.log('select-figures: all tests passed');
} finally {
  fs.rmSync(tmp, { recursive: true });
}
```

- [ ] **Step 2: Run, verify fail**

Run: `node paper-deepstudy/tests/unit/test-select-figures.cjs`
Expected: `Cannot find module ... select-figures.cjs`.

- [ ] **Step 3: Write the script**

`paper-deepstudy/scripts/select-figures.cjs`:

```javascript
#!/usr/bin/env node
// Pure-logic figure picker. Reads `analysis/06-figures.md`, returns top-N by importance.
const fs = require('node:fs');

function parseFiguresFrontmatter(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const match = text.match(/^---\n([\s\S]*?)\n---/);
  if (!match) throw new Error(`No YAML frontmatter in ${filePath}`);
  const yaml = match[1];

  // Lightweight parse: we only need the `figures:` list.
  const lines = yaml.split('\n');
  const figures = [];
  let current = null;
  for (const line of lines) {
    if (/^\s*-\s+file:\s*/.test(line)) {
      if (current) figures.push(current);
      current = { file: line.replace(/^\s*-\s+file:\s*/, '').trim() };
    } else if (current) {
      const m = line.match(/^\s+(caption|importance|role):\s*(.*)$/);
      if (m) {
        const [, key, raw] = m;
        let val = raw.trim();
        if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
        if (key === 'importance') val = parseFloat(val);
        current[key] = val;
      }
    }
  }
  if (current) figures.push(current);
  return figures;
}

function selectFigures(figuresMdPath, n) {
  const figures = parseFiguresFrontmatter(figuresMdPath);
  return figures
    .filter(f => typeof f.importance === 'number' && f.importance > 0.3)
    .sort((a, b) => b.importance - a.importance)
    .slice(0, n);
}

if (require.main === module) {
  const [path, nStr] = process.argv.slice(2);
  if (!path || !nStr) {
    console.error('usage: select-figures.cjs <06-figures.md path> <n>');
    process.exit(1);
  }
  const picks = selectFigures(path, parseInt(nStr, 10));
  console.log(JSON.stringify(picks, null, 2));
}

module.exports = { selectFigures, parseFiguresFrontmatter };
```

```bash
chmod +x paper-deepstudy/scripts/select-figures.cjs
```

- [ ] **Step 4: Run, verify pass**

Run: `node paper-deepstudy/tests/unit/test-select-figures.cjs`
Expected: `select-figures: all tests passed`.

- [ ] **Step 5: Re-extend `paper-deepstudy/package.json`'s `test:unit` script**

Edit the script back to its full form (it was minimized in Task 1 because `test-select-figures.cjs` did not exist yet):

```json
"test:unit": "bats tests/unit && node tests/unit/test-select-figures.cjs"
```

Verify: `cd paper-deepstudy && npm run test:unit` runs both bats and node tests successfully.

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/scripts/select-figures.cjs paper-deepstudy/tests/unit/test-select-figures.cjs paper-deepstudy/package.json
git commit -m "feat(paper-deepstudy): figure selection helper script and tests"
```

---

### Task 18: Main orchestration skill — Stages 0 & 1

**Files:**
- Create: `paper-deepstudy/skills/study-deep/SKILL.md`

This task creates the main orchestration skill but covers only Stages 0 and 1. Stages 2 and 3 are added in Tasks 19 and 20.

- [ ] **Step 1: Write the skill — Stages 0 + 1**

`paper-deepstudy/skills/study-deep/SKILL.md`:

```markdown
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

## Stages 2 & 3

(Continued in subsequent skill content; see Tasks 19, 20 in the implementation plan — they extend this file.)
```

- [ ] **Step 2: Smoke-test that the skill file is well-formed**

Add to `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats` (paths relative to `paper-deepstudy/`):

```bash
@test "study-deep SKILL.md has YAML frontmatter with name" {
  head -5 skills/study-deep/SKILL.md | grep -qF 'name: study-deep'
}

@test "study-deep SKILL.md mentions paper-profiler dispatch" {
  grep -qF 'paper-profiler' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md mentions all 6 Stage 1 sub-agents" {
  for s in problem-framer formalizer method-analyst experiment-critic prior-work-historian figure-interpreter; do
    grep -qF "$s" skills/study-deep/SKILL.md || return 1
  done
}
```

- [ ] **Step 3: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): study-deep skill stages 0 and 1"
```

---

### Task 19: Orchestration skill — Stage 2

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`

- [ ] **Step 1: Add failing test**

Add to `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "study-deep SKILL.md has Stage 2 section" {
  grep -qF '## Stage 2: Review generation' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md mentions reviewer-synthesizer dispatch" {
  grep -qF 'reviewer-synthesizer' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Replace the placeholder Stages 2 & 3 section with Stage 2 content**

Edit `paper-deepstudy/skills/study-deep/SKILL.md`. Replace:

```
## Stages 2 & 3

(Continued in subsequent skill content; see Tasks 19, 20 in the implementation plan — they extend this file.)
```

with:

```markdown
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

## Stages 3

(Stage 3 is added in Task 20.)
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): study-deep skill Stage 2"
```

---

### Task 20: Orchestration skill — Stage 3

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`

- [ ] **Step 1: Add failing tests**

```bash
@test "study-deep SKILL.md has Stage 3 section" {
  grep -qF '## Stage 3: Notes generation' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md mentions all 4 Stage 3 sub-agents" {
  for s in notes-writer title-generator xhs-renderer wechat-renderer; do
    grep -qF "$s" skills/study-deep/SKILL.md || return 1
  done
}

@test "study-deep SKILL.md mentions select-figures.cjs" {
  grep -qF 'select-figures.cjs' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Replace the Stage 3 placeholder**

Replace `## Stages 3\n\n(Stage 3 is added in Task 20.)` with:

```markdown
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
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): study-deep skill Stage 3 and final summary"
```

---

### Task 21: Idempotence — skip-existing logic + `--force` + `--yes`

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`

- [ ] **Step 1: Add failing test**

```bash
@test "study-deep SKILL.md documents --force flag" {
  grep -qF '--force' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md documents --yes flag" {
  grep -qF '--yes' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md describes skip-existing default" {
  grep -qiF 'skip' skills/study-deep/SKILL.md && \
    grep -qF '.bak.' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Add an "Idempotence and re-runs" section**

After Stage 0's intro and before Stage 0.1, insert:

```markdown
### Idempotence and re-runs

Default behavior (no flags): for each output file, if it already exists, skip the corresponding sub-Agent dispatch. Skipped files are reported in the final summary.

`--force`: for each output file that exists, copy it to `<file>.bak.NN` (where NN is the smallest non-existent integer ≥ 1) before re-running.

`--yes`: skip the Stage 0 confirmation prompt. Use the auto-detected profile.

`--only <stage>` (used by `/paper:rerun-<stage>`): rerun only the named stage (`profile | analysis | review | notes`), backing up its outputs first. Implemented as `--force` scoped to that stage's output paths.
```

- [ ] **Step 4: In each Stage's "Dispatch" sub-step, add a check before dispatching**

For each sub-Agent dispatch, prefix:

```
If OUTPUT_PATH exists and --force is not set, log "skipping <subagent> (output exists)" and do not dispatch.
If OUTPUT_PATH exists and --force is set, copy to OUTPUT_PATH.bak.NN first, then dispatch.
```

- [ ] **Step 5: Run, verify pass**

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): idempotence and --force/--yes flags in study-deep"
```

---

### Task 22: `/paper:study` command file

**Files:**
- Create: `paper-deepstudy/commands/study.md`
- Create: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Failing test**

`paper-deepstudy/tests/unit/test-commands.bats` (paths relative to `paper-deepstudy/`; `setup()` cds to plugin root):

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "study.md exists with frontmatter" {
  head -1 commands/study.md | grep -qE '^---$'
}

@test "study.md invokes the study-deep skill" {
  grep -qF 'study-deep' commands/study.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/study.md`:

```markdown
---
name: paper:study
description: Deep-study a paper for ML / computational biology. Produces analysis files, a review draft, and Chinese xhs/wechat learning notes.
argument-hint: "<pdf-path-or-url> [--yes] [--force]"
---

# /paper:study

Invokes the `study-deep` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:study /path/to/paper.pdf`
- `/paper:study https://arxiv.org/abs/1706.03762`
- `/paper:study /path/to/paper.pdf --yes` (skip Stage 0 confirmation)
- `/paper:study /path/to/paper.pdf --force` (re-run all stages)

Use the `study-deep` skill with the user-provided argument. Pass through `--yes` and `--force` if present.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/study.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:study command"
```

---

### Task 23: `/paper:rerun-stage` command

**Files:**
- Create: `paper-deepstudy/commands/rerun-stage.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Add failing test**

```bash
@test "rerun-stage.md has frontmatter" {
  head -1 commands/rerun-stage.md | grep -qE '^---$'
}

@test "rerun-stage.md mentions all 4 stages" {
  for s in profile analysis review notes; do
    grep -qF "$s" commands/rerun-stage.md || return 1
  done
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/rerun-stage.md`:

```markdown
---
name: paper:rerun-stage
description: Re-run a specific stage of paper-deepstudy on the most recently studied paper.
argument-hint: "<stage> [--paper <slug>]"
---

# /paper:rerun-stage

Re-runs one stage of the auto-run pipeline, backing up existing outputs to `.bak.NN`.

Stages:
- `profile` — re-runs `paper-profiler`, regenerates `analysis/00-paper-profile.md`. May change downstream selections, but does not auto-rerun later stages.
- `analysis` — re-runs all six Stage 1 sub-agents, overwriting `analysis/01`–`06`.
- `review` — re-runs `reviewer-synthesizer`, overwriting `review.md`. Note: this loses any edits from `/paper:review-round`. Confirm with user first.
- `notes` — re-runs Stage 3 (notes-writer + title-generator + both renderers).

Optional `--paper <slug>` to target a specific paper folder; default is the most recently modified `~/claude-papers/papers/<slug>/`.

Implementation: invoke `study-deep` skill with `--only <stage>`.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/rerun-stage.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:rerun-stage command"
```

---

### Task 24: Integration test harness (smoke)

**Files:**
- Create: `paper-deepstudy/tests/integration/test-end-to-end.sh`
- Create: `paper-deepstudy/tests/fixtures/tiny-paper/meta.json`
- Create: `paper-deepstudy/tests/fixtures/tiny-paper/summary.md`

This test does not actually invoke Claude (which would require a live LLM). It:
1. Verifies the plugin's static contract is intact (all files referenced by the skill exist).
2. Runs the figure-selection script on a fake `06-figures.md`.
3. Validates that the SKILL.md, when rendered as markdown, has no broken internal references (a script greps for every path mentioned in the skill and confirms the file exists).

Live LLM end-to-end testing is a manual step described in the README.

- [ ] **Step 1: Failing test**

`paper-deepstudy/tests/integration/test-end-to-end.sh` — script lives at `paper-deepstudy/tests/integration/`, so `$(dirname "$0")/../..` resolves to the plugin root (`paper-deepstudy/`):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve to plugin root: tests/integration/ -> tests/ -> paper-deepstudy/
cd "$(dirname "$0")/../.."

ROOT=.
SKILL=$ROOT/skills/study-deep/SKILL.md

fail=0

# 1. All prompt files referenced by the skill exist
for p in paper-profiler problem-framer formalizer method-analyst experiment-critic prior-work-historian figure-interpreter reviewer-synthesizer notes-writer title-generator xhs-renderer wechat-renderer; do
  if ! grep -qF "$p" $SKILL; then
    echo "FAIL: skill does not mention prompt $p"; fail=1
  fi
  if [ ! -f "$ROOT/prompts/$p.md" ]; then
    echo "FAIL: prompt file missing: $ROOT/prompts/$p.md"; fail=1
  fi
done

# 2. All template files referenced by the skill exist
for t in templates/analysis/00-paper-profile.md templates/analysis/01-problem.md templates/analysis/02-formalization.md templates/analysis/03-method-deep.md templates/analysis/04-experiments.md templates/analysis/05-prior-work.md templates/analysis/06-figures.md templates/review.md templates/notes/source.md templates/notes/titles.md templates/notes/xhs.md templates/notes/wechat.md; do
  if [ ! -f "$ROOT/$t" ]; then
    echo "FAIL: template missing: $ROOT/$t"; fail=1
  fi
done

# 3. select-figures script exists and is executable
if [ ! -x "$ROOT/scripts/select-figures.cjs" ]; then
  echo "FAIL: select-figures.cjs missing or not executable"; fail=1
fi

# 4. verify-prereqs script exists and is executable
if [ ! -x "$ROOT/scripts/verify-prereqs.sh" ]; then
  echo "FAIL: verify-prereqs.sh missing or not executable"; fail=1
fi

# 5. Domain packs exist
for d in ml-pure single-cell _template; do
  if [ ! -f "$ROOT/domain-packs/$d.md" ]; then
    echo "FAIL: domain pack missing: $d.md"; fail=1
  fi
done

# 6. Commands exist
for c in study rerun-stage; do
  if [ ! -f "$ROOT/commands/$c.md" ]; then
    echo "FAIL: command missing: $c.md"; fail=1
  fi
done

if [ $fail -ne 0 ]; then
  echo "Integration smoke test: FAILED"; exit 1
fi

echo "Integration smoke test: PASSED"
```

```bash
chmod +x paper-deepstudy/tests/integration/test-end-to-end.sh
```

`paper-deepstudy/tests/fixtures/tiny-paper/meta.json`:

```json
{
  "title": "A Tiny Test Paper",
  "authors": ["Test Author"],
  "abstract": "A minimal abstract used as a fixture for static tests.",
  "githubLinks": [],
  "codeLinks": []
}
```

`paper-deepstudy/tests/fixtures/tiny-paper/summary.md`:

```markdown
# A Tiny Test Paper

This is the extracted text fixture for static testing. Real integration tests against a live LLM happen manually per the plugin README.
```

- [ ] **Step 2: Run, verify pass (since prior tasks created the prerequisites)**

Run: `paper-deepstudy/tests/integration/test-end-to-end.sh`
Expected: `Integration smoke test: PASSED`.

- [ ] **Step 3: Commit**

```bash
git add paper-deepstudy/tests/integration/test-end-to-end.sh paper-deepstudy/tests/fixtures/tiny-paper
git commit -m "test(paper-deepstudy): integration smoke harness and fixtures"
```

---

### Task 25: README update + manual integration recipe

**Files:**
- Modify: `paper-deepstudy/README.md`

- [ ] **Step 1: Failing test**

Append to `paper-deepstudy/tests/unit/test-commands.bats` (paths relative to `paper-deepstudy/`):

```bash
@test "README mentions live integration steps" {
  grep -qF 'Manual integration test' README.md
}

@test "README lists 12 expected outputs" {
  grep -qF '12 outputs' README.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Replace `paper-deepstudy/README.md` with full version**

`paper-deepstudy/README.md`:

```markdown
# paper-deepstudy

Deep paper study for ML and computational-biology papers. Layers on top of `claude-paper:study` to add:

- Deep analysis (problem framing, formal definition, methodology, experiments, prior-work timeline, figure interpretation) — English
- Iterative review with adversarial review rounds — English (review rounds in Plan 2)
- Chinese learning notes for Xiaohongshu / WeChat from a unified source — Chinese

## Install (local dev)

```
# from this repo's root:
/plugin install ./paper-deepstudy
```

Requires `claude-paper:study` already installed.

## Usage

### One-shot auto-run

```
/paper:study /path/to/paper.pdf
/paper:study https://arxiv.org/abs/1706.03762
/paper:study /path/to/paper.pdf --yes      # skip Stage 0 confirmation
/paper:study /path/to/paper.pdf --force    # re-run all stages with backups
```

### Re-run a specific stage

```
/paper:rerun-stage analysis
/paper:rerun-stage review
/paper:rerun-stage notes
/paper:rerun-stage profile
```

## What you get (12 outputs)

Under `~/claude-papers/papers/<slug>/`:

```
analysis/
  00-paper-profile.md       # type, domain, difficulty (English, YAML frontmatter)
  01-problem.md             # background and framing (English)
  02-formalization.md       # math definitions, loss, constraints (English)
  03-method-deep.md         # method with rationale and alternatives (English)
  04-experiments.md         # experiment critique (English)
  05-prior-work.md          # timeline + comparison (English)
  06-figures.md             # per-figure interpretation + scoring (English)
review.md                   # v1 review report (English)
notes/
  source.md                 # unified source content (Chinese)
  titles.md                 # 5+5 candidate titles (Chinese)
  xhs.md                    # Xiaohongshu rendering (Chinese, ~1000 chars)
  wechat.md                 # WeChat rendering (Chinese, ~3000 chars)
```

## Manual integration test

The included `tests/integration/test-end-to-end.sh` is a static smoke test only. To verify against a real paper end-to-end:

1. `/paper:study https://arxiv.org/abs/1706.03762` (Attention Is All You Need)
2. Verify all 12 files exist under `~/claude-papers/papers/attention-is-all-you-need/` (or whatever slug claude-paper:study assigns).
3. Spot-check:
   - `analysis/00-paper-profile.md` should classify it as `paper_type: architecture`, `domain: ml-pure`.
   - `analysis/02-formalization.md` should contain the attention equation in `$$ ... $$`.
   - `notes/xhs.md` should be ≤ 1300 Chinese chars and have exactly 1 figure.
   - `notes/wechat.md` should be ≤ 4000 chars and have 2-3 figures.
   - `review.md` should have a Score and Confidence value (not the placeholder underscores).
4. Repeat with a single-cell paper (e.g. arXiv preprint of scVI or scGPT) and confirm `domain_packs_selected` includes `single-cell`.

## Roadmap

- **Plan 1 (this):** auto-run pipeline, `ml-pure` and `single-cell` packs.
- **Plan 2:** `/paper:review-round` adversarial loop.
- **Plan 3:** seven refinement commands (`refine-notes`, `deep-dive`, `compare`, `reselect-figures`, `retitle`, `add-prior-work`, `reproduce-check`).
- **Plan 4:** five more domain packs (`protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`).
```

- [ ] **Step 4: Run, verify pass**

```bash
bats paper-deepstudy/tests/unit/test-commands.bats
paper-deepstudy/tests/integration/test-end-to-end.sh
```

- [ ] **Step 5: Final commit**

```bash
git add paper-deepstudy/README.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "docs(paper-deepstudy): README with 12 outputs, manual integration recipe, and roadmap"
```

---

## Self-Review checklist (run after Plan 1 complete)

- [ ] All 12 expected outputs (7 analysis + review + 4 notes) generated for at least one ML and one comp-bio paper.
- [ ] `bats paper-deepstudy/tests/unit/*.bats` passes (or `cd paper-deepstudy && npm run test:unit`).
- [ ] `node paper-deepstudy/tests/unit/test-select-figures.cjs` passes.
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` passes.
- [ ] `--yes` skips Stage 0 confirmation.
- [ ] `--force` backs up existing files to `.bak.NN`.
- [ ] Default re-run skips existing files.
- [ ] Sub-Agent failure produces `<!-- FAILED: ... -->` placeholder; pipeline continues.
- [ ] Final summary lists all 12 outputs with ✓ or FAILED.
- [ ] Plugin manifest validates as JSON.
- [ ] Domain pack selection respects user override after Stage 0.
- [ ] xhs/wechat outputs respect length, figure count, and no-emoji rules.

If any box fails to check, write a follow-up task and resolve before declaring Plan 1 complete.
