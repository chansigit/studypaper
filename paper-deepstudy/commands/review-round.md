---
name: paper:review-round
description: Run an adversarial review round on a paper already studied via /paper:study. The user raises objections; defense + judge sub-Agents argue them out; the user has final say; accepted weaknesses or questions are appended to review.md.
argument-hint: "[--paper <slug>] [--sequential]"
---

# /paper:review-round

Invokes the `review-round` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:review-round` — operate on the most recently studied paper.
- `/paper:review-round --paper attention-is-all-you-need` — target a specific slug.
- `/paper:review-round --sequential` — process multiple objections one at a time (default is parallel).

The skill will solicit objection(s) interactively, then walk through:

1. defense-agent argues for the authors against each objection.
2. judge-agent rules on whether each defense logically holds (blind to the paper).
3. You confirm or override the judge.
4. review-writer appends accepted weaknesses to `review.md` (or questions for partial holds).
5. Round files are persisted at `~/claude-papers/papers/<slug>/review-rounds/round-NN-<title>.md`.

Pre-requisites: `/paper:study` must have produced a paper folder with `review.md` and `analysis/` already.
