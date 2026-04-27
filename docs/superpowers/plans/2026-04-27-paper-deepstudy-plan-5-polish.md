# paper-deepstudy Plan 5: Polish (集成修复) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Plan 1/2/3a 的 review 和 live integration test 暴露的小问题集中修一遍 —— Stage 0.2 invocation 太散文化、`--only`/`--paper` 旗标没真正连上、figure-interpreter 的 quality bar 偏弱、review-writer 的 merge tag 格式怪、几处 README 残留的过期文案、以及缺少自动化的 idempotence / judge-YAML / slug derivation 测试。

**Architecture:** 全部是对现有文件的小修小补 —— 修改 `paper-deepstudy/skills/study-deep/SKILL.md`、`paper-deepstudy/prompts/figure-interpreter.md`、`paper-deepstudy/prompts/review-writer.md`、`paper-deepstudy/README.md`、`paper-deepstudy/commands/reselect-figures.md`,加几个 bats 测试。**不创建新插件、新命令、新 sub-Agent**。

**Tech Stack:** Markdown、Bash、Bats(structural tests)。无新依赖。

**修复条目按来源整理:**

来源 | 编号 | 内容 | Plan 5 对应 Task
---|---|---|---
Plan 1 final review | I2 | Stage 0.2 「Invoke the claude-paper study skill」太散文化 —— 没说怎么 invoke、怎么找 slug | Task 1
Plan 1 final review | I3 | `--only`/`--paper` 旗标在 `/paper:rerun-stage` 命令文件里写了,但 `study-deep` SKILL.md 没有真正的分支处理 | Task 2
Plan 1 final review | I4 | Idempotence 的 skip-if-exists 行为只 grep 关键字,没自动化测试 | Task 3
Plan 2 final review | — | `study-deep` SKILL.md line 306 的 `(These commands ship in Plans 2 and 3.)` 已过期(2 已发,3a 已发) | Task 4
Plan 2 final review | — | Judge YAML 解析的散文描述没有 helper 也没有测试 | Task 5
Plan 2 final review | — | Round-file slug derivation 的散文描述没有 helper 也没有测试 | Task 5(合并)
Plan 3a final review | — | README 给 Plan 2/3a/4 都标了 ✓,但 Plan 1 没有 marker | Task 4(合并)
Plan 3a final review | — | `commands/reselect-figures.md` 里 "when wired in" 这句话别扭 | Task 4(合并)
Live test phase 6 | — | figure-interpreter 提示「exactly one figure ≥ 0.9」但实际产出多个 ≥0.9 | Task 6
Live test phase 5 | — | review-writer 的 merge tag 格式是 `← from rounds initial analysis, 1`(类型混搭) | Task 7
Live test 的语言 | — | 多个 SKILL.md 描述 "show user (in user's invocation language)" 但 sub-Agent 不会自动这么做 —— 反正 SKILL.md 是 orchestrator 跑的脚本,实际 user-facing 翻译由 orchestrator 负责。**这条已经在 spec §8 范围内,Plan 5 不需要新动作**,但加个测试断言确保 chat-facing-language 这句话存在于每个 SKILL.md | Task 8

合并后 8 个 task。

---

## File Structure

```
paper-deepstudy/
├── skills/study-deep/SKILL.md                    (modified — Task 1, 2, 4)
├── prompts/
│   ├── figure-interpreter.md                     (modified — Task 6)
│   └── review-writer.md                          (modified — Task 7)
├── commands/reselect-figures.md                  (modified — Task 4)
├── README.md                                      (modified — Task 4)
├── scripts/
│   ├── parse-judge-output.cjs                    (NEW — Task 5)
│   └── slugify-objection.cjs                     (NEW — Task 5)
└── tests/
    ├── unit/
    │   ├── test-idempotence-skip.bats            (NEW — Task 3)
    │   ├── test-parse-judge-output.cjs           (NEW — Task 5)
    │   ├── test-slugify-objection.cjs            (NEW — Task 5)
    │   ├── test-prompts-have-required-sections.bats   (modified — Task 1, 2, 8)
    │   └── test-prompts-have-required-sections.bats   (Task 8 chat-facing-language assertions)
    └── integration/test-end-to-end.sh            (modified — Task 5 to verify new helpers exist)
```

---

## Pre-flight

1. Plan 1/2/3a/4 都已 merge 到 `main`,这个分支是从 `main` 长出来的(`feat/plan-5-polish`)。
2. 现有测试都通过:
   ```bash
   cd paper-deepstudy && npm run test:unit && cd ..
   paper-deepstudy/tests/integration/test-end-to-end.sh
   ```
   预期 84 bats + 2 node + integration smoke 全过。

---

### Task 1: Stage 0.2 落实 claude-paper:study 的具体调用方式

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

Plan 1 的 final review 指出:Stage 0.2 现在只说「Invoke the claude-paper study skill on the input.」,既没说**怎么**调(用 Skill tool 还是 Agent tool 还是别的),也没说**怎么找新生成的 paper folder slug**(因为 meta.json 在 `<slug>/` 下,但 slug 还没确定,有 chicken-and-egg 问题)。

具体的修复:用 Skill tool 调用 `claude-paper:study`,然后通过 `ls -t ~/claude-papers/papers/ | head -1` 找最新生成的 folder。

- [ ] **Step 1: 加一个 failing test**

把这两条 @test 追加到 `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "study-deep SKILL.md Stage 0.2 mentions Skill tool dispatch" {
  grep -qF 'Skill tool' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md Stage 0.2 describes slug discovery" {
  grep -qF 'ls -t' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Run, verify fail**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```
预期 2 个新失败。

- [ ] **Step 3: 改 Stage 0.2**

读 `paper-deepstudy/skills/study-deep/SKILL.md`,找到 `### 0.2 Run claude-paper:study (baseline)` 这一节。当前内容大致是:

```
### 0.2 Run claude-paper:study (baseline)

Invoke the claude-paper study skill on the input. After completion, the paper folder lives at `~/claude-papers/papers/<slug>/` containing at least `meta.json`, `summary.md`, `paper.pdf`, and `images/`. Resolve `<slug>` from `meta.json` produced by claude-paper.

If the paper folder does not exist after running claude-paper:study, abort with: "claude-paper:study did not produce expected outputs at ~/claude-papers/papers/<slug>/".
```

整个 Stage 0.2 替换为:

```markdown
### 0.2 Run claude-paper:study (baseline)

Invoke `claude-paper:study` via the Skill tool with the user's input as args:

```
Skill(skill: "claude-paper:study", args: "<user-input-pdf-path-or-url>")
```

`claude-paper:study` will download / parse the PDF and produce a paper folder under `~/claude-papers/papers/<slug>/`. The slug is auto-derived from the paper title.

After the Skill returns, locate the new paper folder. The most reliable way is to take the most recently modified subdirectory:

```bash
PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
```

Verify required outputs exist:
- `$PAPER_DIR/meta.json`
- `$PAPER_DIR/paper.pdf`
- `$PAPER_DIR/summary.md` (claude-paper's curated summary, not the full text — Stage 0.3.1 extracts the full text via pdftotext)
- `$PAPER_DIR/images/` (may be empty if pdftotext-style extraction fails; report and continue)

If any of these are missing, abort with: `"claude-paper:study did not produce expected outputs at $PAPER_DIR. Check the claude-paper plugin's installation and try /paper:study again."`

Read `$PAPER_DIR/meta.json` and confirm its `slug` field matches the basename of `$PAPER_DIR`. If they disagree, prefer the `meta.json` slug (and adjust `PAPER_DIR` accordingly).
```

- [ ] **Step 4: Run, verify pass**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```
预期所有测试都过。

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): Stage 0.2 spells out Skill-tool invocation and slug discovery"
```

---

### Task 2: study-deep 处理 `--only <stage>` 和 `--paper <slug>` 旗标

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md`
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

Plan 1 final review 的 I3:`/paper:rerun-stage` 命令文件里写了 `<stage>` 和 `--paper <slug>` 参数,SKILL.md 里也提到 `--only <stage>` 和 `--paper`,但**没有真正的分支处理**。一个 LLM 跑 `/paper:rerun-stage analysis` 时不知道「跳过 0/2/3 三个 stage,只跑 1 stage」该怎么实现。

修复:在 `study-deep` SKILL.md 顶部加一节 "Flag dispatch",清晰说明 `--only` / `--paper` / `--yes` / `--force` 各自怎么影响后续 stage。

- [ ] **Step 1: 加 failing tests**

追加到 `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "study-deep SKILL.md has Flag dispatch section" {
  grep -qF '## Flag dispatch' skills/study-deep/SKILL.md
}

@test "study-deep SKILL.md Flag dispatch covers all four flags" {
  for f in --only --paper --yes --force; do
    grep -qF -e "$f" skills/study-deep/SKILL.md || { echo "missing flag: $f"; return 1; }
  done
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: 在 SKILL.md 顶部加 "Flag dispatch" 章节**

在 `paper-deepstudy/skills/study-deep/SKILL.md` 中,找到现在的 "Optional flags:" 列表(在文件顶部 introductory 段落里):

```
Optional flags:
- `--yes`: skip Stage 0 confirmation prompt (auto-accept profile).
- `--force`: re-run all stages, backing up existing outputs.
```

在它**之后**、`---` 分隔线之前,插入新的 `## Flag dispatch` 章节:

```markdown
## Flag dispatch

This skill is invoked by `/paper:study <pdf-or-url> [flags]` and `/paper:rerun-stage <stage> [flags]`. The flags below control which stages run and how outputs are handled. The orchestrator MUST honor all four flags as specified.

### `--paper <slug>`

If set, skip Stage 0.2 (claude-paper:study invocation) and skip Stage 0.3 path resolution. Set `PAPER_DIR=~/claude-papers/papers/<slug>` directly. Verify `$PAPER_DIR/meta.json` exists; abort if not.

If `--paper` is **not** set, the orchestrator either runs Stage 0.2 (for `/paper:study`) or auto-detects the most recent paper folder via `ls -td ~/claude-papers/papers/*/ | head -1` (for `/paper:rerun-stage`).

### `--only <stage>` (used by `/paper:rerun-stage`)

`<stage>` is one of `profile | analysis | review | notes`. When set:

| `--only` value | Skip stages | Run stages |
|---|---|---|
| `profile` | Stage 1, 2, 3 | Stage 0 only (paper-profiler dispatch). The orchestrator backs up the existing `00-paper-profile.md` first. |
| `analysis` | Stage 0.4, 0.5, 2, 3 | Stage 1 only (six parallel analysis sub-Agents). Stage 0.1–0.3.1 still runs to set up paths. Existing analysis files 01–06 are backed up first. |
| `review` | Stage 0.4, 0.5, 1, 3 | Stage 2 only (reviewer-synthesizer). Existing `review.md` backed up. **Note:** this discards any edits made by `/paper:review-round`. The orchestrator MUST warn the user before proceeding. |
| `notes` | Stage 0.4, 0.5, 1, 2 | Stage 3 only (notes-writer + title-generator + xhs/wechat renderers). Existing `notes/*.md` backed up. **Note:** this also overwrites `notes/source.md`, so any manual content edits to `source.md` are lost — refer to `refine-notes` skill for the source-vs-rendering split workflow. |

`--only` implies `--force` scoped to that stage's outputs (existing files are backed up to `<file>.bak.NN` before re-running).

### `--yes`

Skip the Stage 0.5 user-confirmation prompt for the auto-detected profile. Use the profile as-is. Record `--yes auto-accepted` in the final summary.

### `--force`

For each output file in any stage that runs: if the file exists, back it up to `<file>.bak.NN` (smallest non-existent integer ≥ 1) before re-running its sub-Agent. Without `--force`, existing output files are skipped (per the per-dispatch idempotence rule below).

### Conflict handling

- `--only` and `--paper` are independent and may be combined.
- `--only` implies `--force` scoped to the named stage; explicit `--force` on top is redundant but harmless.
- `--yes` is independent of `--only` / `--paper` / `--force`.
```

- [ ] **Step 4: 在 Stage 1.2、Stage 2.1、Stage 3.x 各 dispatch 处提一句**

在每个 sub-Agent dispatch 段落开头加一行:

> **Skipped if `--only` is set and this stage is not the named stage.** See `## Flag dispatch` for full routing.

具体位置:Stage 1.2 ("Dispatch six sub-Agents in parallel") 顶部、Stage 2.1 ("Dispatch reviewer-synthesizer") 顶部、Stage 3.1 ("Dispatch notes-writer") 顶部、Stage 3.2 ("Dispatch title-generator") 顶部、Stage 3.4 ("Dispatch xhs-renderer + wechat-renderer in parallel") 顶部。

- [ ] **Step 5: Run, verify pass**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "fix(paper-deepstudy): wire --only/--paper/--yes/--force flags in study-deep"
```

---

### Task 3: idempotence skip 行为的自动化测试

**Files:**
- Create: `paper-deepstudy/tests/unit/test-idempotence-skip.bats`

Plan 1 final review 的 I4:idempotence 现在只是 `grep -qiF 'skip' skills/study-deep/SKILL.md` —— 不验证规则结构正确,只验证关键字存在。这次写一个真正检查规则结构的 bats 测试。

注意:这是 documentation-level 测试,不是真跑 sub-Agent。我们检查 SKILL.md 的「Per-dispatch idempotence rule」章节是否包含三种关键情况(exists+no-force / exists+force / not-exists)以及它声称覆盖的所有 dispatch site 编号。

- [ ] **Step 1: Write the test**

`paper-deepstudy/tests/unit/test-idempotence-skip.bats`:

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "Per-dispatch idempotence rule lists all three cases" {
  for case in 'exists and `--force` is not set' 'exists and `--force` is set' 'does not exist'; do
    grep -qF "$case" skills/study-deep/SKILL.md || { echo "missing case: $case"; return 1; }
  done
}

@test "Per-dispatch idempotence rule names all 6 dispatch sites" {
  for site in '0.4' '1.2' '2.1' '3.1' '3.2' '3.4'; do
    grep -qF "$site" skills/study-deep/SKILL.md || { echo "missing site: $site"; return 1; }
  done
}

@test "Per-dispatch idempotence rule mentions backing up to .bak.NN" {
  grep -qF '.bak.NN' skills/study-deep/SKILL.md
}

@test "Idempotence rule's --force backup uses smallest non-existent NN" {
  grep -qF "smallest non-existent integer" skills/study-deep/SKILL.md
}

@test "Skipped dispatches still count as completed in final summary" {
  grep -qF 'Skipped dispatches still count' skills/study-deep/SKILL.md
}
```

- [ ] **Step 2: Run, verify pass**

由于 `paper-deepstudy/skills/study-deep/SKILL.md` 在 Plan 1 Task 21 的修复里已经有这些字符串(部分),大部分应该直接通过。如果有不通过的,说明 SKILL.md 文案该补充。修一下 SKILL.md 让所有断言都通过 —— 这就是测试驱动:测试反过来强化 SKILL.md 的具体性。

预期可能要补的字符串:
- "exists and `--force` is not set"
- "exists and `--force` is set"
- "does not exist"
- "Skipped dispatches still count"

如果 SKILL.md 缺少其中某条,补到 `### Per-dispatch idempotence rule` 那一节。

- [ ] **Step 3: Commit**

```bash
git add paper-deepstudy/tests/unit/test-idempotence-skip.bats paper-deepstudy/skills/study-deep/SKILL.md
git commit -m "test(paper-deepstudy): structural test for idempotence skip rule + tighten SKILL.md wording"
```

---

### Task 4: 几处过期文案 / awkward phrase / README marker

**Files:**
- Modify: `paper-deepstudy/skills/study-deep/SKILL.md` (forward-ref to Plans 2/3 已部分发布)
- Modify: `paper-deepstudy/commands/reselect-figures.md` ("when wired in" awkward phrase)
- Modify: `paper-deepstudy/README.md` (Plan 1 missing ✓ marker)

3 个独立的文档小补,放一个 commit 里。

- [ ] **Step 1: 改 study-deep SKILL.md 的 forward-ref**

在 `paper-deepstudy/skills/study-deep/SKILL.md` 末尾(Final summary 章节里)找:

```
  /paper:reproduce-check
  (These commands ship in Plans 2 and 3.)
```

改为(更准确地反映现状):

```
  /paper:reproduce-check
  (These commands ship in: Plan 2 ✓ for /paper:review-round; Plan 3a ✓ for /paper:refine-notes, /paper:retitle, /paper:reselect-figures; Plan 3b for /paper:deep-dive, /paper:compare, /paper:add-prior-work; Plan 3c for /paper:reproduce-check.)
```

- [ ] **Step 2: 改 commands/reselect-figures.md 的 awkward phrase**

`paper-deepstudy/commands/reselect-figures.md` 当前有这句:

```
Both renderings are then re-dispatched with the new figure selections. The body content is preserved (the renderers respect existing `EDIT_INSTRUCTION`-style refinement when wired in; here `EDIT_INSTRUCTION` is omitted, so the renderers re-render from `source.md` and `titles.md` with the new figures).
```

改为:

```
Both renderings are then re-dispatched with the new figure selections. **The body is regenerated from `source.md`** — any prior body edits made via `/paper:refine-notes` are NOT preserved. To preserve body edits while swapping figures, use `/paper:refine-notes <platform>` with an instruction like "swap embedded figure to <filename>" instead of running `/paper:reselect-figures`.
```

- [ ] **Step 3: 改 README.md 的 roadmap 章节**

`paper-deepstudy/README.md` 的 `## Roadmap` 章节现在是:

```
- **Plan 1 (this):** auto-run pipeline, `ml-pure` and `single-cell` packs.
```

(Plan 1 没有 ✓ marker,看起来像未完成。)

改为:

```
- **Plan 1 ✓ (shipped):** auto-run pipeline, `ml-pure` and `single-cell` packs.
```

- [ ] **Step 4: Run all tests to make sure nothing regressed**

```bash
cd paper-deepstudy && npm run test:unit && cd ..
paper-deepstudy/tests/integration/test-end-to-end.sh
```
预期全过(这些只是文案调整,不影响测试断言)。

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/study-deep/SKILL.md paper-deepstudy/commands/reselect-figures.md paper-deepstudy/README.md
git commit -m "docs(paper-deepstudy): refresh stale forward-refs, README Plan 1 marker, reselect-figures phrasing"
```

---

### Task 5: Judge YAML 解析 helper + Round-file slug 派生 helper(各带测试)

**Files:**
- Create: `paper-deepstudy/scripts/parse-judge-output.cjs`
- Create: `paper-deepstudy/scripts/slugify-objection.cjs`
- Create: `paper-deepstudy/tests/unit/test-parse-judge-output.cjs`
- Create: `paper-deepstudy/tests/unit/test-slugify-objection.cjs`
- Modify: `paper-deepstudy/package.json`(给 test:unit 加两个 node test)
- Modify: `paper-deepstudy/skills/review-round/SKILL.md`(用 helper 替换散文描述)
- Modify: `paper-deepstudy/tests/integration/test-end-to-end.sh`(新 helper 加进 check)

Plan 2 final review 指出:judge 的 YAML 输出解析 + round-file 的 slug 派生现在都是散文描述,没 helper 也没测试。提取成两个 pure-logic Node helper(和 `select-figures.cjs` / `next-round-number.cjs` 同款风格),加单元测试。

- [ ] **Step 1: Write failing tests for parse-judge-output**

`paper-deepstudy/tests/unit/test-parse-judge-output.cjs`:

```javascript
const assert = require('node:assert/strict');
const { parseJudgeOutput } = require('../../scripts/parse-judge-output.cjs');

// Case 1: well-formed YAML inside ```yaml fence
const wellFormed = `Some preamble.
\`\`\`yaml
verdict: holds
reasoning: |
  The defense addresses the core claim with specific evidence.
  Coherent throughout.
\`\`\`
Some trailing text.`;
const r1 = parseJudgeOutput(wellFormed);
assert.strictEqual(r1.verdict, 'holds');
assert.match(r1.reasoning, /addresses the core claim/);

// Case 2: partially_holds
const partial = `\`\`\`yaml
verdict: partially_holds
reasoning: |
  Defense reframes rather than answers.
\`\`\``;
const r2 = parseJudgeOutput(partial);
assert.strictEqual(r2.verdict, 'partially_holds');
assert.match(r2.reasoning, /reframes/);

// Case 3: fails
const failsCase = `\`\`\`yaml
verdict: fails
reasoning: |
  Defense fails to address the core.
\`\`\``;
const r3 = parseJudgeOutput(failsCase);
assert.strictEqual(r3.verdict, 'fails');

// Case 4: invalid verdict value → fallback to partially_holds
const invalid = `\`\`\`yaml
verdict: maybe
reasoning: |
  Confused.
\`\`\``;
const r4 = parseJudgeOutput(invalid);
assert.strictEqual(r4.verdict, 'partially_holds');
assert.match(r4.reasoning, /unparseable|invalid/i);

// Case 5: missing yaml fence → fallback
const noFence = `verdict: holds\nreasoning: text`;
const r5 = parseJudgeOutput(noFence);
assert.strictEqual(r5.verdict, 'partially_holds');

// Case 6: empty input → fallback
const r6 = parseJudgeOutput('');
assert.strictEqual(r6.verdict, 'partially_holds');

// Case 7: yaml fence but missing verdict key → fallback
const noVerdict = `\`\`\`yaml
reasoning: just reasoning, no verdict
\`\`\``;
const r7 = parseJudgeOutput(noVerdict);
assert.strictEqual(r7.verdict, 'partially_holds');

console.log('parse-judge-output: all tests passed');
```

- [ ] **Step 2: Verify it fails**

```bash
node paper-deepstudy/tests/unit/test-parse-judge-output.cjs
```
预期 `Cannot find module ../../scripts/parse-judge-output.cjs`.

- [ ] **Step 3: Write parse-judge-output.cjs**

`paper-deepstudy/scripts/parse-judge-output.cjs`:

```javascript
#!/usr/bin/env node
// Pure-logic helper: parse a judge-agent's output text and return { verdict, reasoning }.
// Falls back to {verdict: 'partially_holds', reasoning: '<reason>'} on any parse failure.
// The verdict must be one of holds | partially_holds | fails.

const VALID = new Set(['holds', 'partially_holds', 'fails']);
const FALLBACK = (msg) => ({
  verdict: 'partially_holds',
  reasoning: `Judge output unparseable: ${msg} — manual review required.`,
});

function parseJudgeOutput(text) {
  if (typeof text !== 'string' || text.length === 0) {
    return FALLBACK('empty or non-string input');
  }

  const fenceMatch = text.match(/```yaml\s*\n([\s\S]*?)\n```/);
  if (!fenceMatch) {
    return FALLBACK('no yaml-fenced block found');
  }
  const yaml = fenceMatch[1];

  // Lightweight parse — no full YAML library, just verdict + reasoning extraction.
  const verdictMatch = yaml.match(/^verdict:\s*(\S+)\s*$/m);
  if (!verdictMatch) {
    return FALLBACK('verdict key missing in yaml block');
  }
  const verdict = verdictMatch[1];
  if (!VALID.has(verdict)) {
    return FALLBACK(`invalid verdict value '${verdict}'`);
  }

  // reasoning may be a literal block (`|`) or a single line
  let reasoning;
  const literalMatch = yaml.match(/^reasoning:\s*\|\s*\n((?:\s+.*(?:\n|$))*)/m);
  if (literalMatch) {
    reasoning = literalMatch[1].split('\n').map(l => l.replace(/^\s+/, '')).join(' ').trim();
  } else {
    const inlineMatch = yaml.match(/^reasoning:\s*(.+)$/m);
    reasoning = inlineMatch ? inlineMatch[1].trim() : '';
  }

  return { verdict, reasoning };
}

if (require.main === module) {
  const input = require('node:fs').readFileSync(0, 'utf8');
  console.log(JSON.stringify(parseJudgeOutput(input), null, 2));
}

module.exports = { parseJudgeOutput };
```

```bash
chmod +x paper-deepstudy/scripts/parse-judge-output.cjs
```

- [ ] **Step 4: Verify parse-judge-output test passes**

```bash
node paper-deepstudy/tests/unit/test-parse-judge-output.cjs
```
预期 `parse-judge-output: all tests passed`.

- [ ] **Step 5: Write failing test for slugify-objection**

`paper-deepstudy/tests/unit/test-slugify-objection.cjs`:

```javascript
const assert = require('node:assert/strict');
const { slugifyObjection } = require('../../scripts/slugify-objection.cjs');

// Basic case
assert.strictEqual(
  slugifyObjection("The baseline comparison in §4 uses a 3x smaller compute budget"),
  'the-baseline-comparison-in-uses'
);

// Drops punctuation, keeps alphanumeric only
assert.strictEqual(
  slugifyObjection("Claim 2: zero-shot generalization isn't supported because the test set leaks!"),
  'claim-2-zero-shot-generalization'
);

// Lowercases
assert.strictEqual(
  slugifyObjection("MISSING REPRODUCIBILITY: no random seed reported"),
  'missing-reproducibility-no-random'
);

// Caps at first ~6 words / 40 char
const long = slugifyObjection("This is a very long objection that goes on and on and on and exceeds the cap");
assert.ok(long.length <= 40, `expected length <= 40, got ${long.length}`);
const wordCount = long.split('-').length;
assert.ok(wordCount <= 6, `expected <= 6 words, got ${wordCount}`);

// Empty / whitespace input → 'untitled'
assert.strictEqual(slugifyObjection(''), 'untitled');
assert.strictEqual(slugifyObjection('   '), 'untitled');

// Chinese punctuation / non-ASCII content → strip to ASCII-only or 'untitled'
const chinese = slugifyObjection('实验设计有问题:基线不公平');
// Either 'untitled' (if all stripped) or some ASCII-rendered form is acceptable;
// the test asserts that whatever's returned is purely [a-z0-9-] and non-empty.
assert.match(chinese, /^[a-z0-9-]+$/, 'must be lowercase alphanumeric/hyphen');

// Multi-space and leading/trailing dashes are normalized
assert.strictEqual(
  slugifyObjection("  --leading dashes and    multiple   spaces--  "),
  'leading-dashes-and-multiple-spaces'
);

console.log('slugify-objection: all tests passed');
```

- [ ] **Step 6: Verify test fails**

```bash
node paper-deepstudy/tests/unit/test-slugify-objection.cjs
```
预期 `Cannot find module`.

- [ ] **Step 7: Write slugify-objection.cjs**

`paper-deepstudy/scripts/slugify-objection.cjs`:

```javascript
#!/usr/bin/env node
// Pure-logic helper: derive a round-file slug from an objection text.
// Lowercase, alphanumeric + hyphens only, first ~6 words, cap at 40 chars.
// Returns 'untitled' if the result would be empty.

function slugifyObjection(text) {
  if (typeof text !== 'string') return 'untitled';
  // Strip non-ASCII (keep [A-Za-z0-9 -]); Chinese punctuation gets dropped here.
  const ascii = text.replace(/[^A-Za-z0-9 -]/g, ' ');
  // Lowercase, normalize whitespace
  const normalized = ascii.toLowerCase().split(/\s+/).filter(w => w.length > 0);
  // Take first 6 words
  const words = normalized.slice(0, 6);
  // Join with hyphens
  let slug = words.join('-');
  // Strip leading/trailing dashes
  slug = slug.replace(/^-+|-+$/g, '');
  // Collapse repeated dashes
  slug = slug.replace(/-+/g, '-');
  // Cap at 40 chars (preserve word boundary if possible)
  if (slug.length > 40) {
    slug = slug.slice(0, 40);
    // Trim trailing partial word if cut mid-word
    slug = slug.replace(/-[^-]*$/, '');
  }
  if (slug.length === 0) return 'untitled';
  return slug;
}

if (require.main === module) {
  const input = require('node:fs').readFileSync(0, 'utf8');
  console.log(slugifyObjection(input.trim()));
}

module.exports = { slugifyObjection };
```

```bash
chmod +x paper-deepstudy/scripts/slugify-objection.cjs
```

- [ ] **Step 8: Verify slugify test passes**

```bash
node paper-deepstudy/tests/unit/test-slugify-objection.cjs
```
预期 `slugify-objection: all tests passed`.

- [ ] **Step 9: Update package.json**

读 `paper-deepstudy/package.json`,把 `test:unit` script 从:

```json
"test:unit": "bats tests/unit && node tests/unit/test-select-figures.cjs && node tests/unit/test-next-round-number.cjs"
```

改为:

```json
"test:unit": "bats tests/unit && node tests/unit/test-select-figures.cjs && node tests/unit/test-next-round-number.cjs && node tests/unit/test-parse-judge-output.cjs && node tests/unit/test-slugify-objection.cjs"
```

- [ ] **Step 10: 更新 review-round SKILL.md 引用 helper**

读 `paper-deepstudy/skills/review-round/SKILL.md`。

(a) Stage 2.3 的散文描述「Parse the judge's output to extract `JUDGE_VERDICT_<i>` ... extract by reading lines between ` ```yaml ` and ` ``` `.」改为:

```
Parse the judge's output via the helper:

\`\`\`bash
echo "$JUDGE_OUTPUT" | node $PLUGIN_ROOT/scripts/parse-judge-output.cjs
\`\`\`

The helper returns a JSON object `{verdict, reasoning}`. `verdict` is one of `holds | partially_holds | fails`. On parse failure (missing yaml fence, invalid verdict, etc.), the helper returns `{verdict: "partially_holds", reasoning: "Judge output unparseable: ... — manual review required."}` — the orchestrator can use this directly without additional fallback logic.
```

(注意:写到 SKILL.md 文件里时,反引号要是真的反引号,不要 escape。上面的 \\` 是为了在 prompt 里展示。)

(b) Stage 5.1 的散文描述「`<short-title>`: derived from the first ~6 words of the objection, lowercased, hyphenated, alphanumeric only. Cap at 40 chars.」改为:

```
`<short-title>`: derived from the objection text via the helper:

\`\`\`bash
echo "$OBJECTION" | node $PLUGIN_ROOT/scripts/slugify-objection.cjs
\`\`\`

The helper returns the slug (or `untitled` if input has no extractable ASCII). Slug rules: lowercase, alphanumeric + hyphens only, first ~6 words, capped at 40 chars.
```

- [ ] **Step 11: Update integration smoke test**

`paper-deepstudy/tests/integration/test-end-to-end.sh` 的 check #3a / 类似位置后,加新 check 校验两个 helper 存在并可执行:

```bash
# 3b. parse-judge-output and slugify-objection helpers exist and are executable
for helper in parse-judge-output slugify-objection; do
  if [ ! -x "$ROOT/scripts/$helper.cjs" ]; then
    echo "FAIL: $helper.cjs missing or not executable"; fail=1
  fi
done
```

- [ ] **Step 12: Run all tests**

```bash
cd paper-deepstudy && npm run test:unit && cd ..
paper-deepstudy/tests/integration/test-end-to-end.sh
```
预期:bats + 4 个 node test 全过 + integration smoke PASSED.

- [ ] **Step 13: Commit**

```bash
git add paper-deepstudy/scripts/parse-judge-output.cjs paper-deepstudy/scripts/slugify-objection.cjs paper-deepstudy/tests/unit/test-parse-judge-output.cjs paper-deepstudy/tests/unit/test-slugify-objection.cjs paper-deepstudy/package.json paper-deepstudy/skills/review-round/SKILL.md paper-deepstudy/tests/integration/test-end-to-end.sh
git commit -m "feat(paper-deepstudy): parse-judge-output and slugify-objection helpers + tests, wire into review-round skill"
```

---

### Task 6: figure-interpreter prompt — quality bar 收紧

**Files:**
- Modify: `paper-deepstudy/prompts/figure-interpreter.md`

Live test phase 2 发现:figure-interpreter 当前的 quality bar 写「Exactly one figure should be ≥ 0.9 (the most important one).」,但实际产出有时会有 2 个 ≥ 0.9。这是**约束太紧又没机制保证**。

修复:把约束从「exactly one」改成更宽松但语义更清楚的「at most one figure at 1.0; importance ranges should be calibrated so that select-figures.cjs can reliably pick the top-1 (xhs) and top-3 (wechat) by importance」,这样实际语义和 downstream 用法一致。

- [ ] **Step 1: 改 figure-interpreter.md 的 Quality bar 章节**

读 `paper-deepstudy/prompts/figure-interpreter.md`。当前 quality bar 的第一条:

```
- Importance scores are usable for picking 1 figure (xhs) and 2-3 figures (wechat). Exactly one figure should be ≥ 0.9 (the most important one).
```

改为:

```
- Importance scores must be calibrated so that downstream `select-figures.cjs` can reliably pick the top-1 (xhs) and top-3 (wechat) by score. Specifically:
  - The single most-important figure should score in [0.9, 1.0]. Reserve 1.0 for genuinely headline figures (architecture diagram or main-result figure when there's a clear single one); use 0.9-0.95 otherwise.
  - At most one figure may score ≥ 0.95, but multiple figures may score in 0.7-0.9 range.
  - Spread the next-most-important figures into 0.6-0.85 so the top-3 ordering is unambiguous (no ties at the boundary).
  - Figures that are decorative, repetitive, or not really part of the paper score ≤ 0.3.
```

- [ ] **Step 2: 没有相应的 bats 测试需要改**(quality bar 是 prompt 文档里的一段,不是 grep 断言)。但确认现有的 bats 还过:

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```
预期通过(现有的断言只检查 `## Role` / `## Inputs` / `## Output` / `## Instructions` 章节存在)。

- [ ] **Step 3: Commit**

```bash
git add paper-deepstudy/prompts/figure-interpreter.md
git commit -m "fix(paper-deepstudy): figure-interpreter quality bar — describe importance ranges for downstream selection"
```

---

### Task 7: review-writer merge tag 格式

**Files:**
- Modify: `paper-deepstudy/prompts/review-writer.md`

Live test phase 5 发现:review-writer 在合并新旧 entry 时产出 `← from rounds initial analysis, 1` —— 把字符串 tag「initial analysis」和数字「1」混在一起,语义模糊。

修复:在 review-writer 的 prompt 里指定准确格式,让 merge 输出更整齐。

- [ ] **Step 1: 改 review-writer.md 的 Instructions 第 4 步**

读 `paper-deepstudy/prompts/review-writer.md`。当前第 4 条 dedup/merge 指令大致是:

```
4. **Dedup/merge check.** Read the target section's existing bullets. If any existing bullet is *substantively about the same issue* as your new draft (defined as: same dimension AND same root cause), do NOT append. Instead:
   - Merge: rewrite the existing bullet to encompass both rounds. End with `← from rounds <prior N>, <new N>`.
   - The merged bullet should be no more than 1 sentence longer than either input.
   - If you merge, the snippet you return is the *merged* bullet (not the original).
```

把这一条改为:

```
4. **Dedup/merge check.** Read the target section's existing bullets. If any existing bullet is *substantively about the same issue* as your new draft (defined as: same dimension AND same root cause), do NOT append. Instead:
   - Merge: rewrite the existing bullet to encompass both rounds.
   - The merged bullet should be no more than 1 sentence longer than either input.
   - End with a unified traceability tag according to these rules:
     - If the existing bullet ends with `← from initial analysis`: change to `← from initial analysis, round <new N>`.
     - If the existing bullet ends with `← from round <prior N>`: change to `← from rounds <prior N>, <new N>`.
     - If the existing bullet ends with `← from rounds <list>`: append the new round number to the comma-separated list, e.g. `← from rounds 1, 3, <new N>`.
     - **Never** mix the literal string "initial analysis" with bare round numbers in the same `rounds` list — keep "initial analysis" as a separate clause.
   - If you merge, the snippet you return is the *merged* bullet (not the original).
```

- [ ] **Step 2: 没有 bats 测试需要改**(prompt 文件结构未变)。运行现有测试确认无 regression:

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```
预期通过。

- [ ] **Step 3: Commit**

```bash
git add paper-deepstudy/prompts/review-writer.md
git commit -m "fix(paper-deepstudy): review-writer — explicit merge-tag format rules to avoid mixed string/integer round lists"
```

---

### Task 8: 给所有 SKILL.md 的 chat-facing-language 约束加 bats 断言

**Files:**
- Modify: `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

每个 SKILL.md 都说「show user (in user's invocation language)」或类似 —— 但当前没有断言确保这条规则真的写在文档里。Live test 中如果 sub-Agent 不遵守,可能会用错语言。加 bats 断言,让 review 能 catch 缺失。

- [ ] **Step 1: Append failing tests**

把这些断言追加到 `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "study-deep SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/study-deep/SKILL.md
}

@test "review-round SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/review-round/SKILL.md
}

@test "refine-notes SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/refine-notes/SKILL.md
}

@test "retitle SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/retitle/SKILL.md
}

@test "reselect-figures SKILL.md mentions user's invocation language for chat-facing prose" {
  grep -qF "user's invocation language" skills/reselect-figures/SKILL.md
}
```

- [ ] **Step 2: Run, identify which SKILL.md are missing the phrase**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```

每个失败的 @test 对应的 SKILL.md 都需要补这句话。从 live test 的观察看,五个 SKILL.md 大多已经包含「(in user's invocation language)」或类似 —— 检查每一个,补缺。

- [ ] **Step 3: 给缺少的 SKILL.md 补「user's invocation language」一句**

对每个未通过断言的 SKILL.md,在它的 `## Notes` 或 `Stage X` (用户交互处) 章节加一句:

```
- **Translation:** All chat-facing prose (prompts to user, summary) is rendered in the user's invocation language. Internal artifact content stays per the spec §8 language matrix.
```

如果该 SKILL.md 已经有「Translation」段落,扩充它包含「user's invocation language」字样即可。

- [ ] **Step 4: Run, verify pass**

```bash
bats paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
```
预期 5 个新断言全过。

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/*/SKILL.md paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "test(paper-deepstudy): assert each SKILL.md mentions user's invocation language for chat-facing prose"
```

---

## Self-Review checklist (Plan 5 完成后跑一遍)

- [ ] `cd paper-deepstudy && npm run test:unit` 通过(bats + 4 个 node 测试 = `select-figures` + `next-round-number` + `parse-judge-output` + `slugify-objection`)。
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` 通过,新加的 helper 在 check 列表里。
- [ ] `study-deep` SKILL.md 有 `## Flag dispatch` 章节,涵盖 `--only` / `--paper` / `--yes` / `--force` 四个旗标。
- [ ] `review-round` SKILL.md 引用了 `parse-judge-output.cjs` 和 `slugify-objection.cjs`。
- [ ] README 的 roadmap 给所有已发布的 plan 都标了 ✓。
- [ ] `commands/reselect-figures.md` 不再含 "when wired in" 这句。
- [ ] 8 个 commit,顺序正确,无 Claude co-author。
- [ ] 所有 5 个 SKILL.md 都明确提到 "user's invocation language"。

如果任意一条不通过,补一个 follow-up commit。

---

## 完成 Plan 5 后 main 上的状态变化

新增文件:
- `paper-deepstudy/scripts/parse-judge-output.cjs`
- `paper-deepstudy/scripts/slugify-objection.cjs`
- `paper-deepstudy/tests/unit/test-parse-judge-output.cjs`
- `paper-deepstudy/tests/unit/test-slugify-objection.cjs`
- `paper-deepstudy/tests/unit/test-idempotence-skip.bats`

修改文件:
- `paper-deepstudy/skills/study-deep/SKILL.md`(Stage 0.2 actionable + `## Flag dispatch` + idempotence wording 强化 + forward-ref 修正)
- `paper-deepstudy/skills/review-round/SKILL.md`(用 helper 替换散文 + chat-language 强化)
- `paper-deepstudy/skills/refine-notes/SKILL.md`(chat-language 强化)
- `paper-deepstudy/skills/retitle/SKILL.md`(chat-language 强化)
- `paper-deepstudy/skills/reselect-figures/SKILL.md`(chat-language 强化)
- `paper-deepstudy/prompts/figure-interpreter.md`(quality bar 收紧)
- `paper-deepstudy/prompts/review-writer.md`(merge tag 格式规范化)
- `paper-deepstudy/commands/reselect-figures.md`("when wired in" awkward phrase 修)
- `paper-deepstudy/README.md`(Plan 1 ✓ marker)
- `paper-deepstudy/package.json`(test:unit 加两个 node test)
- `paper-deepstudy/tests/integration/test-end-to-end.sh`(check 两个新 helper)
- `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`(多组新断言)

测试数变化:
- 当前 84 bats + 2 node + integration smoke
- Plan 5 完成后:~95+ bats(Task 1+2+3+8 各加几条)+ 4 node + integration smoke

预计工作量:8 个 commit,大部分是文档/测试修改 + 2 个新 helper。一个会话内就能跑完,subagent-driven 模式下每 task ~3-5 分钟。
