# paper-deepstudy

Deep paper study for ML and computational-biology papers. Layers on top of `claude-paper:study` to add:

- Deep analysis (problem framing, formal definition, methodology, experiments, prior-work timeline, figure interpretation) — English
- Iterative review with adversarial review rounds (`/paper:review-round`) — English
- Analysis extension commands (`/paper:deep-dive`, `/paper:compare`, `/paper:add-prior-work`) — augment the auto-run analysis with deep dives, comparisons, and missed prior-work entries
- Reproducibility audit (`/paper:reproduce-check`) — structured 7-dimension audit (data, code, hyperparameters, seeds, hardware, eval scripts, wet-lab protocol)
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

### Adversarial review round

```
/paper:review-round
/paper:review-round --paper attention-is-all-you-need
/paper:review-round --sequential
```

Interactively raise objections to the paper. The plugin dispatches a defense-agent (arguing for the authors) and a judge-agent (blind to the paper, rules on the defense's logic). You have final say. Accepted objections are appended to `review.md`; every round is persisted at `review-rounds/round-NN-<title>.md`.

### Refine the rendered notes

After /paper:study has produced notes/xhs.md and notes/wechat.md, you can iterate without re-running the full pipeline:

```
/paper:refine-notes xhs              # apply an edit instruction to xhs.md
/paper:refine-notes wechat           # apply an edit instruction to wechat.md
/paper:retitle xhs                   # regenerate 5 title candidates, pick one
/paper:retitle wechat --style hook   # bias candidates toward a style
/paper:reselect-figures              # re-pick which figures get embedded
/paper:reselect-figures --reinterpret  # re-run figure-interpreter first, then re-pick
```

All three commands back up the prior version as `notes/<file>.bak.NN` before mutating, so you can roll back any time.

### Analysis extensions

After /paper:study has produced the analysis directory, three commands let you go deeper:

```
/paper:deep-dive "contrastive loss derivation"             # focused topic deep-dive
/paper:compare attention-is-all-you-need                   # head-to-head with another studied paper
/paper:compare ~/Downloads/scvi.pdf                        # auto-studies the PDF first, then compares
/paper:compare attention-is-all-you-need --lang zh         # Chinese prose
/paper:add-prior-work https://arxiv.org/abs/1706.03762     # add a missed prior-work entry (arXiv URL)
/paper:add-prior-work "@article{vaswani2017,...}"          # BibTeX
```

Outputs land at `~/claude-papers/papers/<slug>/`:
- `deep-dives/<topic-slug>.md` per `/paper:deep-dive`
- `compares/vs-<other-slug>.md` per `/paper:compare`
- `analysis/05-prior-work.md` is augmented in place by `/paper:add-prior-work` (with `.bak.NN` backup)

### Reproducibility audit

```
/paper:reproduce-check                              # audit the most recently studied paper
/paper:reproduce-check --paper string-database-2025 # audit a specific paper
```

The skill rates the paper across 7 dimensions (data, code, hyperparameters, seeds, hardware, evaluation scripts, wet-lab protocol). Each dimension gets ✓ / ✗ / partial / N/A with cited evidence (paper page numbers, GitHub URLs verified via WebFetch). For `ml-pure` papers, wet-lab is N/A.

If the audit finds any ✗ or 3+ partials, the skill suggests `/paper:review-round` to convert reproducibility weaknesses into formal weaknesses in `review.md`.

Output: `~/claude-papers/papers/<slug>/reproduce-check.md`. Existing files are backed up to `.bak.NN`.

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
review-rounds/              # one file per /paper:review-round invocation (English)
deep-dives/                 # one file per /paper:deep-dive invocation (English)
compares/                   # one file per /paper:compare invocation (English by default, Chinese with --lang zh)
reproduce-check.md          # reproducibility audit per /paper:reproduce-check (English)
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

- **Plan 1 ✓ (shipped):** auto-run pipeline, `ml-pure` and `single-cell` packs.
- **Plan 2 ✓ (shipped):** `/paper:review-round` adversarial loop.
- **Plan 3a ✓ (shipped):** notes UX commands — `refine-notes`, `retitle`, `reselect-figures`.
- **Plan 3b ✓ (shipped):** analysis-extension commands — `deep-dive`, `compare`, `add-prior-work`.
- **Plan 3c ✓ (this branch):** `reproduce-check` audit command.
- **Plan 4 ✓ (shipped):** five more domain packs (`protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`).
- **Plan 5 ✓ (shipped):** cross-plan polish — Stage 0.2 invocation, --only/--paper flag wiring, helpers + tests.
