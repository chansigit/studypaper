---
name: paperstudio:rerun-stage
description: Re-run a specific stage of paperstudio on the most recently studied paper.
argument-hint: "<stage> [--paper <slug>]"
---

# /paperstudio:rerun-stage

Re-runs one stage of the auto-run pipeline, backing up existing outputs to `.bak.NN`.

Stages:
- `profile` — re-runs `paper-profiler`, regenerates `analysis/00-paper-profile.md`. May change downstream selections, but does not auto-rerun later stages.
- `analysis` — re-runs all six Stage 1 sub-agents, overwriting `analysis/01`–`06`.
- `review` — re-runs `reviewer-synthesizer`, overwriting `review.md`. Note: this loses any edits from `/paperstudio:review-round`. Confirm with user first.
- `notes` — re-runs Stage 3 (notes-writer + title-generator + both renderers).

Optional `--paper <slug>` to target a specific paper folder; default is the most recently modified `~/claude-papers/papers/<slug>/`.

Implementation: invoke `study-deep` skill with `--only <stage>`.
