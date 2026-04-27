---
name: compare
description: Use when the user wants a head-to-head comparison of two papers. Auto-studies the other paper if not already in ~/claude-papers/papers/, then dispatches compare-agent with both analysis directories.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent, Skill
---

# paper-deepstudy: compare workflow

Invoke after `/paper:study` has produced the focal paper's analysis. Each invocation produces one comparison markdown file at `compares/vs-<other-slug>.md`.

Required positional arg: `<other-paper>` (slug, paper-folder path, PDF path, or URL).
Optional flags:
- `--paper <slug>`: set the focal paper (default: most recently modified paper folder).
- `--lang en|zh`: output language for the prose (default: `en`).

---

## Stage 1: Resolve focal paper

**Resolve target paper folder**

Source the shared helper and resolve which paper folder this invocation targets:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
# After: $PAPER_DIR, $PAPER_SLUG, $PAPER_AUTODETECTED are set.
# If $PAPER_AUTODETECTED is "true", the helper already printed a warning to stderr.
```

If `resolve_paper` returns non-zero, abort with the helper's stderr message.

Set `THIS_PAPER_DIR=$PAPER_DIR` and `THIS_SLUG=$PAPER_SLUG`.

Verify `$THIS_PAPER_DIR/analysis/00-paper-profile.md` exists. If not, abort: `"Focal paper has no analysis directory. Run /paper:study first."`

---

## Stage 2: Resolve other paper (handle 4 input types)

`<other-paper>` is the first positional argument. Detect its kind:

| Pattern | Kind |
|---|---|
| Starts with `http://` or `https://` | URL |
| Ends in `.pdf` (case-insensitive) | PDF path |
| Contains `/` and matches `~/claude-papers/papers/<slug>` | existing paper folder path |
| Otherwise (no `/` and no `.pdf` suffix) | slug |

### 2.1 If kind = slug

Set `OTHER_PAPER_DIR=~/claude-papers/papers/<other-paper>`. Verify it exists with `analysis/00-paper-profile.md`. If not, abort: `"<slug> has no analysis directory in ~/claude-papers/papers/. Run /paper:study <slug> first or pass a PDF/URL to auto-study."`

### 2.2 If kind = paper folder path

Strip trailing `/`. Set `OTHER_PAPER_DIR=<the-path>`. Verify analysis exists.

### 2.3 If kind = PDF path or URL — auto-study

Inform the user (in their invocation language):

```
The other paper has not been studied yet. Auto-studying it now via /paper:study; this may take a few minutes.
```

Invoke `/paper:study` via the Skill tool:

```
Skill(skill: "paper-deepstudy:study-deep", args: "<other-paper> --yes")
```

(`--yes` skips the Stage 0 confirmation prompt for the auto-detected profile, since we don't want a second user-interaction during a `compare` invocation.)

After it returns, locate the new paper folder (most recently modified):

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper
OTHER_PAPER_DIR="$PAPER_DIR"
```

Verify it's a different folder from `THIS_PAPER_DIR` (defensive). If they match, abort: `"Auto-study did not produce a distinct paper folder. Check /paper:study output."`

### 2.4 Set OTHER_SLUG

`OTHER_SLUG=$(basename $OTHER_PAPER_DIR)`.

---

## Stage 3: Resolve language flag and output path

Source the log-dispatch helper and extract plugin version:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
PLUGIN_VERSION=$(grep -m1 '"version"' $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/')
```

Capture `--lang en` or `--lang zh` (default `en`). Set `LANG=english` or `LANG=chinese`.

```bash
COMPARES_DIR="$THIS_PAPER_DIR/compares"
mkdir -p "$COMPARES_DIR"
OUTPUT_PATH="$COMPARES_DIR/vs-${OTHER_SLUG}.md"
```

If `OUTPUT_PATH` already exists, back it up to `<file>.bak.NN` first:

```bash
NN=1
while [ -e "$OUTPUT_PATH.bak.$NN" ]; do
  NN=$((NN + 1))
done
cp "$OUTPUT_PATH" "$OUTPUT_PATH.bak.$NN"
```

(If `OUTPUT_PATH` doesn't exist yet, skip the backup.)

---

## Stage 4: Dispatch compare-agent

```
Agent(
  description: "compare-agent: <THIS_SLUG> vs <OTHER_SLUG>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/compare-agent.md> + concrete inputs:
    THIS_ANALYSIS_DIR=$THIS_PAPER_DIR/analysis
    OTHER_ANALYSIS_DIR=$OTHER_PAPER_DIR/analysis
    THIS_SLUG=$THIS_SLUG
    OTHER_SLUG=$OTHER_SLUG
    OUTPUT_PATH=$OUTPUT_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/compare.md
    LANG=$LANG
    PLUGIN_VERSION=$PLUGIN_VERSION
)
```

Wait for completion. Log the dispatch:

```bash
log_dispatch compare-agent compares/vs-${OTHER_SLUG}.md ok
```

If the agent produced no output: `log_dispatch compare-agent compares/vs-${OTHER_SLUG}.md failed`

---

## Stage 5: Verify and report

If `$OUTPUT_PATH` does not exist or is empty, restore from backup (if a backup exists) and report failure:

```bash
if [ ! -s "$OUTPUT_PATH" ] && [ -e "$OUTPUT_PATH.bak.$NN" ]; then
  cp "$OUTPUT_PATH.bak.$NN" "$OUTPUT_PATH"
  echo "WARN: compare-agent produced empty output; restored from backup."
fi
```

Otherwise, print to chat (in user's invocation language):

```
✓ Comparison complete.
  This:  <THIS_SLUG>
  Other: <OTHER_SLUG>
  Output: $OUTPUT_PATH
  Language: $LANG
  Length: <wc -w on the file> words

Run /paper:compare again with a different paper to add another comparison.
```

---

## Notes

- **Translation:** Chat-facing prose (status messages, errors, final summary) is rendered in the user's invocation language. The compare output file itself is English by default, Chinese if `--lang zh` was set.
- **Auto-study side effect:** When `<other-paper>` is a PDF path or URL, this skill auto-studies the other paper via `/paper:study --yes`. That produces the full Plan 1 outputs for the other paper (12 artifacts), not just the analysis directory. The auto-study is a documented side effect — once-per-paper.
- **Idempotence:** Each invocation backs up an existing `compares/vs-<other-slug>.md` to `.bak.NN` before overwriting. Same-pair comparisons accumulate as `.bak.1`, `.bak.2`, etc.
