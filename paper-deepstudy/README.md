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
