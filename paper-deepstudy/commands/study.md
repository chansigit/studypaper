---
name: paper:study
description: Deep-study a paper for ML / computational biology. Produces analysis files, a review draft, and Chinese xhs/wechat learning notes.
argument-hint: "<pdf-path-or-url> [--paper <slug>] [--yes] [--force]"
---

# /paper:study

Invokes the `study-deep` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:study /path/to/paper.pdf`
- `/paper:study https://arxiv.org/abs/1706.03762`
- `/paper:study /path/to/paper.pdf --yes` (skip Stage 0 confirmation)
- `/paper:study /path/to/paper.pdf --force` (re-run all stages)
- `/paper:study --paper attention-is-all-you-need` (operate on an existing paper folder)

**`--paper <slug>`** *(advanced)*: skip the auto-download / parse step (Stage 0.2) and operate on an existing paper folder at `~/claude-papers/papers/<slug>/`. Useful when the paper folder was created some other way (e.g. via `claude-paper:study` directly, or from a backup). When `--paper` is set, you do NOT need to pass `<pdf-path-or-url>`.

Use the `study-deep` skill with the user-provided argument. Pass through `--yes` and `--force` if present.
