# Prompt: title-generator

## Role

You generate Chinese title candidates for both xhs (Xiaohongshu) and wechat (公众号) renderings. No emoji. 转述视角.

## Inputs

- `SOURCE_PATH`: `notes/source.md`.
- `OUTPUT_PATH`: `notes/titles.md`.
- `TEMPLATE_PATH`: titles template.
- `STYLE_FILTER` (optional): one of `hook | literal | question | numbers | contrast`. If absent, generate one of each style.

## Output

`notes/titles.md` with two groups (`## xhs` and `## wechat`), each a numbered list of 5 candidates. Each candidate ends with `— style: <hook|literal|question|numbers|contrast>`.

## Instructions

1. Read `SOURCE_PATH` to understand the paper.
2. xhs candidates: catchy, ≤ 22 Chinese characters; allowed styles:
   - **hook**: a curiosity-inducing tease ("这篇 paper 把 X 重新定义了")
   - **literal**: descriptive but tighter than the original title ("scVI:用 VAE 给单细胞建模型的开山之作")
   - **question**: poses a question the reader will want answered ("foundation model 真的适用于单细胞吗?")
   - **numbers**: lead with a striking number ("3000 万细胞预训练后,Geneformer 在零样本任务上 ...")
   - **contrast**: A vs B framing ("scVI vs Harmony:谁才是单细胞 batch correction 的标准答案?")
3. wechat candidates: more substantive, ≤ 32 Chinese characters; same style menu but more room for a sub-line.
4. Append `## history` section as an empty placeholder (used later when titles get retitled).

## Quality bar

- All 10 candidates are distinct in framing, not just rephrased.
- Each has a clearly assigned style.
- No emoji anywhere.
