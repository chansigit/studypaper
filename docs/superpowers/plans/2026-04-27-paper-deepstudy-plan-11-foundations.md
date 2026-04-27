# paper-deepstudy Plan 11: Phase A — Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase A 基础设施 —— 给整个 plugin 注入 observability(provenance + 本地 dispatch log)+ 抽出 cross-skill 重复的 paper-resolve 逻辑到一个共享 helper。这是 reviewer 推荐的最高 ROI 工作,也为 Phase B(behavioral testing)和 Phase C(robustness)提供必要前置。

**Architecture:** 一个新的 `scripts/lib/` 目录承载共享 bash helper(`resolve-paper.sh` + `log-dispatch.sh`),9 个 skill 改用 helper 替代 inline 重复;每个 sub-Agent 产物头部加 HTML 注释 provenance line(无 schema 改动);加 `count-tests.sh` + 修 README badge drift。

**Tech Stack:** Bash 4+(macOS 自带 3.x 也能用,要避 bash 4 only 特性)+ Bats + Node。无新外部依赖。

**Phase A 之后的边界:** 不动任何 sub-Agent 的语义、不引入新功能、不改输出格式(YAML schema 不变)。所有 Phase A 改动都是 *additive* —— 旧的 paper folder 重新跑也兼容。

**任务条目:**

| # | Task | Theme | Effort |
|---|---|---|---|
| 1 | 抽 `scripts/lib/resolve-paper.sh`(纯 helper + bats) | T3 | 1h |
| 2 | 9 个 skill 改用 helper(替代 inline auto-detect) | T3 | 1.5h |
| 3 | `scripts/lib/log-dispatch.sh`(运行日志 helper + bats) | T4 | 1h |
| 4 | 9 个 skill wire dispatch 后调 `log_dispatch`(study-deep 6 处、其它 1-2 处) | T4 | 1.5h |
| 5 | 16 个 sub-Agent prompt + 16 个 template + 1 个 skill 加 provenance HTML 注释 directive | T4 | 1.5h |
| 6 | `scripts/count-tests.sh` + README badge 修 drift | meta | 0.5h |

6 task,每 task 一个 commit。预期总实施时间 ~7 小时(单人 + 一天)。

---

## File Structure

```
paper-deepstudy/
├── scripts/
│   ├── lib/                                   (NEW directory)
│   │   ├── resolve-paper.sh                   (NEW — Task 1)
│   │   └── log-dispatch.sh                    (NEW — Task 3)
│   └── count-tests.sh                         (NEW — Task 6)
├── skills/
│   ├── study-deep/SKILL.md                    (modified — Tasks 2, 4)
│   ├── refine-notes/SKILL.md                  (modified — Tasks 2, 4)
│   ├── retitle/SKILL.md                       (modified — Tasks 2, 4)
│   ├── reselect-figures/SKILL.md              (modified — Tasks 2, 4)
│   ├── review-round/SKILL.md                  (modified — Tasks 2, 4, 5*)
│   ├── deep-dive/SKILL.md                     (modified — Tasks 2, 4)
│   ├── compare/SKILL.md                       (modified — Tasks 2, 4)
│   ├── add-prior-work/SKILL.md                (modified — Tasks 2, 4)
│   └── reproduce-check/SKILL.md               (modified — Tasks 2, 4)
├── prompts/                                   (16 files modified — Task 5)
│   ├── paper-profiler.md
│   ├── problem-framer.md
│   ├── formalizer.md
│   ├── method-analyst.md
│   ├── experiment-critic.md
│   ├── prior-work-historian.md
│   ├── figure-interpreter.md
│   ├── reviewer-synthesizer.md
│   ├── review-writer.md
│   ├── notes-writer.md
│   ├── title-generator.md
│   ├── xhs-renderer.md
│   ├── wechat-renderer.md
│   ├── deep-dive-agent.md
│   ├── compare-agent.md
│   └── reproduce-checker.md
├── templates/                                 (16 files modified — Task 5)
│   ├── analysis/{00-paper-profile,01-problem,02-formalization,03-method-deep,04-experiments,05-prior-work,06-figures}.md
│   ├── review.md
│   ├── review-round.md
│   ├── deep-dive.md
│   ├── compare.md
│   ├── reproduce-check.md
│   └── notes/{source,titles,xhs,wechat}.md
└── tests/
    ├── unit/
    │   ├── test-resolve-paper.bats            (NEW — Task 1)
    │   ├── test-log-dispatch.bats             (NEW — Task 3)
    │   ├── test-count-tests.bats              (NEW — Task 6)
    │   └── test-prompts-have-required-sections.bats   (modified — Tasks 2, 4, 5, 6)
    └── fixtures/
        └── mock-papers/                       (NEW — Task 1)
            ├── alpha/.placeholder
            ├── beta/.placeholder
            └── gamma/.placeholder

README.md                                       (modified — Task 6, badge fix)
```

\* review-round 的 SKILL.md 编排 round-NN-*.md 文件,所以 Task 5 也加它的 provenance(不止 prompt 写文件;有些文件由 skill 拼装)。

---

## Pre-flight

Branch `feat/plan-11-foundations` 已从 post-Plan-10 main(daf1d85)长出。`cd paper-deepstudy && npm run test:unit` 通过(160 bats + 4 node + integration smoke pass)。

Plan 11 的所有 helper 都用 POSIX-compatible bash,在 macOS BSD bash 3.2 上能跑。所有 helper 用 `set -euo pipefail` 但要小心 `set -u` 与 sourcing 互动;helper 内部用 `${VAR:-}` 防 unbound。

**Helper 的运行模型:** skill SKILL.md 里的 bash code block 由 orchestrator(LLM)在一个连续 bash session 中执行,变量在 block 之间持续。所以 `source helper.sh` 后定义的函数和导出的变量在后续 block 可用。这是现状(study-deep 的 PAPER_DIR 跨多个 stage 的 bash block 共用,验证了这个模型)。

---

### Task 1: scripts/lib/resolve-paper.sh + bats

**Files:**
- Create: `paper-deepstudy/scripts/lib/resolve-paper.sh`
- Create: `paper-deepstudy/tests/fixtures/mock-papers/alpha/.placeholder`
- Create: `paper-deepstudy/tests/fixtures/mock-papers/beta/.placeholder`
- Create: `paper-deepstudy/tests/fixtures/mock-papers/gamma/.placeholder`
- Create: `paper-deepstudy/tests/unit/test-resolve-paper.bats`

**Helper 契约:**
- Sourceable bash file(`source resolve-paper.sh` 后函数 `resolve_paper` 可调用).
- `resolve_paper [--paper <slug>] [--papers-root <dir>]`.
- 设置 caller 可见的变量:`PAPER_SLUG`、`PAPER_DIR`、`PAPER_AUTODETECTED`(`true|false`).
- 默认 `--papers-root` 为 `${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}`.
- 行为:
  - `--paper foo` 显式给 → 取 `<root>/foo`,如不存在 stderr 报错并 `return 2`.
  - 无 `--paper`,目录非空 → 取 `ls -td <root>/*/ | head -1`,设 PAPER_AUTODETECTED=true,stderr 打印 `Warning: targeting <slug> (most recently modified). Pass --paper to override.`.
  - 无 `--paper`,目录空 → stderr 报错 `return 3`.
  - 自动剥 trailing slash.

- [ ] **Step 1: 创建 fixture 目录 + .placeholder 文件**

```bash
mkdir -p paper-deepstudy/tests/fixtures/mock-papers/{alpha,beta,gamma}
touch paper-deepstudy/tests/fixtures/mock-papers/{alpha,beta,gamma}/.placeholder
```

为了让 `ls -td` 排序确定,bats setup 里会 `touch -t YYYYMMDDHHMM` 改 mtime,详见 Step 4 测试代码。

- [ ] **Step 2: 写 failing bats 测试 `tests/unit/test-resolve-paper.bats`**

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  # Create a temp papers root for this test, populated from fixtures
  TEST_PAPERS_ROOT="$(mktemp -d)"
  cp -r tests/fixtures/mock-papers/. "$TEST_PAPERS_ROOT/"
  # Force deterministic mtime ordering: gamma newest, beta middle, alpha oldest
  touch -t 202001010000 "$TEST_PAPERS_ROOT/alpha"
  touch -t 202101010000 "$TEST_PAPERS_ROOT/beta"
  touch -t 202201010000 "$TEST_PAPERS_ROOT/gamma"
  export TEST_PAPERS_ROOT
}

teardown() {
  [ -n "$TEST_PAPERS_ROOT" ] && rm -rf "$TEST_PAPERS_ROOT"
}

@test "resolve_paper sets PAPER_DIR and PAPER_SLUG when --paper is given" {
  source scripts/lib/resolve-paper.sh
  resolve_paper --paper alpha --papers-root "$TEST_PAPERS_ROOT"
  [ "$PAPER_SLUG" = "alpha" ]
  [ "$PAPER_DIR" = "$TEST_PAPERS_ROOT/alpha" ]
  [ "$PAPER_AUTODETECTED" = "false" ]
}

@test "resolve_paper picks most recently modified when --paper is absent" {
  source scripts/lib/resolve-paper.sh
  resolve_paper --papers-root "$TEST_PAPERS_ROOT"
  [ "$PAPER_SLUG" = "gamma" ]
  [ "$PAPER_AUTODETECTED" = "true" ]
}

@test "resolve_paper warns to stderr on auto-detect" {
  source scripts/lib/resolve-paper.sh
  run bash -c "source scripts/lib/resolve-paper.sh && resolve_paper --papers-root '$TEST_PAPERS_ROOT' 2>&1 1>/dev/null"
  [[ "$output" == *"most recently modified"* ]]
  [[ "$output" == *"Pass --paper"* ]]
}

@test "resolve_paper does NOT warn when --paper is given" {
  source scripts/lib/resolve-paper.sh
  run bash -c "source scripts/lib/resolve-paper.sh && resolve_paper --paper alpha --papers-root '$TEST_PAPERS_ROOT' 2>&1 1>/dev/null"
  [[ "$output" != *"most recently modified"* ]]
}

@test "resolve_paper errors with exit 2 when --paper points to nonexistent slug" {
  source scripts/lib/resolve-paper.sh
  run resolve_paper --paper nonexistent --papers-root "$TEST_PAPERS_ROOT"
  [ "$status" -eq 2 ]
}

@test "resolve_paper errors with exit 3 when papers-root is empty" {
  source scripts/lib/resolve-paper.sh
  EMPTY_ROOT="$(mktemp -d)"
  run resolve_paper --papers-root "$EMPTY_ROOT"
  [ "$status" -eq 3 ]
  rm -rf "$EMPTY_ROOT"
}

@test "resolve_paper strips trailing slash from --paper" {
  source scripts/lib/resolve-paper.sh
  resolve_paper --paper "alpha/" --papers-root "$TEST_PAPERS_ROOT"
  [ "$PAPER_SLUG" = "alpha" ]
  [ "$PAPER_DIR" = "$TEST_PAPERS_ROOT/alpha" ]
}

@test "resolve_paper honors CLAUDE_PAPERS_ROOT env when --papers-root is absent" {
  source scripts/lib/resolve-paper.sh
  CLAUDE_PAPERS_ROOT="$TEST_PAPERS_ROOT" resolve_paper --paper beta
  [ "$PAPER_SLUG" = "beta" ]
}
```

- [ ] **Step 3: Verify fail**

```bash
cd paper-deepstudy && bats tests/unit/test-resolve-paper.bats
```

预期 8 fail(helper 还不存在)。

- [ ] **Step 4: 写 helper `paper-deepstudy/scripts/lib/resolve-paper.sh`**

```bash
#!/usr/bin/env bash
# scripts/lib/resolve-paper.sh — resolve which paper folder a skill should target.
#
# Source this file, then call:
#   resolve_paper [--paper <slug>] [--papers-root <dir>]
#
# After successful return, these vars are set in the calling shell:
#   PAPER_SLUG          — the slug (basename of paper folder)
#   PAPER_DIR           — absolute path to ~/claude-papers/papers/<slug>
#   PAPER_AUTODETECTED  — "true" if --paper was absent and we picked most-recent;
#                         "false" if --paper was explicit
#
# Exit codes (from `return`, since this is sourced):
#   0 — ok
#   2 — --paper points at a nonexistent slug
#   3 — no --paper and the papers-root is empty / nonexistent
#
# Default papers-root resolution order:
#   1. --papers-root flag (test override)
#   2. $CLAUDE_PAPERS_ROOT env var (test override)
#   3. $HOME/claude-papers/papers (production default)

resolve_paper() {
  local explicit_slug=""
  local papers_root="${CLAUDE_PAPERS_ROOT:-$HOME/claude-papers/papers}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --paper)
        explicit_slug="${2:-}"
        shift 2
        ;;
      --papers-root)
        papers_root="${2:-}"
        shift 2
        ;;
      *)
        # Unknown flag — leave for the caller to handle (e.g., --force, --yes)
        shift
        ;;
    esac
  done

  # Strip trailing slash from explicit_slug if present
  explicit_slug="${explicit_slug%/}"

  if [ -n "$explicit_slug" ]; then
    if [ ! -d "$papers_root/$explicit_slug" ]; then
      echo "Error: --paper '$explicit_slug' not found under $papers_root" >&2
      return 2
    fi
    PAPER_SLUG="$explicit_slug"
    PAPER_DIR="$papers_root/$explicit_slug"
    PAPER_AUTODETECTED="false"
    return 0
  fi

  # No --paper — auto-detect most-recently-modified
  if [ ! -d "$papers_root" ]; then
    echo "Error: papers root '$papers_root' does not exist" >&2
    return 3
  fi

  local recent
  recent="$(ls -td "$papers_root"/*/ 2>/dev/null | head -1)"
  if [ -z "$recent" ]; then
    echo "Error: no paper folders found under $papers_root" >&2
    return 3
  fi

  PAPER_DIR="${recent%/}"
  PAPER_SLUG="$(basename "$PAPER_DIR")"
  PAPER_AUTODETECTED="true"
  echo "Warning: targeting '$PAPER_SLUG' (most recently modified paper folder under $papers_root). Pass --paper <slug> to override." >&2
  return 0
}

# When sourced, do nothing; when executed directly, print help.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cat >&2 <<'EOF'
resolve-paper.sh — must be sourced, not executed directly.

Usage in a skill:
  source $PLUGIN_ROOT/scripts/lib/resolve-paper.sh
  resolve_paper [--paper <slug>] [--papers-root <dir>]
  # After success, $PAPER_SLUG, $PAPER_DIR, $PAPER_AUTODETECTED are set.
EOF
  exit 1
fi
```

`chmod +x` 不需要(sourced helper),但加上 shebang 方便 lint。

- [ ] **Step 5: Verify pass**

```bash
cd paper-deepstudy && bats tests/unit/test-resolve-paper.bats
```

预期 8/8 pass.

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/scripts/lib/resolve-paper.sh \
        paper-deepstudy/tests/fixtures/mock-papers/ \
        paper-deepstudy/tests/unit/test-resolve-paper.bats
git commit -m "feat(paper-deepstudy): scripts/lib/resolve-paper.sh helper with bats coverage (Plan 11 T1)"
```

---

### Task 2: 9 skills 改用 resolve-paper.sh

**Files:** 9 个 SKILL.md + `tests/unit/test-prompts-have-required-sections.bats`

每个 skill 当前都有一段类似:

```bash
# parse --paper flag
PAPER_FLAG_VALUE=""
... (10-15 行 case 解析)

if [ -z "$PAPER_FLAG_VALUE" ]; then
  PAPER_DIR=$(ls -td ~/claude-papers/papers/*/ 2>/dev/null | head -1 | sed 's:/$::')
  PAPER_SLUG=$(basename "$PAPER_DIR")
  echo "Warning: targeting ..."  # Plan 10 加的
else
  PAPER_DIR="$HOME/claude-papers/papers/${PAPER_FLAG_VALUE%/}"
  PAPER_SLUG="${PAPER_FLAG_VALUE%/}"
fi
```

替换成:

```bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
# After: $PAPER_DIR, $PAPER_SLUG, $PAPER_AUTODETECTED are set.
# If $PAPER_AUTODETECTED is "true", the helper already printed a warning to stderr.
```

**注意 study-deep 的特殊性:** `/paper:study` 第一次跑时 paper folder 还不存在(由 Stage 0.2 创建),所以 study-deep 的 helper 调用要在 Stage 0.4(post-Stage-0.2)之后,而不是 Stage 0.1。原来的 study-deep 已经是这样的顺序;只需把 Stage 0.4 的 inline auto-detect 替换成 helper 调用。

- [ ] **Step 1: Append failing tests** to `tests/unit/test-prompts-have-required-sections.bats`:

```bash
@test "all 9 skills source the resolve-paper helper instead of inline auto-detect" {
  for f in skills/study-deep/SKILL.md \
           skills/refine-notes/SKILL.md \
           skills/retitle/SKILL.md \
           skills/reselect-figures/SKILL.md \
           skills/review-round/SKILL.md \
           skills/deep-dive/SKILL.md \
           skills/compare/SKILL.md \
           skills/add-prior-work/SKILL.md \
           skills/reproduce-check/SKILL.md; do
    grep -qE 'scripts/lib/resolve-paper\.sh' "$f" || { echo "FAIL: $f does not source resolve-paper.sh"; return 1; }
    grep -qF 'resolve_paper' "$f" || { echo "FAIL: $f does not call resolve_paper"; return 1; }
  done
}

@test "no skill still has inline ls -td papers auto-detect (post-Plan-11)" {
  # After Plan 11, only the helper has this idiom; skills delegate.
  for f in skills/refine-notes/SKILL.md \
           skills/retitle/SKILL.md \
           skills/reselect-figures/SKILL.md \
           skills/review-round/SKILL.md \
           skills/deep-dive/SKILL.md \
           skills/compare/SKILL.md \
           skills/add-prior-work/SKILL.md \
           skills/reproduce-check/SKILL.md; do
    if grep -qE 'ls -td.*claude-papers/papers/\*' "$f"; then
      echo "FAIL: $f still has inline auto-detect"
      return 1
    fi
  done
  # study-deep gets a free pass — its Stage 0.2 wraps claude-paper:study and may
  # need a different paper-folder discovery mechanism (most-recently-MODIFIED is
  # how it picks the freshly-created folder). Leave that as-is.
}

@test "Plan-10 'most recently modified' assertion now lives in helper, not skills" {
  grep -qF 'most recently modified' scripts/lib/resolve-paper.sh
}
```

**Important:** delete or update the existing `@test "skills with most-recent-paper auto-detect warn the user"` test from Plan 10 — after refactor, the warning string lives in the helper, not the skill files. Keep the test but rewrite it to assert the helper has the warning (which the new test above already covers; the old test should be DELETED to avoid duplication).

- [ ] **Step 2: Verify fail** — the new tests should fail (skills don't source the helper yet).

- [ ] **Step 3: Edit each of the 9 skills**

For each skill in the list above, locate the auto-detect block (look for `ls -td` / `--paper` parsing / `Warning: targeting`) and replace with:

```markdown
**Resolve target paper folder**

Source the shared helper and resolve which paper folder this invocation targets:

\`\`\`bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
# After: $PAPER_DIR, $PAPER_SLUG, $PAPER_AUTODETECTED are set.
# If $PAPER_AUTODETECTED is "true", the helper already printed a warning to stderr.
\`\`\`

If `resolve_paper` returns non-zero, abort with the helper's stderr message.
```

**study-deep specifically:** the paper folder is created by `claude-paper:study` in Stage 0.2 with a slug it derives from the title. After Stage 0.2, study-deep needs to find that newly-created folder. That's a "discover the most-recently-modified folder" pattern that the helper covers, but with a subtle difference: at this point we haven't seen the slug yet, so `--paper` cannot be passed. Use the helper in auto-detect mode AFTER Stage 0.2 succeeds. For `/paper:rerun-stage`, the helper is called with whatever flags came in. Both paths reuse the same helper.

Concretely, in `study-deep/SKILL.md` Stage 0.4, replace the inline `PAPER_DIR=$(ls -td ...)` with:

```markdown
\`\`\`bash
source $CLAUDE_PLUGIN_ROOT/scripts/lib/resolve-paper.sh
resolve_paper "$@"
\`\`\`
```

For Stage 0.2's post-claude-paper-study folder discovery (where we don't yet have a slug to pass), the same helper works because `resolve_paper` with no flags picks most-recently-modified — which is exactly what we want immediately after `claude-paper:study` finished creating the new folder.

- [ ] **Step 4: Verify pass** — all 3 new tests + existing 160 tests pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/skills/*/SKILL.md \
        paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "refactor(paper-deepstudy): 9 skills delegate paper-folder resolution to scripts/lib/resolve-paper.sh (Plan 11 T2)"
```

---

### Task 3: scripts/lib/log-dispatch.sh + bats

**Files:**
- Create: `paper-deepstudy/scripts/lib/log-dispatch.sh`
- Create: `paper-deepstudy/tests/unit/test-log-dispatch.bats`

**Helper 契约:**
- Sourceable bash file. After source, function `log_dispatch` is callable.
- `log_dispatch <subagent> <output_path> <status> [duration_ms]`.
- Appends one JSONL line to `$PAPER_DIR/.deepstudy/run.jsonl`.
- Schema:

```json
{
  "ts": "2026-04-27T12:34:56Z",
  "subagent": "reviewer-synthesizer",
  "output": "review.md",
  "status": "ok",
  "duration_ms": 18430,
  "plugin_version": "0.1.0"
}
```

  - `ts`: ISO8601 UTC, second precision.
  - `subagent`: string, no escaping needed (controlled inputs).
  - `output`: paper-folder-relative path.
  - `status`: `ok | failed | skipped`.
  - `duration_ms`: optional integer; omitted if not provided.
  - `plugin_version`: read from `$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json` via `grep -m1 '"version"'`.

- **Opt-out:** if `PAPER_DEEPSTUDY_NO_RUN_LOG=1`, skip silently (return 0).
- **Robustness:** if `$PAPER_DIR` doesn't exist or write fails, fail silently — must NEVER break the caller.
- **Privacy:** the log records ONLY metadata (subagent name, output filename, status). NO paper content, NO user input. The whole file is local to `$PAPER_DIR/.deepstudy/run.jsonl` — nothing phones home.

- [ ] **Step 1: 写 failing bats `tests/unit/test-log-dispatch.bats`**

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  TEST_PAPER_DIR="$(mktemp -d)"
  export TEST_PAPER_DIR
  # Mock plugin manifest so log-dispatch can read version
  export CLAUDE_PLUGIN_ROOT="$BATS_TEST_DIRNAME/../.."
}

teardown() {
  [ -n "$TEST_PAPER_DIR" ] && rm -rf "$TEST_PAPER_DIR"
}

@test "log_dispatch writes one JSONL line to .deepstudy/run.jsonl" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch reviewer-synthesizer review.md ok
  [ -f "$TEST_PAPER_DIR/.deepstudy/run.jsonl" ]
  line_count=$(wc -l < "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  [ "$line_count" -eq 1 ]
}

@test "log_dispatch JSONL line has required fields" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch reviewer-synthesizer review.md ok 1234
  line=$(cat "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  [[ "$line" == *'"ts":'* ]]
  [[ "$line" == *'"subagent":"reviewer-synthesizer"'* ]]
  [[ "$line" == *'"output":"review.md"'* ]]
  [[ "$line" == *'"status":"ok"'* ]]
  [[ "$line" == *'"duration_ms":1234'* ]]
  [[ "$line" == *'"plugin_version":'* ]]
}

@test "log_dispatch is JSON-valid (parseable by node)" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch reviewer-synthesizer review.md ok
  node -e "JSON.parse(require('fs').readFileSync('$TEST_PAPER_DIR/.deepstudy/run.jsonl','utf8').trim())"
}

@test "log_dispatch creates .deepstudy dir if missing" {
  source scripts/lib/log-dispatch.sh
  [ ! -d "$TEST_PAPER_DIR/.deepstudy" ]
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo bar ok
  [ -d "$TEST_PAPER_DIR/.deepstudy" ]
}

@test "log_dispatch appends, not overwrites, on second call" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo a.md ok
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch bar b.md failed
  line_count=$(wc -l < "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  [ "$line_count" -eq 2 ]
}

@test "log_dispatch skips silently when PAPER_DEEPSTUDY_NO_RUN_LOG=1" {
  source scripts/lib/log-dispatch.sh
  PAPER_DEEPSTUDY_NO_RUN_LOG=1 PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo a.md ok
  [ ! -f "$TEST_PAPER_DIR/.deepstudy/run.jsonl" ]
}

@test "log_dispatch never errors when PAPER_DIR is unset" {
  source scripts/lib/log-dispatch.sh
  unset PAPER_DIR
  run log_dispatch foo bar ok
  [ "$status" -eq 0 ]
}

@test "log_dispatch never errors when output dir is unwritable" {
  source scripts/lib/log-dispatch.sh
  chmod -w "$TEST_PAPER_DIR"
  run bash -c "source scripts/lib/log-dispatch.sh && PAPER_DIR='$TEST_PAPER_DIR' log_dispatch foo bar ok"
  chmod +w "$TEST_PAPER_DIR"
  [ "$status" -eq 0 ]
}

@test "log_dispatch ts is ISO8601 UTC second-precision" {
  source scripts/lib/log-dispatch.sh
  PAPER_DIR="$TEST_PAPER_DIR" log_dispatch foo a.md ok
  line=$(cat "$TEST_PAPER_DIR/.deepstudy/run.jsonl")
  ts=$(echo "$line" | sed -nE 's/.*"ts":"([^"]+)".*/\1/p')
  # Pattern: YYYY-MM-DDTHH:MM:SSZ
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
```

- [ ] **Step 2: Verify fail.**

- [ ] **Step 3: 写 helper `paper-deepstudy/scripts/lib/log-dispatch.sh`**

```bash
#!/usr/bin/env bash
# scripts/lib/log-dispatch.sh — append a single JSONL line per sub-Agent dispatch.
#
# Usage:
#   source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
#   log_dispatch <subagent> <output_path> <status> [duration_ms]
#
# Behavior:
#   - Appends one JSONL line to $PAPER_DIR/.deepstudy/run.jsonl
#   - Returns 0 silently on any failure (must never break the caller)
#   - Skips writing if $PAPER_DEEPSTUDY_NO_RUN_LOG is "1"
#   - Auto-creates the .deepstudy/ subdirectory
#
# Schema:
#   {"ts":"<iso8601-utc>","subagent":"...","output":"...","status":"ok|failed|skipped",
#    "duration_ms":<int-or-null>,"plugin_version":"..."}
#
# Privacy:
#   Records ONLY metadata (subagent name, output filename, status).
#   No paper content, no user input, no chat history.

log_dispatch() {
  # Honor opt-out
  if [ "${PAPER_DEEPSTUDY_NO_RUN_LOG:-0}" = "1" ]; then
    return 0
  fi

  # Required env / args
  local paper_dir="${PAPER_DIR:-}"
  if [ -z "$paper_dir" ] || [ ! -d "$paper_dir" ]; then
    return 0  # silent — never break caller
  fi

  local subagent="${1:-unknown}"
  local output="${2:-}"
  local status="${3:-ok}"
  local duration_ms="${4:-}"

  # Compose plugin_version from manifest, fallback "?"
  local plugin_version="?"
  local manifest="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
  if [ -f "$manifest" ]; then
    plugin_version=$(grep -m1 '"version"' "$manifest" 2>/dev/null \
      | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/' || echo "?")
  fi

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Compose JSONL line. duration_ms is omitted (not null) if absent.
  local line
  if [ -n "$duration_ms" ]; then
    line=$(printf '{"ts":"%s","subagent":"%s","output":"%s","status":"%s","duration_ms":%s,"plugin_version":"%s"}' \
      "$ts" "$subagent" "$output" "$status" "$duration_ms" "$plugin_version")
  else
    line=$(printf '{"ts":"%s","subagent":"%s","output":"%s","status":"%s","plugin_version":"%s"}' \
      "$ts" "$subagent" "$output" "$status" "$plugin_version")
  fi

  # Ensure .deepstudy dir exists; ignore mkdir failure (caller will get nothing logged)
  mkdir -p "$paper_dir/.deepstudy" 2>/dev/null || return 0

  # Append; ignore append failure
  echo "$line" >> "$paper_dir/.deepstudy/run.jsonl" 2>/dev/null || return 0

  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cat >&2 <<'EOF'
log-dispatch.sh — must be sourced, not executed directly.

Usage in a skill:
  source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
  log_dispatch <subagent> <output_path> <status> [duration_ms]
EOF
  exit 1
fi
```

- [ ] **Step 4: Verify pass** — 9/9 bats tests pass.

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/scripts/lib/log-dispatch.sh \
        paper-deepstudy/tests/unit/test-log-dispatch.bats
git commit -m "feat(paper-deepstudy): scripts/lib/log-dispatch.sh + bats coverage (Plan 11 T3)"
```

---

### Task 4: Wire all dispatching skills to call log_dispatch

**Files:** 9 SKILL.md + `tests/unit/test-prompts-have-required-sections.bats`

每个 skill 在 dispatch sub-Agent 后(或 dispatch 失败的错误路径)调一次 `log_dispatch <subagent> <output_path> <status>`。

**Dispatch sites 清单:**

- `study-deep/SKILL.md`:
  - Stage 0.4: `paper-profiler` → `analysis/00-paper-profile.md`
  - Stage 1.x(parallel): `problem-framer`, `formalizer`, `method-analyst`, `experiment-critic`, `prior-work-historian`, `figure-interpreter` → 6 个 analysis files
  - Stage 2: `reviewer-synthesizer` → `review.md`
  - Stage 3: `notes-writer`, `title-generator`, `xhs-renderer`, `wechat-renderer` → 4 个 notes files
  - 总计 11 个 dispatch site
- `review-round/SKILL.md`: `defense-agent`, `judge-agent`, `review-writer` → 3 个 dispatch
- `deep-dive/SKILL.md`: `deep-dive-agent` → 1
- `compare/SKILL.md`: `compare-agent` → 1
- `add-prior-work/SKILL.md`: `prior-work-historian` (augmentation) → 1
- `reproduce-check/SKILL.md`: `reproduce-checker` → 1
- `refine-notes/SKILL.md`: `xhs-renderer` 或 `wechat-renderer` → 1
- `retitle/SKILL.md`: `title-generator` → 1
- `reselect-figures/SKILL.md`: `xhs-renderer` + `wechat-renderer`(re-render) → 2

总共约 22 个 dispatch site。每个 site 加 3 行:source helper、调 `log_dispatch`、参数对齐。

**Wiring template** — 每个 dispatch 后插入:

```bash
# After Agent(...) returns, log the dispatch:
source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh
log_dispatch <subagent-name> <output-relative-to-paper-dir> ok
```

如果 dispatch 失败(orchestrator 检测到 FAILED 或 timeout):

```bash
log_dispatch <subagent-name> <output-relative-to-paper-dir> failed
```

`source` 只需在 skill 第一次调用前 source 一次;后续 dispatch 复用同一 session 的函数。所以实操上把 source 放在 skill 顶部 setup,各 dispatch 只调 `log_dispatch`。

- [ ] **Step 1: Append failing tests**

```bash
@test "all dispatching skills source the log-dispatch helper" {
  for f in skills/study-deep/SKILL.md \
           skills/review-round/SKILL.md \
           skills/deep-dive/SKILL.md \
           skills/compare/SKILL.md \
           skills/add-prior-work/SKILL.md \
           skills/reproduce-check/SKILL.md \
           skills/refine-notes/SKILL.md \
           skills/retitle/SKILL.md \
           skills/reselect-figures/SKILL.md; do
    grep -qE 'scripts/lib/log-dispatch\.sh' "$f" || { echo "FAIL: $f does not source log-dispatch.sh"; return 1; }
    grep -qF 'log_dispatch' "$f" || { echo "FAIL: $f does not call log_dispatch"; return 1; }
  done
}

@test "study-deep logs dispatch for all 11 stage sub-Agents" {
  # study-deep dispatches: paper-profiler, problem-framer, formalizer, method-analyst,
  # experiment-critic, prior-work-historian, figure-interpreter, reviewer-synthesizer,
  # notes-writer, title-generator, xhs-renderer, wechat-renderer (12 total)
  for agent in paper-profiler problem-framer formalizer method-analyst \
               experiment-critic prior-work-historian figure-interpreter \
               reviewer-synthesizer notes-writer title-generator xhs-renderer \
               wechat-renderer; do
    grep -qE "log_dispatch[[:space:]]+$agent" skills/study-deep/SKILL.md \
      || { echo "FAIL: study-deep missing log_dispatch for $agent"; return 1; }
  done
}

@test "PAPER_DEEPSTUDY_NO_RUN_LOG documented in at least one user-facing place" {
  # Document the opt-out env var so users know how to disable logging
  grep -q 'PAPER_DEEPSTUDY_NO_RUN_LOG' README.md \
    || grep -q 'PAPER_DEEPSTUDY_NO_RUN_LOG' paper-deepstudy/README.md
}
```

- [ ] **Step 2: Verify fail.**

- [ ] **Step 3: Edit each of the 9 skills** — add `source $CLAUDE_PLUGIN_ROOT/scripts/lib/log-dispatch.sh` near the top of the bash setup, then add `log_dispatch <agent> <output> <status>` after each Agent dispatch.

For `study-deep`, this means 12 `log_dispatch` calls (one per dispatched sub-Agent). For each, the `<output>` is the relative path to the file the sub-Agent wrote (e.g., `analysis/00-paper-profile.md`). Use the actual filenames already specified in the dispatch table (Stage 0.4, Stage 1, Stage 2, Stage 3 sections).

For each skill, after the Agent dispatch returns, the inline bash should look like:

```markdown
After the Agent returns, log the dispatch:

\`\`\`bash
log_dispatch reviewer-synthesizer review.md ok
\`\`\`

If the orchestrator detected the agent produced a FAILED placeholder or timed out:

\`\`\`bash
log_dispatch reviewer-synthesizer review.md failed
\`\`\`
```

(Adapt the agent name and output path per dispatch site.)

- [ ] **Step 4: Document the opt-out env var**

In `paper-deepstudy/README.md` Troubleshooting section (or a new "Privacy" subsection), add:

```markdown
### Disabling the per-paper run log

`paper-deepstudy` writes a one-line-per-dispatch JSONL log at `~/claude-papers/papers/<slug>/.deepstudy/run.jsonl` to help debug bad outputs. The log contains only metadata (sub-Agent names, output filenames, timestamps, status) — never paper content or user input — and is purely local to your filesystem. To disable:

\`\`\`bash
export PAPER_DEEPSTUDY_NO_RUN_LOG=1
\`\`\`
```

- [ ] **Step 5: Verify pass.**

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/skills/*/SKILL.md \
        paper-deepstudy/README.md \
        paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): wire 9 skills to log dispatches via log-dispatch.sh + document opt-out (Plan 11 T4)"
```

---

### Task 5: Provenance HTML 注释 — 16 prompts + 16 templates + review-round skill

**Files:**
- 16 prompts under `paper-deepstudy/prompts/`
- 16 templates under `paper-deepstudy/templates/`
- 1 skill: `paper-deepstudy/skills/review-round/SKILL.md`(round-NN file 由 skill 拼装)
- `paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats`

**Provenance line format:**

```html
<!-- generated: 2026-04-27T12:34:56Z by reviewer-synthesizer (paper-deepstudy v0.1.0) -->
```

放在文件最顶部,**在 YAML frontmatter 之前**(HTML 注释对 YAML 解析无影响,因为 frontmatter 解析器查找第一个 `---`,前面的注释被忽略)。无 frontmatter 的 markdown 文件就直接放最顶部。

**Prompts that produce files (16):**

| Prompt | Output file |
|---|---|
| paper-profiler.md | `analysis/00-paper-profile.md` |
| problem-framer.md | `analysis/01-problem.md` |
| formalizer.md | `analysis/02-formalization.md` |
| method-analyst.md | `analysis/03-method-deep.md` |
| experiment-critic.md | `analysis/04-experiments.md` |
| prior-work-historian.md | `analysis/05-prior-work.md` |
| figure-interpreter.md | `analysis/06-figures.md` |
| reviewer-synthesizer.md | `review.md` |
| review-writer.md | `review.md`(edits) |
| notes-writer.md | `notes/source.md` |
| title-generator.md | `notes/titles.md` |
| xhs-renderer.md | `notes/xhs.md` |
| wechat-renderer.md | `notes/wechat.md` |
| deep-dive-agent.md | `deep-dives/<topic>.md` |
| compare-agent.md | `compares/vs-<other>.md` |
| reproduce-checker.md | `reproduce-check.md` |

每个 prompt 的 Output 段加:

```markdown
**Generated-by header (REQUIRED):** at the very top of OUTPUT_PATH, BEFORE any YAML frontmatter or content, write a single HTML comment line:

\`\`\`html
<!-- generated: <runtime-iso8601-utc> by <subagent-name> (paper-deepstudy v<plugin-version>) -->
\`\`\`

- Use the runtime ISO8601 UTC timestamp at the moment of writing.
- `<subagent-name>` is your role (e.g., `reviewer-synthesizer`).
- `<plugin-version>` is the value the orchestrator passed in as `PLUGIN_VERSION`. If absent, write `?`.
- This header is inert (HTML comment) and does NOT affect YAML frontmatter parsing.
- Do NOT fabricate the date. If you cannot determine it, leave the placeholder `<runtime-timestamp>` and the orchestrator will substitute it.
```

每个 template 的最顶部加:

```html
<!-- generated: <runtime-timestamp> by <subagent-name> (paper-deepstudy v<plugin-version>) -->
```

**review-writer 特殊** —— 它 *修改* `review.md` 而非新建。directive:

```markdown
**Provenance refresh:** when you edit `review.md`, update the existing `<!-- generated: ... -->` header at the top. Append your role (e.g., `<!-- generated: <ts> by reviewer-synthesizer; edited <ts> by review-writer (paper-deepstudy v0.1.0) -->`) so the audit trail records both authors. If no provenance comment exists (legacy file), prepend a fresh one.
```

**review-round skill**(round-NN-*.md 由 skill 拼接,不是 sub-Agent):
SKILL.md 写文件那段加 provenance line。这个文件没有 sub-Agent 作者,所以 author 写 `review-round-orchestrator`。

- [ ] **Step 1: Append failing tests**

```bash
@test "all 16 sub-Agent prompts mandate provenance HTML comment" {
  for f in prompts/paper-profiler.md \
           prompts/problem-framer.md \
           prompts/formalizer.md \
           prompts/method-analyst.md \
           prompts/experiment-critic.md \
           prompts/prior-work-historian.md \
           prompts/figure-interpreter.md \
           prompts/reviewer-synthesizer.md \
           prompts/review-writer.md \
           prompts/notes-writer.md \
           prompts/title-generator.md \
           prompts/xhs-renderer.md \
           prompts/wechat-renderer.md \
           prompts/deep-dive-agent.md \
           prompts/compare-agent.md \
           prompts/reproduce-checker.md; do
    grep -qF 'Generated-by header' "$f" \
      || grep -qF '<!-- generated:' "$f" \
      || { echo "FAIL: $f missing provenance directive"; return 1; }
  done
}

@test "all 16 templates have a provenance HTML comment placeholder" {
  for f in templates/analysis/00-paper-profile.md \
           templates/analysis/01-problem.md \
           templates/analysis/02-formalization.md \
           templates/analysis/03-method-deep.md \
           templates/analysis/04-experiments.md \
           templates/analysis/05-prior-work.md \
           templates/analysis/06-figures.md \
           templates/review.md \
           templates/review-round.md \
           templates/deep-dive.md \
           templates/compare.md \
           templates/reproduce-check.md \
           templates/notes/source.md \
           templates/notes/titles.md \
           templates/notes/xhs.md \
           templates/notes/wechat.md; do
    head -1 "$f" | grep -qE '^<!-- generated:' \
      || { echo "FAIL: $f missing provenance line on line 1"; return 1; }
  done
}

@test "review-round SKILL writes provenance line into round-NN file" {
  grep -qF '<!-- generated:' skills/review-round/SKILL.md
  grep -qF 'review-round-orchestrator' skills/review-round/SKILL.md
}
```

- [ ] **Step 2: Verify fail.**

- [ ] **Step 3: Edit 16 prompts** — for each, add the "Generated-by header" directive at the bottom of the Output / Instructions section.

- [ ] **Step 4: Edit 16 templates** — prepend the HTML comment line as line 1 of each file. Existing content stays as-is (frontmatter, headings, body).

- [ ] **Step 5: Edit review-round SKILL.md** — find the section that composes round-NN-*.md content; add the provenance line as the first line of the composed file.

- [ ] **Step 6: Update study-deep dispatch templates to pass PLUGIN_VERSION**

In `study-deep/SKILL.md`(and similarly for other dispatching skills), the Agent inputs need a `PLUGIN_VERSION` value so the sub-Agent can fill in the placeholder. Add:

```bash
PLUGIN_VERSION=$(grep -m1 '"version"' $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json | sed -E 's/.*"version"[^"]*"([^"]+)".*/\1/')
```

near the top of the orchestration setup, then pass `PLUGIN_VERSION=$PLUGIN_VERSION` as one of the Agent inputs in every dispatch.

- [ ] **Step 7: Verify pass.**

- [ ] **Step 8: Commit**

```bash
git add paper-deepstudy/prompts/*.md \
        paper-deepstudy/templates/ \
        paper-deepstudy/skills/review-round/SKILL.md \
        paper-deepstudy/skills/study-deep/SKILL.md \
        paper-deepstudy/tests/unit/test-prompts-have-required-sections.bats
git commit -m "feat(paper-deepstudy): provenance HTML comment header on every generated file (Plan 11 T5)"
```

---

### Task 6: scripts/count-tests.sh + README badge fix

**Files:**
- Create: `paper-deepstudy/scripts/count-tests.sh`
- Create: `paper-deepstudy/tests/unit/test-count-tests.bats`
- Modify: `README.md`

**Helper 契约:** prints one line: `<bats-count> bats + <node-count> node = <total> total`. Optionally, with `--badge-format` flag, prints just the total integer for use in shields.io.

- [ ] **Step 1: 写 failing bats `tests/unit/test-count-tests.bats`**

```bash
#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "count-tests.sh runs and prints a total" {
  run bash scripts/count-tests.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats"* ]]
  [[ "$output" == *"node"* ]]
  [[ "$output" == *"total"* ]]
}

@test "count-tests.sh --badge-format prints just the integer total" {
  run bash scripts/count-tests.sh --badge-format
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "count-tests.sh integer is in the expected range (>= 100)" {
  total=$(bash scripts/count-tests.sh --badge-format)
  [ "$total" -ge 100 ]
}
```

- [ ] **Step 2: Verify fail.**

- [ ] **Step 3: 写 helper `paper-deepstudy/scripts/count-tests.sh`**

```bash
#!/usr/bin/env bash
# scripts/count-tests.sh — count bats + node test cases in this plugin.
# Usage:
#   scripts/count-tests.sh                  # human format
#   scripts/count-tests.sh --badge-format   # just the integer total

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

# Bats: count `@test "..."` lines across all .bats files
bats_count=0
if [ -d tests/unit ]; then
  bats_count=$(grep -hE '^@test ' tests/unit/*.bats 2>/dev/null | wc -l | tr -d ' ')
fi

# Node: count `console.log\(.*passed.*\)` markers — each test file emits one
# "<helper>: all tests passed" line per pass. We approximate one-per-file.
node_count=0
if [ -d tests/unit ]; then
  node_count=$(ls tests/unit/test-*.cjs 2>/dev/null | wc -l | tr -d ' ')
fi

total=$((bats_count + node_count))

if [ "${1:-}" = "--badge-format" ]; then
  echo "$total"
else
  echo "$bats_count bats + $node_count node = $total total"
fi
```

`chmod +x scripts/count-tests.sh`.

- [ ] **Step 4: Verify pass.**

- [ ] **Step 5: 修 README badge**

`README.md` 当前 line 8:

```html
<img alt="Tests passing" src="https://img.shields.io/badge/tests-146%20passing-22C55E?style=flat-square">
```

跑 `bash paper-deepstudy/scripts/count-tests.sh --badge-format` 拿当前数(预期 ~170 含本 plan 新增的 bats)。把 `146%20passing` 替换成 `<count>%20passing`。同时在中文 mirror 段如有则同步。

注意:这个 badge 是 **静态**(无 CI 自动更新)。在 README 加一行隐藏注释提醒维护者:

```html
<!-- maintainer: rebuild badge by running paper-deepstudy/scripts/count-tests.sh --badge-format -->
```

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/scripts/count-tests.sh \
        paper-deepstudy/tests/unit/test-count-tests.bats \
        README.md
git commit -m "feat(paper-deepstudy): scripts/count-tests.sh + fix README test-count badge drift (Plan 11 T6)"
```

---

## Self-Review checklist

- [ ] `cd paper-deepstudy && npm run test:unit` 通过.
  - 预期 bats: 160 → 160 + 8(T1)+ 9(T3)+ 3(T6)+ 几个新 prompt/skill 断言(T2/T4/T5)≈ 185.
  - 预期 node: 4 / 4(无新 node 测试).
- [ ] `tests/integration/test-end-to-end.sh` 通过(无文件 move,无破坏).
- [ ] `scripts/lib/resolve-paper.sh` 存在并 sourceable.
- [ ] `scripts/lib/log-dispatch.sh` 存在并 sourceable.
- [ ] 9 个 skill 都 source 了 resolve-paper.sh 和 log-dispatch.sh.
- [ ] 16 个 prompt 含 "Generated-by header" directive.
- [ ] 16 个 template 顶部第 1 行是 `<!-- generated: ... -->`.
- [ ] `review-round` skill 给 round-NN-*.md 加 provenance.
- [ ] README badge 数字与 `count-tests.sh --badge-format` 一致.
- [ ] `PAPER_DEEPSTUDY_NO_RUN_LOG` opt-out 在 README 文档化.
- [ ] No Claude co-author on any commit.

---

## What Plan 11 deliberately does NOT do

(These are scoped for Plan 12+, NOT regression in Plan 11.)

- 不改任何 sub-Agent 的语义、不改输出 schema(provenance 是 inert HTML 注释).
- 不引入 phoning-home 遥测(`run.jsonl` 纯本地).
- 不写 paper folder lock(那是 Plan 13 robustness).
- 不加 fixture paper 也不写 golden tests(Plan 12).
- 不动 plugin version(Plan 14 才升 0.2.0).
- 不动 marketplace.json category / tags(Plan 14).

---

## Live verification (post-implementation, optional)

如果想看 provenance + run.jsonl 真的 work,跑一次:

```bash
/paper:study https://arxiv.org/abs/1706.03762
```

然后:

```bash
ls ~/claude-papers/papers/attention-is-all-you-need/.deepstudy/
cat ~/claude-papers/papers/attention-is-all-you-need/.deepstudy/run.jsonl | head
head -1 ~/claude-papers/papers/attention-is-all-you-need/review.md
```

预期看到:
- `.deepstudy/run.jsonl` 有 ~12 行,每行一个 sub-Agent dispatch.
- `review.md` 第一行是 `<!-- generated: 2026-04-27T... by reviewer-synthesizer (paper-deepstudy v0.1.0) -->`.
- 关 logging 验证:`PAPER_DEEPSTUDY_NO_RUN_LOG=1 /paper:study ...` —— 不应生成 `.deepstudy/run.jsonl`.

可选,不是必须 —— 静态 bats 已经验证 prompt/skill 的指令字符串到位.
