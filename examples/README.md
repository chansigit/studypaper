# Examples

This directory contains real outputs produced by the `paperstudio` plugin during its own live integration testing. They show what each command produces against an actual research paper.

These examples are at the **repo root**, not inside `paperstudio/`, so they ship with the GitHub repo but are NOT installed when a user runs `/plugin install ./paperstudio`.

## Available examples

- [`string-database-2025/`](./string-database-2025/) — full pipeline run on "The STRING database in 2025" (Szklarczyk et al., 2025; *Nucleic Acids Research*). Demonstrates `/paperstudio:study`, `/paperstudio:review-round`, `/paperstudio:refine-notes`, `/paperstudio:deep-dive`, `/paperstudio:compare`, `/paperstudio:reproduce-check`, and `/paperstudio:add-prior-work` outputs end-to-end.

## How to use

Each subdirectory shows what the corresponding command produced for that paper. Read alongside `paperstudio/README.md` to see how the commands fit together.

The full output set lives under `~/claude-papers/papers/<slug>/` after a real run; these examples are a curated subset showcasing the most representative artifacts.
