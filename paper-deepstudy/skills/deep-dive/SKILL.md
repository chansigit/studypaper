---
name: deep-dive
description: Use when the user wants an in-depth treatment of a single topic in a paper that is already studied. Dispatches deep-dive-agent with topic + paper text + analysis files. Output lands at deep-dives/<topic-slug>.md.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: deep-dive workflow

Invoke after `/paper:study` has produced the paper's analysis directory. Each invocation produces one deep-dive markdown file on the user-specified topic.

Required positional arg: `<topic>` (the topic to deep-dive on).
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
- `$PAPER_DIR/analysis/` directory with at least `00-paper-profile.md`
- `$PAPER_DIR/paper.txt` (or `$PAPER_DIR/paper.pdf` as fallback)

If missing, abort with: `"No analysis directory at $PAPER_DIR. Run /paper:study on this paper first."`

Set:
- `ANALYSIS_DIR=$PAPER_DIR/analysis`
- `PAPER_TEXT=$PAPER_DIR/paper.txt`
- `PAPER_PDF=$PAPER_DIR/paper.pdf`
- `DEEP_DIVES_DIR=$PAPER_DIR/deep-dives` (mkdir if absent)
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`
- `LANG=<english if user invocation language is English; chinese if Chinese; default english>` — the orchestrator detects the user's invocation language for the current `/paper:deep-dive` call and sets `LANG` accordingly. Falls back to `english` if uncertain.

### 1.2 Capture the topic

`<topic>` is the first positional argument (everything before `--paper` if present). Treat the entire string as the topic verbatim. If empty, abort with: `"Usage: /paper:deep-dive <topic> [--paper <slug>]"`.

Set `TOPIC=<verbatim topic string>`.

### 1.3 Derive topic-slug and check for collisions

```bash
TOPIC_SLUG=$(echo "$TOPIC" | node $PLUGIN_ROOT/scripts/slugify-objection.cjs)
```

(Despite the helper's name, the slugify logic is identical to what we want for topics — see Plan 5 Task 5.)

If `$DEEP_DIVES_DIR/$TOPIC_SLUG.md` already exists, find the next available suffix:

```bash
SUFFIX=2
while [ -e "$DEEP_DIVES_DIR/$TOPIC_SLUG-$SUFFIX.md" ]; do
  SUFFIX=$((SUFFIX + 1))
done
TOPIC_SLUG="${TOPIC_SLUG}-${SUFFIX}"
```

Set `OUTPUT_PATH=$DEEP_DIVES_DIR/$TOPIC_SLUG.md`.

---

## Stage 2: Dispatch deep-dive-agent

```
Agent(
  description: "deep-dive-agent on <TOPIC>",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/deep-dive-agent.md> + concrete inputs:
    PAPER_TEXT=$PAPER_TEXT
    PAPER_PDF=$PAPER_PDF
    ANALYSIS_DIR=$ANALYSIS_DIR
    TOPIC="$TOPIC"
    OUTPUT_PATH=$OUTPUT_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/deep-dive.md
    WEBFETCH allowed (cap 3 fetches)
    LANG=$LANG
)
```

Wait for completion. The agent writes the deep-dive file directly.

---

## Stage 3: Verify and report

If `$OUTPUT_PATH` does not exist or is empty, log a warning and report failure: `"deep-dive-agent did not produce output. Run /paper:deep-dive again or check the agent dispatch."`

Otherwise, print to chat (in user's invocation language):

```
✓ Deep dive complete.
  Topic: <TOPIC>
  Output: $OUTPUT_PATH
  Length: <wc -w on the file> words

Run /paper:deep-dive again with another topic to continue the deep-dive series.
```

---

## Notes

- **Translation:** All chat-facing prose (the final summary, error messages) is rendered in the user's invocation language. Per spec §8, the deep-dive output file itself follows the user's invocation language too — the orchestrator sets `LANG` accordingly when dispatching the agent. Section headings stay English so downstream tooling can grep them.
- **Idempotence:** Each invocation produces a new file. Same topic re-dived → adds `-2`, `-3`, ... suffix. The orchestrator does NOT overwrite existing deep-dives.
- **Failure mode:** Agent produces empty output → orchestrator surfaces warning, leaves no file behind.
