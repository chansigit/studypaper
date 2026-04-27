---
name: paper:retitle
description: Regenerate 5 title candidates for an existing xhs or wechat rendering, let the user pick one, swap it into the rendering, and archive the prior title. Optional --style filter to bias the candidates.
argument-hint: "[xhs|wechat] [--style <hook|literal|question|numbers|contrast>] [--paper <slug>]"
---

# /paper:retitle

Invokes the `retitle` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:retitle xhs` — regenerate Xiaohongshu titles, pick one, apply.
- `/paper:retitle wechat` — same for WeChat.
- `/paper:retitle xhs --style hook` — bias candidates toward the hook style.
- `/paper:retitle wechat --paper attention-is-all-you-need` — target a specific paper.

Style options (from `title-generator.md`):
- `hook` — curiosity-inducing tease
- `literal` — descriptive but tighter
- `question` — poses a question
- `numbers` — leads with a striking number
- `contrast` — A vs. B framing

Without `--style`, the generator produces one of each style.

The chosen title replaces the rendering's frontmatter `title:` field; the previous title moves into `notes/titles.md` `## history` section. The rendering's body and figure list are untouched.

Pre-requisites: `/paper:study` must have produced `notes/source.md`, `notes/titles.md`, and `notes/<platform>.md` already.
