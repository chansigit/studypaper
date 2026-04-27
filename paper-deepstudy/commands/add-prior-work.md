---
name: paper:add-prior-work
description: Augment analysis/05-prior-work.md with a new prior work entry that the auto-run pipeline missed. Accepts BibTeX entry, arXiv URL, or free-text "author + year + one-line description". Updates timeline, comparison table, and lineage diagram.
argument-hint: "<ref> [--paper <slug>]"
---

# /paper:add-prior-work

Invokes the `add-prior-work` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:add-prior-work "@inproceedings{vaswani2017attention, title={Attention Is All You Need}, author={Vaswani et al.}, year={2017}}"` — BibTeX entry.
- `/paper:add-prior-work https://arxiv.org/abs/1706.03762` — arXiv URL (skill auto-fetches metadata via WebFetch).
- `/paper:add-prior-work "Vaswani 2017 — introduced the Transformer architecture, displaced RNN/LSTM for long-range sequence modeling"` — free-text "author + year + one-line description".
- `/paper:add-prior-work <ref> --paper string-database-2025` — explicit target paper.

The skill dispatches `prior-work-historian` (the same sub-Agent from Plan 1's Stage 1, now re-invoked with the existing `05-prior-work.md` + the new ref). The historian:
1. Decides where in the chronological timeline the new entry belongs.
2. Adds a row to the comparison table.
3. Updates the lineage diagram if the new entry is structurally significant.
4. Saves the modified `analysis/05-prior-work.md` (with `<file>.bak.NN` backup of the prior version).

If the new entry might affect existing review.md weaknesses about prior-work coverage, the orchestrator suggests `/paper:review-round` afterward.

Pre-requisites: `/paper:study` must have produced `analysis/05-prior-work.md` already.
