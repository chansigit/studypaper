---
name: paperstudio:reselect-figures
description: Re-pick which figures get embedded in xhs.md and wechat.md. Shows the user the figures from analysis/06-figures.md with their importance scores and captions; user multi-selects per platform; renderers are re-dispatched with the new selections.
argument-hint: "[--reinterpret] [--paper <slug>]"
---

# /paperstudio:reselect-figures

Invokes the `reselect-figures` skill from the `paperstudio` plugin.

Usage:
- `/paperstudio:reselect-figures` — interactively pick figures for both xhs and wechat from the existing `analysis/06-figures.md`.
- `/paperstudio:reselect-figures --reinterpret` — first re-run `figure-interpreter` to refresh the importance scores, then proceed.
- `/paperstudio:reselect-figures --paper attention-is-all-you-need` — target a specific paper.

The skill will list every figure under `images/` along with the interpreter's importance score and caption, then prompt you to select:
- 1 figure for xhs.md
- 2-3 figures for wechat.md

Both renderings are then re-dispatched with the new figure selections. **The body is regenerated from `source.md`** — any prior body edits made via `/paperstudio:refine-notes` are NOT preserved. To preserve body edits while swapping figures, use `/paperstudio:refine-notes <platform>` with an instruction like "swap embedded figure to <filename>" instead of running `/paperstudio:reselect-figures`.

The prior xhs.md and wechat.md are backed up as `.bak.NN`.

Pre-requisites: `/paperstudio:study` must have produced `analysis/06-figures.md`, `notes/source.md`, `notes/titles.md`, `notes/xhs.md`, and `notes/wechat.md` already.
