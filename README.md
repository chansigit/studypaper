<div align="center">

<img src="assets/banner.svg" alt="studypaper — Read it. Roast it. Reproduce it." width="100%"/>

<p>
  <a href="https://github.com/chansigit/studypaper/blob/main/LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-F59E0B.svg?style=flat-square"></a>
  <img alt="Plugin version" src="https://img.shields.io/badge/plugin-v0.5.1-7C3AED?style=flat-square">
  <!-- maintainer: rebuild badge by running paperstudio/scripts/count-tests.sh --badge-format -->
  <img alt="Tests passing" src="https://img.shields.io/badge/tests-246%20passing-22C55E?style=flat-square">
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-plugin-A78BFA?style=flat-square&logo=anthropic&logoColor=white">
  <img alt="Domain packs" src="https://img.shields.io/badge/domain%20packs-7-22D3EE?style=flat-square">
  <a href="https://github.com/chansigit/studypaper/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/chansigit/studypaper?style=flat-square&color=FBBF24"></a>
  <a href="https://github.com/chansigit/studypaper/issues"><img alt="GitHub issues" src="https://img.shields.io/github/issues/chansigit/studypaper?style=flat-square"></a>
  <a href="https://github.com/chansigit/studypaper/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/chansigit/studypaper?style=flat-square&color=06B6D4"></a>
</p>

### **Read it. Roast it. Reproduce it.**

**One PDF in. A peer-review-grade workspace out — in twenty minutes.**

</div>

## Install · 安装

In any [Claude Code](https://claude.com/claude-code) session (CLI / IDE / Web), run:

```text
/plugin marketplace add chansigit/studypaper
/plugin install paperstudio@studypaper
```

> Requires [`claude-paper`](https://github.com/alaliqing/claude-paper) installed first — the marketplace does not auto-install dependencies yet. · 需先装 [`claude-paper`](https://github.com/alaliqing/claude-paper)。

<div align="center">

[English](#english-) · [中文](#中文-) · [Design](#design--prompt-as-code) · [Quick start](#quick-start) · [Examples](examples/) · [Changelog](CHANGELOG.md)

</div>

---

## English <a id="english-"></a>

You have 50 papers in your reading queue. You scan abstracts. You skim figures. You forget what you read by Friday.

`studypaper` does the work you wish you had time for.

It is a [Claude Code](https://claude.com/claude-code) plugin that turns any ML or computational-biology paper (PDF or arXiv URL) into a complete, navigable research workspace — a structured analysis directory, a reviewer-style verdict, and bilingual social-media notes — from one command, in about twenty minutes. Run extension commands (adversarial review, deep-dive, head-to-head compare, reproducibility audit) on top.

### Why studypaper

| Without studypaper | With studypaper |
|---|---|
| You scan abstracts and forget what you read | A 7-file structured analysis you can `grep`, diff, and revisit a year later |
| You vaguely sense "this paper is sketchy" | An adversarial review captures the objection in writing — author defense, *blind* judge, your call |
| You assume the GitHub link works | A 7-dimension reproducibility audit verifies it live and flags missing seeds, hardware, eval scripts |
| You write the WeChat / 小红书 post from scratch | A 3000-character draft lands ready, with auto-selected figures and 5 candidate titles |
| Your second paper repeats the work of your first | Re-usable domain packs (`single-cell`, `genomics`, `protein-structure` …) inject the right context every time |

### What you get

Every `/paperstudio:study` produces these artifacts under `~/claude-papers/papers/<slug>/`:

```text
analysis/
  00-paper-profile.md       paper type · domain · difficulty (YAML frontmatter)
  01-problem.md             problem statement and framing
  02-formalization.md       math: notation, loss, constraints
  03-method-deep.md         method with rationale + alternatives considered
  04-experiments.md         experiment critique (not just description)
  05-prior-work.md          chronological timeline + comparison
  06-figures.md             per-figure interpretation + scoring
review.md                   academic-reviewer-style verdict (Strengths / Weaknesses / Score)
notes/
  source.md                 unified Chinese source (single point of truth)
  titles.md                 5+5 candidate titles
  xhs.md                    Xiaohongshu rendering (~1000 chars, 1 figure)
  wechat.md                 WeChat rendering (~3000 chars, 2-3 figures)
```

The remaining workspace artifacts are produced by **extension commands**, not by `/paperstudio:study`:

| Command | Artifact |
|---|---|
| `/paperstudio:review-round` | `review-rounds/round-NN-<title>.md` (one file per round) |
| `/paperstudio:deep-dive`    | `deep-dives/<topic-slug>.md` |
| `/paperstudio:compare`      | `compares/vs-<other-slug>.md` |
| `/paperstudio:reproduce-check` | `reproduce-check.md` |

Every file is regeneratable. Every mutation backs up to `<file>.bak.NN`. Nothing is destructive.

### Install

In Claude Code (CLI / IDE / Web):

```text
/plugin marketplace add chansigit/studypaper
/plugin install paperstudio@studypaper
```

**Prerequisites**

- [`claude-paper`](https://github.com/alaliqing/claude-paper) plugin installed (declared as a dependency; install it first — the marketplace does not auto-install dependencies yet).
- `pdftotext` (from `poppler-utils`) on `PATH` for full-text extraction. *Optional* — without it, the orchestrator falls back to passing the PDF directly to sub-agents.
  - macOS: `brew install poppler`
  - Debian/Ubuntu: `sudo apt install poppler-utils`

### Design · prompt-as-code <a id="design--prompt-as-code"></a>

`paperstudio` is **not a typical software project** — it is an LLM orchestration system written almost entirely in Markdown. The "code" is constraints, templates, and dispatch instructions that the model interprets at runtime. Understanding it requires switching frames: **Markdown is the program; the model is the runtime**.

**Five layers, top to bottom:**

```text
[1] commands/      ×10   Slash-command entry points. Just argument hints +
                         "go run that skill". No business logic.
[2] skills/        ×9    The orchestrators ("directors"). Stage ordering, flag
                         parsing, idempotence rules, who-dispatches-whom.
                         This is where the project's control flow lives.
[3] prompts/       ×19   Sub-agent scripts ("actors"). Each one is the full
                         prompt for a single specialized sub-agent (paper-profiler,
                         method-analyst, reviewer-synthesizer, …). They never
                         talk to each other directly — they exchange data via
                         files on disk that the skill layer routes.
[4] templates/     ×16   Output skeletons with <runtime-timestamp>,
                         <fill-this> placeholders. Sub-agents copy + fill.
                         Job: enforce uniform structure (required H2 sections,
                         frontmatter keys) so downstream parsing is reliable.
[5] scripts/             Deterministic bits (cjs + sh): things the model
                         shouldn't do (URL normalization, schema validation,
                         JSONL log writing, figure ranking, slugification).
```

**Two filesystem coordinate systems** — keep them straight:

| | **Plugin code** (read-only, in Git) | **User data** (read/write, not in Git) |
|---|---|---|
| Location | `~/.claude/plugins/cache/studypaper/paperstudio/<ver>/` | `$CLAUDE_PAPERS_ROOT` (default `~/claude-papers/papers/<slug>/`) |
| Owns | the prompts, templates, scripts | the paper, all generated artifacts, dispatch log |
| Stable | yes (versioned) | no (one folder per paper studied) |

**Four cross-cutting abstractions you'll see everywhere:**

1. **Provenance.** Every generated file's line 1 is `<!-- generated: <ts> by <agent> (paperstudio v<ver>) -->`. Audit-by-grep: any artifact tells you who, when, with which version. Enforced by `validate-artifact.sh`.
2. **Idempotence.** If an output already exists, the dispatching skill skips that sub-agent (no token re-burn). `--force` backs up to `<file>.bak.NN` before overwrite. `--only <stage>` re-runs just one stage. The whole pipeline is safe to interrupt and resume.
3. **Dispatch log.** `<paper>/.deepstudy/run.jsonl` — one JSONL line per sub-agent dispatch, with status + timestamp + plugin version. The only runtime observability signal. Local only; opt out with `PAPER_DEEPSTUDY_NO_RUN_LOG=1`.
4. **Domain packs.** `domain-packs/{single-cell,protein-structure,ml-pure,…}.md` are not docs — they are knowledge-injection text. The `paper-profiler` picks 1–N relevant packs at Stage 0; later sub-agents prepend the chosen pack contents to their own prompts. Multi-domain adaptation by *concatenation*, not by maintaining per-domain prompt forks.

**Walking through one `/paperstudio:study` call:**

```text
user types  /paperstudio:study https://arxiv.org/abs/1706.03762
                  │
                  ▼
[command]  commands/study.md  ──── dispatches ───▶  Skill(study-deep)
                  │
                  ▼
[skill]    skills/study-deep/SKILL.md  (the orchestrator wakes up)
            ├── 0.1  verify-prereqs.sh
            ├── 0.2  normalize URL → claude-paper:study downloads PDF
            ├── 0.3  resolve paper folder, set $PAPER_DIR
            ├── 0.4  Agent(paper-profiler)  → analysis/00-paper-profile.md
            │
            ├── Stage 1 (6 parallel Agent calls, one prompt each):
            │     problem-framer / formalizer / method-analyst /
            │     experiment-critic / prior-work-historian / figure-interpreter
            │     → analysis/01–06
            │
            ├── Stage 2: Agent(reviewer-synthesizer) → review.md
            │
            └── Stage 3:
                  Agent(notes-writer)     → notes/source.md
                  Agent(title-generator)  → notes/titles.md
                  select-figures.cjs      (deterministic figure pick)
                  Agent(xhs-renderer) ║ Agent(wechat-renderer)  parallel
                  → notes/xhs.md, notes/wechat.md
```

After every Agent call: `log_dispatch <agent> <output> ok` appends a JSONL line. After every Stage: idempotence rule decides skip-or-overwrite.

**Why this architecture is worth it:**

- Iterating on model behavior = editing Markdown, not redeploying code.
- Source and docs are the same file — onboarding is reading the prompts.
- Layers have crisp responsibilities → small bug-fix radius.

**What you give up:**

- No stack traces. Debugging = reading `.deepstudy/run.jsonl` + diffing produced artifacts.
- No static guarantees. Correctness = constraints in prompts + schema validation + golden-snapshot behavior tests (`tests/behavior/`). The discipline of catching drift falls on the test suite.
- A prompt change can silently shift output style across the whole pipeline. The 17-assertion golden-snapshot test is the safety net for this.

**Where to extend:**

| You want to add… | Touch this |
|---|---|
| A new slash command | `commands/<name>.md` + `skills/<name>/SKILL.md` |
| A new sub-agent role | `prompts/<role>.md` + dispatch it from some `SKILL.md` |
| A new domain | `domain-packs/<x>.md` + add detection rule to `paper-profiler.md` |
| A new artifact type | `templates/<x>.md` + new schema arm in `validate-artifact.sh` |
| A new paper-host URL | regex case in `scripts/normalize-paper-url.sh` |

If you only remember one thing: **constraints + templates + schema validation + behavior tests are how this project tames an otherwise unpredictable runtime (the model)**. Take any one of those four away and the whole thing collapses into "creative drift".

### Quick start

```text
# One-shot full pipeline — fetch, analyze, review, render notes
/paperstudio:study https://arxiv.org/abs/1706.03762

# Same, but render the Stage 3 notes (xhs / wechat) in English instead of the default 中文
/paperstudio:study https://arxiv.org/abs/1706.03762 --lang en

# An adversarial review round — you raise an objection, defense and blind judge respond
/paperstudio:review-round

# Drill into a sub-topic that the analysis brushed over
/paperstudio:deep-dive "scaled dot-product attention derivation"

# Head-to-head with another paper you've already studied (or auto-study + compare)
/paperstudio:compare attention-is-all-you-need --lang zh

# 7-dimension reproducibility audit, with live GitHub link verification
/paperstudio:reproduce-check
```

### Commands at a glance

| Command | What it does |
|---|---|
| `/paperstudio:study <pdf-or-url> [--lang en]` | One-shot full pipeline. Default Stage 3 (xhs / wechat) language is 中文; `--lang en` switches to English. |
| `/paperstudio:rerun-stage <stage>` | Re-run a single stage (`analysis` / `review` / `notes` / `profile`) |
| `/paperstudio:review-round` | Adversarial review round (objection → defense → blind judge → user verdict) |
| `/paperstudio:refine-notes <variant>` | Apply an edit instruction to `xhs.md` or `wechat.md` |
| `/paperstudio:retitle <variant>` | Regenerate 5 title candidates |
| `/paperstudio:reselect-figures` | Re-pick which figures get embedded |
| `/paperstudio:deep-dive <topic>` | Focused sub-topic write-up |
| `/paperstudio:compare <target>` | Head-to-head comparison with another paper |
| `/paperstudio:add-prior-work <ref>` | Append a missed prior-work entry (arXiv URL / BibTeX) |
| `/paperstudio:reproduce-check` | 7-dimension reproducibility audit |

Run any command without arguments for inline help, or see [`paperstudio/README.md`](paperstudio/README.md) for the full reference.

### Examples

Real outputs from running the pipeline on actual papers:

- [`examples/string-database-2025/`](examples/string-database-2025/) — full pipeline on *The STRING database in 2025* (a `cs-bio` / `protein-function` database paper). Includes the adversarial review round, the deep-dive, the cross-paper comparison, the reproducibility audit, and the bilingual notes — every artifact generated by the live integration test.

### Repository layout

```text
studypaper/
├── .claude-plugin/
│   └── marketplace.json          marketplace registration — what makes /plugin install work
├── paperstudio/              the plugin
│   ├── .claude-plugin/plugin.json
│   ├── commands/                 10 slash commands
│   ├── skills/                   orchestration skills (study-deep, review-round, …)
│   ├── prompts/                  19 sub-agent prompts
│   ├── templates/                output templates for every artifact
│   ├── domain-packs/             7 domain knowledge packs
│   ├── scripts/                  helper scripts (verify-prereqs, parse-judge-output, …)
│   └── tests/                    225 bats + 4 node + integration smoke
├── examples/                     curated real-paper outputs
├── assets/                       logo + banner SVGs
└── docs/                         design specs and implementation plans
```

### Contributing

The project follows test-driven development. Run the suite:

```bash
cd paperstudio
npm install      # one-time, installs Bats
npm run test:unit
```

Structural assertions are bats-based; pure-logic helpers have node test scripts. The integration smoke test (`tests/integration/test-end-to-end.sh`) verifies file-level wiring without dispatching real sub-agents.

For non-trivial changes, the project uses the [Superpowers](https://github.com/jasonkneen/superpowers) workflow: brainstorming → spec → plan → subagent-driven implementation. Specs live in `docs/superpowers/specs/`; plans in `docs/superpowers/plans/`.

### License

MIT — see [LICENSE](LICENSE).

### Credits

Built on top of [`claude-paper`](https://github.com/alaliqing/claude-paper) by `alaliqing`. Workflow patterns (TDD, subagent-driven development, brainstorming) come from the [`superpowers`](https://github.com/jasonkneen/superpowers) skills library. Logo and banner crafted in plain SVG.

---

## 中文 <a id="中文-"></a>

你的待读论文堆了 50 篇。你扫摘要、瞄图、礼拜五就忘了自己看过啥。

`studypaper` 替你做你一直没时间做的事情。

它是一个 [Claude Code](https://claude.com/claude-code) 插件,把任意一篇机器学习或计算生物学论文(PDF 或 arXiv 链接)转换成一个完整、可导航的研究工作区 —— 一份结构化分析目录、一份审稿人视角的判定、一套双语社交媒体笔记 —— 一条命令搞定,大约二十分钟。扩展命令(对抗性审阅、深挖、正面对比、可复现性审计)按需追加。

### 为什么是 studypaper

| 没有 studypaper | 有 studypaper |
|---|---|
| 扫摘要,扫完就忘 | 一份 7 文件结构化分析,可 `grep`、可 diff、一年后还能回看 |
| 隐约觉得"这论文有点水" | 把质疑写下来 —— 作者辩护、**盲审** judge、你最终拍板 |
| 默认 GitHub 链接还活着 | 7 维可复现性审计,实时验证链接、标注缺失的种子/硬件/评估脚本 |
| 微信 / 小红书帖子从零写 | 一份 3000 字草稿现成,配图自动选好,5 个候选标题候选 |
| 第二篇论文重复第一篇的功夫 | 可复用的领域包(`single-cell`、`genomics`、`protein-structure` …)每次自动注入对应上下文 |

### 你会得到什么

每次 `/paperstudio:study` 在 `~/claude-papers/papers/<slug>/` 下生成以下产物:

```text
analysis/
  00-paper-profile.md       论文类型 · 领域 · 难度(YAML frontmatter)
  01-problem.md             问题陈述与框定
  02-formalization.md       数学:符号、损失、约束
  03-method-deep.md         方法精读 + 设计 rationale + 候选方案
  04-experiments.md         实验批评(不仅是描述)
  05-prior-work.md          时间线 + 对比
  06-figures.md             逐图解读 + 评分
review.md                   学术审稿人风格判定(优点 / 缺点 / 分数)
notes/
  source.md                 中文统一 source(唯一真源)
  titles.md                 5+5 候选标题
  xhs.md                    小红书渲染(~1000 字,1 张图)
  wechat.md                 微信渲染(~3000 字,2-3 张图)
```

其余工作区产物由**扩展命令**生成,不属于 `/paperstudio:study`:

| 命令 | 产物 |
|---|---|
| `/paperstudio:review-round` | `review-rounds/round-NN-<title>.md`(每轮一个文件) |
| `/paperstudio:deep-dive`    | `deep-dives/<topic-slug>.md` |
| `/paperstudio:compare`      | `compares/vs-<other-slug>.md` |
| `/paperstudio:reproduce-check` | `reproduce-check.md` |

每个文件都可重新生成。任何修改前都备份成 `<file>.bak.NN`。无破坏性操作。

### 安装

在 Claude Code(CLI / IDE / Web)中执行:

```text
/plugin marketplace add chansigit/studypaper
/plugin install paperstudio@studypaper
```

**前置要求**

- 已安装 [`claude-paper`](https://github.com/alaliqing/claude-paper) 插件(声明为依赖,但目前 marketplace 不会自动装依赖,需先手动安装)。
- `pdftotext`(来自 `poppler-utils`)在 `PATH` 中用于全文抽取。*可选* —— 缺失时 orchestrator 会退化为把 PDF 直接传给 sub-agent。
  - macOS:`brew install poppler`
  - Debian/Ubuntu:`sudo apt install poppler-utils`

### 设计 · prompt-as-code

`paperstudio` **不是常规软件项目** —— 它是一个**几乎完全用 Markdown 写成的 LLM 编排系统**。"代码"是约束、模板和派发指令,由模型在运行时解释。理解它需要切换思维:**Markdown 是程序;模型是运行时**。

**自顶向下五层:**

```text
[1] commands/      ×10   斜杠命令入口。只有 argument-hint + "去跑下面那个 skill"。
                         不含业务逻辑。
[2] skills/        ×9    编排器("导演")。stage 顺序、flag 解析、幂等规则、
                         谁派给谁。项目控制流的所在。
[3] prompts/       ×19   子 Agent 脚本("演员")。每个文件是一个专职子 Agent
                         (paper-profiler / method-analyst / reviewer-synthesizer …)
                         的完整 prompt。它们彼此不直接通信 —— 通过磁盘文件
                         交接,skill 层负责路由。
[4] templates/     ×16   产物骨架,带 <runtime-timestamp> / <fill-this> 占位符。
                         子 Agent 复制并填空。目的:统一结构(必需的 H2 小节、
                         frontmatter key),让下游解析可靠。
[5] scripts/             确定性逻辑(cjs + sh):模型不擅长做的事
                         (URL 归一化、schema 校验、JSONL 日志、图表排序、
                         slug 生成)。
```

**两套文件系统坐标 —— 必须分清:**

| | **插件代码**(只读,跟 Git) | **用户数据**(读写,不进 Git) |
|---|---|---|
| 位置 | `~/.claude/plugins/cache/studypaper/paperstudio/<ver>/` | `$CLAUDE_PAPERS_ROOT`(默认 `~/claude-papers/papers/<slug>/`) |
| 拥有 | prompts、templates、scripts | 论文、所有产物、dispatch log |
| 稳定性 | 是(版本化) | 否(每篇论文一个文件夹) |

**4 个横切抽象,你会反复见到:**

1. **Provenance(留痕)。** 每个产物 line 1 必为 `<!-- generated: <ts> by <agent> (paperstudio v<ver>) -->`。grep 即审计:任何文件都告诉你"谁、什么时候、用哪版插件"。`validate-artifact.sh` 强制。
2. **幂等。** 产物已存在 → skill 跳过对应子 Agent(不重烧 token)。`--force` 备份成 `<file>.bak.NN` 再覆盖。`--only <stage>` 只重跑一个 stage。整条流水线随时可中断、可续跑。
3. **Dispatch log。** `<paper>/.deepstudy/run.jsonl` —— 每次子 Agent 派发追加一行 JSONL,带状态 + 时间戳 + 插件版本。**唯一的运行时可观测信号**。仅本地;`PAPER_DEEPSTUDY_NO_RUN_LOG=1` 可关。
4. **Domain pack。** `domain-packs/{single-cell,protein-structure,ml-pure,…}.md` 不是文档,是**知识注入文本**。`paper-profiler` 在 Stage 0 选出 1–N 个相关 pack;后续每个子 Agent 把所选 pack 内容拼到自己 prompt 前面再发。**多领域适配靠拼接,不靠维护多份 prompt 分支**。

**一次 `/paperstudio:study` 的调用走向:**

```text
用户敲     /paperstudio:study https://arxiv.org/abs/1706.03762
                  │
                  ▼
[命令]     commands/study.md  ──── 派发 ───▶  Skill(study-deep)
                  │
                  ▼
[skill]    skills/study-deep/SKILL.md  (orchestrator 醒来)
            ├── 0.1  verify-prereqs.sh
            ├── 0.2  归一化 URL → claude-paper:study 下载 PDF
            ├── 0.3  解析 paper folder,设置 $PAPER_DIR
            ├── 0.4  Agent(paper-profiler) → analysis/00-paper-profile.md
            │
            ├── Stage 1(6 个子 Agent 并行,每个一份 prompt):
            │     problem-framer / formalizer / method-analyst /
            │     experiment-critic / prior-work-historian / figure-interpreter
            │     → analysis/01–06
            │
            ├── Stage 2:Agent(reviewer-synthesizer) → review.md
            │
            └── Stage 3:
                  Agent(notes-writer)     → notes/source.md
                  Agent(title-generator)  → notes/titles.md
                  select-figures.cjs      (确定性选图)
                  Agent(xhs-renderer) ║ Agent(wechat-renderer)  并行
                  → notes/xhs.md, notes/wechat.md
```

每次 Agent 调用后:`log_dispatch <agent> <output> ok` 追加 JSONL。每个 Stage 后:幂等规则决定跳过还是覆盖。

**为什么这种架构值得:**

- 迭代模型行为 = 改 Markdown,不需重新部署代码
- 源码和文档是同一份文件,新人 onboard 就是读 prompt
- 各层职责清晰,bug 半径小

**代价:**

- 没有 stack trace。调试 = 读 `.deepstudy/run.jsonl` + diff 产物
- 没有静态正确性保证。正确性 = prompt 里的约束 + schema 校验 + golden-snapshot 行为测试(`tests/behavior/`)。抓漂移的纪律全押在测试套件上
- prompt 一改,整条流水线产出风格可能静默漂移。17 条 golden-snapshot 测试是这条的安全网

**扩展点:**

| 想加什么 | 改哪 |
|---|---|
| 新的斜杠命令 | `commands/<name>.md` + `skills/<name>/SKILL.md` |
| 新的子 Agent 角色 | `prompts/<role>.md` + 在某个 `SKILL.md` 里 dispatch 它 |
| 新领域 | `domain-packs/<x>.md` + 在 `paper-profiler.md` 加识别规则 |
| 新的产物类型 | `templates/<x>.md` + 在 `validate-artifact.sh` 加 schema arm |
| 新的论文 host URL | 在 `scripts/normalize-paper-url.sh` 加正则 |

只需记住一件事:**约束 + 模板 + schema 校验 + 行为测试,这四件事一起驯服了一个本来不可预测的运行时(模型)**。少了任何一个,整套就坍缩成"创意漂移"。

### 快速上手

```text
# 一键全自动 —— 下载、分析、审稿、渲染笔记
/paperstudio:study https://arxiv.org/abs/1706.03762

# 同上,但 Stage 3 笔记(xhs / wechat)输出英文,而不是默认中文
/paperstudio:study https://arxiv.org/abs/1706.03762 --lang en

# 一轮对抗式审稿 —— 你提质疑,辩护方和盲审 judge 应答
/paperstudio:review-round

# 钻入一个分析没展开的子话题
/paperstudio:deep-dive "scaled dot-product attention 推导"

# 与另一篇已研读的论文做正面比较(或自动研读 + 比较)
/paperstudio:compare attention-is-all-you-need --lang zh

# 7 维可复现性审计,实时验证 GitHub 链接
/paperstudio:reproduce-check
```

### 命令一览

| 命令 | 用途 |
|---|---|
| `/paperstudio:study <pdf-or-url> [--lang en]` | 一键全自动 pipeline。Stage 3 笔记默认中文;`--lang en` 切换为英文。 |
| `/paperstudio:rerun-stage <stage>` | 重跑单个 stage(`analysis` / `review` / `notes` / `profile`) |
| `/paperstudio:review-round` | 对抗式审稿(质疑 → 辩护 → 盲审 → 用户拍板) |
| `/paperstudio:refine-notes <variant>` | 对 `xhs.md` 或 `wechat.md` 应用一条修改指令 |
| `/paperstudio:retitle <variant>` | 重新生成 5 个候选标题 |
| `/paperstudio:reselect-figures` | 重新选取嵌入哪些图 |
| `/paperstudio:deep-dive <topic>` | 子话题深度展开 |
| `/paperstudio:compare <target>` | 与另一篇论文正面对比 |
| `/paperstudio:add-prior-work <ref>` | 增补一条先前工作(arXiv URL / BibTeX) |
| `/paperstudio:reproduce-check` | 7 维可复现性审计 |

不带参数运行任何命令可看 inline help,完整参考见 [`paperstudio/README.md`](paperstudio/README.md)。

### 示例

对真实论文跑完 pipeline 的实际产物:

- [`examples/string-database-2025/`](examples/string-database-2025/) —— 在《The STRING database in 2025》(`cs-bio` / `protein-function` 数据库类论文)上的完整 pipeline。包含对抗审稿、深度展开、跨论文比较、可复现性审计、双语笔记 —— 全部由 live 集成测试生成。

### 仓库结构

```text
studypaper/
├── .claude-plugin/
│   └── marketplace.json          marketplace 注册 —— 让 /plugin install 能识别的关键
├── paperstudio/              插件本体
│   ├── .claude-plugin/plugin.json
│   ├── commands/                 10 个 slash 命令
│   ├── skills/                   orchestration 技能(study-deep, review-round, …)
│   ├── prompts/                  19 个 sub-agent 提示词
│   ├── templates/                所有产物的模板
│   ├── domain-packs/             7 个领域知识包
│   ├── scripts/                  辅助脚本
│   └── tests/                    225 bats + 4 node + 集成 smoke
├── examples/                     精选真实论文产物
├── assets/                       logo + banner SVG
└── docs/                         设计 spec 和实现 plan
```

### 贡献

项目遵循 TDD。运行测试套件:

```bash
cd paperstudio
npm install      # 一次性,安装 Bats
npm run test:unit
```

结构性断言基于 bats;纯逻辑 helper 有 node 测试脚本。集成 smoke test 验证文件级 wiring,不会真的派 sub-agent。

非平凡改动遵循 [Superpowers](https://github.com/jasonkneen/superpowers) 工作流:brainstorming → spec → plan → subagent-driven 实现。Spec 在 `docs/superpowers/specs/`,plan 在 `docs/superpowers/plans/`。

### 许可

MIT —— 详见 [LICENSE](LICENSE)。

### 致谢

构建在 `alaliqing` 的 [`claude-paper`](https://github.com/alaliqing/claude-paper) 之上。工作流模式(TDD、subagent-driven 开发、brainstorming)来自 [`superpowers`](https://github.com/jasonkneen/superpowers) 技能库。Logo 与 banner 由纯 SVG 手写。
