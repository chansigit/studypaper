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

If `--paper <slug>` is provided, set `PAPER_DIR=~/claude-papers/papers/<slug>`. Otherwise:

```bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
```

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

- **Translation:** All chat-facing prose (the final summary, error messages) is rendered in the user's invocation language. The deep-dive output file itself is English per spec §8.
- **Idempotence:** Each invocation produces a new file. Same topic re-dived → adds `-2`, `-3`, ... suffix. The orchestrator does NOT overwrite existing deep-dives.
- **Failure mode:** Agent produces empty output → orchestrator surfaces warning, leaves no file behind.
