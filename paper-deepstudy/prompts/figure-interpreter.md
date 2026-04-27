# Prompt: figure-interpreter

## Role

You read every figure in the paper, write a caption-aware explanation, and assign each figure an importance score so downstream renderers can pick the best ones.

## Inputs

- `PAPER_TEXT`: full paper text (figure captions are inline).
- `IMAGES_DIR`: directory with extracted figure files (e.g. `images/figure-1.png`, ...). Filenames may be `figure-N.png` or arbitrary (e.g. `page3-img1.png`).
- `OUTPUT_PATH`: where to write `analysis/06-figures.md`.
- `TEMPLATE_PATH`: path to the figure template.

## Output

`analysis/06-figures.md`. YAML frontmatter `figures:` list with one entry per file in `IMAGES_DIR`. Each entry:
- `file` (basename only)
- `caption` (string; the paper's caption verbatim, or "" if none found)
- `importance` (float in [0.0, 1.0], 2 decimal places)
- `role` (one of: architecture, pipeline, main-result, ablation, qualitative, other)

After frontmatter, one `## Figure N` section per figure, in the same order as the frontmatter list. Each section: 2-4 sentences explaining what the figure shows, what to read off it, why it matters.

## Instructions

1. List files in `IMAGES_DIR`.
2. For each, find its caption in `PAPER_TEXT` by matching figure number. If filename has no number, infer from order or page context.
3. Score importance:
   - 1.0: the architecture diagram OR the headline-result figure
   - 0.7-0.9: a key ablation, key intuition diagram, or paper's lead qualitative example
   - 0.4-0.6: secondary results or supporting illustrations
   - 0.1-0.3: incidental, repetitive, or appendix-quality
   - 0.0: probably not a real figure (extracted artifact, decorative banner)
4. Pick `role` based on the figure's purpose.
5. Write the explanation: not a re-statement of the caption, but a "what this means" reading.

## Quality bar

- Importance scores are usable for picking 1 figure (xhs) and 2-3 figures (wechat). Exactly one figure should be ≥ 0.9 (the most important one).
- Caption field is verbatim text, not a paraphrase.
- Explanation tells a non-specialist why the figure matters.
- Output language: English. This file is consumed by downstream sub-Agents that expect English; the user-facing notes are translated separately by the notes pipeline.
