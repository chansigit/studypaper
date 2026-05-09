# Changelog

All notable changes to `paperstudio` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.1] — 2026-05-08

Closes the 15 findings from the superpowers code-review on commit `79bc4c3`.

- **C1 (ship-blocker)**: `review-writer` now updates `review.md` YAML frontmatter on every round (review_round / strengths_count / weaknesses_count / open_questions_count, with documented verdict-downgrade rules). `validate-artifact.sh` gains `check_review_count_consistency` so frontmatter / body drift is caught at validation time.
- **C2 (ship-blocker)**: `study-deep` Hard-rules Rule 6 referenced the wrong rule in `_shared/dispatch-rules.md`; replaced with the standard wording shared by the other 8 SKILLs.
- **I1**: `--only analysis` now also re-runs Stage 1.5 (`analysis-coherence-checker`); the table in `study-deep/SKILL.md` was missing the coherence step.
- **I2**: `paperstudio/package.json` no longer carries a `version` field — single source of truth is `.claude-plugin/plugin.json`. New `tests/unit/test-version-source-of-truth.bats` asserts plugin.json and marketplace.json agree.
- **I3**: top-level README and `paperstudio/README.md` now document `/paperstudio:study --lang en` (it shipped in v0.5.0 but was missing from both READMEs).
- **I4**: README architecture diagram + repo-layout snippet now say "19 sub-agent prompts" (was 18; v0.6.0 added `analysis-coherence-checker.md`).
- **I5**: `scripts/search-arxiv.sh` User-Agent string is now read from `plugin.json` instead of being hard-coded to `paperstudio/0.4.0`.
- **I6**: `scripts/search-arxiv.sh` final pipeline replaced `head -n "$max"` with an `awk NR<=max` form to avoid SIGPIPE under `set -o pipefail`.
- **I7**: `tests/behavior/test-golden-string-database.bats` forward-compat tests now read the golden's provenance version; once the snapshot is regenerated under v0.6.0+, the `skip`s flip to hard failures (no more silent forever-skip).
- **M1**: `validate-artifact.sh` gains a `PAPERSTUDIO_VALIDATE_STRICT=1` env knob that promotes the v0.6.0 review frontmatter keys from "enum-when-present" to "required" — useful in CI on freshly regenerated paper folders.
- **M2**: `add-prior-work` SKILL's "DOI not yet supported" roadmap blockquote moved out of the unusual position above the H1; now lives in the body next to the `<ref>` argument description.
- **M3**: `_shared/dispatch-rules.md` Rule 3 reworded so "skip = no JSONL but still ✓ in summary" is no longer surface-contradictory with Rule 2's "Skipped dispatches still count".
- **M4**: `analysis-coherence-checker` anchor-rule regex broadened to accept both `[§N]` (analysis-prompt convention) and `(paper §N)` (defense-agent convention) plus the explicit `[anchor not found]` opt-out, preventing silent under-reporting of anchor gaps once review-round artifacts feed downstream consumers.
- **M5**: `scripts/lib/log-dispatch.sh` now JSON-escapes its three string fields (subagent, output, status) before serializing the JSONL line — defensive against any future caller that pipes a user-supplied string with quotes / backslashes / newlines.
- **M6**: `examples/string-database-2025/README.md` gains a prominent "snapshot vintage" note explaining that the example was generated under v0.1.0 and what v0.6.0+ regeneration will add (frontmatter, `_coherence.md`, anchor citations) — so new users don't mistake a legacy snapshot for the current output shape.

Tests: 248 bats (+3 new version-source) + 4 node, all passing. 3 forward-compat tests still `skip` against the legacy v0.1.0 golden but will hard-fail on v0.6.0+ regeneration.

## [0.6.0] — 2026-05-08

The "review-flow upgrade" release. Six analysis/review improvements identified in the post-v0.5.2 self-review, shipped together. All are additive — existing paper folders keep working; full benefit appears after re-running `/paperstudio:study` on a paper.

### Added

- **Reviewer-synthesizer reads paper text directly** (Stage 2). Previously it only saw the analysis files (`summary of summaries`). Now it receives `PAPER_TEXT_PATH` and is required to do a "Discussion / Conclusion / Limitations sweep" on the raw paper to catch claims the analysis pipeline missed. Prompt + Stage 2 dispatch updated.
- **Anchor citation rule** in all 6 analysis prompts (problem-framer, formalizer, method-analyst, experiment-critic, prior-work-historian, figure-interpreter). Every claim about the paper must cite `§N`, `Fig. N`, `Table N`, `Eq. N`, or `p. N`. Bullets without an anchor must be either dropped or marked `[anchor not found]`. Makes downstream review-round / reproduce-check evidence-traceable.
- **Structured `review.md` frontmatter**: `verdict` (enum: strong_accept|accept|weak_accept|borderline|weak_reject|reject|strong_reject), `confidence` (low|medium|high), `review_round` (int), and counts for strengths / weaknesses / open_questions. Makes reviews machine-readable and comparable across papers. Enforced by `validate-artifact.sh` as enum-when-present (legacy reviews without frontmatter still validate).
- **Judge-agent duplication awareness**. `/paperstudio:review-round` now passes `CURRENT_REVIEW_PATH=review.md` to the judge so it can detect when an objection duplicates an already-accepted weakness or question. Pure-blind behavior remains available via the new `--strict-blind` flag.
- **Stage 1.5: cross-analysis coherence check.** New `analysis-coherence-checker` sub-agent reads all 7 analysis files + `paper.txt` after Stage 1 completes, produces `analysis/_coherence.md` with frontmatter (`issues_count`, `contradictions`, `notation_drift`, `missing_links`, `anchor_gaps`, `severity ∈ {none,low,medium,high}`). Reviewer-synthesizer ingests it as additional context. `severity: high` surfaces a chat warning but does not block.
- **Stats-critic checklist** embedded in `experiment-critic`. Replaces a 1-line statistical-rigor bullet with an explicit 9-item checklist (sample size, variance, seeds ≥ 3, significance test, multiple-comparison correction, outliers, effect size, biological vs technical replicates, small-n caveats).
- 3 forward-compatible behavior tests in `tests/behavior/`: validate `verdict`, `confidence`, and coherence `severity` enums when the fields are present (currently `skip`, will activate when golden is regenerated under v0.6.0+).
- 1 prompt count test bumped: 16 → 17 sub-agent prompts (adds `analysis-coherence-checker`).

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

[Unreleased]: https://github.com/chansigit/studypaper/compare/v0.6.1...HEAD
[0.6.1]: https://github.com/chansigit/studypaper/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/chansigit/studypaper/compare/v0.5.2...v0.6.0
[0.5.2]: https://github.com/chansigit/studypaper/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/chansigit/studypaper/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/chansigit/studypaper/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/chansigit/studypaper/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/chansigit/studypaper/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/chansigit/studypaper/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/chansigit/studypaper/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/chansigit/studypaper/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/chansigit/studypaper/releases/tag/v0.1.0
