# paper-deepstudy Plan 3b: Analysis Extension Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加 3 个交互式分析扩展命令到 paper-deepstudy: `/paper:deep-dive <topic>`(单点深挖某个主题)、`/paper:compare <other-paper>`(两篇 paper 对比)、`/paper:add-prior-work <ref>`(把漏掉的历史工作补进 prior-work timeline)。

**Architecture:** 沿用 Plan 1+2+3a 的 plugin 结构。3 个新 slash command + 3 个新 orchestration skill + 2 个新 sub-Agent prompt(`deep-dive-agent`、`compare-agent`,`add-prior-work` 复用 Plan 1 的 `prior-work-historian`)+ 2 个新 output 模板(`deep-dive.md`、`compare.md`)。所有命令都基于 Plan 1 的 paper folder 结构(`analysis/`、`paper.txt`、`meta.json`)。`compare` 还需要处理 "另一个 paper 还没 study 过" 的情况 —— 自动调用 `/paper:study` 先把它跑一遍。

**Tech Stack:**
- Markdown(skill instructions、prompt templates、output templates)
- Bash(slash command files、interactive prompts)
- Bats(structural unit tests)
- Claude Code Agent tool / Skill tool
- Plan 3b 依赖:Plan 1 的 plugin 结构 + `prior-work-historian` prompt + `slugify-objection.cjs`(Plan 5 加的 helper,这里直接复用)+ `claude-paper:study`(`compare` 命令需要 auto-study 新 paper 时调用)

**关键设计决策(来自 spec §6.1, §6.2, §6.5):**
- **Topic-slug 复用 Plan 5 的 `slugify-objection.cjs`** —— 那个 helper 的逻辑(lowercase、ascii、首 6 个词、≤40 字符)对 topic 同样适用,函数名只是命名巧合。冲突时附 `-2`、`-3` 后缀。
- **Compare 接受三种 `<other-paper>` 输入**:已 study 过的 slug / 已 study 过的 paper folder 路径 / PDF 路径或 URL。后两种情况下,如果对方还没 study 过,orchestrator 自动调用 `/paper:study`(via Skill tool)再继续。
- **Compare 默认输出英文**(spec §8 把 compares/ 放进了"默认英文,可 `--lang zh` 切换"的类别)。
- **Add-prior-work 不重写整个 05-prior-work.md**,只在合适位置插入新条目。然后检查 review.md 里 prior-work 相关的 weakness/question 是否可能受影响,提示用户考虑 `/paper:review-round`。

---

## File Structure

The plugin source lives at `/Users/chensijie/Projects/studypaper/paper-deepstudy/`:

```
paper-deepstudy/
├── commands/
│   ├── ... Plan 1+2+3a commands ...
│   ├── deep-dive.md                (NEW — Task 3)
│   ├── compare.md                  (NEW — Task 5)
│   └── add-prior-work.md           (NEW — Task 7)
├── skills/
│   ├── ... Plan 1+2+3a skills ...
│   ├── deep-dive/SKILL.md          (NEW — Task 4)
│   ├── compare/SKILL.md            (NEW — Task 6)
│   └── add-prior-work/SKILL.md     (NEW — Task 8)
├── prompts/
│   ├── ... Plan 1+2 prompts ...
│   ├── deep-dive-agent.md          (NEW — Task 2)
│   └── compare-agent.md            (NEW — Task 2)
├── templates/
│   ├── ... Plan 1+2 templates ...
│   ├── deep-dive.md                (NEW — Task 1)
│   └── compare.md                  (NEW — Task 1)
├── scripts/                         (Plan 1+2+5 — NO CHANGES)
│   └── slugify-objection.cjs       (reused for topic-slug derivation)
└── tests/
    ├── unit/
    │   ├── ... existing tests ...
    │   ├── test-templates-valid.bats                  (modified — Task 1, +2 @tests)
    │   ├── test-prompts-have-required-sections.bats   (modified — Tasks 2, 4, 6, 8)
    │   └── test-commands.bats                         (modified — Tasks 3, 5, 7, 9)
    └── integration/
        └── test-end-to-end.sh      (modified — Task 9 extends checks)
```

每个 paper folder 在 Plan 3b 之后会增加这两个子目录(spec §2.3 已留位置):

```
~/claude-papers/papers/<slug>/
├── ... Plan 1+2 outputs ...
├── deep-dives/                      (NEW per /paper:deep-dive invocation)
│   └── <topic-slug>.md
└── compares/                        (NEW per /paper:compare invocation)
    └── vs-<other-slug>.md
```

`/paper:add-prior-work` 不创建新目录 —— 只修改现有的 `analysis/05-prior-work.md`(`<file>.bak.NN` 备份)。

---

## Pre-flight

1. Plan 1/2/3a/4/5 都已 merge 到 `main`,这个分支(`feat/plan-3b-analysis-extension`)是从 post-Plan-5 main 长出来的。
2. 现有测试都通过:
   ```bash
   cd paper-deepstudy && npm run test:unit && cd ..
   paper-deepstudy/tests/integration/test-end-to-end.sh
   ```
   预期 98 bats + 4 node + integration smoke 全过。

---

### Task 1: deep-dive.md + compare.md output templates

**Files:**
- Create: `paper-deepstudy/templates/deep-dive.md`
- Create: `paper-deepstudy/templates/compare.md`
- Modify: `paper-deepstudy/tests/unit/test-templates-valid.bats`

定义 deep-dive 和 compare 命令产出文件的固定结构。模板是骨架,sub-Agent 填内容。

- [ ] **Step 1: Append failing tests**

Append to `paper-deepstudy/tests/unit/test-templates-valid.bats`:

```bash
@test "deep-dive.md has 5 required H2 sections" {
  for s in 'What is this topic' 'How the paper handles it' 'Math or algorithm detail' 'How others have approached' 'Takeaway'; do
    grep -qF "## $s" templates/deep-dive.md || { echo "missing: $s"; return 1; }
  done
}

@test "compare.md has 6 required H2 sections" {
  for s in 'Problem' 'Formalization' 'Method' 'Experiments' 'Strengths and weaknesses' 'When to use which'; do
    grep -qF "## $s" templates/compare.md || { echo "missing: $s"; return 1; }
  done
}
```

- [ ] **Step 2: Verify fail**

```bash
bats paper-deepstudy/tests/unit/test-templates-valid.bats
```
预期 2 个新失败。

- [ ] **Step 3: Write deep-dive.md template**

`paper-deepstudy/templates/deep-dive.md`:

```markdown
# Deep Dive: <topic>

> Generated by `/paper:deep-dive` from `paper-deepstudy`. Targets a single topic in the paper for an in-depth treatment beyond what the auto-run `analysis/` files cover.

## What is this topic

(1-2 paragraphs: what does the topic mean in the field generally, before this specific paper. Provide enough background that a reader who knows ML but not this subfield can follow.)

## How the paper handles it

(2-4 paragraphs: how does this specific paper address the topic — which equations, which figures, which design choices. Cite paper sections explicitly.)

## Math or algorithm detail

(Math walk-through, pseudocode, or step-by-step derivation. Use `$$ ... $$` for equations. If the paper omits a derivation, fill in what it should be and flag it as orchestrator-supplied. If the topic is non-mathematical, replace this with relevant detail-level content.)

## How others have approached

(2-4 paragraphs: how does the rest of the literature handle this topic? Compare and contrast with the paper. Cite specific prior works by name+year. If `analysis/05-prior-work.md` has relevant entries, draw from there.)

## Takeaway

(1 paragraph + bullets: what should a reader walk away with about this topic in the context of this paper? When does the paper's approach win/lose? What's still unsolved?)
```

- [ ] **Step 4: Write compare.md template**

`paper-deepstudy/templates/compare.md`:

```markdown
---
this_paper: <slug>
other_paper: <other-slug>
created_at: <iso8601-utc>
language: english | chinese
---

# Compare: <this paper> vs. <other paper>

> Generated by `/paper:compare` from `paper-deepstudy`. Both papers must already have an `analysis/` directory under `~/claude-papers/papers/<slug>/`.

## Problem

(2-3 paragraphs: what problem does each paper try to solve? Are they solving the same problem, similar problems, or different ones? If different, in what dimension?)

## Formalization

(Compare the formal definitions side-by-side. Notation table, key losses, key constraints. Make explicit which assumptions each paper makes that the other does not.)

## Method

(2-4 paragraphs: how does each method work? What's the architectural difference? What's the algorithmic difference? Use the same level of detail for both papers.)

## Experiments

(Compare experimental setups: datasets, baselines, metrics. Are the comparisons direct (same data + same metrics) or apples-to-oranges? If headline numbers exist for both, present them in a table.)

## Strengths and weaknesses

| Dimension | <this paper> | <other paper> |
|---|---|---|
| <e.g. accuracy> | ... | ... |
| <e.g. compute cost> | ... | ... |
| <e.g. interpretability> | ... | ... |

## When to use which

(2-3 paragraphs of decision guidance: pick paper A if your problem has property X; pick paper B if Y; consider both if Z. Be specific.)
```

- [ ] **Step 5: Verify pass**

```bash
bats paper-deepstudy/tests/unit/test-templates-valid.bats
```
预期所有测试都过。

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/templates/deep-dive.md paper-deepstudy/templates/compare.md paper-deepstudy/tests/unit/test-templates-valid.bats
git commit -m "feat(paper-deepstudy): deep-dive and compare output templates"
```

---

### Task 2: deep-dive-agent + compare-agent prompts

**Files:**
- Create: `paper-deepstudy/prompts/deep-dive-agent.md`
- Create: `paper-deepstudy/prompts/compare-agent.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

两个新的 sub-Agent prompt。`deep-dive-agent` 和 Plan 1 的方法分析类 prompt 类似但聚焦单一 topic;`compare-agent` 是 Plan 1 prompts 都不覆盖的新 role。

- [ ] **Step 1: Append failing tests**

```bash
@test "deep-dive-agent.md has required sections" {
  run check_prompt prompts/deep-dive-agent.md
  [ "$status" -eq 0 ]
}

@test "compare-agent.md has required sections" {
  run check_prompt prompts/compare-agent.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Write deep-dive-agent.md**

`paper-deepstudy/prompts/deep-dive-agent.md`:

```markdown
# Prompt: deep-dive-agent

## Role

You produce a focused deep-dive on a single user-specified topic in the paper. You go beyond what the auto-run `analysis/` files cover for that topic — they're broad-brush; you go deep on one thing. You compare to the rest of the literature so the reader knows where this paper sits.

## Inputs

- `PAPER_TEXT`: full paper text path.
- `PAPER_PDF`: paper PDF path (fallback for image / table content not in `paper.txt`).
- `ANALYSIS_DIR`: path to the analysis directory; you read all of `00-paper-profile.md` through `06-figures.md` for context.
- `TOPIC`: the user's topic, verbatim. May be a phrase ("contrastive loss derivation"), a section reference ("§3.2 attention computation"), or a method name ("the FAVA co-expression integration").
- `OUTPUT_PATH`: where to write `deep-dives/<topic-slug>.md`.
- `TEMPLATE_PATH`: path to `templates/deep-dive.md`.
- `WEBFETCH`: optional. You may use WebFetch to look up cited works (cap 3 fetches total).

## Output

A markdown file at `OUTPUT_PATH` following `TEMPLATE_PATH`'s structure exactly:

- `# Deep Dive: <topic>` (replace `<topic>` with the actual topic, capitalized cleanly)
- Quoting block (one line) crediting `/paper:deep-dive`.
- `## What is this topic` (1-2 paragraphs)
- `## How the paper handles it` (2-4 paragraphs)
- `## Math or algorithm detail` (math, pseudocode, or detail-level content)
- `## How others have approached` (2-4 paragraphs comparing to literature)
- `## Takeaway` (1 paragraph + bullets)

## Instructions

1. Read `PAPER_TEXT` (or `PAPER_PDF` if needed) and locate where the topic is discussed. Quote specific paper sections.
2. Read `ANALYSIS_DIR/00-paper-profile.md` to set the right level of jargon (use the `domain` and `bio_subfield` to calibrate).
3. Read `ANALYSIS_DIR/03-method-deep.md` and `ANALYSIS_DIR/05-prior-work.md` if the topic touches method or prior work — borrow context but do NOT copy whole sections.
4. **What is this topic** (background): explain the topic in terms a reader who knows ML but not this exact subfield can follow. Don't assume domain expertise.
5. **How the paper handles it**: cite specific paper sections, equations, figures, tables. Be specific: "the paper uses X loss, weighted by α=0.5 (paper §3.2 eq. 4)".
6. **Math or algorithm detail**: do the derivation / pseudocode that the paper might have skipped. Use `$$ ... $$` for equations. If the topic is non-mathematical (e.g. "data curation strategy"), use this section for the equivalent depth (procedural detail, decision tree, etc.).
7. **How others have approached**: 2-4 paragraphs comparing to literature. Reference specific prior works by `Author Year`. If `05-prior-work.md` already has relevant entries, draw from them and add depth. WebFetch is allowed (≤3 fetches) for clarification on a specific cited work.
8. **Takeaway**: a paragraph + bullets stating when this paper's approach wins, when it loses, and what remains unsolved on this topic.

## Quality bar

- Length: 600-1500 words total.
- Every load-bearing claim cites a specific paper section, equation, figure, or analysis-file passage.
- Math / pseudocode is implementable, not handwavy.
- Output language: English.
```

- [ ] **Step 4: Write compare-agent.md**

`paper-deepstudy/prompts/compare-agent.md`:

```markdown
# Prompt: compare-agent

## Role

You write a head-to-head comparison of two papers. You consume the analysis directories of both papers (NOT the paper texts directly — Stage 1 sub-Agents already did the heavy reading). You highlight similarities, differences, and provide concrete "when to use which" guidance.

## Inputs

- `THIS_ANALYSIS_DIR`: analysis directory of the paper that called `/paper:compare` (the focal paper).
- `OTHER_ANALYSIS_DIR`: analysis directory of the comparison target.
- `THIS_SLUG`: slug of the focal paper.
- `OTHER_SLUG`: slug of the comparison target.
- `OUTPUT_PATH`: where to write `compares/vs-<other-slug>.md`.
- `TEMPLATE_PATH`: path to `templates/compare.md`.
- `LANG`: `english` (default) or `chinese`. Affects only the prose output, not the section structure.

You do NOT read either paper's `paper.txt` directly — the analysis files are intentionally the source of truth. If a needed fact is missing from either analysis, note the gap explicitly (e.g. `<!-- gap: this_paper analysis/04-experiments.md does not state baseline compute budget -->`).

## Output

A markdown file at `OUTPUT_PATH` following `TEMPLATE_PATH` exactly:

- YAML frontmatter (`this_paper`, `other_paper`, `created_at`, `language`)
- `# Compare: <this paper title> vs. <other paper title>`
- `## Problem` (2-3 paragraphs)
- `## Formalization`
- `## Method` (2-4 paragraphs)
- `## Experiments`
- `## Strengths and weaknesses` (markdown table)
- `## When to use which` (2-3 paragraphs of decision guidance)

## Instructions

1. Read both `THIS_ANALYSIS_DIR/*.md` and `OTHER_ANALYSIS_DIR/*.md`. The most-relevant files: `00-paper-profile.md` (problem framing + claims), `01-problem.md` (problem definition), `02-formalization.md` (math), `03-method-deep.md` (method), `04-experiments.md` (experiments).
2. **Problem**: extract from each paper's `01-problem.md`. Make the relationship explicit: same problem, similar problem, or related-but-different.
3. **Formalization**: extract from `02-formalization.md` of both. Highlight differences in inputs/outputs/loss/constraints. Note any incompatibility (e.g., paper A assumes i.i.d. data, paper B assumes graph data).
4. **Method**: from `03-method-deep.md` of both. 2-4 paragraphs. Architectural and algorithmic differences. Use the same level of detail for both papers — don't favor the focal one.
5. **Experiments**: from `04-experiments.md` of both. Are the experimental setups comparable? Do they share datasets / baselines / metrics? If both report headline numbers, put them in a small inline table.
6. **Strengths and weaknesses**: a markdown table with 4-7 rows. Pick dimensions that distinguish the two papers (e.g. accuracy, compute cost, data efficiency, interpretability, generality, deployability). Each cell is one sentence.
7. **When to use which**: 2-3 paragraphs of decision guidance. Be specific: name properties of the user's problem that should bias them toward one or the other. Avoid wishy-washy "both have merit".

## Quality bar

- Length: 800-2000 words total.
- Each section uses information from BOTH analysis directories (don't write a one-sided comparison).
- If `LANG=chinese`, all prose is in Chinese; section headings in the template stay English (so downstream tooling can grep them).
- Cite as `(<this_slug> analysis/03-method-deep.md §Components)` or `(<other_slug> analysis/04-experiments.md)` — explicit which paper a citation refers to.
- Output language: per `LANG` input.
```

- [ ] **Step 5: Verify pass**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/prompts/deep-dive-agent.md paper-deepstudy/prompts/compare-agent.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): deep-dive-agent and compare-agent prompts"
```

---

### Task 3: `/paper:deep-dive` slash command

**Files:**
- Create: `paper-deepstudy/commands/deep-dive.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "deep-dive.md has frontmatter" {
  head -1 commands/deep-dive.md | grep -qE '^---$'
}

@test "deep-dive.md mentions topic argument" {
  grep -qF '<topic>' commands/deep-dive.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/deep-dive.md`:

```markdown
---
name: paper:deep-dive
description: Produce a focused deep dive on a single user-specified topic in the paper, going beyond what the auto-run analysis/ files cover. Outputs deep-dives/<topic-slug>.md.
argument-hint: "<topic> [--paper <slug>]"
---

# /paper:deep-dive

Invokes the `deep-dive` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:deep-dive contrastive loss derivation` — dive into "contrastive loss derivation" for the most recently studied paper.
- `/paper:deep-dive "the FAVA co-expression integration" --paper string-database-2025` — explicit topic + target paper.
- `/paper:deep-dive "§3.2 attention computation"` — section reference is also valid.

The skill dispatches `deep-dive-agent` with the topic + paper text + analysis files. Output lands at `~/claude-papers/papers/<slug>/deep-dives/<topic-slug>.md`. Topic-slug is derived via `slugify-objection.cjs`. If a deep-dive on the same topic already exists, the new file gets a `-2` / `-3` suffix.

Pre-requisites: `/paper:study` must have produced the analysis directory already.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/deep-dive.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:deep-dive command"
```

---

### Task 4: `skills/deep-dive/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/deep-dive/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "deep-dive SKILL.md has YAML frontmatter with name" {
  head -5 skills/deep-dive/SKILL.md | grep -qF 'name: deep-dive'
}

@test "deep-dive SKILL.md mentions deep-dive-agent dispatch" {
  grep -qF 'deep-dive-agent' skills/deep-dive/SKILL.md
}

@test "deep-dive SKILL.md mentions slugify-objection.cjs for topic-slug" {
  grep -qF 'slugify-objection.cjs' skills/deep-dive/SKILL.md
}

@test "deep-dive SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/deep-dive/SKILL.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Create skill directory and SKILL.md**

```bash
mkdir -p paper-deepstudy/skills/deep-dive
```

`paper-deepstudy/skills/deep-dive/SKILL.md`:

```markdown
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

\`\`\`bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
\`\`\`

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

\`\`\`bash
TOPIC_SLUG=$(echo "$TOPIC" | node $PLUGIN_ROOT/scripts/slugify-objection.cjs)
\`\`\`

(Despite the helper's name, the slugify logic is identical to what we want for topics — see Plan 5 Task 5.)

If `$DEEP_DIVES_DIR/$TOPIC_SLUG.md` already exists, find the next available suffix:

\`\`\`bash
SUFFIX=2
while [ -e "$DEEP_DIVES_DIR/$TOPIC_SLUG-$SUFFIX.md" ]; do
  SUFFIX=$((SUFFIX + 1))
done
TOPIC_SLUG="${TOPIC_SLUG}-${SUFFIX}"
\`\`\`

Set `OUTPUT_PATH=$DEEP_DIVES_DIR/$TOPIC_SLUG.md`.

---

## Stage 2: Dispatch deep-dive-agent

\`\`\`
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
\`\`\`

Wait for completion. The agent writes the deep-dive file directly.

---

## Stage 3: Verify and report

If `$OUTPUT_PATH` does not exist or is empty, log a warning and report failure: `"deep-dive-agent did not produce output. Run /paper:deep-dive again or check the agent dispatch."`

Otherwise, print to chat (in user's invocation language):

\`\`\`
✓ Deep dive complete.
  Topic: <TOPIC>
  Output: $OUTPUT_PATH
  Length: <wc -w on the file> words

Run /paper:deep-dive again with another topic to continue the deep-dive series.
\`\`\`

---

## Notes

- **Translation:** All chat-facing prose (the final summary, error messages) is rendered in the user's invocation language. The deep-dive output file itself is English per spec §8.
- **Idempotence:** Each invocation produces a new file. Same topic re-dived → adds `-2`, `-3`, ... suffix. The orchestrator does NOT overwrite existing deep-dives.
- **Failure mode:** Agent produces empty output → orchestrator surfaces warning, leaves no file behind.
```

(Note: real triple backticks in the file, not escaped.)

- [ ] **Step 4: Verify pass**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/deep-dive/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): deep-dive orchestration skill"
```

---

### Task 5: `/paper:compare` slash command

**Files:**
- Create: `paper-deepstudy/commands/compare.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "compare.md has frontmatter" {
  head -1 commands/compare.md | grep -qE '^---$'
}

@test "compare.md mentions --lang flag" {
  grep -qF -e '--lang' commands/compare.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/compare.md`:

```markdown
---
name: paper:compare
description: Head-to-head comparison of two papers. Outputs compares/vs-<other-slug>.md with sections for problem, formalization, method, experiments, strengths/weaknesses, and when-to-use-which decision guidance.
argument-hint: "<other-paper> [--paper <slug>] [--lang en|zh]"
---

# /paper:compare

Invokes the `compare` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:compare attention-is-all-you-need` — compare the most recently studied paper against the slug `attention-is-all-you-need` (which must already be in `~/claude-papers/papers/`).
- `/paper:compare ~/Downloads/scvi.pdf` — compare against a PDF that hasn't been studied yet. The skill auto-runs `/paper:study` on the new PDF first.
- `/paper:compare https://arxiv.org/abs/1706.03762` — same with a URL.
- `/paper:compare attention-is-all-you-need --paper string-database-2025` — both sides explicit.
- `/paper:compare attention-is-all-you-need --lang zh` — output Chinese prose (section headings stay English).

`<other-paper>` accepts:
- An existing slug (string with no `/` or `.pdf` and matching `~/claude-papers/papers/<slug>/`).
- A path to a paper folder under `~/claude-papers/papers/`.
- A PDF path (ends in `.pdf`) — auto-studied first.
- An arXiv or general URL — auto-studied first.

Output: `~/claude-papers/papers/<this-slug>/compares/vs-<other-slug>.md`. Default language is English; `--lang zh` switches the prose to Chinese (section headings stay English so downstream tooling can grep them).

Pre-requisites: `/paper:study` must have produced the focal paper's analysis directory. The `<other-paper>` will be auto-studied if not yet present.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/compare.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:compare command"
```

---

### Task 6: `skills/compare/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/compare/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

This is the most complex of Plan 3b's three skills — it has to detect input type and conditionally auto-study a new paper before comparing.

- [ ] **Step 1: Append failing tests**

```bash
@test "compare SKILL.md has YAML frontmatter with name" {
  head -5 skills/compare/SKILL.md | grep -qF 'name: compare'
}

@test "compare SKILL.md mentions compare-agent dispatch" {
  grep -qF 'compare-agent' skills/compare/SKILL.md
}

@test "compare SKILL.md handles three input types for other-paper" {
  for kind in 'slug' 'PDF path' 'URL'; do
    grep -qF "$kind" skills/compare/SKILL.md || { echo "missing: $kind"; return 1; }
  done
}

@test "compare SKILL.md auto-studies the other paper when needed" {
  grep -qF 'auto-studies' skills/compare/SKILL.md
}

@test "compare SKILL.md mentions --lang flag handling" {
  grep -qF -e '--lang' skills/compare/SKILL.md
}

@test "compare SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/compare/SKILL.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Create directory and SKILL.md**

```bash
mkdir -p paper-deepstudy/skills/compare
```

`paper-deepstudy/skills/compare/SKILL.md`:

```markdown
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

If `--paper <slug>` is provided, set `THIS_PAPER_DIR=~/claude-papers/papers/<slug>`. Otherwise:

\`\`\`bash
THIS_PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
\`\`\`

Verify `$THIS_PAPER_DIR/analysis/00-paper-profile.md` exists. If not, abort: `"Focal paper has no analysis directory. Run /paper:study first."`

Read `$THIS_PAPER_DIR/analysis/00-paper-profile.md` frontmatter to extract `THIS_SLUG` (basename of `$THIS_PAPER_DIR`).

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

\`\`\`
The other paper has not been studied yet. Auto-studying it now via /paper:study; this may take a few minutes.
\`\`\`

Invoke `/paper:study` via the Skill tool:

\`\`\`
Skill(skill: "paper-deepstudy:study-deep", args: "<other-paper> --yes")
\`\`\`

(`--yes` skips the Stage 0 confirmation prompt for the auto-detected profile, since we don't want a second user-interaction during a `compare` invocation.)

After it returns, locate the new paper folder (most recently modified):

\`\`\`bash
OTHER_PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
\`\`\`

Verify it's a different folder from `THIS_PAPER_DIR` (defensive). If they match, abort: `"Auto-study did not produce a distinct paper folder. Check /paper:study output."`

### 2.4 Set OTHER_SLUG

`OTHER_SLUG=$(basename $OTHER_PAPER_DIR)`.

---

## Stage 3: Resolve language flag and output path

Capture `--lang en` or `--lang zh` (default `en`). Set `LANG=english` or `LANG=chinese`.

\`\`\`bash
COMPARES_DIR="$THIS_PAPER_DIR/compares"
mkdir -p "$COMPARES_DIR"
OUTPUT_PATH="$COMPARES_DIR/vs-${OTHER_SLUG}.md"
\`\`\`

If `OUTPUT_PATH` already exists, back it up to `<file>.bak.NN` first:

\`\`\`bash
NN=1
while [ -e "$OUTPUT_PATH.bak.$NN" ]; do
  NN=$((NN + 1))
done
cp "$OUTPUT_PATH" "$OUTPUT_PATH.bak.$NN"
\`\`\`

(If `OUTPUT_PATH` doesn't exist yet, skip the backup.)

---

## Stage 4: Dispatch compare-agent

\`\`\`
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
)
\`\`\`

Wait for completion. The agent writes the comparison file directly.

---

## Stage 5: Verify and report

If `$OUTPUT_PATH` does not exist or is empty, restore from backup (if a backup exists) and report failure:

\`\`\`bash
if [ ! -s "$OUTPUT_PATH" ] && [ -e "$OUTPUT_PATH.bak.$NN" ]; then
  cp "$OUTPUT_PATH.bak.$NN" "$OUTPUT_PATH"
  echo "WARN: compare-agent produced empty output; restored from backup."
fi
\`\`\`

Otherwise, print to chat (in user's invocation language):

\`\`\`
✓ Comparison complete.
  This:  <THIS_SLUG>
  Other: <OTHER_SLUG>
  Output: $OUTPUT_PATH
  Language: $LANG
  Length: <wc -w on the file> words

Run /paper:compare again with a different paper to add another comparison.
\`\`\`

---

## Notes

- **Translation:** Chat-facing prose (status messages, errors, final summary) is rendered in the user's invocation language. The compare output file itself is English by default, Chinese if `--lang zh` was set.
- **Auto-study side effect:** When `<other-paper>` is a PDF path or URL, this skill auto-studies the other paper via `/paper:study --yes`. That produces the full Plan 1 outputs for the other paper (12 artifacts), not just the analysis directory. The auto-study is a documented side effect — once-per-paper.
- **Idempotence:** Each invocation backs up an existing `compares/vs-<other-slug>.md` to `.bak.NN` before overwriting. Same-pair comparisons accumulate as `.bak.1`, `.bak.2`, etc.
```

(Real triple backticks in file.)

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/compare/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): compare orchestration skill"
```

---

### Task 7: `/paper:add-prior-work` slash command

**Files:**
- Create: `paper-deepstudy/commands/add-prior-work.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests**

```bash
@test "add-prior-work.md has frontmatter" {
  head -1 commands/add-prior-work.md | grep -qE '^---$'
}

@test "add-prior-work.md mentions BibTeX, arXiv URL, and free-text inputs" {
  for kind in 'BibTeX' 'arXiv' 'free-text'; do
    grep -qiF "$kind" commands/add-prior-work.md || { echo "missing kind: $kind"; return 1; }
  done
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Write the command file**

`paper-deepstudy/commands/add-prior-work.md`:

```markdown
---
name: paper:add-prior-work
description: Augment analysis/05-prior-work.md with a new prior work entry that the auto-run pipeline missed. Accepts BibTeX entry, arXiv URL, or free-text "author + year + one-line description". Updates timeline, comparison table, and lineage diagram.
argument-hint: "<ref> [--paper <slug>]"
---

# /paper:add-prior-work

Invokes the `add-prior-work` skill from the `paper-deepstudy` plugin.

Usage:
- `/paper:add-prior-work "@inproceedings{vaswani2017attention, title={Attention Is All You Need}, author={Vaswani et al.}, year={2017}}"` — BibTeX entry.
- `/paper:add-prior-work https://arxiv.org/abs/1706.03762` — arXiv URL (skill auto-fetches metadata via WebFetch).
- `/paper:add-prior-work "Vaswani 2017 — introduced the Transformer architecture, displaced RNN/LSTM for long-range sequence modeling"` — free-text "author + year + one-line description".
- `/paper:add-prior-work <ref> --paper string-database-2025` — explicit target paper.

The skill dispatches `prior-work-historian` (the same sub-Agent from Plan 1's Stage 1, now re-invoked with the existing `05-prior-work.md` + the new ref). The historian:
1. Decides where in the chronological timeline the new entry belongs.
2. Adds a row to the comparison table.
3. Updates the lineage diagram if the new entry is structurally significant.
4. Saves the modified `analysis/05-prior-work.md` (with `<file>.bak.NN` backup of the prior version).

If the new entry might affect existing review.md weaknesses about prior-work coverage, the orchestrator suggests `/paper:review-round` afterward.

Pre-requisites: `/paper:study` must have produced `analysis/05-prior-work.md` already.
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/commands/add-prior-work.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "feat(paper-deepstudy): /paper:add-prior-work command"
```

---

### Task 8: `skills/add-prior-work/SKILL.md` orchestration

**Files:**
- Create: `paper-deepstudy/skills/add-prior-work/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

This skill reuses the existing `prior-work-historian` prompt from Plan 1. No new sub-Agent prompt is needed.

- [ ] **Step 1: Append failing tests**

```bash
@test "add-prior-work SKILL.md has YAML frontmatter with name" {
  head -5 skills/add-prior-work/SKILL.md | grep -qF 'name: add-prior-work'
}

@test "add-prior-work SKILL.md reuses prior-work-historian prompt" {
  grep -qF 'prior-work-historian' skills/add-prior-work/SKILL.md
}

@test "add-prior-work SKILL.md backs up 05-prior-work.md before mutation" {
  grep -qF '.bak.' skills/add-prior-work/SKILL.md
}

@test "add-prior-work SKILL.md suggests /paper:review-round when prior-work weaknesses might be affected" {
  grep -qF '/paper:review-round' skills/add-prior-work/SKILL.md
}

@test "add-prior-work SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/add-prior-work/SKILL.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Create directory and SKILL.md**

```bash
mkdir -p paper-deepstudy/skills/add-prior-work
```

`paper-deepstudy/skills/add-prior-work/SKILL.md`:

```markdown
---
name: add-prior-work
description: Use when the user wants to add a missing prior-work entry to analysis/05-prior-work.md. Re-dispatches prior-work-historian with the existing file + the new reference, asks it to update timeline + comparison table + lineage diagram.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Agent
---

# paper-deepstudy: add-prior-work workflow

Invoke after `/paper:study` has produced `analysis/05-prior-work.md`. Each invocation augments that file with one new prior-work entry the auto-run pipeline missed. Reuses the `prior-work-historian` sub-Agent prompt from Plan 1 with extended inputs.

Required positional arg: `<ref>` (BibTeX entry, arXiv URL, or free-text description).
Optional flag: `--paper <slug>` (default: most recently modified paper folder).

---

## Stage 1: Setup

### 1.1 Resolve target paper

If `--paper <slug>` is provided, set `PAPER_DIR=~/claude-papers/papers/<slug>`. Otherwise:

\`\`\`bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
\`\`\`

Verify `$PAPER_DIR/analysis/05-prior-work.md` exists. If not, abort: `"No analysis/05-prior-work.md at $PAPER_DIR. Run /paper:study or /paper:rerun-stage analysis first."`

Set:
- `PRIOR_WORK_PATH=$PAPER_DIR/analysis/05-prior-work.md`
- `ANALYSIS_DIR=$PAPER_DIR/analysis`
- `PAPER_TEXT=$PAPER_DIR/paper.txt`
- `PROFILE_PATH=$PAPER_DIR/analysis/00-paper-profile.md`
- `PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}`
- `REVIEW_PATH=$PAPER_DIR/review.md` (may not exist yet; see Stage 4)

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

\`\`\`bash
NN=1
while [ -e "$PRIOR_WORK_PATH.bak.$NN" ]; do
  NN=$((NN + 1))
done
cp "$PRIOR_WORK_PATH" "$PRIOR_WORK_PATH.bak.$NN"
\`\`\`

The backup is the rollback point; if the agent fails, restore from this.

---

## Stage 3: Dispatch prior-work-historian

The Plan 1 `prior-work-historian` prompt already supports WebFetch and writes to a `05-prior-work.md` path. Here we invoke it in **augmentation mode** by passing the existing file's content as additional context.

\`\`\`
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
\`\`\`

Wait for completion. The agent writes the modified file directly to `$PRIOR_WORK_PATH`.

---

## Stage 4: Check for review.md follow-up

If `$REVIEW_PATH` does not exist, skip this stage.

If it exists, read it. Look for any bullet point in `## Weaknesses/<dimension>` or `## Suggestions` that mentions "prior work" / "missing baseline" / "incomplete comparison" / "literature coverage" (case-insensitive grep on a small list of keywords).

If any matches, print to chat (in user's invocation language):

\`\`\`
The new prior-work entry may affect existing review.md notes about literature coverage.
Found: <relevant bullet text> (review.md line <N>)

Consider running /paper:review-round to revisit. Or update review.md manually if you
just want to remove a now-resolved point.
\`\`\`

If no matches, skip the suggestion silently.

---

## Stage 5: Verify and report

If `$PRIOR_WORK_PATH` is empty, restore from `$PRIOR_WORK_PATH.bak.$NN` and report failure. Otherwise:

\`\`\`
✓ Added prior-work entry.
  Reference: <REF (truncated to 80 chars if longer)>
  File: $PRIOR_WORK_PATH
  Backup: $PRIOR_WORK_PATH.bak.$NN

<optional review-round suggestion from Stage 4>

Run /paper:add-prior-work again to add more references.
\`\`\`

---

## Notes

- **Translation:** Chat-facing prose (status messages, the optional review-round suggestion) is in the user's invocation language. The augmented `05-prior-work.md` content stays English per spec §8.
- **Augmentation vs regeneration:** This skill uses `prior-work-historian` in augmentation mode (via extended instructions) so we don't lose the existing curated content. The Plan 1 prompt itself isn't modified — augmentation mode is purely an orchestrator-side instruction.
- **Failure modes:**
  - Reference can't be resolved (WebFetch failed for URL, BibTeX is malformed) → agent leaves a `<!-- could not resolve <REF>: <reason> -->` placeholder in the new entry; orchestrator reports the partial result.
  - Agent overwrites the whole file (regen mode by accident) → the `.bak.NN` backup lets the user `cp` it back.
```

(Real triple backticks in file.)

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/add-prior-work/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): add-prior-work orchestration skill"
```

---

### Task 9: Integration smoke test extension + README update

**Files:**
- Modify: `paper-deepstudy/tests/integration/test-end-to-end.sh`
- Modify: `paper-deepstudy/README.md`
- Modify: `paper-deepstudy/tests/unit/test-commands.bats`

- [ ] **Step 1: Append failing tests for README**

Append to `paper-deepstudy/tests/unit/test-commands.bats`:

```bash
@test "README documents /paper:deep-dive" {
  grep -qF '/paper:deep-dive' README.md
}

@test "README documents /paper:compare" {
  grep -qF '/paper:compare' README.md
}

@test "README documents /paper:add-prior-work" {
  grep -qF '/paper:add-prior-work' README.md
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Extend integration smoke test**

Modify `paper-deepstudy/tests/integration/test-end-to-end.sh`:

(a) **Extend prompts list (check #1):** Add `deep-dive-agent` and `compare-agent`.

```bash
for p in paper-profiler problem-framer formalizer method-analyst experiment-critic prior-work-historian figure-interpreter reviewer-synthesizer notes-writer title-generator xhs-renderer wechat-renderer defense-agent judge-agent review-writer deep-dive-agent compare-agent; do
```

(b) **Extend templates list (check #2):** Add `templates/deep-dive.md` and `templates/compare.md`.

```bash
for t in templates/analysis/00-paper-profile.md templates/analysis/01-problem.md templates/analysis/02-formalization.md templates/analysis/03-method-deep.md templates/analysis/04-experiments.md templates/analysis/05-prior-work.md templates/analysis/06-figures.md templates/review.md templates/review-round.md templates/deep-dive.md templates/compare.md templates/notes/source.md templates/notes/titles.md templates/notes/xhs.md templates/notes/wechat.md; do
```

(c) **Extend commands list (check #6):** Add `deep-dive`, `compare`, `add-prior-work`.

```bash
for c in study rerun-stage review-round refine-notes retitle reselect-figures deep-dive compare add-prior-work; do
```

(d) **Extend Plan 3a-style skill check (existing check #8):** Currently lists `refine-notes retitle reselect-figures`. Add the 3 new skills:

```bash
for s in refine-notes retitle reselect-figures deep-dive compare add-prior-work; do
```

(Or rename the comment from "Plan 3a skills" to "Plan 3a + 3b skills" for clarity.)

- [ ] **Step 4: Edit README**

Read `paper-deepstudy/README.md` first. Make these changes:

(a) **Update bullet 2 of features list at top:** find:

```
- Iterative review with adversarial review rounds (`/paper:review-round`) — English
```

Add a new bullet right after it:

```
- Analysis extension commands (`/paper:deep-dive`, `/paper:compare`, `/paper:add-prior-work`) — augment the auto-run analysis with deep dives, comparisons, and missed prior-work entries
```

(b) **Add a new "Analysis extensions" sub-section under "## Usage"** AFTER the "### Refine the rendered notes" sub-section (which Plan 3a added):

```
### Analysis extensions

After /paper:study has produced the analysis directory, three commands let you go deeper:

\`\`\`
/paper:deep-dive "contrastive loss derivation"             # focused topic deep-dive
/paper:compare attention-is-all-you-need                   # head-to-head with another studied paper
/paper:compare ~/Downloads/scvi.pdf                        # auto-studies the PDF first, then compares
/paper:compare attention-is-all-you-need --lang zh         # Chinese prose
/paper:add-prior-work https://arxiv.org/abs/1706.03762     # add a missed prior-work entry (arXiv URL)
/paper:add-prior-work "@article{vaswani2017,...}"          # BibTeX
\`\`\`

Outputs land at `~/claude-papers/papers/<slug>/`:
- `deep-dives/<topic-slug>.md` per `/paper:deep-dive`
- `compares/vs-<other-slug>.md` per `/paper:compare`
- `analysis/05-prior-work.md` is augmented in place by `/paper:add-prior-work` (with `.bak.NN` backup)
```

(c) **Extend the "What you get" output tree** (under "## What you get (12 outputs)"):

After the existing `review-rounds/` line, add:

```
deep-dives/                 # one file per /paper:deep-dive invocation (English)
compares/                   # one file per /paper:compare invocation (English by default, Chinese with --lang zh)
```

(d) **Update Roadmap** — find the existing roadmap and replace the relevant lines:

```
- **Plan 3a (this branch):** notes UX commands — `refine-notes`, `retitle`, `reselect-figures`. ✓
- **Plan 3b (future):** analysis-extension commands — `deep-dive`, `compare`, `add-prior-work`.
- **Plan 3c (future):** `reproduce-check` audit command.
```

with:

```
- **Plan 3a ✓ (shipped):** notes UX commands — `refine-notes`, `retitle`, `reselect-figures`.
- **Plan 3b ✓ (this branch):** analysis-extension commands — `deep-dive`, `compare`, `add-prior-work`.
- **Plan 3c (future):** `reproduce-check` audit command.
```

If there's a Plan 4 line and Plan 5 line, leave them alone. If Plan 5 isn't on the roadmap yet, add it:

```
- **Plan 5 ✓ (shipped):** cross-plan polish — Stage 0.2 invocation, --only/--paper flag wiring, helpers + tests.
```

- [ ] **Step 5: Verify all tests pass**

```bash
cd paper-deepstudy && npm run test:unit && cd ..
paper-deepstudy/tests/integration/test-end-to-end.sh
```

Expected: bats > 100 (existing 98 + 3 new from this task + others from Tasks 1-8 added along the way), 4 node, integration smoke PASSED.

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/tests/integration/test-end-to-end.sh paper-deepstudy/README.md paper-deepstudy/tests/unit/test-commands.bats
git commit -m "test+docs(paper-deepstudy): integration smoke + README cover Plan 3b commands"
```

---

## Self-Review checklist (Plan 3b 完成后跑一遍)

- [ ] All 3 new command files exist with frontmatter (`commands/deep-dive.md`, `compare.md`, `add-prior-work.md`).
- [ ] All 3 new orchestration skills exist (`skills/deep-dive/SKILL.md`, `compare/SKILL.md`, `add-prior-work/SKILL.md`).
- [ ] 2 new sub-Agent prompts exist (`prompts/deep-dive-agent.md`, `compare-agent.md`).
- [ ] 2 new output templates exist (`templates/deep-dive.md`, `compare.md`).
- [ ] `cd paper-deepstudy && npm run test:unit` passes (bats grew by ~15 from Plan 3b's tests + node helpers all green).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` passes; check #1 lists 17 prompts, check #2 lists 15 templates, check #6 lists 9 commands, check #8 lists 6 Plan 3a/3b skills.
- [ ] `compare` SKILL.md handles all 4 input kinds for `<other-paper>` (slug, paper-folder path, PDF path, URL) and auto-studies in the latter two cases.
- [ ] `add-prior-work` SKILL.md uses augmentation mode (does NOT regenerate the entire file) and has the `.bak.NN` backup.
- [ ] `deep-dive` SKILL.md uses `slugify-objection.cjs` for topic-slug derivation and handles same-topic collisions with `-2`/`-3` suffix.
- [ ] All 3 SKILL.md mention "user's invocation language" for chat-facing prose.
- [ ] No Claude co-author on any commit.

---

## Live test recipe (manual, post-implementation)

After all 9 tasks ship, validate against the existing `string-database-2025` paper:

1. **Test `/paper:deep-dive`:** `/paper:deep-dive "the FAVA co-expression integration"`. Verify `deep-dives/the-fava-co-expression-integration.md` is produced with all 5 H2 sections.

2. **Test `/paper:compare` slug case:** First `/paper:study https://arxiv.org/abs/1706.03762` (Attention Is All You Need). Then `/paper:compare attention-is-all-you-need`. Verify `compares/vs-attention-is-all-you-need.md` is produced.

3. **Test `/paper:compare` auto-study case:** `/paper:compare https://arxiv.org/abs/<some other paper>`. Verify the skill auto-studies the new paper, then writes the compare file.

4. **Test `/paper:add-prior-work` BibTeX case:** Pick a real reference STRING 12.5 didn't cite, e.g. `/paper:add-prior-work "@article{snel2002string, title={STRING: a web-server to retrieve and display the repeatedly occurring neighbourhood of a gene}, author={Snel et al.}, year={2002}}"`. Verify `analysis/05-prior-work.md` got augmented with this 2002 STRING-precursor entry, and `analysis/05-prior-work.md.bak.1` exists.

5. **Test `/paper:add-prior-work` arXiv URL case:** `/paper:add-prior-work https://arxiv.org/abs/1907.11692` (RoBERTa). Verify the entry is added with year 2019 + RoBERTa info auto-fetched.

If any step diverges from expected behavior, file as a follow-up issue against Plan 3b — not a blocker for declaring Plan 3b complete since the static contract tests pass.
