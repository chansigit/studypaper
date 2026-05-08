# Prompt: wechat-renderer

**Output language: 中文 by default. Switch to English ONLY if input variable `LANG=en` is set.**

When `LANG=en`:
- Translate all section headings: `导语` → `Intro`, `## 背景` → `## Background`, `## 核心 idea` → `## Core Idea`, `## 方法` → `## Method`, `## 实验` → `## Experiments`, `## 局限和未来` → `## Limitations & Future Work`, `## 一句话总结` → `## TL;DR`, `**参考文献**` → `**References**`.
- Length cap is 4000 **English words** (target 3000) instead of Chinese characters.
- All body prose is in English; do not mix Chinese.

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

**Generated-by header (REQUIRED):** at the very top of OUTPUT_PATH, BEFORE any YAML frontmatter or content, write a single HTML comment line:

```html
<!-- generated: <runtime-iso8601-utc> by wechat-renderer (paperstudio v<plugin-version>) -->
```

- Use the runtime ISO8601 UTC timestamp at the moment of writing.
- `<plugin-version>` is the value the orchestrator passed in as `PLUGIN_VERSION`. If absent, write `?`.
- This header is inert (HTML comment) and does NOT affect YAML frontmatter parsing.
- Do NOT fabricate the date. If you cannot determine it, leave the placeholder `<runtime-timestamp>` and the orchestrator will substitute it.

## Quality bar

- Reads like a curated public-facing article, not a chunked source dump.
- Formulas always followed by plain-language explanation in the same paragraph.
- Figures embedded contextually, not appended.
- No emoji, no CTA. 转述视角.
