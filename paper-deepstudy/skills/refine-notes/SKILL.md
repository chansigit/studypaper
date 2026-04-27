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

**Resolve target paper folder**

Source the shared helper and resolve which paper folder this invocation targets:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
# After: $PAPER_DIR, $PAPER_SLUG, $PAPER_AUTODETECTED are set.
# If $PAPER_AUTODETECTED is "true", the helper already printed a warning to stderr.
```

If `resolve_paper` returns non-zero, abort with the helper's stderr message.

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
