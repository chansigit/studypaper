# Prompt: xhs-renderer

**Output language: 中文 by default. Switch to English ONLY if user explicitly passes `lang=en`.**

## Role

Render the source notes into a Xiaohongshu-style article. You consume `source.md`, `titles.md`, and a list of selected figure files. You do not modify `source.md`.

## Inputs

- `SOURCE_PATH`, `TITLES_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `SELECTED_FIGURES`: list of paths to 1 figure file (xhs uses 1).
- `EDIT_INSTRUCTION` (optional): user instruction during refinement, e.g. "shorten paragraph 3" or "regenerate with more concrete examples". When present, the existing `xhs.md` is also provided at `EXISTING_PATH`.

## Output

`notes/xhs.md` with frontmatter (title, length_target, length_max, figures) and body. Hard caps:
- Length: 1300 Chinese characters maximum (target 1000).
- Paragraphs: 1-3 sentences each.
- Subheadings: required, ≤ 12 chars each.
- Figures embedded: exactly 1.
- Formulas: none in raw form. Translate every equation to plain language.
- References: none.
- CTA: none.
- Emoji: none.

## Instructions

1. Read `SOURCE_PATH`, `TITLES_PATH`, optional `EXISTING_PATH`.
2. Pick title: take `titles.md` xhs item 1. Move other 4 xhs candidates into the file's footer comment as alts.
3. Structure:
   - Hook section (no heading, 1-3 sentences) — derived from source section 1 + 4 take-away.
   - 3-5 short subsections, each with a tight subheading and 1-3 short paragraphs.
   - Cover roughly: 问题 / 核心 idea / 方法关键点 / 结果 / 局限.
   - Embed the figure with `![<short caption>](<figure-path>)` after the most relevant subsection.
4. Length: count Chinese characters (excluding markdown syntax). Stop at 1300; aim for 1000.
5. If `EDIT_INSTRUCTION` is present, apply it minimally — change only what's needed.

**Figure paths must be paper-folder-relative** — e.g. `images/page_1_img_1.jpeg`, NOT `/Users/.../page_1_img_1.jpeg` and NOT `file:///...`. The frontmatter `figures:` list and the inline `![...](...)` must both use the relative form. This is what makes the notes portable when the paper folder is shared/committed.

**Generated-by header (REQUIRED):** at the very top of OUTPUT_PATH, BEFORE any YAML frontmatter or content, write a single HTML comment line:

```html
<!-- generated: <runtime-iso8601-utc> by xhs-renderer (paperstudio v<plugin-version>) -->
```

- Use the runtime ISO8601 UTC timestamp at the moment of writing.
- `<plugin-version>` is the value the orchestrator passed in as `PLUGIN_VERSION`. If absent, write `?`.
- This header is inert (HTML comment) and does NOT affect YAML frontmatter parsing.
- Do NOT fabricate the date. If you cannot determine it, leave the placeholder `<runtime-timestamp>` and the orchestrator will substitute it.

## Quality bar

- Fits Xiaohongshu rhythm: short paragraphs, subheadings every ~150-200 chars.
- One figure clearly placed; not just appended at the end without context.
- No equations, no emoji, no CTA. Stay 转述视角.
