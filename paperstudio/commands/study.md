---
name: paperstudio:study
description: Deep-study a paper for ML / computational biology. Produces analysis files, a review draft, and Chinese xhs/wechat learning notes.
argument-hint: "<pdf-path-or-url-or-title> [--paper <slug>] [--yes] [--force]"
---

# /paperstudio:study

Invokes the `study-deep` skill from the `paperstudio` plugin.

Usage:
- `/paperstudio:study /path/to/paper.pdf`
- `/paperstudio:study https://arxiv.org/abs/1706.03762`
- `/paperstudio:study https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1`
- `/paperstudio:study https://openreview.net/forum?id=abc123`
- `/paperstudio:study https://aclanthology.org/2023.acl-long.123`
- `/paperstudio:study https://huggingface.co/papers/2401.12345`
- `/paperstudio:study "attention is all you need"` (free-text title → arXiv search; pick from top 5)
- `/paperstudio:study /path/to/paper.pdf --yes` (skip Stage 0 confirmation)
- `/paperstudio:study /path/to/paper.pdf --force` (re-run all stages)
- `/paperstudio:study --paper attention-is-all-you-need` (operate on an existing paper folder)

**Supported URL hosts** (auto-converted to direct PDF URL): arXiv, bioRxiv / medRxiv / chemRxiv, OpenReview, ACL Anthology, HuggingFace papers. Unknown URLs pass through to the downloader unchanged.

**Free-text title search**: if the argument is neither a path nor a URL, it's treated as an arXiv title query. The top 5 hits are listed; pick one to proceed.

**`--paper <slug>`** *(advanced)*: skip the auto-download / parse step (Stage 0.2) and operate on an existing paper folder at `~/claude-papers/papers/<slug>/`. Useful when the paper folder was created some other way (e.g. via `claude-paper:study` directly, or from a backup). When `--paper` is set, you do NOT need to pass `<pdf-path-or-url>`.

Use the `study-deep` skill with the user-provided argument. Pass through `--yes` and `--force` if present.
