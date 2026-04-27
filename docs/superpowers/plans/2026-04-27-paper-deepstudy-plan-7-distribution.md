# paper-deepstudy Plan 7: Distribution Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修补 compare live test 暴露的 C1 (compare-agent fabricated `created_at`),并把 distribution 层面的两个 polish 一起做了 —— README 加 Troubleshooting 章节,在 repo 根加 `examples/` 目录把 string-database-2025 的真实跑出来的产物作为可读的 example。

**Architecture:** 3 个独立的小变更。C1 是 `prompts/compare-agent.md` 的小修(类比 Plan 6 的 R3),examples 目录是 repo-root 的 curated mini-gallery,README 是文档扩展。

**Tech Stack:** Markdown + Bats(structural assertion for C1)。无新依赖。

---

## File Structure

```
paper-deepstudy/
├── prompts/compare-agent.md            (modified — Task 1: C1 fix)
├── README.md                           (modified — Task 2: troubleshooting + example link)
└── tests/unit/test-prompts-have-required-sections.bats   (modified — Task 1 assertion)

examples/                                (NEW at repo root — Task 3)
└── string-database-2025/
    ├── README.md                       (overview + how to read)
    ├── analysis/00-paper-profile.md    (curated copy)
    ├── review.md                       (curated copy)
    ├── notes/xhs.md                    (curated copy)
    ├── notes/wechat.md                 (curated copy)
    ├── review-rounds/round-01-*.md     (curated copy)
    ├── reproduce-check.md              (curated copy)
    ├── deep-dives/*.md                 (curated copy)
    └── compares/vs-attention-is-all-you-need.md  (curated copy)
```

3 tasks。

---

## Pre-flight

Plan 1/2/3a/3b/3c/4/5/6 都已 merge。这个分支从 post-Plan-6 main 长出来。

---

### Task 1: compare-agent runtime `created_at` (C1)

**Files:**
- Modify: `paper-deepstudy/prompts/compare-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

跟 Plan 6 R3 同样的 fix,只不过这次目标文件是 compare-agent。

- [ ] **Step 1: Append failing test**

```bash
@test "compare-agent.md mandates runtime created_at, not fabricated" {
  grep -qF 'runtime ISO8601' prompts/compare-agent.md
}
```

- [ ] **Step 2: Verify fail**

`bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 3: Edit `paper-deepstudy/prompts/compare-agent.md`**

In the Output section, find the YAML frontmatter description:

```
- YAML frontmatter (`this_paper`, `other_paper`, `created_at`, `language`)
```

Replace with:

```
- YAML frontmatter (`this_paper`, `other_paper`, `created_at`, `language`).

  **About `created_at`:** must be the runtime ISO8601 UTC timestamp (e.g. `2026-04-27T03:14:15Z`). Use the current timestamp at the moment of generation. Do NOT use a fabricated, plan-doc-derived, or template-default date. If you cannot determine the current time, leave it as `<runtime-timestamp>` and let the orchestrator fill it in.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/prompts/compare-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): compare-agent mandates runtime created_at (C1)"
```

---

### Task 2: README troubleshooting section

**Files:**
- Modify: `paper-deepstudy/README.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

加 Troubleshooting 章节,覆盖最常见的几个安装/运行问题。

- [ ] **Step 1: Append failing test**

```bash
@test "README has Troubleshooting section" {
  grep -qF '## Troubleshooting' README.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Edit `paper-deepstudy/README.md`**

Read it first. Add a new `## Troubleshooting` section AFTER the existing `## Manual integration test` section and BEFORE the `## Roadmap` section. Insert:

```markdown
## Troubleshooting

### `verify-prereqs.sh` exits with code 1: claude-paper not found

The plugin requires `claude-paper:study` to be installed. Install via the Claude Code marketplace, or look for it under `~/.claude/plugins/marketplaces/`. Once installed, the prereq check should find it under `~/.claude/plugins/cache/claude-paper/claude-paper/<version>/skills/study/SKILL.md`.

### `verify-prereqs.sh` warns about missing pdftotext

Stage 0.3.1 of `study-deep` extracts the paper's full text via `pdftotext` (from `poppler-utils`). On macOS: `brew install poppler`. On Debian/Ubuntu: `sudo apt install poppler-utils`. Without `pdftotext`, the orchestrator falls back to passing `paper.pdf` directly to sub-Agents — slower, but still works.

### `/paper:study` fails with "claude-paper:study did not produce expected outputs"

This means the upstream `claude-paper:study` skill ran but didn't write to `~/claude-papers/papers/<slug>/`. Common causes:
- The PDF URL didn't return a real PDF (e.g. paywall redirect to login page).
- claude-paper's parse-pdf.js failed silently (try `node ~/.claude/plugins/cache/claude-paper/claude-paper/*/skills/study/scripts/parse-pdf.js <pdf-path>` directly).
- The paper folder slug is unexpected (claude-paper derives slug from title; legal-notice headers in arxiv PDFs sometimes confuse this).

Workaround: run `claude-paper:study` standalone first, verify `meta.json` exists, then re-run `/paper:study` (which will skip-or-detect the existing folder).

### `figure-interpreter` produces an empty `analysis/06-figures.md`

`claude-paper:study` extracts images via `pymupdf`. If the PDF has no extractable raster images (e.g. all-vector text-only papers), `images/` will be empty and `figure-interpreter` has nothing to interpret. The orchestrator records a `<!-- FAILED: no images extracted -->` placeholder; the rest of the pipeline continues. xhs/wechat renders will skip the figure embed.

### `/paper:review-round` judge verdict is always `partially_holds`

Most likely the judge-agent's YAML output couldn't be parsed by `parse-judge-output.cjs`. Check the judge-agent's chat output: it should be a YAML code-fenced block with `verdict:` and `reasoning:` keys. If the judge wrote the YAML in prose form or used a different fence label, `parse-judge-output.cjs` falls back to `partially_holds` per spec. Re-running the round usually resolves transient parse failures.

### Backups (`.bak.NN`) accumulate over time

Every refinement command (`/paper:refine-notes`, `/paper:retitle`, `/paper:reselect-figures`, `/paper:add-prior-work`, `/paper:reproduce-check`, etc.) writes a `.bak.NN` before mutating its target. There's no automatic rotation in v1. To clean up, just delete `*.bak.*` files manually:

```bash
find ~/claude-papers/papers/<slug>/ -name '*.bak.*' -delete
```

This is on the spec §11 open-questions list (backup retention policy) for a future polish.
```

- [ ] **Step 4: Verify pass**

```bash
bats paper-deepstudy/tests/unit/test-commands.bats
```

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/README.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "docs(paper-deepstudy): README Troubleshooting section"
```

---

### Task 3: Examples gallery at repo root

**Files:**
- Create: `examples/README.md`
- Create: `examples/string-database-2025/README.md`
- Create: 6-8 curated copies under `examples/string-database-2025/` (selected outputs from the live integration tests run in this session)
- Modify: `paper-deepstudy/README.md` (add link to examples/)
- Modify: `paper-deepstudy/tests/unit/test-commands.bats` (assert README links to examples)

Examples are at the **repo root** (`/Users/chensijie/Projects/studypaper/examples/`),不是在 plugin tree 里 —— 这样 plugin install 不会拷一份 ~100KB 的 example data。Github clone 的人能看到 examples,plugin 用户不会。

`examples/string-database-2025/` 是 curated 版本 —— 不是把 `~/claude-papers/papers/string-database-2025/` 整盘拷过来,而是挑几个典型产物来展示每个命令的真实输出。

- [ ] **Step 1: Append failing test**

```bash
@test "README links to examples directory" {
  grep -qF 'examples/' README.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Create the examples directory tree**

Use `cp` from `~/claude-papers/papers/string-database-2025/` for the curated copies:

```bash
mkdir -p examples/string-database-2025/{analysis,notes,review-rounds,deep-dives,compares}

# Curated subset — these are the most representative outputs of each command
cp ~/claude-papers/papers/string-database-2025/analysis/00-paper-profile.md examples/string-database-2025/analysis/
cp ~/claude-papers/papers/string-database-2025/review.md examples/string-database-2025/
cp ~/claude-papers/papers/string-database-2025/notes/xhs.md examples/string-database-2025/notes/
cp ~/claude-papers/papers/string-database-2025/notes/wechat.md examples/string-database-2025/notes/
cp ~/claude-papers/papers/string-database-2025/review-rounds/round-01-string-baseline-comparison.md examples/string-database-2025/review-rounds/
cp ~/claude-papers/papers/string-database-2025/reproduce-check.md examples/string-database-2025/
cp ~/claude-papers/papers/string-database-2025/deep-dives/the-fava-co-expression-integration.md examples/string-database-2025/deep-dives/
cp ~/claude-papers/papers/string-database-2025/compares/vs-attention-is-all-you-need.md examples/string-database-2025/compares/
```

- [ ] **Step 4: Write `examples/README.md`** — top-level index:

```markdown
# Examples

This directory contains real outputs produced by the `paper-deepstudy` plugin during its own live integration testing. They show what each command produces against an actual research paper.

These examples are at the **repo root**, not inside `paper-deepstudy/`, so they ship with the GitHub repo but are NOT installed when a user runs `/plugin install ./paper-deepstudy`.

## Available examples

- [`string-database-2025/`](./string-database-2025/) — full pipeline run on "The STRING database in 2025" (Szklarczyk et al., 2025; *Nucleic Acids Research*). Demonstrates `/paper:study`, `/paper:review-round`, `/paper:refine-notes`, `/paper:deep-dive`, `/paper:compare`, `/paper:reproduce-check`, and `/paper:add-prior-work` outputs end-to-end.

## How to use

Each subdirectory shows what the corresponding command produced for that paper. Read alongside `paper-deepstudy/README.md` to see how the commands fit together.

The full output set lives under `~/claude-papers/papers/<slug>/` after a real run; these examples are a curated subset showcasing the most representative artifacts.
```

- [ ] **Step 5: Write `examples/string-database-2025/README.md`** — per-paper index:

```markdown
# Example: STRING database in 2025

Real outputs from running the `paper-deepstudy` pipeline against "The STRING database in 2025: protein networks with directionality of regulation" (Szklarczyk et al., 2025; *Nucleic Acids Research*; arXiv-equivalent: NAR `gkae1113`). The paper is a database release, classified as `cs-bio` / `protein-function` by the auto-run profiler.

## Files in this example

| File | Source command | What it shows |
|---|---|---|
| [`analysis/00-paper-profile.md`](./analysis/00-paper-profile.md) | `/paper:study` Stage 0 | Auto-detected paper profile: type, domain, packs, key baselines |
| [`review.md`](./review.md) | `/paper:study` Stage 2 | v1 review report (~20KB) with hybrid ML+bio reviewer standards. Score 6/10. |
| [`notes/xhs.md`](./notes/xhs.md) | `/paper:study` Stage 3 + `/paper:refine-notes xhs` | Xiaohongshu rendering, ~830 chars Chinese |
| [`notes/wechat.md`](./notes/wechat.md) | `/paper:study` Stage 3 | WeChat 公众号 rendering, ~3800 chars Chinese, 3 figures embedded |
| [`review-rounds/round-01-string-baseline-comparison.md`](./review-rounds/round-01-string-baseline-comparison.md) | `/paper:review-round` | One adversarial round: objection / defense / blind judge verdict / user decision |
| [`reproduce-check.md`](./reproduce-check.md) | `/paper:reproduce-check` | 7-dimension reproducibility audit. Overall score: yellow/red. |
| [`deep-dives/the-fava-co-expression-integration.md`](./deep-dives/the-fava-co-expression-integration.md) | `/paper:deep-dive` | Focused topic deep-dive on FAVA, ~1956 words |
| [`compares/vs-attention-is-all-you-need.md`](./compares/vs-attention-is-all-you-need.md) | `/paper:compare` | Comparison with Vaswani 2017 (Transformer). Demonstrates handling "different problem, related lineage" pairing. |

## Notes

- These are real outputs, not curated mockups — including occasional rough edges from sub-Agent quirks (e.g. `created_at` timestamps from the agents may be off; see Plan 6 / 7 for the in-progress fixes).
- The `analysis/05-prior-work.md` was also augmented post-pipeline via `/paper:add-prior-work` to add a PubMedBERT entry; see the live test transcript for what that command does.
- Skipped from this gallery: `analysis/01-06.md` analysis files (large, less directly user-facing), `notes/source.md` (the unified source that xhs/wechat are rendered from), `notes/titles.md` (the candidate titles list).
```

- [ ] **Step 6: Update `paper-deepstudy/README.md`** to link to examples

Find the existing "## Manual integration test" section. Add a new section AFTER it (before "## Troubleshooting" from Task 2):

```markdown
## Examples

Real outputs from running this pipeline on actual papers, including the live integration tests that produced the artifacts in this repo:

- [`examples/string-database-2025/`](../examples/string-database-2025/) — full pipeline on "The STRING database in 2025" (a `cs-bio` / `protein-function` database paper)

(Examples are at the repo root, not inside the plugin install. Browse the folder on GitHub or after cloning the repo.)
```

- [ ] **Step 7: Verify all tests + smoke pass**

```bash
cd paper-deepstudy && npm run test:unit && cd ..
paper-deepstudy/tests/integration/test-end-to-end.sh
```

- [ ] **Step 8: Commit**

```bash
git add examples/ paper-deepstudy/README.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "docs(paper-deepstudy): examples gallery at repo root + README link"
```

---

## Self-Review checklist (Plan 7 完成后)

- [ ] `cd paper-deepstudy && npm run test:unit` 通过(bats grew by 3, 4 node tests still pass).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` 通过.
- [ ] `compare-agent.md` 包含 "runtime ISO8601" mandate(C1 已修).
- [ ] README 有 `## Troubleshooting` section + link to `../examples/string-database-2025/`.
- [ ] `examples/string-database-2025/` 包含 8 个 curated 文件 + 2 个 README.
- [ ] No Claude co-author on any commit.
