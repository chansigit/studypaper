---
name: add-prior-work
description: Use when the user wants to add a missing prior-work entry to analysis/05-prior-work.md. Re-dispatches prior-work-historian with the existing file + the new reference, asks it to update timeline + comparison table + lineage diagram.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

> **Roadmap note:** DOI inputs (e.g. `10.1093/nar/gkae1113`) are not yet supported. The current implementation falls back to "free-text" parsing for DOIs which produces poor results. Use the arXiv URL or BibTeX form instead. *DOI not yet supported* — tracking issue in spec §11.

# paperstudio: add-prior-work workflow

Invoke after `/paperstudio:study` has produced `analysis/05-prior-work.md`. Each invocation augments that file with one new prior-work entry the auto-run pipeline missed. Reuses the `prior-work-historian` sub-Agent prompt from Plan 1 with extended inputs.

Required positional arg: `<ref>` (BibTeX entry, arXiv URL, or free-text description).
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

Verify `$PAPER_DIR/analysis/05-prior-work.md` exists. If not, abort: `"No analysis/05-prior-work.md at $PAPER_DIR. Run /paperstudio:study or /paperstudio:rerun-stage analysis first."`

Set:
- `PRIOR_WORK_PATH=$PAPER_DIR/analysis/05-prior-work.md`
- `ANALYSIS_DIR=$PAPER_DIR/analysis`
- `PAPER_TEXT=$PAPER_DIR/paper.txt`
- `PROFILE_PATH=$PAPER_DIR/analysis/00-paper-profile.md`
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`
- `REVIEW_PATH=$PAPER_DIR/review.md` (may not exist yet; see Stage 4)

Source the log-dispatch helper and extract plugin version:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
PLUGIN_VERSION=$(grep -m1 '"version"' $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/')
```

### 1.2 Capture and classify the reference

`<ref>` is the first positional argument. Detect its kind:

| Pattern | Kind |
|---|---|
| Starts with `@` (e.g. `@article`, `@inproceedings`) | BibTeX |
| Starts with `http://arxiv.org/` or `https://arxiv.org/` | arXiv URL |
| Contains `://` but isn't arXiv | other URL (treat like arXiv URL: WebFetch the page) |
| Otherwise | free-text |

Set `REF_KIND` and `REF=<verbatim ref string>`.

---

## Stage 2: Backup the existing prior-work file

```bash
NN=1
while [ -e "$PRIOR_WORK_PATH.bak.$NN" ]; do
  NN=$((NN + 1))
done
cp "$PRIOR_WORK_PATH" "$PRIOR_WORK_PATH.bak.$NN"
```

The backup is the rollback point; if the agent fails, restore from this.

---

## Stage 3: Dispatch prior-work-historian

The Plan 1 `prior-work-historian` prompt already supports WebFetch and writes to a `05-prior-work.md` path. Here we invoke it in **augmentation mode** by passing the existing file's content as additional context.

```
Agent(
  description: "prior-work-historian (augmentation mode)",
  subagent_type: "general-purpose",
  prompt: <contents of $PLUGIN_ROOT/prompts/prior-work-historian.md> + concrete inputs:
    PAPER_TEXT=$PAPER_TEXT
    PROFILE_PATH=$PROFILE_PATH
    OUTPUT_PATH=$PRIOR_WORK_PATH
    TEMPLATE_PATH=$PLUGIN_ROOT/templates/analysis/05-prior-work.md
    DOMAIN_PACKS=<list — read from PROFILE_PATH frontmatter's domain_packs_selected>
    WEBFETCH allowed (cap 5 fetches)
    PLUGIN_VERSION=$PLUGIN_VERSION

    + Extended instructions for augmentation mode:
    "AUGMENTATION MODE: Do NOT regenerate the entire 05-prior-work.md from scratch.
    Read the existing file at $PRIOR_WORK_PATH. Insert ONE new entry corresponding to
    the reference below into the timeline (chronological order), the comparison table
    (if it's structurally a peer of existing entries), and the lineage diagram (if it
    sits on the lineage path of this paper).

    NEW REFERENCE (kind: $REF_KIND): $REF

    Resolve the reference's bibliographic info as follows:
    - kind=BibTeX: parse the BibTeX entry directly.
    - kind=arXiv URL: WebFetch the URL to get title/authors/year/abstract.
    - kind=other URL: WebFetch to extract title/authors/year if possible.
    - kind=free-text: use the text as-is; if author/year/contribution are clear, use them.

    After inserting the new entry, leave the rest of the file unchanged. Verify
    file structure: Timeline / Comparison table / Lineage diagram (text) / What this
    paper inherits vs invents / Notable omissions remain in the original order."
)
```

Wait for completion. Log the dispatch:

```bash
log_dispatch prior-work-historian analysis/05-prior-work.md ok
```

If the agent failed: `log_dispatch prior-work-historian analysis/05-prior-work.md failed`

---

## Stage 4: Check for review.md follow-up

If `$REVIEW_PATH` does not exist, skip this stage.

If it exists, read it. Look for any bullet point in `## Weaknesses/<dimension>` or `## Suggestions` that mentions "prior work" / "missing baseline" / "incomplete comparison" / "literature coverage" (case-insensitive grep on a small list of keywords).

If any matches, print to chat (in user's invocation language):

```
The new prior-work entry may affect existing review.md notes about literature coverage.
Found: <relevant bullet text> (review.md line <N>)

Consider running /paperstudio:review-round to revisit. Or update review.md manually if you
just want to remove a now-resolved point.
```

If no matches, skip the suggestion silently.

---

## Stage 5: Verify and report

If `$PRIOR_WORK_PATH` is empty, restore from `$PRIOR_WORK_PATH.bak.$NN` and report failure. Otherwise:

```
✓ Added prior-work entry.
  Reference: <REF (truncated to 80 chars if longer)>
  File: $PRIOR_WORK_PATH
  Backup: $PRIOR_WORK_PATH.bak.$NN

<optional review-round suggestion from Stage 4>

Run /paperstudio:add-prior-work again to add more references.
```

---

## Notes

- **Translation:** Chat-facing prose (status messages, the optional review-round suggestion) is in the user's invocation language. The augmented `05-prior-work.md` content stays English per spec §8.
- **Augmentation vs regeneration:** This skill uses `prior-work-historian` in augmentation mode (via extended instructions) so we don't lose the existing curated content. The Plan 1 prompt itself isn't modified — augmentation mode is purely an orchestrator-side instruction.
- **Failure modes:**
  - Reference can't be resolved (WebFetch failed for URL, BibTeX is malformed) → agent leaves a `<!-- could not resolve <REF>: <reason> -->` placeholder in the new entry; orchestrator reports the partial result.
  - Agent overwrites the whole file (regen mode by accident) → the `.bak.NN` backup lets the user `cp` it back.
