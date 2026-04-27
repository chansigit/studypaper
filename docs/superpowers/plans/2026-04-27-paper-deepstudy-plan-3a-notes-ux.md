# paper-deepstudy Plan 3a: Notes UX Refinement Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three interactive refinement commands to the `paper-deepstudy` plugin: `/paper:refine-notes [xhs|wechat]` (apply user edit instructions to existing renderings), `/paper:retitle [xhs|wechat]` (regenerate title candidates and swap one in), and `/paper:reselect-figures` (re-pick figures from the analysis and re-render xhs/wechat).

**Architecture:** All three commands operate on Plan 1's per-paper outputs (`notes/source.md`, `notes/titles.md`, `notes/xhs.md`, `notes/wechat.md`, `analysis/06-figures.md`). Each refinement writes a `<file>.bak.NN` backup before mutating. No new sub-Agent prompts are needed — Plan 1's `xhs-renderer`, `wechat-renderer`, and `title-generator` prompts already accept the necessary inputs (`EDIT_INSTRUCTION`, `EXISTING_PATH`, `STYLE_FILTER`, `SELECTED_FIGURES`). Plan 3a just adds three orchestration skills that wire user input into those existing prompts.

**Tech Stack:**
- Markdown (skill instructions, command files)
- Bash (interactive prompts, backup logic, slash command files)
- Claude Code Agent tool for sub-Agent dispatch
- Bats for structural unit tests
- Plan 3a depends on Plan 1's plugin (xhs-renderer, wechat-renderer, title-generator prompts; the four `notes/*.md` outputs; `analysis/06-figures.md`) and on Plan 4's domain packs being available (no direct dependency, just convention).

**Key design decisions (carried from spec §5 and §6):**
- **`source.md` is invariant under refinement.** All three commands operate downstream of `notes/source.md`. If the user wants content changes (not just rendering changes), the orchestrator detects this and asks "update source.md and re-render both platforms?" — but does not silently mutate source.
- **Backups before mutation.** Every refinement writes `<file>.bak.NN` before overwriting (smallest non-existent integer ≥ 1).
- **Interactive but bounded.** Each command has a clear input → ask → confirm → apply loop. The user can iterate (run the command again with another edit) but each invocation is one round-trip.
- **Reuse existing prompts.** No new sub-Agent prompts. The orchestration skills dispatch `xhs-renderer.md`, `wechat-renderer.md`, or `title-generator.md` from Plan 1 with appropriate inputs.

---

## File Structure

The plugin source lives at `/Users/chensijie/Projects/studypaper/paper-deepstudy/`:

```
paper-deepstudy/
├── commands/
│   ├── study.md                    (Plan 1)
│   ├── rerun-stage.md              (Plan 1)
│   ├── review-round.md             (Plan 2)
│   ├── refine-notes.md             (NEW — Task 1)
│   ├── retitle.md                  (NEW — Task 3)
│   └── reselect-figures.md         (NEW — Task 5)
├── skills/
│   ├── study-deep/SKILL.md         (Plan 1)
│   ├── review-round/SKILL.md       (Plan 2)
│   ├── refine-notes/SKILL.md       (NEW — Task 2)
│   ├── retitle/SKILL.md            (NEW — Task 4)
│   └── reselect-figures/SKILL.md   (NEW — Task 6)
├── prompts/                         (Plan 1+2 — NO CHANGES)
├── domain-packs/                    (Plan 1+4 — NO CHANGES)
├── templates/                       (Plan 1+2 — NO CHANGES)
├── scripts/                         (Plan 1+2 — NO CHANGES)
└── tests/
    ├── unit/
    │   ├── test-commands.bats                            (modified — append 6 @tests, 2 per command)
    │   └── test-prompts-have-required-sections.bats      (modified — append 3 @tests, one per skill)
    └── integration/
        └── test-end-to-end.sh      (modified — Task 7 extends commands list and adds skill checks)
```

Per-paper outputs touched by Plan 3a (under `~/claude-papers/papers/<slug>/`):

```
notes/
├── source.md       (read-only by Plan 3a — except when user opts in to source-level edits)
├── titles.md       (modified by /paper:retitle — appends to ## history, replaces ## xhs / ## wechat groups)
├── xhs.md          (modified by /paper:refine-notes xhs / /paper:retitle xhs / /paper:reselect-figures)
└── wechat.md       (modified by /paper:refine-notes wechat / /paper:retitle wechat / /paper:reselect-figures)

notes/*.bak.NN      (backups produced before any mutation — ignored by .gitignore from Plan 1)
```

---

## Pre-flight

1. Plan 1, 2, 4 must all be merged to `main` (this branch should be off the post-Plan-4 main).
2. Existing tests pass:
   ```bash
   cd paper-deepstudy && npm run test:unit && cd ..
   paper-deepstudy/tests/integration/test-end-to-end.sh
   ```
   Expect 66 bats + 2 node + integration smoke pass.

---

### Task 1: `/paper:refine-notes` slash command

**Files:**
- Create: `paper-deepstudy/commands/refine-notes.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

Append to `paper-deepstudy/tests/unit/test-commands.bats`:

```bash
@test "refine-notes.md has frontmatter" {
  head -1 commands/refine-notes.md | grep -qE '^---$'
}

@test "refine-notes.md mentions both platforms" {
  grep -qF 'xhs' commands/refine-notes.md
  grep -qF 'wechat' commands/refine-notes.md
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-commands.bats`
Expected: 2 new failures.

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/refine-notes.md`:

```markdown
---
name: paper:refine-notes
description: Apply a user edit instruction to an existing rendered note (xhs or wechat). Reads the current rendering, dispatches the matching renderer with EDIT_INSTRUCTION, writes back with a backup of the prior version.
argument-hint: "[xhs|wechat] [--paper <slug>]"
---

# /paper:refine-notes

Invokes the `refine-notes` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:refine-notes xhs` — refine the Xiaohongshu rendering of the most recently studied paper.
- `/paper:refine-notes wechat` — refine the WeChat rendering.
- `/paper:refine-notes xhs --paper attention-is-all-you-need` — target a specific paper.

The skill will show you the current rendering, ask what to change, dispatch the appropriate renderer (`xhs-renderer` or `wechat-renderer`) with your edit instruction, and write the new version back. The prior version is preserved as `notes/<platform>.md.bak.NN`.

If your edit instruction sounds like a content change (not just rephrasing / restructuring), the skill will pause and ask whether you want to update `notes/source.md` and re-render both platforms instead.

Pre-requisites: `/paper:study` must have produced `notes/source.md` and `notes/<platform>.md` already.
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-commands.bats`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/refine-notes.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:refine-notes command"
```

---

### Task 2: `skills/refine-notes/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/refine-notes/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing tests**

Append to `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "refine-notes SKILL.md has YAML frontmatter with name" {
  head -5 skills/refine-notes/SKILL.md | grep -qF 'name: refine-notes'
}

@test "refine-notes SKILL.md mentions xhs-renderer and wechat-renderer dispatch" {
  grep -qF 'xhs-renderer' skills/refine-notes/SKILL.md
  grep -qF 'wechat-renderer' skills/refine-notes/SKILL.md
}

@test "refine-notes SKILL.md describes .bak. backup convention" {
  grep -qF '.bak.' skills/refine-notes/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`
Expected: 3 new failures.

- [ ] **Step 3: Create skills directory and SKILL.md**

```bash
mkdir -p paper-deepstudy/skills/refine-notes
```

`paper-deepstudy/skills/refine-notes/SKILL.md`:

```markdown
---
name: refine-notes
description: Use when the user wants to refine an existing xhs.md or wechat.md rendering with a specific edit instruction. Dispatches the matching renderer with EDIT_INSTRUCTION, backs up the prior version.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: refine-notes workflow

Invoke after `/paper:study` has produced `notes/source.md`, `notes/titles.md`, `notes/xhs.md`, and `notes/wechat.md`. Each invocation refines one platform's rendering based on the user's instruction.

Required first arg: `xhs` or `wechat`.
Optional flag: `--paper <slug>` (default: most recently modified paper folder).

---

## Stage 1: Setup

### 1.1 Resolve target paper and platform

Parse the user's command. The first positional argument selects the platform:
- `xhs` → operate on `notes/xhs.md`
- `wechat` → operate on `notes/wechat.md`

If neither is provided or the value is invalid, abort with: "Usage: /paper:refine-notes [xhs|wechat] [--paper <slug>]".

If `--paper <slug>` is provided, set `PAPER_DIR=~/claude-papers/papers/<slug>`. Otherwise:

```bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1)
```

Strip trailing slash. Verify:
- `$PAPER_DIR/notes/source.md` exists. If not, abort: "No notes/source.md at <path>. Run /paper:study on this paper first."
- `$PAPER_DIR/notes/<platform>.md` exists. If not, abort: "No notes/<platform>.md at <path>. Run /paper:study or /paper:rerun-stage notes."
- `$PAPER_DIR/notes/titles.md` exists.

Set:
- `SOURCE_PATH=$PAPER_DIR/notes/source.md`
- `TITLES_PATH=$PAPER_DIR/notes/titles.md`
- `EXISTING_PATH=$PAPER_DIR/notes/<platform>.md`
- `OUTPUT_PATH=$EXISTING_PATH` (refine-notes overwrites in place)
- `PLATFORM=<xhs|wechat>`
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`
- `PROMPT_PATH=$PLUGIN_ROOT/prompts/<platform>-renderer.md`
- `TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/<platform>.md`

### 1.2 Show current rendering and solicit edit instruction

Read `EXISTING_PATH`. Show the user a preview (last 60 lines, or full file if shorter) along with this prompt (in user's invocation language):

```
Current notes/<platform>.md (<line count> lines, ~<char count> Chinese chars):

<preview>

What would you like to change? Examples:
  - "shorten paragraph 3"
  - "regenerate the hook with more concrete examples"
  - "remove the formula in §方法 and explain it in plain language instead"
  - "swap the embedded figure to figure-2.png"

Type your instruction (or 'cancel' to abort):
```

Wait for user input. Capture the instruction as `EDIT_INSTRUCTION`. If user says `cancel`, exit gracefully without modifying anything.

### 1.3 Detect content-level vs. rendering-level edits

Inspect `EDIT_INSTRUCTION`. Heuristics for "this is a content change, not just rendering":

- mentions adding a new fact / claim / number not in `source.md`
- mentions correcting a misunderstanding ("the paper actually shows X, fix this")
- mentions changing the take-away or section 9 conclusion
- mentions adding / removing a whole section (vs. rephrasing one)

If any heuristic fires, pause and ask:

```
This sounds like a change to the underlying notes content, not just the <platform> rendering. The right fix may be to update notes/source.md (which is the shared source for both xhs and wechat) and re-render both platforms.

Options:
  1. Apply only to <platform>.md (it'll diverge from source.md). Type 'rendering'.
  2. Update source.md and re-render both. Type 'source'.
  3. Cancel. Type 'cancel'.
```

Wait for user. If `source`, exit this skill and show the user this guidance:

> "To update source.md and re-render both platforms:
> 1. Manually edit `notes/source.md` with your content change.
> 2. **Do NOT run `/paper:rerun-stage notes`** — that re-runs notes-writer and would overwrite your source.md edits.
> 3. Instead, run `/paper:refine-notes xhs` and `/paper:refine-notes wechat` separately, with a rendering-level instruction like 'sync to updated source.md' for each. The renderers read source.md on each invocation, so they'll pick up your edits."
>
> (A future Plan 3b may add a dedicated `/paper:rerender-notes` command for this workflow.)

(Do NOT auto-modify source.md from this skill.)

If `rendering`, proceed to Stage 2 with the original `EDIT_INSTRUCTION`.

If `cancel`, exit gracefully.

If no heuristic fires (instruction is rendering-level), proceed directly to Stage 2.

---

## Stage 2: Backup + dispatch + write

### 2.1 Backup the current rendering

Compute the next available `.bak.NN` suffix using shell logic (no separate helper script needed):

```bash
NN=1
while [ -e "$EXISTING_PATH.bak.$NN" ]; do
  NN=$((NN + 1))
done
BAK_PATH="$EXISTING_PATH.bak.$NN"
cp "$EXISTING_PATH" "$BAK_PATH"
```

After this, the prior version is preserved at `$EXISTING_PATH.bak.<NN>` for rollback.

### 2.2 Dispatch the renderer

Read `PROMPT_PATH` (the matching `xhs-renderer.md` or `wechat-renderer.md` from Plan 1 — they already declare `EDIT_INSTRUCTION` and `EXISTING_PATH` as inputs). Re-pick figures from the existing rendering's frontmatter (do NOT change the figure selection in this skill — that's `/paper:reselect-figures`'s job).

Read `EXISTING_PATH`'s YAML frontmatter to extract its current `figures:` list. The frontmatter typically contains basenames (e.g. `page_3_img_1.png`). Reconstruct absolute paths by prepending `$PAPER_DIR/images/` to each basename. Set `SELECTED_FIGURES` to the resulting list of absolute paths.

Dispatch via the Agent tool:

```
Agent(
  description: "<platform>-renderer applying user edit",
  subagent_type: "general-purpose",
  prompt: <contents of $PROMPT_PATH> + concrete inputs:
    SOURCE_PATH=$SOURCE_PATH
    TITLES_PATH=$TITLES_PATH
    OUTPUT_PATH=$OUTPUT_PATH
    TEMPLATE_PATH=$TEMPLATE_PATH
    SELECTED_FIGURES=<list of figure paths from current frontmatter>
    EDIT_INSTRUCTION=<verbatim user instruction>
    EXISTING_PATH=$BAK_PATH    (so the renderer can read the prior version for context)
)
```

Wait for completion. The renderer writes the new version directly to `$OUTPUT_PATH`.

### 2.3 Verify output

If `$OUTPUT_PATH` no longer exists or is empty, restore from backup:

```bash
if [ ! -s "$OUTPUT_PATH" ]; then
  cp "$BAK_PATH" "$OUTPUT_PATH"
  echo "WARN: renderer produced empty output; restored from $BAK_PATH"
fi
```

---

## Stage 3: Show diff and offer iteration

Show the user a brief summary (in their language):

```
✓ Applied edit to notes/<platform>.md
  Backup: notes/<platform>.md.bak.<NN>
  Diff (lines changed): <wc -l before> → <wc -l after>

Want another round? Run /paper:refine-notes <platform> again.
Want to roll back? cp notes/<platform>.md.bak.<NN> notes/<platform>.md
```

---

## Notes

- **Translation:** Chat-facing prose to user is in user's invocation language. The rendering itself stays Chinese (the renderer prompt enforces this).
- **No idempotence skip.** Each invocation produces a fresh edit. Backups accumulate as `.bak.1`, `.bak.2`, etc.
- **Failure modes:**
  - User cancels → no mutation, no backup created.
  - Renderer fails / produces empty output → restore from backup automatically, surface warning.
  - User instruction is a content change → defer to user via the source/rendering split prompt in Stage 1.3.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/refine-notes/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): refine-notes orchestration skill"
```

---

### Task 3: `/paper:retitle` slash command

**Files:**
- Create: `paper-deepstudy/commands/retitle.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "retitle.md has frontmatter" {
  head -1 commands/retitle.md | grep -qE '^---$'
}

@test "retitle.md mentions style filter" {
  grep -qF -e '--style' commands/retitle.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/retitle.md`:

```markdown
---
name: paper:retitle
description: Regenerate 5 title candidates for an existing xhs or wechat rendering, let the user pick one, swap it into the rendering, and archive the prior title. Optional --style filter to bias the candidates.
argument-hint: "[xhs|wechat] [--style <hook|literal|question|numbers|contrast>] [--paper <slug>]"
---

# /paper:retitle

Invokes the `retitle` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:retitle xhs` — regenerate Xiaohongshu titles, pick one, apply.
- `/paper:retitle wechat` — same for WeChat.
- `/paper:retitle xhs --style hook` — bias candidates toward the hook style.
- `/paper:retitle wechat --paper attention-is-all-you-need` — target a specific paper.

Style options (from `title-generator.md`):
- `hook` — curiosity-inducing tease
- `literal` — descriptive but tighter
- `question` — poses a question
- `numbers` — leads with a striking number
- `contrast` — A vs. B framing

Without `--style`, the generator produces one of each style.

The chosen title replaces the rendering's frontmatter `title:` field; the previous title moves into `notes/titles.md` `## history` section. The rendering's body and figure list are untouched.

Pre-requisites: `/paper:study` must have produced `notes/source.md`, `notes/titles.md`, and `notes/<platform>.md` already.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/retitle.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:retitle command"
```

---

### Task 4: `skills/retitle/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/retitle/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "retitle SKILL.md has YAML frontmatter with name" {
  head -5 skills/retitle/SKILL.md | grep -qF 'name: retitle'
}

@test "retitle SKILL.md mentions title-generator dispatch" {
  grep -qF 'title-generator' skills/retitle/SKILL.md
}

@test "retitle SKILL.md describes history archival" {
  grep -qF 'history' skills/retitle/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Create the SKILL.md**

```bash
mkdir -p paper-deepstudy/skills/retitle
```

`paper-deepstudy/skills/retitle/SKILL.md`:

```markdown
---
name: retitle
description: Use when the user wants to regenerate title candidates for an existing xhs.md or wechat.md rendering and pick a new one. Re-dispatches title-generator with optional --style filter, lets the user choose, swaps the title into the rendering, archives the prior title.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: retitle workflow

Invoke after `/paper:study` has produced the notes set. Each invocation regenerates titles for one platform and applies the user's choice.

Required first arg: `xhs` or `wechat`.
Optional flags:
- `--style <hook|literal|question|numbers|contrast>`: bias the generator toward one style. Without this, the generator produces one of each style (5 candidates total).
- `--paper <slug>`: target a specific paper folder.

---

## Stage 1: Setup

### 1.1 Resolve target paper and platform

Parse first positional arg as `PLATFORM` (must be `xhs` or `wechat`). If invalid, abort with usage hint.

Resolve `PAPER_DIR` from `--paper <slug>` or default to most recent. Verify `notes/source.md`, `notes/titles.md`, and `notes/<platform>.md` all exist; abort with helpful message otherwise.

Capture `--style <value>` if present as `STYLE_FILTER`; validate it's one of the 5 allowed values.

Set:
- `SOURCE_PATH=$PAPER_DIR/notes/source.md`
- `TITLES_PATH=$PAPER_DIR/notes/titles.md`
- `RENDERING_PATH=$PAPER_DIR/notes/<platform>.md`
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

### 1.2 Read current title

Read the YAML frontmatter of `$RENDERING_PATH` to extract its current `title:` value as `OLD_TITLE`.

---

## Stage 2: Generate new candidates

### 2.1 Backup `titles.md`

```bash
TITLES_BAK_NN=1
while [ -e "$TITLES_PATH.bak.$TITLES_BAK_NN" ]; do
  TITLES_BAK_NN=$((TITLES_BAK_NN + 1))
done
TITLES_BAK_PATH="$TITLES_PATH.bak.$TITLES_BAK_NN"
cp "$TITLES_PATH" "$TITLES_BAK_PATH"
```

### 2.2 Dispatch title-generator

Read `$PLUGIN_ROOT/prompts/title-generator.md`. Dispatch:

```
Agent(
  description: "title-generator (retitle for <platform>)",
  subagent_type: "general-purpose",
  prompt: <contents of title-generator.md> + concrete inputs:
    SOURCE_PATH=$SOURCE_PATH
    OUTPUT_PATH=$TITLES_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/titles.md
    STYLE_FILTER=<STYLE_FILTER if set, else omit>
)
```

Wait for completion. The generator writes a fresh `titles.md` with new candidates in `## xhs` and `## wechat` sections.

**Important:** the generator overwrites `titles.md` for both platforms. The other platform's section also gets refreshed. This is intentional — calling retitle bumps both lists, but only the targeted platform's rendering is updated. To preserve the other platform's title selection, the orchestrator extracts and re-applies it after Stage 4 (see Stage 4.2).

### 2.3 Show new candidates to user

Parse the new `titles.md`'s `## <platform>` group. Show the user (in their invocation language):

```
New title candidates for <platform>:
  1. <candidate 1> — <style>
  2. <candidate 2> — <style>
  3. <candidate 3> — <style>
  4. <candidate 4> — <style>
  5. <candidate 5> — <style>

Current title: "<OLD_TITLE>"

Which one? (number 1-5, or 'keep' to abort and revert titles.md, or 'regen' to re-run with a different style filter)
```

Wait for user input. Parse:
- Number 1-5 → `NEW_TITLE = candidates[<num> - 1]`. Proceed to Stage 3.
- `keep` → restore `titles.md` from `$TITLES_BAK_PATH`, exit gracefully.
- `regen` → re-prompt for style, then re-dispatch title-generator (loop back to Stage 2.2). Cap at 3 regens to avoid runaway.

**Important:** `$TITLES_BAK_PATH` (set in Stage 2.1) is the SINGLE original-state backup taken on first entry to this stage. Even if the user re-runs Stage 2.2 multiple times via `regen`, this restore point does NOT change — `keep` always restores the pre-retitle state. Stage 2.1 must NOT be re-executed during the regen loop. The `regen` branch loops back to Stage 2.2 (NOT Stage 2.1), so the original backup persists.

---

## Stage 3: Apply title to rendering

### 3.1 Backup the rendering

```bash
RENDERING_BAK_NN=1
while [ -e "$RENDERING_PATH.bak.$RENDERING_BAK_NN" ]; do
  RENDERING_BAK_NN=$((RENDERING_BAK_NN + 1))
done
RENDERING_BAK_PATH="$RENDERING_PATH.bak.$RENDERING_BAK_NN"
cp "$RENDERING_PATH" "$RENDERING_BAK_PATH"
```

### 3.2 Replace the title

Use the Edit tool to replace the YAML frontmatter `title:` line in `$RENDERING_PATH`. The YAML frontmatter looks like:

```
---
title: <OLD_TITLE>
length_target: ...
length_max: ...
figures:
...
---
```

Replace `title: <OLD_TITLE>` with `title: <NEW_TITLE>`. Also replace any first-line H1 `# <OLD_TITLE>` after the frontmatter (if it matches `OLD_TITLE` exactly; otherwise leave the H1 alone).

---

## Stage 4: Archive old title and restore other platform's title

### 4.1 Append OLD_TITLE to titles.md history section

Read `$TITLES_PATH`. Find the `## history` section (the titles template seeds an empty placeholder). Append:

```
- <OLD_TITLE> — replaced for <platform> on <iso8601-utc>
```

Use the Edit tool. If `## history` section is missing (shouldn't happen; the template includes it), append it at end of file.

### 4.2 Restore the other platform's title selection

The other platform (the one not being retitled) had its `## <other-platform>` group overwritten in Stage 2.2. Read `$TITLES_BAK_PATH` (Stage 2.1's backup) and extract the prior `## <other-platform>` group. Replace the new file's `## <other-platform>` group with the saved one using the Edit tool.

This guarantees:
- Targeted platform: new candidates
- Other platform: unchanged

---

## Stage 5: Final summary

```
✓ Retitled notes/<platform>.md
  New title: "<NEW_TITLE>"
  Old title archived in titles.md ## history
  Backups:
    titles.md.bak.<TITLES_BAK_NN>
    <platform>.md.bak.<RENDERING_BAK_NN>
```

---

## Notes

- **Translation:** chat-facing prose follows user's invocation language. Title content stays in the language Plan 1 produces (Chinese for xhs/wechat per spec §8).
- **`--regen` loop is capped at 3 to prevent runaway.**
- **Renderer is NOT re-dispatched.** Only the title is swapped; the body of the rendering is untouched. To apply broader changes, use `/paper:refine-notes`.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/retitle/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): retitle orchestration skill"
```

---

### Task 5: `/paper:reselect-figures` slash command

**Files:**
- Create: `paper-deepstudy/commands/reselect-figures.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "reselect-figures.md has frontmatter" {
  head -1 commands/reselect-figures.md | grep -qE '^---$'
}

@test "reselect-figures.md mentions reinterpret flag" {
  grep -qF -e '--reinterpret' commands/reselect-figures.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/reselect-figures.md`:

```markdown
---
name: paper:reselect-figures
description: Re-pick which figures get embedded in xhs.md and wechat.md. Shows the user the figures from analysis/06-figures.md with their importance scores and captions; user multi-selects per platform; renderers are re-dispatched with the new selections.
argument-hint: "[--reinterpret] [--paper <slug>]"
---

# /paper:reselect-figures

Invokes the `reselect-figures` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:reselect-figures` — interactively pick figures for both xhs and wechat from the existing `analysis/06-figures.md`.
- `/paper:reselect-figures --reinterpret` — first re-run `figure-interpreter` to refresh the importance scores, then proceed.
- `/paper:reselect-figures --paper attention-is-all-you-need` — target a specific paper.

The skill will list every figure under `images/` along with the interpreter's importance score and caption, then prompt you to select:
- 1 figure for xhs.md
- 2-3 figures for wechat.md

Both renderings are then re-dispatched with the new figure selections. The body content is preserved (the renderers respect existing `EDIT_INSTRUCTION`-style refinement when wired in; here `EDIT_INSTRUCTION` is omitted, so the renderers re-render from `source.md` and `titles.md` with the new figures).

The prior xhs.md and wechat.md are backed up as `.bak.NN`.

Pre-requisites: `/paper:study` must have produced `analysis/06-figures.md`, `notes/source.md`, `notes/titles.md`, `notes/xhs.md`, and `notes/wechat.md` already.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/reselect-figures.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:reselect-figures command"
```

---

### Task 6: `skills/reselect-figures/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/reselect-figures/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "reselect-figures SKILL.md has YAML frontmatter with name" {
  head -5 skills/reselect-figures/SKILL.md | grep -qF 'name: reselect-figures'
}

@test "reselect-figures SKILL.md mentions xhs-renderer and wechat-renderer dispatch" {
  grep -qF 'xhs-renderer' skills/reselect-figures/SKILL.md
  grep -qF 'wechat-renderer' skills/reselect-figures/SKILL.md
}

@test "reselect-figures SKILL.md mentions figure-interpreter for --reinterpret" {
  grep -qF 'figure-interpreter' skills/reselect-figures/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Create the SKILL.md**

```bash
mkdir -p paper-deepstudy/skills/reselect-figures
```

`paper-deepstudy/skills/reselect-figures/SKILL.md`:

```markdown
---
name: reselect-figures
description: Use when the user wants to change which figures are embedded in xhs.md and wechat.md. Shows the user the figures with importance scores from analysis/06-figures.md, lets them multi-select per platform, re-runs both renderers with new selections.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: reselect-figures workflow

Invoke after `/paper:study` has produced `analysis/06-figures.md` plus the notes set. Both `notes/xhs.md` and `notes/wechat.md` are re-rendered with the new figure selections; their prior versions are backed up.

Optional flags:
- `--reinterpret`: re-run `figure-interpreter` first to refresh `analysis/06-figures.md` importance scores. Useful if the original interpretation was off.
- `--paper <slug>`: target a specific paper folder.

---

## Stage 1: Setup

### 1.1 Resolve target paper

Resolve `PAPER_DIR` from `--paper <slug>` or default to most recent. Verify required files:
- `$PAPER_DIR/analysis/06-figures.md`
- `$PAPER_DIR/images/` directory (non-empty)
- `$PAPER_DIR/notes/source.md`
- `$PAPER_DIR/notes/titles.md`
- `$PAPER_DIR/notes/xhs.md`
- `$PAPER_DIR/notes/wechat.md`

Abort with helpful message if any are missing.

Set:
- `FIGURES_MD=$PAPER_DIR/analysis/06-figures.md`
- `IMAGES_DIR=$PAPER_DIR/images`
- `XHS_PATH=$PAPER_DIR/notes/xhs.md`
- `WECHAT_PATH=$PAPER_DIR/notes/wechat.md`
- `SOURCE_PATH=$PAPER_DIR/notes/source.md`
- `TITLES_PATH=$PAPER_DIR/notes/titles.md`
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

### 1.2 Optionally re-interpret figures

If `--reinterpret` is set:

First, back up the existing `06-figures.md`:

```bash
NN=1
while [ -e "$FIGURES_MD.bak.$NN" ]; do
  NN=$((NN + 1))
done
cp "$FIGURES_MD" "$FIGURES_MD.bak.$NN"
```

Then dispatch figure-interpreter:

```
Agent(
  description: "figure-interpreter (refresh scores)",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/figure-interpreter.md> + concrete inputs:
    PAPER_TEXT=$PAPER_DIR/paper.txt (or paper.pdf if .txt missing)
    IMAGES_DIR=$IMAGES_DIR
    OUTPUT_PATH=$FIGURES_MD
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/analysis/06-figures.md
)
```

Wait for completion.

If `--reinterpret` is not set, skip this step.

---

## Stage 2: Show figures to user

### 2.1 Parse 06-figures.md

Read `$FIGURES_MD`. Parse YAML frontmatter to extract the `figures:` list — for each figure, capture `file`, `caption`, `importance`, `role`.

If the YAML is the FAILED placeholder (`<!-- FAILED: ... -->`), abort: "analysis/06-figures.md is FAILED — re-run /paper:rerun-stage analysis or /paper:reselect-figures --reinterpret first."

### 2.2 Display the menu

Show the user (in their invocation language):

```
Figures available (from analysis/06-figures.md):

  [1] page_1_img_1.png  importance=0.95  role=architecture
      Caption: "Overview of the model showing input → encoder → decoder."

  [2] page_3_img_2.png  importance=0.85  role=main-result
      Caption: "BLEU on WMT'14: our method 28.4 vs prior 27.3."

  [3] ...

Pick figures:
  - For xhs (1 figure): type a number, e.g. "1"
  - For wechat (2-3 figures): type comma-separated numbers, e.g. "1,2,4"
  - Type 'cancel' to abort.

xhs choice:
```

Wait for user input. Validate:
- xhs: exactly 1 number, must be in range [1, len(figures)].
- Re-prompt on invalid.

Then prompt for wechat:

```
wechat choice (2-3 numbers, comma-separated):
```

Wait for user input. Validate:
- wechat: 2 or 3 numbers, all in range, no duplicates.
- Re-prompt on invalid.

Set:
- `XHS_FIGURES=[<images_dir>/<filename> for the chosen xhs figure]` (1 path)
- `WECHAT_FIGURES=[<images_dir>/<filename> for each chosen wechat figure]` (2-3 paths)

If user types 'cancel' at either prompt, exit gracefully without modifying anything.

---

## Stage 3: Backup + dispatch renderers

### 3.1 Back up both renderings

```bash
for path in "$XHS_PATH" "$WECHAT_PATH"; do
  NN=1
  while [ -e "$path.bak.$NN" ]; do
    NN=$((NN + 1))
  done
  cp "$path" "$path.bak.$NN"
done
```

### 3.2 Dispatch xhs-renderer + wechat-renderer in parallel

Issue both Agent calls in one message:

```
Agent(  // xhs
  description: "xhs-renderer with new figure selection",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/xhs-renderer.md> + concrete inputs:
    SOURCE_PATH=$SOURCE_PATH
    TITLES_PATH=$TITLES_PATH
    OUTPUT_PATH=$XHS_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/xhs.md
    SELECTED_FIGURES=<XHS_FIGURES>
)

Agent(  // wechat
  description: "wechat-renderer with new figure selection",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/wechat-renderer.md> + concrete inputs:
    SOURCE_PATH=$SOURCE_PATH
    TITLES_PATH=$TITLES_PATH
    OUTPUT_PATH=$WECHAT_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/notes/wechat.md
    SELECTED_FIGURES=<WECHAT_FIGURES>
)
```

(Note: `EDIT_INSTRUCTION` and `EXISTING_PATH` are intentionally omitted — this skill re-renders from scratch with new figures. The user's prior body edits will not be preserved. If the user wants to preserve body edits, they should use `/paper:refine-notes` with a figure-swap instruction instead.)

### 3.3 Verify outputs

If either output is missing or empty, restore from backup:

```bash
for path in "$XHS_PATH" "$WECHAT_PATH"; do
  if [ ! -s "$path" ]; then
    bak=$(ls -t "$path".bak.* 2>/dev/null | head -1)
    if [ -n "$bak" ]; then
      cp "$bak" "$path"
      echo "WARN: renderer produced empty output for $(basename "$path"); restored from $bak"
    fi
  fi
done
```

---

## Stage 4: Final summary

```
✓ Reselected figures for both renderings.
  xhs.md:    <new figure list> (was: <prior figure list>)
  wechat.md: <new figure list> (was: <prior figure list>)
  Backups:
    notes/xhs.md.bak.<NN>
    notes/wechat.md.bak.<NN>
    <if --reinterpret was set: analysis/06-figures.md.bak.<NN>>
```

---

## Notes

- **Body content is regenerated.** Unlike `/paper:refine-notes` which surgically edits, `/paper:reselect-figures` re-renders both files from `source.md`. Prior body edits (e.g., from earlier `/paper:refine-notes` rounds) will be lost. To preserve body edits, use `/paper:refine-notes <platform>` and ask the renderer to swap a figure as part of the instruction.
- **--reinterpret only refreshes scores, doesn't change image files.** The actual image files in `images/` are produced by `claude-paper:study` and are read-only here.
- **Translation:** chat-facing prose to user is in user's invocation language. Renderings stay Chinese.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/reselect-figures/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): reselect-figures orchestration skill"
```

---

### Task 7: Integration smoke test extension

**Files:**
- Modify: `paper-deepstudy/tests/integration/test-end-to-end.sh`

Extend the integration smoke test to verify the 3 new commands and 3 new skills exist.

- [ ] **Step 1: Modify the script**

In `paper-deepstudy/tests/integration/test-end-to-end.sh`:

(a) **Extend the commands list** in check #6. Find:

```bash
for c in study rerun-stage review-round; do
```

Replace with:

```bash
for c in study rerun-stage review-round refine-notes retitle reselect-figures; do
```

(b) **Add a new check #8** for the three new skills, immediately before the final `if [ $fail -ne 0 ]; then`:

```bash
# 8. Plan 3a skills exist
for s in refine-notes retitle reselect-figures; do
  if [ ! -f "$ROOT/skills/$s/SKILL.md" ]; then
    echo "FAIL: skill $s missing"; fail=1
  fi
done
```

- [ ] **Step 2: Run, verify pass**

```bash
paper-deepstudy/tests/integration/test-end-to-end.sh
```
Expected: `Integration smoke test: PASSED`.

- [ ] **Step 3: Commit**

```bash
git add paper-deepstudy/tests/integration/test-end-to-end.sh
git commit -m "test(paper-deepstudy): integration smoke covers Plan 3a commands and skills"
```

---

### Task 8: README update

**Files:**
- Modify: `paper-deepstudy/README.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

Append to `paper-deepstudy/tests/unit/test-commands.bats`:

```bash
@test "README documents /paper:refine-notes" {
  grep -qF '/paper:refine-notes' README.md
}

@test "README documents /paper:retitle" {
  grep -qF '/paper:retitle' README.md
}

@test "README documents /paper:reselect-figures" {
  grep -qF '/paper:reselect-figures' README.md
}
```

- [ ] **Step 2: Run, verify fail**

`bats paper-deepstudy/tests/unit/test-commands.bats`
Expected: 3 new failures.

### Step 3: Edit README

Read `paper-deepstudy/README.md` first. Make 2 changes:

(a) **Add a new "Notes UX refinement" sub-section under "## Usage".** Insert it AFTER the "### Adversarial review round" sub-section (which lives between "Re-run a specific stage" and the "What you get" section). Insert this block (replace the leading triple-backticks with literal triple backticks when writing — the escapes here are because of nested fences):

```
### Refine the rendered notes

After /paper:study has produced notes/xhs.md and notes/wechat.md, you can iterate without re-running the full pipeline:

\`\`\`
/paper:refine-notes xhs              # apply an edit instruction to xhs.md
/paper:refine-notes wechat           # apply an edit instruction to wechat.md
/paper:retitle xhs                   # regenerate 5 title candidates, pick one
/paper:retitle wechat --style hook   # bias candidates toward a style
/paper:reselect-figures              # re-pick which figures get embedded
/paper:reselect-figures --reinterpret  # re-run figure-interpreter first, then re-pick
\`\`\`

All three commands back up the prior version as `notes/<file>.bak.NN` before mutating, so you can roll back any time.
```

(b) **Update the Roadmap section.** Find:

```
- **Plan 3:** seven refinement commands (`refine-notes`, `deep-dive`, `compare`, `reselect-figures`, `retitle`, `add-prior-work`, `reproduce-check`).
```

Replace with:

```
- **Plan 3a (this branch):** notes UX commands — `refine-notes`, `retitle`, `reselect-figures`. ✓
- **Plan 3b (future):** analysis-extension commands — `deep-dive`, `compare`, `add-prior-work`.
- **Plan 3c (future):** `reproduce-check` audit command.
```

- [ ] **Step 4: Verify**

```bash
bats paper-deepstudy/tests/unit/test-commands.bats
paper-deepstudy/tests/integration/test-end-to-end.sh
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/README.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "docs(paper-deepstudy): README documents Plan 3a notes UX commands"
```

---

## Self-Review checklist (run after Plan 3a complete)

- [ ] All 6 new files exist (3 commands + 3 skills).
- [ ] Each new command file has YAML frontmatter (name + description + argument-hint).
- [ ] Each new skill SKILL.md has YAML frontmatter with `name` + `description` + `allowed-tools`.
- [ ] `cd paper-deepstudy && npm run test:unit` passes (was 66 bats; +6 from Tasks 1/3/5 + +9 from Tasks 2/4/6 + +3 from Task 8 = 84 expected; verify actual count).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` passes; check #6 lists 6 commands, check #8 lists 3 skills.
- [ ] Each refinement skill describes the `.bak.NN` backup convention.
- [ ] `refine-notes` has the source-vs-rendering split prompt (Stage 1.3).
- [ ] `retitle` archives old titles to `## history` (Stage 4.1) and restores the other platform's title group (Stage 4.2).
- [ ] `reselect-figures` validates xhs (1 figure) vs. wechat (2-3 figures) selection rules.
- [ ] `--reinterpret` flag in `reselect-figures` correctly dispatches `figure-interpreter`.
- [ ] README documents all 3 new commands + Plan 3a marked done in roadmap.
- [ ] No Claude co-author on any commit.

If any item fails, write a follow-up task and resolve before declaring Plan 3a complete.

---

## Live test recipe (manual, post-implementation)

After all 8 tasks ship:

1. Pick a paper that already has the full Plan 1 outputs (`/paper:study` was run; `notes/source.md`, `notes/titles.md`, `notes/xhs.md`, `notes/wechat.md`, `analysis/06-figures.md` all exist).

2. **Test `/paper:refine-notes`:**
   - `/paper:refine-notes xhs`
   - When prompted, type a rendering-level instruction: "shorten paragraph 3 to one sentence"
   - Verify `notes/xhs.md` updated with shorter para 3, `notes/xhs.md.bak.1` exists with prior version.
   - Run again with a content-level instruction: "the paper actually used Adam not SGD, fix this"
   - Verify the skill detects content-level and offers the source/rendering split.

3. **Test `/paper:retitle`:**
   - `/paper:retitle xhs --style hook`
   - Verify 5 hook-style candidates appear; pick one (e.g. number 2).
   - Verify `notes/xhs.md` frontmatter `title:` is updated; `notes/titles.md` `## history` has the old title; `notes/titles.md` `## wechat` group is unchanged from before this command.

4. **Test `/paper:reselect-figures`:**
   - `/paper:reselect-figures`
   - Verify the menu shows all images with importance scores.
   - For xhs, pick 1 figure; for wechat, pick 2-3.
   - Verify both `notes/xhs.md` and `notes/wechat.md` are re-rendered with the new figures embedded.
   - Verify `.bak.NN` backups exist for both.
   - Run again with `--reinterpret` and verify `analysis/06-figures.md.bak.NN` is also created.

If any step diverges from expected behavior, file as a follow-up issue against Plan 3a — not a blocker for declaring Plan 3a complete since the static contract tests pass.
