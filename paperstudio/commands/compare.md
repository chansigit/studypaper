---
name: paperstudio:compare
description: Head-to-head comparison of two papers. Outputs compares/vs-<other-slug>.md with sections for problem, formalization, method, experiments, strengths/weaknesses, and when-to-use-which decision guidance.
argument-hint: "<other-paper> [--paper <slug>] [--lang en|zh]"
---

# /paperstudio:compare

Invokes the `compare` skill from the `paperstudio` plugin.

Usage:
- `/paperstudio:compare attention-is-all-you-need` — compare the most recently studied paper against the slug `attention-is-all-you-need` (which must already be in `~/claude-papers/papers/`).
- `/paperstudio:compare ~/Downloads/scvi.pdf` — compare against a PDF that hasn't been studied yet. The skill auto-runs `/paperstudio:study` on the new PDF first.
- `/paperstudio:compare https://arxiv.org/abs/1706.03762` — same with a URL.
- `/paperstudio:compare attention-is-all-you-need --paper string-database-2025` — both sides explicit.
- `/paperstudio:compare attention-is-all-you-need --lang zh` — output Chinese prose (section headings stay English).

`<other-paper>` accepts:
- An existing slug (string with no `/` or `.pdf` and matching `~/claude-papers/papers/<slug>/`).
- A path to a paper folder under `~/claude-papers/papers/`.
- A PDF path (ends in `.pdf`) — auto-studied first.
- An arXiv or general URL — auto-studied first.

Output: `~/claude-papers/papers/<this-slug>/compares/vs-<other-slug>.md`. Default language is English; `--lang zh` switches the prose to Chinese (section headings stay English so downstream tooling can grep them).

Pre-requisites: `/paperstudio:study` must have produced the focal paper's analysis directory. The `<other-paper>` will be auto-studied if not yet present.
