---
name: reproduce-check
description: Use when the user wants a structured reproducibility audit of a studied paper. Dispatches reproduce-checker on 7 dimensions (or 6 for ml-pure papers — wet-lab is N/A). Output goes to reproduce-check.md. Suggests /paperstudio:review-round if serious issues are found.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paperstudio: reproduce-check workflow

Invoke after `/paperstudio:study` has produced the paper's analysis directory and `meta.json`. Each invocation produces one `reproduce-check.md` audit at the paper folder root.

Optional flag: `--paper <slug>` (default: most recently modified paper folder).

---

## Stage 1: Setup

### 1.1 Resolve target paper

**Resolve target paper folder**

Source the shared helper and resolve which paper folder this invocation targets:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
# After: $PAPER_DIR, $PAPER_SLUG, $PAPER_AUTODETECTED are set.
# If $PAPER_AUTODETECTED is "true", the helper already printed a warning to stderr.
```

If `resolve_paper` returns non-zero, abort with the helper's stderr message.

Verify required files:
- `$PAPER_DIR/analysis/00-paper-profile.md`
- `$PAPER_DIR/analysis/03-method-deep.md`
- `$PAPER_DIR/analysis/04-experiments.md`
- `$PAPER_DIR/meta.json`
- `$PAPER_DIR/paper.txt` (fallback `paper.pdf`)

If missing, abort with: `"Paper $PAPER_DIR is missing analysis files. Run /paperstudio:study first."`

Set:
- `OUTPUT_PATH=$PAPER_DIR/reproduce-check.md`
- `ANALYSIS_DIR=$PAPER_DIR/analysis`
- `META_JSON=$PAPER_DIR/meta.json`
- `PAPER_TEXT=$PAPER_DIR/paper.txt`
- `PAPER_PDF=$PAPER_DIR/paper.pdf`
- `REVIEW_PATH=$PAPER_DIR/review.md` (may not exist; checked in Stage 4)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`

### 1.2 Determine if wet-lab dimension applies

Read `$ANALYSIS_DIR/00-paper-profile.md` frontmatter and inspect the `domain` field:

| Profile `domain` | Wet-lab dimension |
|---|---|
| `ml-pure` | N/A (skip — set `checked_dimensions: 6`) |
| `ml-bio-hybrid` | check normally |
| `cs-bio` | check normally |
| `wet-lab-heavy` | check normally |

Set `WET_LAB_APPLICABLE=true` for non-ml-pure profiles.

Source the log-dispatch helper and extract plugin version:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
PLUGIN_VERSION=$(grep -m1 '"version"' $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/')
```

### 1.3 Backup existing reproduce-check.md if present

```bash
if [ -e "$OUTPUT_PATH" ]; then
  NN=1
  while [ -e "$OUTPUT_PATH.bak.$NN" ]; do
    NN=$((NN + 1))
  done
  cp "$OUTPUT_PATH" "$OUTPUT_PATH.bak.$NN"
fi
```

(If no existing file, no backup needed.)

---

## Stage 2: Dispatch reproduce-checker

```
Agent(
  description: "reproduce-checker for $(basename $PAPER_DIR)",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/reproduce-checker.md> + concrete inputs:
    PAPER_TEXT=$PAPER_TEXT
    PAPER_PDF=$PAPER_PDF
    ANALYSIS_DIR=$ANALYSIS_DIR
    META_JSON=$META_JSON
    OUTPUT_PATH=$OUTPUT_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/reproduce-check.md
    WEBFETCH allowed (cap 5 fetches)
    WET_LAB_APPLICABLE=$WET_LAB_APPLICABLE
    PLUGIN_VERSION=$PLUGIN_VERSION
)
```

Wait for completion. Log the dispatch:

```bash
log_dispatch reproduce-checker reproduce-check.md ok
```

If the agent produced no output: `log_dispatch reproduce-checker reproduce-check.md failed`

---

## Stage 3: Verify output

If `$OUTPUT_PATH` does not exist or is empty:

```bash
if [ ! -s "$OUTPUT_PATH" ]; then
  if [ -e "$OUTPUT_PATH.bak.$NN" ]; then
    cp "$OUTPUT_PATH.bak.$NN" "$OUTPUT_PATH"
    echo "WARN: reproduce-checker produced empty output; restored from backup."
  else
    echo "ERROR: reproduce-checker produced no output and no backup exists."
  fi
  exit 1
fi
```

Otherwise read `$OUTPUT_PATH` to extract the YAML frontmatter `fails_count` and `partials_count` for use in Stage 4.

---

## Stage 4: Suggest review-round if serious

Parse the frontmatter:
- `FAILS_COUNT` from `fails_count: <integer>`
- `PARTIALS_COUNT` from `partials_count: <integer>`

If `FAILS_COUNT >= 1` OR `PARTIALS_COUNT >= 3`, AND `$REVIEW_PATH` exists:

Print to chat (in user's invocation language):

```
The reproducibility audit found <FAILS_COUNT> failure(s) and <PARTIALS_COUNT> partial(s).

The reproduce-check.md file's "Recommended next steps" section already lists which
dimensions are weak. Consider running /paperstudio:review-round to convert these into
formal weaknesses in review.md (dimension: reproducibility, severity: major or minor
based on which dimensions failed).
```

If `$REVIEW_PATH` does not exist (Plan 1's `/paperstudio:study` produced review.md, so this is unlikely but defensive):

```
The reproducibility audit found <FAILS_COUNT> failure(s) and <PARTIALS_COUNT> partial(s).

To convert these into formal review weaknesses, you'd need review.md first
(produced by /paperstudio:study Stage 2). Re-run /paperstudio:study or /paperstudio:rerun-stage review.
```

If `FAILS_COUNT == 0` AND `PARTIALS_COUNT < 3`, skip this stage (no suggestion needed).

---

## Stage 5: Final summary

Print to chat (in user's invocation language):

```
✓ Reproducibility check complete.
  Paper: <basename of PAPER_DIR>
  Output: $OUTPUT_PATH
  Overall: <green | yellow | red> (<FAILS_COUNT> ✗, <PARTIALS_COUNT> partial)
  Wet-lab dimension: <checked | N/A — pure-ML paper>

<optional review-round suggestion from Stage 4>
```

---

## Notes

- **Translation:** All chat-facing prose (final summary, errors, review-round suggestion) is rendered in the user's invocation language. The `reproduce-check.md` file itself is English per spec §8 (analysis-side artifact).
- **WebFetch budget:** 5 fetches max per invocation. Skill does not enforce this — the agent is trusted to honor the budget per its prompt.
- **Idempotence:** Each invocation re-checks. Existing `reproduce-check.md` backs up to `.bak.NN` before re-write. The audit may produce different results if the paper text or analysis files change between invocations (e.g., user added prior-work entries).
- **Failure modes:**
  - Agent produces empty output → orchestrator restores from backup if available, else reports ERROR.
  - WebFetch quota exhausted → agent records `<!-- WebFetch quota exhausted -->` in evidence; non-fatal.
  - Repo URL returns 404 → recorded as `✗ <url> — 404` in Code availability evidence; counts as a fail for that dimension.
