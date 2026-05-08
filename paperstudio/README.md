# paperstudio

Deep paper study for ML and computational-biology papers. Layers on top of `claude-paper:study` to add:

- Deep analysis (problem framing, formal definition, methodology, experiments, prior-work timeline, figure interpretation) — English
- Iterative review with adversarial review rounds (`/paperstudio:review-round`) — English
- Analysis extension commands (`/paperstudio:deep-dive`, `/paperstudio:compare`, `/paperstudio:add-prior-work`) — augment the auto-run analysis with deep dives, comparisons, and missed prior-work entries
- Reproducibility audit (`/paperstudio:reproduce-check`) — structured 7-dimension audit (data, code, hyperparameters, seeds, hardware, eval scripts, wet-lab protocol)
- Chinese learning notes for Xiaohongshu / WeChat from a unified source — Chinese

## Install (local dev)

```
# from this repo's root:
/plugin install ./paperstudio
```

Requires `claude-paper:study` already installed.

## Usage

### One-shot auto-run

```
/paperstudio:study /path/to/paper.pdf
/paperstudio:study https://arxiv.org/abs/1706.03762
/paperstudio:study /path/to/paper.pdf --yes      # skip Stage 0 confirmation
/paperstudio:study /path/to/paper.pdf --force    # re-run all stages with backups
```

### Re-run a specific stage

```
/paperstudio:rerun-stage analysis
/paperstudio:rerun-stage review
/paperstudio:rerun-stage notes
/paperstudio:rerun-stage profile
```

### Adversarial review round

```
/paperstudio:review-round
/paperstudio:review-round --paper attention-is-all-you-need
/paperstudio:review-round --sequential
```

Interactively raise objections to the paper. The plugin dispatches a defense-agent (arguing for the authors) and a judge-agent (blind to the paper, rules on the defense's logic). You have final say. Accepted objections are appended to `review.md`; every round is persisted at `review-rounds/round-NN-<title>.md`.

### Refine the rendered notes

After /paperstudio:study has produced notes/xhs.md and notes/wechat.md, you can iterate without re-running the full pipeline:

```
/paperstudio:refine-notes xhs              # apply an edit instruction to xhs.md
/paperstudio:refine-notes wechat           # apply an edit instruction to wechat.md
/paperstudio:retitle xhs                   # regenerate 5 title candidates, pick one
/paperstudio:retitle wechat --style hook   # bias candidates toward a style
/paperstudio:reselect-figures              # re-pick which figures get embedded
/paperstudio:reselect-figures --reinterpret  # re-run figure-interpreter first, then re-pick
```

All three commands back up the prior version as `notes/<file>.bak.NN` before mutating, so you can roll back any time.

### Analysis extensions

After /paperstudio:study has produced the analysis directory, three commands let you go deeper:

```
/paperstudio:deep-dive "contrastive loss derivation"             # focused topic deep-dive
/paperstudio:compare attention-is-all-you-need                   # head-to-head with another studied paper
/paperstudio:compare ~/Downloads/scvi.pdf                        # auto-studies the PDF first, then compares
/paperstudio:compare attention-is-all-you-need --lang zh         # Chinese prose
/paperstudio:add-prior-work https://arxiv.org/abs/1706.03762     # add a missed prior-work entry (arXiv URL)
/paperstudio:add-prior-work "@article{vaswani2017,...}"          # BibTeX
```

Outputs land at `~/claude-papers/papers/<slug>/`:
- `deep-dives/<topic-slug>.md` per `/paperstudio:deep-dive`
- `compares/vs-<other-slug>.md` per `/paperstudio:compare`
- `analysis/05-prior-work.md` is augmented in place by `/paperstudio:add-prior-work` (with `.bak.NN` backup)

### Reproducibility audit

```
/paperstudio:reproduce-check                              # audit the most recently studied paper
/paperstudio:reproduce-check --paper string-database-2025 # audit a specific paper
```

The skill rates the paper across 7 dimensions (data, code, hyperparameters, seeds, hardware, evaluation scripts, wet-lab protocol). Each dimension gets ✓ / ✗ / partial / N/A with cited evidence (paper page numbers, GitHub URLs verified via WebFetch). For `ml-pure` papers, wet-lab is N/A.

If the audit finds any ✗ or 3+ partials, the skill suggests `/paperstudio:review-round` to convert reproducibility weaknesses into formal weaknesses in `review.md`.

Output: `~/claude-papers/papers/<slug>/reproduce-check.md`. Existing files are backed up to `.bak.NN`.

## What you get (12 outputs)

Under `~/claude-papers/papers/<slug>/`:

```
analysis/
  00-paper-profile.md       # type, domain, difficulty (English, YAML frontmatter)
  01-problem.md             # background and framing (English)
  02-formalization.md       # math definitions, loss, constraints (English)
  03-method-deep.md         # method with rationale and alternatives (English)
  04-experiments.md         # experiment critique (English)
  05-prior-work.md          # timeline + comparison (English)
  06-figures.md             # per-figure interpretation + scoring (English)
review.md                   # v1 review report (English)
review-rounds/              # one file per /paperstudio:review-round invocation (English)
deep-dives/                 # one file per /paperstudio:deep-dive invocation (English)
compares/                   # one file per /paperstudio:compare invocation (English by default, Chinese with --lang zh)
reproduce-check.md          # reproducibility audit per /paperstudio:reproduce-check (English)
notes/
  source.md                 # unified source content (Chinese)
  titles.md                 # 5+5 candidate titles (Chinese)
  xhs.md                    # Xiaohongshu rendering (Chinese, ~1000 chars)
  wechat.md                 # WeChat rendering (Chinese, ~3000 chars)
```

## Manual integration test

The included `tests/integration/test-end-to-end.sh` is a static smoke test only. To verify against a real paper end-to-end:

1. `/paperstudio:study https://arxiv.org/abs/1706.03762` (Attention Is All You Need)
2. Verify all 12 files exist under `~/claude-papers/papers/attention-is-all-you-need/` (or whatever slug claude-paper:study assigns).
3. Spot-check:
   - `analysis/00-paper-profile.md` should classify it as `paper_type: architecture`, `domain: ml-pure`.
   - `analysis/02-formalization.md` should contain the attention equation in `$$ ... $$`.
   - `notes/xhs.md` should be ≤ 1300 Chinese chars and have exactly 1 figure.
   - `notes/wechat.md` should be ≤ 4000 chars and have 2-3 figures.
   - `review.md` should have a Score and Confidence value (not the placeholder underscores).
4. Repeat with a single-cell paper (e.g. arXiv preprint of scVI or scGPT) and confirm `domain_packs_selected` includes `single-cell`.

## Examples

Real outputs from running this pipeline on actual papers, including the live integration tests that produced the artifacts in this repo:

- [`examples/string-database-2025/`](../examples/string-database-2025/) — or browse on GitHub: [github.com/chansigit/studypaper/tree/main/examples/string-database-2025](https://github.com/chansigit/studypaper/tree/main/examples/string-database-2025) — full pipeline on "The STRING database in 2025" (a `cs-bio` / `protein-function` database paper)

(Examples live at the repo root, not inside the marketplace plugin install. Use the GitHub link above when reading this README from a marketplace cache.)

## Troubleshooting

### `verify-prereqs.sh` exits with code 1: claude-paper not found

The plugin requires `claude-paper:study` to be installed. Install via the Claude Code marketplace, or look for it under `~/.claude/plugins/marketplaces/`. Once installed, the prereq check should find it under `~/.claude/plugins/cache/claude-paper/claude-paper/<version>/skills/study/SKILL.md`.

### `verify-prereqs.sh` warns about missing pdftotext

Stage 0.3.1 of `study-deep` extracts the paper's full text via `pdftotext` (from `poppler-utils`). On macOS: `brew install poppler`. On Debian/Ubuntu: `sudo apt install poppler-utils`. Without `pdftotext`, the orchestrator falls back to passing `paper.pdf` directly to sub-Agents — slower, but still works.

### `/paperstudio:study` fails with "claude-paper:study did not produce expected outputs"

This means the upstream `claude-paper:study` skill ran but didn't write to `~/claude-papers/papers/<slug>/`. Common causes:
- The PDF URL didn't return a real PDF (e.g. paywall redirect to login page).
- claude-paper's parse-pdf.js failed silently (try `node ~/.claude/plugins/cache/claude-paper/claude-paper/*/skills/study/scripts/parse-pdf.js <pdf-path>` directly).
- The paper folder slug is unexpected (claude-paper derives slug from title; legal-notice headers in arxiv PDFs sometimes confuse this).

Workaround: run `claude-paper:study` standalone first, verify `meta.json` exists, then re-run `/paperstudio:study` (which will skip-or-detect the existing folder).

### `figure-interpreter` produces an empty `analysis/06-figures.md`

`claude-paper:study` extracts images via `pymupdf`. If the PDF has no extractable raster images (e.g. all-vector text-only papers), `images/` will be empty and `figure-interpreter` has nothing to interpret. The orchestrator records a `<!-- FAILED: no images extracted -->` placeholder; the rest of the pipeline continues. xhs/wechat renders will skip the figure embed.

### `/paperstudio:review-round` judge verdict is always `partially_holds`

Most likely the judge-agent's YAML output couldn't be parsed by `parse-judge-output.cjs`. Check the judge-agent's chat output: it should be a YAML code-fenced block with `verdict:` and `reasoning:` keys. If the judge wrote the YAML in prose form or used a different fence label, `parse-judge-output.cjs` falls back to `partially_holds` per spec. Re-running the round usually resolves transient parse failures.

### Disabling the per-paper run log

`paperstudio` writes a one-line-per-dispatch JSONL log at `~/claude-papers/papers/<slug>/.deepstudy/run.jsonl` to help debug bad outputs. The log contains only metadata (sub-Agent names, output filenames, timestamps, status) — never paper content or user input — and is purely local to your filesystem. To disable:

```bash
export PAPER_DEEPSTUDY_NO_RUN_LOG=1
```

### Backups (`.bak.NN`) accumulate over time

Every refinement command (`/paperstudio:refine-notes`, `/paperstudio:retitle`, `/paperstudio:reselect-figures`, `/paperstudio:add-prior-work`, `/paperstudio:reproduce-check`, etc.) writes a `.bak.NN` before mutating its target. There's no automatic rotation in v1. To clean up, just delete `*.bak.*` files manually:

```bash
find ~/claude-papers/papers/<slug>/ -name '*.bak.*' -delete
```

This is on the spec §11 open-questions list (backup retention policy) for a future polish.

## Roadmap

- **Plan 1 ✓ (shipped):** auto-run pipeline, `ml-pure` and `single-cell` packs.
- **Plan 2 ✓ (shipped):** `/paperstudio:review-round` adversarial loop.
- **Plan 3a ✓ (shipped):** notes UX commands — `refine-notes`, `retitle`, `reselect-figures`.
- **Plan 3b ✓ (shipped):** analysis-extension commands — `deep-dive`, `compare`, `add-prior-work`.
- **Plan 3c ✓ (this branch):** `reproduce-check` audit command.
- **Plan 4 ✓ (shipped):** five more domain packs (`protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`).
- **Plan 5 ✓ (shipped):** cross-plan polish — Stage 0.2 invocation, --only/--paper flag wiring, helpers + tests.
