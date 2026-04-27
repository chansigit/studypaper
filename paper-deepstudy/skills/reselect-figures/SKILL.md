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

Resolve `PAPER_DIR` from `--paper <slug>` or default to most recent (most recently modified paper folder). If `--paper` was not specified, print to chat: `Warning: targeting <slug> (most recently modified paper folder). Pass --paper <slug> to override.` Verify required files:
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
