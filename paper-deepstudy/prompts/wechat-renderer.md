# Prompt: wechat-renderer

## Role

Render the source notes into a WeChat 公众号-style article. Consume `source.md`, `titles.md`, and selected figures.

## Inputs

- `SOURCE_PATH`, `TITLES_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `SELECTED_FIGURES`: list of paths to 2-3 figure files.
- `EDIT_INSTRUCTION` and `EXISTING_PATH` (optional, same semantics as xhs).

## Output

`notes/wechat.md`:
- Length target: 3000 chars; max: 4000.
- Paragraphs: long allowed.
- Subheadings: required.
- Figures embedded: 2-3.
- Formulas: 1-2 key formulas allowed (in `$$ ... $$`), each followed by 1-2 sentences plain-language explanation.
- References: up to 3 key references with links at end.
- CTA: none.
- Emoji: none.

## Instructions

1. Read `SOURCE_PATH`, `TITLES_PATH`, optional `EXISTING_PATH`.
2. Pick title: `titles.md` wechat item 1. Move other 4 to footer comment.
3. Structure:
   - 导语 (1-2 paragraphs) — set the stage.
   - `## 背景` — from source sections 2-3.
   - `## 核心 idea` — from source section 4.
   - `## 方法` — from source section 5; may include 1-2 key formulas.
   - `## 实验` — from source section 6.
   - `## 局限和未来` — from source section 8.
   - `## 一句话总结` — from source section 9.
   - `**参考文献**` — up to 3 references with links if available from `05-prior-work.md`.
4. Embed figures at relevant points:
   - Architecture / pipeline figure goes in `## 方法`.
   - Main-result figure goes in `## 实验`.
   - Optional third figure in `## 核心 idea` or `## 背景`.
5. Length: 3000 target, 4000 hard cap.
6. If `EDIT_INSTRUCTION`, apply minimally.

**Figure paths must be paper-folder-relative** — e.g. `images/page_1_img_1.jpeg`, NOT `/Users/.../page_1_img_1.jpeg` and NOT `file:///...`. The frontmatter `figures:` list and the inline `![...](...)` must both use the relative form. This is what makes the notes portable when the paper folder is shared/committed.

## Quality bar

- Reads like a curated public-facing article, not a chunked source dump.
- Formulas always followed by plain-language explanation in the same paragraph.
- Figures embedded contextually, not appended.
- No emoji, no CTA. 转述视角.
