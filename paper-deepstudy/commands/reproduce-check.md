---
name: paper:reproduce-check
description: Audit the paper's reproducibility along 7 dimensions (data, code, hyperparameters, seeds, hardware, evaluation scripts, wet-lab protocol). Each dimension rated ✓ / ✗ / partial with cited evidence. Suggests review-round if serious issues are found.
argument-hint: "[--paper <slug>]"
---

# /paper:reproduce-check

Invokes the `reproduce-check` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:reproduce-check` — audit the most recently studied paper.
- `/paper:reproduce-check --paper string-database-2025` — audit a specific paper.

The skill dispatches `reproduce-checker`, which examines 7 dimensions:

1. **Data availability** — datasets, versions, DOIs, private-data callouts
2. **Code availability** — public repo? README + LICENSE? WebFetch verification
3. **Hyperparameters** — learning rate, batch size, optimizer, epochs, model size
4. **Random seeds** — seed value reported? variance across seeds?
5. **Hardware** — GPU type, count, training time, memory
6. **Evaluation scripts** — metrics precisely defined? eval scripts in repo?
7. **Wet-lab protocol** — only for biology / wet-lab papers. ml-pure papers get N/A.

Output: `~/claude-papers/papers/<slug>/reproduce-check.md` with a Summary table, per-dimension sections, and (if any ✗ or ≥3 partials) a "Recommended next steps" section suggesting `/paper:review-round` to convert weaknesses into review.md entries.

The skill backs up an existing `reproduce-check.md` to `<file>.bak.NN` before overwriting.

Pre-requisites: `/paper:study` must have produced the analysis directory + `meta.json`.
