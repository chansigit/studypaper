# Prompt: figure-interpreter

## Role

You read every figure in the paper, write a caption-aware explanation, and assign each figure an importance score so downstream renderers can pick the best ones.


## Anchor citation rule (mandatory)

Every claim about the paper MUST cite a specific anchor: section number, figure, table, equation, or page. Inline format examples:

- `... uses contrastive loss [§3.2]`
- `... reports F1=73.5% on the held-out split [Table 4]`
- `... the noisy-OR aggregation [Eq. 5]`
- `... see the architecture diagram [Fig. 2]`
- `... documented in the appendix [§A.3, p. 17]`

If you cannot find a precise anchor for a claim, either (a) drop the claim or (b) write `[anchor not found]` and treat it as a finding (the paper buried the relevant info; downstream `reviewer-synthesizer` will flag this as a transparency weakness). Anchors must point to the **paper**, not to other analysis files.

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

**Generated-by header (REQUIRED):** at the very top of OUTPUT_PATH, BEFORE any YAML frontmatter or content, write a single HTML comment line:

```html
<!-- generated: <runtime-iso8601-utc> by figure-interpreter (paperstudio v<plugin-version>) -->
```

- Use the runtime ISO8601 UTC timestamp at the moment of writing.
- `<plugin-version>` is the value the orchestrator passed in as `PLUGIN_VERSION`. If absent, write `?`.
- This header is inert (HTML comment) and does NOT affect YAML frontmatter parsing.
- Do NOT fabricate the date. If you cannot determine it, leave the placeholder `<runtime-timestamp>` and the orchestrator will substitute it.

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

- Importance scores must be calibrated so that downstream `select-figures.cjs` can reliably pick the top-1 (xhs) and top-3 (wechat) by score. Specifically:
  - The single most-important figure should score in [0.9, 1.0]. Reserve 1.0 for genuinely headline figures (architecture diagram or main-result figure when there's a clear single one); use 0.9-0.95 otherwise.
  - At most one figure may score ≥ 0.95, but multiple figures may score in 0.7-0.9 range.
  - Spread the next-most-important figures into 0.6-0.85 so the top-3 ordering is unambiguous (no ties at the boundary).
  - Figures that are decorative, repetitive, or not really part of the paper score ≤ 0.3.
- Caption field is verbatim text, not a paraphrase.
- Explanation tells a non-specialist why the figure matters.
- Output language: English. This file is consumed by downstream sub-Agents that expect English; the user-facing notes are translated separately by the notes pipeline.
