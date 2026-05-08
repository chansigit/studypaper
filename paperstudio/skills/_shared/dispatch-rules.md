# Shared dispatch rules (read me first)

This file is **referenced**, not auto-included. Every SKILL.md in `paperstudio/skills/` follows the rules below; instead of repeating them in each file, the SKILL points here.

If you change anything here, the change applies to every dispatching skill — re-read the affected SKILLs to make sure no skill's local rules contradict.

---

## Rule 1 — Provenance is mandatory

Every artifact a sub-Agent writes MUST start, on **line 1**, with:

```html
<!-- generated: <runtime-iso8601-utc> by <subagent-name> (paperstudio v<plugin-version>) -->
```

- `<runtime-iso8601-utc>` is the wall-clock UTC timestamp at write time, ISO-8601, e.g. `2026-05-08T14:23:55Z`.
- `<subagent-name>` matches the prompt filename without `.md` (e.g. `paper-profiler`, `reviewer-synthesizer`).
- `<plugin-version>` is read from `paperstudio/.claude-plugin/plugin.json` at the start of the orchestrator and passed in as `PLUGIN_VERSION`.

This line is enforced by `scripts/lib/validate-artifact.sh`. Drift = test failure.

---

## Rule 2 — Per-dispatch idempotence

Before issuing **every** Agent call (Stages 0.4 / 1.x / 2.x / 3.x — every dispatching block in any SKILL):

| Condition | Action |
|---|---|
| `OUTPUT_PATH` does **not** exist | Dispatch normally |
| `OUTPUT_PATH` exists **and** `--force` is **not** set | Log `skipping <subagent> (output exists)`. Do **not** dispatch. Skipped dispatches still count as ✓ in the final summary (the existing file is the output). |
| `OUTPUT_PATH` exists **and** `--force` is set | Copy `OUTPUT_PATH` → `OUTPUT_PATH.bak.NN` (smallest non-existent integer ≥ 1) **first**, then dispatch. |
| `--only <stage>` is set | Treat as `--force` scoped to that stage's outputs. Stages outside the named one MUST be skipped. |

This rule applies uniformly. If a SKILL has a stage-local exception, it states it explicitly inline.

---

## Rule 3 — Log every dispatch

After every Agent call returns (success or failure), invoke:

```bash
log_dispatch <subagent-name> <relative-output-path> <ok|failed> [duration_ms]
```

The function is sourced from `scripts/lib/log-dispatch.sh` near the top of every SKILL. It appends one JSONL line to `${PAPER_DIR}/.deepstudy/run.jsonl`. It MUST NEVER cause the orchestrator to abort — the function returns 0 even on its own write failure.

For pre-dispatch skips (Rule 2 row 2), do NOT call `log_dispatch` — skips are not events.

---

## Rule 4 — Paper root is configurable

Resolve the paper root **once** at orchestrator start:

```bash
PAPERS_ROOT="${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}"
mkdir -p "$PAPERS_ROOT"
```

Then use `${PAPERS_ROOT}` throughout. The shorthand `~/claude-papers/papers/` shown in user-facing chat strings is the default-case display only — when `CLAUDE_PAPERS_ROOT` is set, substitute the override in any path you print or write.

For paper-folder resolution (`--paper <slug>` resolution and "auto-detect most recent"), source `scripts/lib/resolve-paper.sh` and call `resolve_paper "$@"`. Do not re-implement the resolution logic in each SKILL.

---

## Rule 5 — Chat-facing prose uses the user's invocation language

Reply to the user in the language they invoked the skill in (zh / en — detect from their first message). The English/Chinese matrix applies only to **written artifacts** under the paper folder. Section names like "进度" / "Progress" in chat are translated; file paths and command names stay verbatim.

---

## Rule 6 — Dispatch failures are non-destructive

If an Agent call fails:

1. Do NOT delete the partial output (if any was written).
2. Do NOT auto-retry.
3. Log `log_dispatch <subagent> <output> failed`.
4. Print a clear chat message: which sub-Agent, which stage, what the user can do (e.g. `/paperstudio:rerun-stage <stage>`).
5. Continue with stages that have no dependency on the failed one, when reasonable. Otherwise stop and surface the partial-completion summary.

---

## When you can break a rule

You can't, except by writing it explicitly in the SKILL with a one-line **why**. "I'm violating Rule 2 here because Stage 0.5 is a confirmation prompt that is not an artifact write."

If you find yourself wanting to violate a rule, that's usually a sign the rule needs editing — bring it up before silently diverging.
