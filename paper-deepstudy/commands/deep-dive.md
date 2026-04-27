---
name: paper:deep-dive
description: Produce a focused deep dive on a single user-specified topic in the paper, going beyond what the auto-run analysis/ files cover. Outputs deep-dives/<topic-slug>.md.
argument-hint: "<topic> [--paper <slug>]"
---

# /paper:deep-dive

Invokes the `deep-dive` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:deep-dive contrastive loss derivation` — dive into "contrastive loss derivation" for the most recently studied paper.
- `/paper:deep-dive "the FAVA co-expression integration" --paper string-database-2025` — explicit topic + target paper.
- `/paper:deep-dive "§3.2 attention computation"` — section reference is also valid.

The skill dispatches `deep-dive-agent` with the topic + paper text + analysis files. Output lands at `~/claude-papers/papers/<slug>/deep-dives/<topic-slug>.md`. Topic-slug is derived via `slugify-objection.cjs`. If a deep-dive on the same topic already exists, the new file gets a `-2` / `-3` suffix.

Pre-requisites: `/paper:study` must have produced the analysis directory already.
