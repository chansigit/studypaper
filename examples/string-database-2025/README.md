# Example: STRING database in 2025

Real outputs from running the `paperstudio` pipeline against "The STRING database in 2025: protein networks with directionality of regulation" (Szklarczyk et al., 2025; *Nucleic Acids Research*; arXiv-equivalent: NAR `gkae1113`). The paper is a database release, classified as `cs-bio` / `protein-function` by the auto-run profiler.

> **Note on snapshot vintage.** This example was generated under **paperstudio v0.1.0** (provenance lines say `paperstudio v0.1.0 [Plan 7 retrofit]`). It does not yet reflect v0.6.0 outputs:
>
> - `review.md` here has no YAML frontmatter; v0.6.0 reviews start with `verdict / confidence / review_round / *_count` keys.
> - There is no `analysis/_coherence.md` in this snapshot; v0.6.0 produces one in Stage 1.5.
> - Analysis bullets do not yet carry the `[§N]` / `[Fig. N]` / `[Table N]` anchor citations the v0.6.0 prompts require.
>
> When you regenerate this example under v0.6.0+, those additions appear automatically. The forward-compat behavior tests in `paperstudio/tests/behavior/` already enforce the new shape and will switch from `skip` to hard failures once the snapshot's provenance line shows `v0.6.0` or later.

## Files in this example

| File | Source command | What it shows |
|---|---|---|
| [`analysis/00-paper-profile.md`](./analysis/00-paper-profile.md) | `/paperstudio:study` Stage 0 | Auto-detected paper profile: type, domain, packs, key baselines |
| [`review.md`](./review.md) | `/paperstudio:study` Stage 2 | v1 review report (~20KB) with hybrid ML+bio reviewer standards. Score 6/10. |
| [`notes/xhs.md`](./notes/xhs.md) | `/paperstudio:study` Stage 3 + `/paperstudio:refine-notes xhs` | Xiaohongshu rendering, ~830 chars Chinese |
| [`notes/wechat.md`](./notes/wechat.md) | `/paperstudio:study` Stage 3 | WeChat 公众号 rendering, ~3800 chars Chinese, 3 figures embedded |
| [`review-rounds/round-01-string-baseline-comparison.md`](./review-rounds/round-01-string-baseline-comparison.md) | `/paperstudio:review-round` | One adversarial round: objection / defense / blind judge verdict / user decision |
| [`reproduce-check.md`](./reproduce-check.md) | `/paperstudio:reproduce-check` | 7-dimension reproducibility audit. Overall score: yellow/red. |
| [`deep-dives/the-fava-co-expression-integration.md`](./deep-dives/the-fava-co-expression-integration.md) | `/paperstudio:deep-dive` | Focused topic deep-dive on FAVA, ~1956 words |
| [`compares/vs-attention-is-all-you-need.md`](./compares/vs-attention-is-all-you-need.md) | `/paperstudio:compare` | Comparison with Vaswani 2017 (Transformer). Demonstrates handling "different problem, related lineage" pairing. |

## Notes

- These are real outputs, not curated mockups — including occasional rough edges from sub-Agent quirks (e.g. `created_at` timestamps from the agents may be off; see Plan 6 / 7 for the in-progress fixes).
- The `analysis/05-prior-work.md` was also augmented post-pipeline via `/paperstudio:add-prior-work` to add a PubMedBERT entry; see the live test transcript for what that command does.
- Skipped from this gallery: `analysis/01-06.md` analysis files (large, less directly user-facing), `notes/source.md` (the unified source that xhs/wechat are rendered from), `notes/titles.md` (the candidate titles list).
