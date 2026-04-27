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

Resolve `PAPER_DIR` from `--paper <slug>` or default to most recent (most recently modified paper folder). If `--paper` was not specified, print to chat: `Warning: targeting <slug> (most recently modified paper folder). Pass --paper <slug> to override.` Verify `notes/source.md`, `notes/titles.md`, and `notes/<platform>.md` all exist; abort with helpful message otherwise.

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

**Important:** `$TITLES_BAK_PATH` (set in Stage 2.1) is the SINGLE original-state backup taken on first entry to this stage. Even if the user re-runs Stage 2.2 multiple times via `regen`, this restore point does NOT change — `keep` always restores the pre-retitle state. Stage 2.1 must NOT be re-executed during the regen loop. The `regen` branch loops back to Stage 2.2 (NOT Stage 2.1), so the original backup persists.

Wait for user input. Parse:
- Number 1-5 → `NEW_TITLE = candidates[<num> - 1]`. Proceed to Stage 3.
- `keep` → restore `titles.md` from `$TITLES_BAK_PATH`, exit gracefully.
- `regen` → re-prompt for style, then re-dispatch title-generator (loop back to Stage 2.2). Cap at 3 regens to avoid runaway.

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
