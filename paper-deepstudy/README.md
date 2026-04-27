# paper-deepstudy

Deep paper study for ML and computational-biology papers. Layers on top of `claude-paper:study` to add:

- Deep analysis (problem framing, formal definition, methodology, experiments, prior-work timeline, figure interpretation) — English
- Iterative review with adversarial review rounds (`/paper:review-round`) — English
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

- **Plan 1:** auto-run pipeline, `ml-pure` and `single-cell` packs.
- **Plan 2 (this branch):** `/paper:review-round` adversarial loop. ✓
- **Plan 3a (this branch):** notes UX commands — `refine-notes`, `retitle`, `reselect-figures`. ✓
- **Plan 3b (future):** analysis-extension commands — `deep-dive`, `compare`, `add-prior-work`.
- **Plan 3c (future):** `reproduce-check` audit command.
- **Plan 4 (this branch):** five more domain packs (`protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`). ✓
