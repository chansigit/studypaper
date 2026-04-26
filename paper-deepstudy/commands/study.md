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
