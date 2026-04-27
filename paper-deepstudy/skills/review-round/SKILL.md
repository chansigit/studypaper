---
name: review-round
description: Use when the user wants to run an adversarial review round on a paper that has already been studied via /paper:study. Solicits objections, dispatches defense+judge sub-Agents, gets the user's final verdict, and updates review.md with accepted weaknesses or questions.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: review-round workflow

Invoke after `/paper:study` has produced a paper folder under `~/claude-papers/papers/<slug>/`. The user is the reviewer; this skill orchestrates the dialectic and writes the resulting review entries.

Optional flags:
- `--paper <slug>`: target a specific paper folder. Default: the most recently modified `~/claude-papers/papers/<slug>/`.
- `--sequential`: run multiple objections one at a time (default is parallel).

---

## Stage 1: Setup

### 1.1 Resolve target paper

If `--paper <slug>` is provided, set `PAPER_DIR=~/claude-papers/papers/<slug>`. Otherwise:

```bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1)
```

Strip trailing slash. Verify:
- `$PAPER_DIR/review.md` exists. If not, abort with: "No review.md found at <path>. Run /paper:study on this paper first."
- `$PAPER_DIR/analysis/` directory exists with at least `00-paper-profile.md`. If not, abort with same message.
- `$PAPER_DIR/paper.txt` (or `paper.pdf`) exists.

Set the additional path variables:
- `PAPER_TEXT=$PAPER_DIR/paper.txt` (fall back to `$PAPER_DIR/paper.pdf` if `paper.txt` does not exist)
- `PAPER_PDF=$PAPER_DIR/paper.pdf`
- `ANALYSIS_DIR=$PAPER_DIR/analysis`
- `REVIEW_PATH=$PAPER_DIR/review.md`
- `ROUNDS_DIR=$PAPER_DIR/review-rounds` (mkdir if absent)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

Read `$ANALYSIS_DIR/00-paper-profile.md` frontmatter to extract `slug` (used in round filenames).

### 1.2 Solicit objections

Prompt the user (in their invocation language):

```
Adversarial review for <title>.
Raise one or more objections. Format: one objection per line. End input with a blank line.
Examples:
  - The baseline comparison in §4 uses a 3x smaller compute budget; the win is unfair.
  - Claim 2 ("zero-shot generalization") isn't supported because the test set leaks training distribution.
  - Reproducibility: no random seed, no GPU type reported.
```

Wait for user input. Parse as a list of objections (split on newlines, drop empty lines).

### 1.3 Tag each objection

For each objection, infer:
- `dimension`: one of `method | experiment | claim | reproducibility | writing | bio-rigor`. Heuristics:
  - mentions baselines / fairness / training procedures → `method` or `experiment`
  - mentions metrics / variance / seeds / ablations → `experiment`
  - mentions claim/SOTA/generalization correctness → `claim`
  - mentions code / data / hyperparameters / hardware → `reproducibility`
  - mentions clarity / typo / structure → `writing`
  - mentions wet-lab / cell types / biological plausibility → `bio-rigor` (only meaningful when profile's `domain_packs_selected` includes a bio pack)
- `severity`: `major | minor`. Default `major` unless the objection language is explicitly hedged ("could be slightly", "minor point").

Show the user the inferred tags and ask for corrections, e.g.:

```
Objection 1: "The baseline comparison in §4 uses a 3x smaller compute budget; the win is unfair."
  → dimension: method, severity: major
Objection 2: "...":
  → dimension: experiment, severity: minor

Confirm or correct each (e.g. "obj 1 → experiment, minor"). Type 'ok' to proceed.
```

Wait for user. Apply corrections. Proceed when user types `ok` or equivalent.

---

## Stage 2: Defense + Judge dispatches

### 2.1 Determine parallelism

If `--sequential` is set, process objections one at a time through Stages 2.2 → 2.3 → 3 (i.e., run defense, judge, and user confirmation for objection 1, then repeat for objection 2, etc.).

Otherwise (default): dispatch all defense-agent calls in parallel (Stage 2.2), wait, then all judge-agent calls in parallel (Stage 2.3), wait, then proceed to Stage 3.

### 2.2 Dispatch defense-agent (one per objection)

For each objection, dispatch via the Agent tool:

```
Agent(
  description: "defense-agent for objection <i>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/defense-agent.md> + concrete inputs:
    PAPER_TEXT=$PAPER_TEXT
    PAPER_PDF=$PAPER_PDF
    ANALYSIS_DIR=$ANALYSIS_DIR
    OBJECTION=<verbatim objection>
    DIMENSION=<dimension>
)
```

Capture each defense agent's full output text as `DEFENSE_<i>`.

### 2.3 Dispatch judge-agent (one per objection)

For each `(objection, defense)` pair:

```
Agent(
  description: "judge-agent for objection <i>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/judge-agent.md> + concrete inputs:
    OBJECTION=<verbatim objection>
    DEFENSE=<DEFENSE_<i>>
)
```

**Important:** the judge dispatch must NOT include `PAPER_TEXT`, `ANALYSIS_DIR`, or any other paper context. The judge is intentionally blind. Only objection + defense.

Parse the judge's output via the helper:

```bash
echo "$JUDGE_OUTPUT" | node $PLUGIN_ROOT/scripts/parse-judge-output.cjs
```

The helper returns a JSON object `{verdict, reasoning}`. `verdict` is one of `holds | partially_holds | fails`. On parse failure (missing yaml fence, invalid verdict, etc.), the helper returns `{verdict: "partially_holds", reasoning: "Judge output unparseable: ... — manual review required."}` — the orchestrator can use this directly without additional fallback logic.

---

## Stage 3: User confirmation

For each objection, show the user:

```
─── Objection <i> (dimension: <dim>, severity: <sev>) ───

Objection:
<objection text>

Defense (from defense-agent):
<defense text>

Judge verdict: <holds|partially_holds|fails>
Judge reasoning:
<judge reasoning>

Your decision? (confirm | override <new-verdict> <reason>)
```

Wait for user input. Parse:
- `confirm` → `FINAL_VERDICT_<i> = JUDGE_VERDICT_<i>`, `USER_DECISION_<i> = "confirm"`, `USER_REASONING_<i> = ""`.
- `override <verdict> <reason>` → `FINAL_VERDICT_<i> = <verdict>` (validate is one of holds|partially_holds|fails), `USER_DECISION_<i> = "override"`, `USER_REASONING_<i> = <reason>`.

If user input is malformed, re-prompt.

---

## Stage 3.5: Pre-assign round numbers

Before any review-writer dispatch or round-file write, assign round numbers to every objection in this invocation in input order — regardless of their verdict. This avoids races where Stage 4 file writes change `next-round-number.cjs`'s answer for Stage 5 holds-verdict files.

```bash
BASE=$(node $PLUGIN_ROOT/scripts/next-round-number.cjs $ROUNDS_DIR)
```

For objection `i` (1-indexed), `ROUND_NUMBER_<i> = BASE + (i - 1)`. Persist this mapping for use in Stages 4 and 5.

## Stage 4: Review-writer dispatches (only for non-`holds` verdicts)

For each objection where `FINAL_VERDICT_<i>` is `partially_holds` or `fails`:

### 4.1 Dispatch review-writer

```
Agent(
  description: "review-writer for round <N>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/review-writer.md> + inputs:
    REVIEW_PATH=$REVIEW_PATH
    OBJECTION=<verbatim objection>
    DEFENSE=<defense text>
    JUDGE_VERDICT=<final verdict>
    JUDGE_REASONING=<judge reasoning OR user override reasoning if user overrode>
    DIMENSION=<dim>
    SEVERITY=<sev>
    ROUND_NUMBER=<ROUND_NUMBER_<i> from Stage 3.5>
)
```

Capture the snippet returned between `ADDED_SNIPPET_START` / `ADDED_SNIPPET_END` markers as `FINAL_REVIEW_SNIPPET_<i>`.

For `holds` verdicts, skip review-writer. The round file still gets written in Stage 5 using the pre-assigned `ROUND_NUMBER_<i>`; `final_review_snippet` is empty.

---

## Stage 5: Persist round files

For each objection (regardless of verdict), write a round file at `$ROUNDS_DIR/round-<NN>-<short-title>.md`.

### 5.1 Compute filename

- `<NN>`: zero-padded two-digit (or more) round number from Stage 3.5.
- `<short-title>`: derived from the objection text via the helper:

```bash
echo "$OBJECTION" | node $PLUGIN_ROOT/scripts/slugify-objection.cjs
```

The helper returns the slug (or `untitled` if input has no extractable ASCII). Slug rules: lowercase, alphanumeric + hyphens only, first ~6 words, capped at 40 chars.

Example: objection "The baseline comparison in §4 uses a 3x smaller compute budget" → slug `the-baseline-comparison-in-4-uses` → filename `round-01-the-baseline-comparison-in-4-uses.md`.

### 5.2 Write file

Read `$PLUGIN_ROOT/templates/review-round.md` and substitute fields. The frontmatter must contain all 12 required fields per the template:
- `round`: pre-assigned `ROUND_NUMBER_<i>` from Stage 3.5
- `created_at`: current UTC time as ISO8601 (e.g. `2026-04-27T03:59:24Z`)
- `objection`: verbatim user text (use YAML literal block `|`)
- `dimension`, `severity`: as tagged
- `defense`: defense agent's full output (literal block `|`)
- `judge_verdict`, `judge_reasoning`: from Stage 2.3
- `user_decision`, `user_reasoning`: from Stage 3
- `final_verdict`: from Stage 3 (post user input)
- `final_review_snippet`: from Stage 4.1 (empty if verdict was `holds`)

After the frontmatter, write `# Round <NN> — <short-title>` and leave the free-form notes section empty (orchestrator does not auto-populate it).

Use Write tool to create the file. The filename uses zero-padded `NN` from `ROUND_NUMBER_<i>` per Stage 5.1.

---

## Stage 6: Final summary

After all objections are processed, print to chat (in user's invocation language):

```
✓ review-round complete for <slug>

Processed <K> objection(s):
  Round <NN>: <verdict> — <one-line objection summary>
  ...

Outcomes:
  - holds:           <count> (no review.md changes; recorded in review-rounds/ for history)
  - partially_holds: <count> (added to Questions to Authors in review.md)
  - fails:           <count> (added to Weaknesses/<dim> in review.md)

Updated files:
  - review.md (if any partially_holds or fails)
  - review-rounds/round-NN-<title>.md × <K>

Run /paper:review-round again any time to layer more rounds. Run /paper:rerun-stage review to discard all rounds and regenerate review.md from analysis (you'll lose the round history's edits).
```

---

## Notes

- **Translation:** All chat-facing prose (prompts to user, summary) is rendered in the user's invocation language. Round file content (objection, defense, judge output, review.md edits) stays English to match the artifact language matrix from the design spec §8.
- **Failure modes:**
  - defense-agent returns empty / truncated → log warning, treat as if defense was "(no defense produced)" and let judge return `fails`.
  - judge output unparseable → default to `partially_holds`, surface to user in Stage 3.
  - review-writer fails to write → log error, persist the round file with `final_review_snippet` empty and a note "review-writer failed: see chat".
- **No idempotence skip:** unlike `study-deep`'s default skip-existing behavior, every invocation of `/paper:review-round` produces fresh rounds. The user is the source of truth for what to argue about.
