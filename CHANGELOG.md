# Changelog

All notable changes to `paperstudio` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.2] — 2026-05-08

### Changed

- **SKILL.md hardening (Plan A + B from the recent self-review).**
  - Every SKILL.md now starts with a 6-line `## Hard rules` block (provenance / idempotence / log / paths / failure / chat-language). The rules are non-negotiable invariants — exceptions must be stated inline with a one-line "why".
  - Repeated dispatch boilerplate (the `--force` / skip / `.bak.NN` / `Skipped dispatches still count` paragraphs that were duplicated across 9 skills) is extracted to a single `paperstudio/skills/_shared/dispatch-rules.md`. Each SKILL points there for the full text.
  - `study-deep/SKILL.md`'s "Idempotence and re-runs" + "Per-dispatch idempotence rule" sections collapsed (rules now live in `_shared/`); only study-deep–specific notes remain inline (e.g. `--yes` semantics).
  - `test-idempotence-skip.bats` updated to look for the rules in either `study-deep/SKILL.md` or `_shared/dispatch-rules.md`. All 242 bats + 4 node tests still pass.

## [0.5.1] — 2026-05-08

### Added

- **Behavior-invariant test suite** at `tests/behavior/test-golden-string-database.bats` — 17 content-level assertions over the committed STRING-2025 golden snapshot. Pins invariants (frontmatter keys, required H2 sections, lookup-table consistency for `reproduce-check`, figure-embed counts, paper-folder-relative figure paths, line-1 provenance) that must hold on any future regeneration. The integration smoke test now runs these after schema validation. File header documents the manual "regenerate golden" workflow.
- `count-tests.sh` now folds in `tests/behavior/` automatically.

### Fixed

- Removed the false ChemRxiv page-normalization claim/rule. ChemRxiv article pages are not bioRxiv-style `/content/...` URLs, so the normalizer now passes them through instead of fabricating invalid `.full.pdf` URLs.

## [0.5.0] — 2026-05-08

### Added

- **`--lang en` flag** plumbed end-to-end. `/paperstudio:study <input> --lang en` renders Stage 3 outputs (`notes/source.md`, `titles.md`, `xhs.md`, `wechat.md`) in English with translated section headings and English-word length counting. All 4 Stage 3 sub-Agents (notes-writer, title-generator, xhs-renderer, wechat-renderer) now receive `LANG` as a prompt input. Default and unset → 中文.
- **`CLAUDE_PAPERS_ROOT` env var** plumbed through `study-deep`. Paper folders default to `~/claude-papers/papers/`; override by exporting `CLAUDE_PAPERS_ROOT=/some/other/dir`. The skill resolves the root once at start as `PAPERS_ROOT="${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}"` and uses it for both `--paper <slug>` resolution and the `ls -td` auto-detect path.
- **arXiv search picker now interactive.** The Stage 0.2 placeholder is replaced with a concrete pick-1-of-5 flow. With `--yes`, auto-pick `[1]`. User may type `cancel` to abort; an invalid number aborts with an error message. Bilingual prompt phrasing.

## [0.4.1] — 2026-05-08

### Added

- URL normalization for **NeurIPS proceedings** (both modern `proceedings.neurips.cc/paper_files/...-Abstract[-Conference].html` and legacy `papers.nips.cc/paper/.../Abstract.html`) and **PMLR** (`proceedings.mlr.press/v<vol>/<name>.html` → `<name>/<name>.pdf`, covering ICML / AISTATS / COLT / etc.).
- 4 new bats tests for the proceedings URL patterns.

## [0.4.0] — 2026-05-08

### Added

- **Expanded paper-intake URL support.** `/paperstudio:study` now accepts paper-host URLs beyond arXiv and converts them to direct PDF URLs before dispatching the downloader. Supported: arXiv (`abs/` and `pdf/`), bioRxiv / medRxiv / chemRxiv content pages, OpenReview `forum?id=`, ACL Anthology pages, HuggingFace papers (mapped to arXiv). Unknown URLs pass through unchanged. Implemented in `scripts/normalize-paper-url.sh`.
- **arXiv title search.** `/paperstudio:study "<title or query>"` (no path / no URL) hits the public arXiv API and returns the top 5 hits; user picks one to proceed. Implemented in `scripts/search-arxiv.sh`. No API key required; identifies itself with a `paperstudio/<ver>` User-Agent.
- **Default output language directive.** `xhs-renderer` and `wechat-renderer` prompts now declare `Output language: 中文 by default` explicitly at the top, with `lang=en` as the only override. Previously this was implicit (Chinese subheadings, Chinese-char length counting).
- 12 new bats tests covering all URL normalization rules + the empty-arg error path.

## [0.3.0] — 2026-05-08

### Changed (breaking)

- **Renamed plugin `paper-deepstudy` → `paperstudio`.** All slash commands change prefix: `/paper:study` → `/paperstudio:study`, `/paper:review-round` → `/paperstudio:review-round`, etc. (10 commands total). Skill namespace changes to `paperstudio:*`.
- Plugin folder in the marketplace repo renamed `paper-deepstudy/` → `paperstudio/`; marketplace `source` updated accordingly. Existing installs must `/plugin uninstall paper-deepstudy@studypaper` and `/plugin install paperstudio@studypaper`.
- Provenance HTML comment line is now `<!-- generated: <ts> by <agent> (paperstudio v<ver>) -->`. The `validate-artifact.sh` regex enforces the new name.

## [0.2.1] — 2026-05-08

### Fixed

- Removed non-standard `dependencies` field from `paperstudio/.claude-plugin/plugin.json`. The field was not part of the Claude Code plugin manifest schema and caused the plugin's commands and skills to be silently skipped on install — `/paperstudio:*` slash commands and `paperstudio:*` skills were not registered after `/plugin install`. The `claude-paper` upstream is still required at runtime; users should install it from its own marketplace.

## [0.2.0] — 2026-04-27

The "quality + foundations" release. Hardens the v0.1.0 pipeline with structured observability, refactors duplicated paper-resolution logic into shared helpers, and turns the test suite from grep-based structural checks into schema-validated behavioral coverage.

### Added

- `scripts/lib/resolve-paper.sh` — shared paper-folder resolution helper used by all 9 skills (replaces inline duplication; warns on auto-detect).
- `scripts/lib/log-dispatch.sh` — per-paper local dispatch log at `<paper>/.deepstudy/run.jsonl`. Records sub-Agent name, output filename, status, timestamp. Opt-out via `PAPER_DEEPSTUDY_NO_RUN_LOG=1`. **Local only — nothing phones home.**
- `scripts/lib/validate-artifact.sh` — schema-validation harness covering 16 artifact types (provenance, frontmatter keys, required H2 headings, banned-content patterns, `reproduce-check` lookup-table consistency).
- `scripts/count-tests.sh` — single source of truth for the test count (drives the README badge).
- Provenance HTML comment on line 1 of every generated file: `<!-- generated: <ts> by <agent> (paperstudio v<ver>) -->`.
- 14 new helper edge-case tests covering emoji / surrogate-pair / RTL slugify; `yml` / `YAML` / multi-doc judge fences; string-importance / missing-field figure parsing; and consecutive-whitespace handling.
- Schema validation of all 8 example artifacts in `examples/string-database-2025/` is wired into the integration smoke test.
- `LICENSE` (MIT), bilingual EN / 中文 `README.md`, `assets/{logo,banner}.svg`, eight shields.io badges.

### Changed

- `parse-judge-output.cjs` regex relaxed to accept `yml`, `YAML`, and fence-with-attrs forms. Previously was lowercase-`yaml`-only and silently fell back to `partially_holds` on every other form.
- All 9 skills source `resolve-paper.sh` for paper-folder resolution; auto-detect always emits a `Warning: targeting <slug>` line so retargeting never goes silent.
- `study-deep` no longer leaks Plan-numbered marketing strings into the user-facing chat output.
- README and `paperstudio/README.md` brought into bilingual EN / 中文 parity; clarified that `/paperstudio:study` produces 12 outputs and extension commands add more (was previously implying everything came from `/paperstudio:study`).

### Fixed

- **C1 (ship-blocker)**: `study-deep` `allowed-tools` was missing `Skill`, blocking every fresh `/paperstudio:study` install when allow-lists are enforced.
- **R3 / C1 / Last-updated**: `reproduce-checker`, `compare-agent`, `reviewer-synthesizer`, `review-writer` all now mandate runtime ISO8601 timestamps. Previous prompts allowed the LLM to fabricate dates (observed in live tests).
- **R1 / R2**: `reproduce-checker` enforces a self-check (`pass + fails + partials + na == checked_dimensions`) and a lookup-table for `overall_score`. Previously `fails_count >= 2` could be misclassified as `yellow` instead of `red`.
- **C2 / C3 / C4 / D1**: `compare-agent` and `deep-dive-agent` length caps relaxed and a verbatim-section-heading rule added; banned the spurious `## Summary` section the LLM tended to insert.
- **I6**: `slugify-objection` falls back to `cjk-<hash>` for non-ASCII inputs. Previously two distinct CJK objections both produced `untitled.md`.
- **I7**: figure paths in renderer outputs are paper-folder-relative. Previously absolute `/Users/<author>/...` paths leaked into committed example notes.
- **I8**: `/paperstudio:study` argument-hint documents the `--paper` flag.
- **I9**: README no longer claims `/paperstudio:add-prior-work` accepts DOI (it doesn't yet).
- **I10**: `title-generator` `STYLE_FILTER` semantics disambiguated.
- **M11**: `verify-prereqs.sh` glob no longer hardcodes the marketplace name.
- **M12**: 9 skills warn on auto-detected paper folder.
- **M14 / M15**: study-deep stripped of internal release-tracking text; README `/paperstudio:compare BERT` example replaced with a real arXiv-derived slug.

### Test counts

- bats: 143 → 208 (+65)
- node: 4 / 4 (each file extended with new edge cases internally)
- integration smoke: file-existence + 8 schema validations against committed examples

## [0.1.0] — 2026-04-26

Initial release. Plugin published on the [`chansigit/studypaper`](https://github.com/chansigit/studypaper) Claude Code marketplace.

### Added

- 4-stage auto-run pipeline (`/paperstudio:study`): paper profile → 7 analysis files → reviewer-style verdict → bilingual social-media notes.
- 10 slash commands: `study`, `rerun-stage`, `review-round`, `refine-notes`, `retitle`, `reselect-figures`, `deep-dive`, `compare`, `add-prior-work`, `reproduce-check`.
- 9 orchestration skills + 18 sub-Agent prompts.
- 7 domain packs: `ml-pure`, `single-cell`, `protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`.
- Adversarial review loop (`/paperstudio:review-round`): user objection → defense agent → *blind* judge agent → user verdict; every round persisted.
- 7-dimension reproducibility audit (`/paperstudio:reproduce-check`) with live GitHub URL verification via WebFetch.
- Examples gallery (`examples/string-database-2025/`) showing the full pipeline output on *The STRING database in 2025*.

[Unreleased]: https://github.com/chansigit/studypaper/compare/v0.5.2...HEAD
[0.5.2]: https://github.com/chansigit/studypaper/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/chansigit/studypaper/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/chansigit/studypaper/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/chansigit/studypaper/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/chansigit/studypaper/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/chansigit/studypaper/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/chansigit/studypaper/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/chansigit/studypaper/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/chansigit/studypaper/releases/tag/v0.1.0
