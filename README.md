<div align="center">

<img src="assets/banner.svg" alt="studypaper — Read it. Roast it. Reproduce it." width="100%"/>

<p>
  <a href="https://github.com/chansigit/studypaper/blob/main/LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-F59E0B.svg?style=flat-square"></a>
  <img alt="Plugin version" src="https://img.shields.io/badge/plugin-v0.2.0-7C3AED?style=flat-square">
  <!-- maintainer: rebuild badge by running paper-deepstudy/scripts/count-tests.sh --badge-format -->
  <img alt="Tests passing" src="https://img.shields.io/badge/tests-212%20passing-22C55E?style=flat-square">
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-plugin-A78BFA?style=flat-square&logo=anthropic&logoColor=white">
  <img alt="Domain packs" src="https://img.shields.io/badge/domain%20packs-7-22D3EE?style=flat-square">
  <a href="https://github.com/chansigit/studypaper/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/chansigit/studypaper?style=flat-square&color=FBBF24"></a>
  <a href="https://github.com/chansigit/studypaper/issues"><img alt="GitHub issues" src="https://img.shields.io/github/issues/chansigit/studypaper?style=flat-square"></a>
  <a href="https://github.com/chansigit/studypaper/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/chansigit/studypaper?style=flat-square&color=06B6D4"></a>
</p>

### **Read it. Roast it. Reproduce it.**

**One PDF in. A peer-review-grade workspace out — in twenty minutes.**

[English](#english-) · [中文](#中文-) · [Install](#install) · [Quick start](#quick-start) · [Examples](examples/)

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

Every `/paper:study` produces these artifacts under `~/claude-papers/papers/<slug>/`:

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

The remaining workspace artifacts are produced by **extension commands**, not by `/paper:study`:

| Command | Artifact |
|---|---|
| `/paper:review-round` | `review-rounds/round-NN-<title>.md` (one file per round) |
| `/paper:deep-dive`    | `deep-dives/<topic-slug>.md` |
| `/paper:compare`      | `compares/vs-<other-slug>.md` |
| `/paper:reproduce-check` | `reproduce-check.md` |

Every file is regeneratable. Every mutation backs up to `<file>.bak.NN`. Nothing is destructive.

### Install

In Claude Code (CLI / IDE / Web):

```text
/plugin marketplace add chansigit/studypaper
/plugin install paper-deepstudy@studypaper
```

**Prerequisites**

- [`claude-paper`](https://github.com/alaliqing/claude-paper) plugin installed (declared as a dependency; install it first — the marketplace does not auto-install dependencies yet).
- `pdftotext` (from `poppler-utils`) on `PATH` for full-text extraction. *Optional* — without it, the orchestrator falls back to passing the PDF directly to sub-agents.
  - macOS: `brew install poppler`
  - Debian/Ubuntu: `sudo apt install poppler-utils`

### Quick start

```text
# One-shot full pipeline — fetch, analyze, review, render notes
/paper:study https://arxiv.org/abs/1706.03762

# An adversarial review round — you raise an objection, defense and blind judge respond
/paper:review-round

# Drill into a sub-topic that the analysis brushed over
/paper:deep-dive "scaled dot-product attention derivation"

# Head-to-head with another paper you've already studied (or auto-study + compare)
/paper:compare attention-is-all-you-need --lang zh

# 7-dimension reproducibility audit, with live GitHub link verification
/paper:reproduce-check
```

### Commands at a glance

| Command | What it does |
|---|---|
| `/paper:study <pdf-or-url>` | One-shot full pipeline |
| `/paper:rerun-stage <stage>` | Re-run a single stage (`analysis` / `review` / `notes` / `profile`) |
| `/paper:review-round` | Adversarial review round (objection → defense → blind judge → user verdict) |
| `/paper:refine-notes <variant>` | Apply an edit instruction to `xhs.md` or `wechat.md` |
| `/paper:retitle <variant>` | Regenerate 5 title candidates |
| `/paper:reselect-figures` | Re-pick which figures get embedded |
| `/paper:deep-dive <topic>` | Focused sub-topic write-up |
| `/paper:compare <target>` | Head-to-head comparison with another paper |
| `/paper:add-prior-work <ref>` | Append a missed prior-work entry (arXiv URL / BibTeX) |
| `/paper:reproduce-check` | 7-dimension reproducibility audit |

Run any command without arguments for inline help, or see [`paper-deepstudy/README.md`](paper-deepstudy/README.md) for the full reference.

### Examples

Real outputs from running the pipeline on actual papers:

- [`examples/string-database-2025/`](examples/string-database-2025/) — full pipeline on *The STRING database in 2025* (a `cs-bio` / `protein-function` database paper). Includes the adversarial review round, the deep-dive, the cross-paper comparison, the reproducibility audit, and the bilingual notes — every artifact generated by the live integration test.

### Repository layout

```text
studypaper/
├── .claude-plugin/
│   └── marketplace.json          marketplace registration — what makes /plugin install work
├── paper-deepstudy/              the plugin
│   ├── .claude-plugin/plugin.json
│   ├── commands/                 10 slash commands
│   ├── skills/                   orchestration skills (study-deep, review-round, …)
│   ├── prompts/                  18 sub-agent prompts
│   ├── templates/                output templates for every artifact
│   ├── domain-packs/             7 domain knowledge packs
│   ├── scripts/                  helper scripts (verify-prereqs, parse-judge-output, …)
│   └── tests/                    146 bats + 4 node + integration smoke
├── examples/                     curated real-paper outputs
├── assets/                       logo + banner SVGs
└── docs/                         design specs and implementation plans
```

### Contributing

The project follows test-driven development. Run the suite:

```bash
cd paper-deepstudy
npm install      # one-time, installs bats-core
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

每次 `/paper:study` 在 `~/claude-papers/papers/<slug>/` 下生成以下产物:

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

其余工作区产物由**扩展命令**生成,不属于 `/paper:study`:

| 命令 | 产物 |
|---|---|
| `/paper:review-round` | `review-rounds/round-NN-<title>.md`(每轮一个文件) |
| `/paper:deep-dive`    | `deep-dives/<topic-slug>.md` |
| `/paper:compare`      | `compares/vs-<other-slug>.md` |
| `/paper:reproduce-check` | `reproduce-check.md` |

每个文件都可重新生成。任何修改前都备份成 `<file>.bak.NN`。无破坏性操作。

### 安装

在 Claude Code(CLI / IDE / Web)中执行:

```text
/plugin marketplace add chansigit/studypaper
/plugin install paper-deepstudy@studypaper
```

**前置要求**

- 已安装 [`claude-paper`](https://github.com/alaliqing/claude-paper) 插件(声明为依赖,但目前 marketplace 不会自动装依赖,需先手动安装)。
- `pdftotext`(来自 `poppler-utils`)在 `PATH` 中用于全文抽取。*可选* —— 缺失时 orchestrator 会退化为把 PDF 直接传给 sub-agent。
  - macOS:`brew install poppler`
  - Debian/Ubuntu:`sudo apt install poppler-utils`

### 快速上手

```text
# 一键全自动 —— 下载、分析、审稿、渲染笔记
/paper:study https://arxiv.org/abs/1706.03762

# 一轮对抗式审稿 —— 你提质疑,辩护方和盲审 judge 应答
/paper:review-round

# 钻入一个分析没展开的子话题
/paper:deep-dive "scaled dot-product attention 推导"

# 与另一篇已研读的论文做正面比较(或自动研读 + 比较)
/paper:compare attention-is-all-you-need --lang zh

# 7 维可复现性审计,实时验证 GitHub 链接
/paper:reproduce-check
```

### 命令一览

| 命令 | 用途 |
|---|---|
| `/paper:study <pdf-or-url>` | 一键全自动 pipeline |
| `/paper:rerun-stage <stage>` | 重跑单个 stage(`analysis` / `review` / `notes` / `profile`) |
| `/paper:review-round` | 对抗式审稿(质疑 → 辩护 → 盲审 → 用户拍板) |
| `/paper:refine-notes <variant>` | 对 `xhs.md` 或 `wechat.md` 应用一条修改指令 |
| `/paper:retitle <variant>` | 重新生成 5 个候选标题 |
| `/paper:reselect-figures` | 重新选取嵌入哪些图 |
| `/paper:deep-dive <topic>` | 子话题深度展开 |
| `/paper:compare <target>` | 与另一篇论文正面对比 |
| `/paper:add-prior-work <ref>` | 增补一条先前工作(arXiv URL / BibTeX) |
| `/paper:reproduce-check` | 7 维可复现性审计 |

不带参数运行任何命令可看 inline help,完整参考见 [`paper-deepstudy/README.md`](paper-deepstudy/README.md)。

### 示例

对真实论文跑完 pipeline 的实际产物:

- [`examples/string-database-2025/`](examples/string-database-2025/) —— 在《The STRING database in 2025》(`cs-bio` / `protein-function` 数据库类论文)上的完整 pipeline。包含对抗审稿、深度展开、跨论文比较、可复现性审计、双语笔记 —— 全部由 live 集成测试生成。

### 仓库结构

```text
studypaper/
├── .claude-plugin/
│   └── marketplace.json          marketplace 注册 —— 让 /plugin install 能识别的关键
├── paper-deepstudy/              插件本体
│   ├── .claude-plugin/plugin.json
│   ├── commands/                 10 个 slash 命令
│   ├── skills/                   orchestration 技能(study-deep, review-round, …)
│   ├── prompts/                  18 个 sub-agent 提示词
│   ├── templates/                所有产物的模板
│   ├── domain-packs/             7 个领域知识包
│   ├── scripts/                  辅助脚本
│   └── tests/                    146 bats + 4 node + 集成 smoke
├── examples/                     精选真实论文产物
├── assets/                       logo + banner SVG
└── docs/                         设计 spec 和实现 plan
```

### 贡献

项目遵循 TDD。运行测试套件:

```bash
cd paper-deepstudy
npm install      # 一次性,装 bats-core
npm run test:unit
```

结构性断言基于 bats;纯逻辑 helper 有 node 测试脚本。集成 smoke test 验证文件级 wiring,不会真的派 sub-agent。

非平凡改动遵循 [Superpowers](https://github.com/jasonkneen/superpowers) 工作流:brainstorming → spec → plan → subagent-driven 实现。Spec 在 `docs/superpowers/specs/`,plan 在 `docs/superpowers/plans/`。

### 许可

MIT —— 详见 [LICENSE](LICENSE)。

### 致谢

构建在 `alaliqing` 的 [`claude-paper`](https://github.com/alaliqing/claude-paper) 之上。工作流模式(TDD、subagent-driven 开发、brainstorming)来自 [`superpowers`](https://github.com/jasonkneen/superpowers) 技能库。Logo 与 banner 由纯 SVG 手写。
