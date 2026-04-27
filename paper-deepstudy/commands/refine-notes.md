---
name: paper:refine-notes
description: Apply a user edit instruction to an existing rendered note (xhs or wechat). Reads the current rendering, dispatches the matching renderer with EDIT_INSTRUCTION, writes back with a backup of the prior version.
argument-hint: "[xhs|wechat] [--paper <slug>]"
---

# /paper:refine-notes

Invokes the `refine-notes` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:refine-notes xhs` — refine the Xiaohongshu rendering of the most recently studied paper.
- `/paper:refine-notes wechat` — refine the WeChat rendering.
- `/paper:refine-notes xhs --paper attention-is-all-you-need` — target a specific paper.

The skill will show you the current rendering, ask what to change, dispatch the appropriate renderer (`xhs-renderer` or `wechat-renderer`) with your edit instruction, and write the new version back. The prior version is preserved as `notes/<platform>.md.bak.NN`.

If your edit instruction sounds like a content change (not just rephrasing / restructuring), the skill will pause and ask whether you want to update `notes/source.md` and re-render both platforms instead.

Pre-requisites: `/paper:study` must have produced `notes/source.md` and `notes/<platform>.md` already.
