---
# `figures` is filled in by the figure-interpreter sub-Agent at runtime.
# Each entry's `file` is the basename of an image in $PAPER_DIR/images/.
# Real filenames from claude-paper:study look like `page_3_img_1.png`,
# not `figure-1.png` — the placeholders below are illustrative only.
figures:
  - file: <basename-from-images-dir>
    caption: "<caption>"
    importance: 0.0  # 0.0–1.0, set by interpreter
    role: architecture | pipeline | main-result | ablation | qualitative | other
  - file: <another-basename>
    caption: ""
    importance: 0.0
    role: other
---

# Figures

## Figure 1 — <short title>

(Plain-language explanation of what the figure shows. Why it matters. What to read off it.)

## Figure 2 — <short title>

...
