# Changelog

All notable changes to `paper-deepstudy` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] — 2026-05-08

### Fixed

- Removed non-standard `dependencies` field from `paper-deepstudy/.claude-plugin/plugin.json`. The field was not part of the Claude Code plugin manifest schema and caused the plugin's commands and skills to be silently skipped on install — `/paper:*` slash commands and `paper-deepstudy:*` skills were not registered after `/plugin install`. The `claude-paper` upstream is still required at runtime; users should install it from its own marketplace.

## [0.2.0] — 2026-04-27

The "quality + foundations" release. Hardens the v0.1.0 pipeline with structured observability, refactors duplicated paper-resolution logic into shared helpers, and turns the test suite from grep-based structural checks into schema-validated behavioral coverage.

### Added

- `scripts/lib/resolve-paper.sh` — shared paper-folder resolution helper used by all 9 skills (replaces inline duplication; warns on auto-detect).
- `scripts/lib/log-dispatch.sh` — per-paper local dispatch log at `<paper>/.deepstudy/run.jsonl`. Records sub-Agent name, output filename, status, timestamp. Opt-out via `PAPER_DEEPSTUDY_NO_RUN_LOG=1`. **Local only — nothing phones home.**
- `scripts/lib/validate-artifact.sh` — schema-validation harness covering 16 artifact types (provenance, frontmatter keys, required H2 headings, banned-content patterns, `reproduce-check` lookup-table consistency).
- `scripts/count-tests.sh` — single source of truth for the test count (drives the README badge).
- Provenance HTML comment on line 1 of every generated file: `<!-- generated: <ts> by <agent> (paper-deepstudy v<ver>) -->`.
- 14 new helper edge-case tests covering emoji / surrogate-pair / RTL slugify; `yml` / `YAML` / multi-doc judge fences; string-importance / missing-field figure parsing; and consecutive-whitespace handling.
- Schema validation of all 8 example artifacts in `examples/string-database-2025/` is wired into the integration smoke test.
- `LICENSE` (MIT), bilingual EN / 中文 `README.md`, `assets/{logo,banner}.svg`, eight shields.io badges.

### Changed

- `parse-judge-output.cjs` regex relaxed to accept `yml`, `YAML`, and fence-with-attrs forms. Previously was lowercase-`yaml`-only and silently fell back to `partially_holds` on every other form.
- All 9 skills source `resolve-paper.sh` for paper-folder resolution; auto-detect always emits a `Warning: targeting <slug>` line so retargeting never goes silent.
- `study-deep` no longer leaks Plan-numbered marketing strings into the user-facing chat output.
- README and `paper-deepstudy/README.md` brought into bilingual EN / 中文 parity; clarified that `/paper:study` produces 12 outputs and extension commands add more (was previously implying everything came from `/paper:study`).

### Fixed

- **C1 (ship-blocker)**: `study-deep` `allowed-tools` was missing `Skill`, blocking every fresh `/paper:study` install when allow-lists are enforced.
- **R3 / C1 / Last-updated**: `reproduce-checker`, `compare-agent`, `reviewer-synthesizer`, `review-writer` all now mandate runtime ISO8601 timestamps. Previous prompts allowed the LLM to fabricate dates (observed in live tests).
- **R1 / R2**: `reproduce-checker` enforces a self-check (`pass + fails + partials + na == checked_dimensions`) and a lookup-table for `overall_score`. Previously `fails_count >= 2` could be misclassified as `yellow` instead of `red`.
- **C2 / C3 / C4 / D1**: `compare-agent` and `deep-dive-agent` length caps relaxed and a verbatim-section-heading rule added; banned the spurious `## Summary` section the LLM tended to insert.
- **I6**: `slugify-objection` falls back to `cjk-<hash>` for non-ASCII inputs. Previously two distinct CJK objections both produced `untitled.md`.
- **I7**: figure paths in renderer outputs are paper-folder-relative. Previously absolute `/Users/<author>/...` paths leaked into committed example notes.
- **I8**: `/paper:study` argument-hint documents the `--paper` flag.
- **I9**: README no longer claims `/paper:add-prior-work` accepts DOI (it doesn't yet).
- **I10**: `title-generator` `STYLE_FILTER` semantics disambiguated.
- **M11**: `verify-prereqs.sh` glob no longer hardcodes the marketplace name.
- **M12**: 9 skills warn on auto-detected paper folder.
- **M14 / M15**: study-deep stripped of internal release-tracking text; README `/paper:compare BERT` example replaced with a real arXiv-derived slug.

### Test counts

- bats: 143 → 208 (+65)
- node: 4 / 4 (each file extended with new edge cases internally)
- integration smoke: file-existence + 8 schema validations against committed examples

## [0.1.0] — 2026-04-26

Initial release. Plugin published on the [`chansigit/studypaper`](https://github.com/chansigit/studypaper) Claude Code marketplace.

### Added

- 4-stage auto-run pipeline (`/paper:study`): paper profile → 7 analysis files → reviewer-style verdict → bilingual social-media notes.
- 10 slash commands: `study`, `rerun-stage`, `review-round`, `refine-notes`, `retitle`, `reselect-figures`, `deep-dive`, `compare`, `add-prior-work`, `reproduce-check`.
- 9 orchestration skills + 18 sub-Agent prompts.
- 7 domain packs: `ml-pure`, `single-cell`, `protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`.
- Adversarial review loop (`/paper:review-round`): user objection → defense agent → *blind* judge agent → user verdict; every round persisted.
- 7-dimension reproducibility audit (`/paper:reproduce-check`) with live GitHub URL verification via WebFetch.
- Examples gallery (`examples/string-database-2025/`) showing the full pipeline output on *The STRING database in 2025*.

[Unreleased]: https://github.com/chansigit/studypaper/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/chansigit/studypaper/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/chansigit/studypaper/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/chansigit/studypaper/releases/tag/v0.1.0
