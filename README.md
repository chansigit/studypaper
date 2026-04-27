# studypaper

> Deep paper study toolkit for ML and computational-biology research, built as a [Claude Code](https://claude.com/claude-code) plugin marketplace.
>
> 面向机器学习和计算生物学的深度论文研读工具,作为 [Claude Code](https://claude.com/claude-code) 插件市场发布。

[English](#english) · [中文](#中文)

---

## English

### What it is

`studypaper` ships **`paper-deepstudy`** — a Claude Code plugin that turns a single paper PDF (or arXiv URL) into a complete study workspace:

- **Deep analysis** in 7 structured English files: paper profile, problem framing, formal definition, method deep-dive, experiment critique, prior-work timeline, figure interpretation.
- **Adversarial review** — you raise objections, a defense sub-agent argues for the authors, a *blind* judge sub-agent (which never sees the paper) rules on the defense's logic, and you have the final say. Every round is persisted.
- **Reproducibility audit** — 7-dimension structured rating (data, code, hyperparameters, seeds, hardware, eval scripts, wet-lab protocol), with GitHub URL verification via WebFetch.
- **Analysis extensions** — focused deep-dives on a sub-topic, head-to-head comparison with another studied paper, and surgical augmentation of the prior-work timeline with missed citations.
- **Chinese learning notes** — from a single curated source, render two voices: 小红书 (~1000 chars) and 微信 (~3000 chars), with auto-selected figures and 3-5 candidate titles. No emoji, transcribe-perspective, plain-language explanations.
- **Domain awareness** — 7 domain packs (`ml-pure`, `single-cell`, `protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`) auto-injected based on Stage 0 paper profiling.

The plugin is built on top of [`claude-paper:study`](https://github.com/alaliqing/claude-paper) and extends it with deeper analysis, iterative review, and bilingual rendering.

### Install

In Claude Code (CLI / IDE / Web):

```text
/plugin marketplace add chansigit/studypaper
/plugin install paper-deepstudy@studypaper
```

**Prerequisites:**

- [`claude-paper`](https://github.com/alaliqing/claude-paper) plugin installed (the plugin manifest declares it as a dependency, but the marketplace doesn't auto-install dependencies yet — install it manually first).
- `pdftotext` (from `poppler-utils`) on `PATH` for full-text extraction. Optional; the orchestrator falls back to passing `paper.pdf` directly to sub-agents if missing.
  - macOS: `brew install poppler`
  - Debian/Ubuntu: `sudo apt install poppler-utils`

### Quick start

```text
# One-shot auto-run (downloads + studies + reviews + renders notes)
/paper:study https://arxiv.org/abs/1706.03762

# Adversarial review round
/paper:review-round

# Focused deep-dive on a sub-topic
/paper:deep-dive "scaled dot-product attention derivation"

# Head-to-head comparison with another studied paper
/paper:compare BERT --lang zh

# Reproducibility audit
/paper:reproduce-check
```

All outputs land at `~/claude-papers/papers/<slug>/`. Existing files are backed up to `<file>.bak.NN` before any mutation, so you can iterate without fear.

### What you get

12 outputs per paper, under `~/claude-papers/papers/<slug>/`:

```text
analysis/
  00-paper-profile.md       # type, domain, difficulty (English, YAML frontmatter)
  01-problem.md             # background and framing (English)
  02-formalization.md       # math definitions, loss, constraints (English)
  03-method-deep.md         # method with rationale and alternatives (English)
  04-experiments.md         # experiment critique (English)
  05-prior-work.md          # timeline + comparison (English)
  06-figures.md             # per-figure interpretation + scoring (English)
review.md                   # academic-reviewer-style report (English)
review-rounds/              # one file per /paper:review-round invocation (English)
deep-dives/                 # one file per /paper:deep-dive invocation (English)
compares/                   # one file per /paper:compare invocation
reproduce-check.md          # 7-dimension reproducibility audit (English)
notes/
  source.md                 # unified source content (Chinese)
  titles.md                 # 5+5 candidate titles (Chinese)
  xhs.md                    # Xiaohongshu rendering (Chinese, ~1000 chars)
  wechat.md                 # WeChat rendering (Chinese, ~3000 chars)
```

### Commands at a glance

| Command | Purpose |
|---|---|
| `/paper:study <pdf-or-url>` | One-shot auto-run pipeline |
| `/paper:rerun-stage <stage>` | Re-run a single stage (`analysis` / `review` / `notes` / `profile`) |
| `/paper:review-round` | Adversarial review round (objection → defense → blind judge → user) |
| `/paper:refine-notes <variant>` | Apply an edit instruction to `xhs.md` or `wechat.md` |
| `/paper:retitle <variant>` | Regenerate 5 title candidates |
| `/paper:reselect-figures` | Re-pick which figures get embedded |
| `/paper:deep-dive <topic>` | Focused sub-topic write-up |
| `/paper:compare <target>` | Head-to-head comparison with another paper |
| `/paper:add-prior-work <ref>` | Append a missed prior-work entry (arXiv URL / BibTeX / DOI) |
| `/paper:reproduce-check` | 7-dimension reproducibility audit |

Run any command without arguments for inline help, or see [`paper-deepstudy/README.md`](paper-deepstudy/README.md) for the full reference.

### Examples

Real outputs from running the pipeline on actual papers:

- [`examples/string-database-2025/`](examples/string-database-2025/) — full pipeline on *The STRING database in 2025* (a `cs-bio` / `protein-function` database paper). Includes the adversarial review round, the deep-dive, the cross-paper comparison, the reproducibility audit, and the bilingual notes — all generated by the live integration test.

### Repository layout

```text
studypaper/
├── .claude-plugin/
│   └── marketplace.json     # marketplace registration (this is what makes it installable)
├── paper-deepstudy/         # the plugin itself
│   ├── .claude-plugin/plugin.json
│   ├── commands/            # 10 slash commands
│   ├── skills/              # orchestration skills (study-deep, review-round, ...)
│   ├── prompts/             # 18 sub-agent prompts
│   ├── templates/           # output templates for all artifacts
│   ├── domain-packs/        # 7 domain knowledge packs
│   ├── scripts/             # helper scripts (verify-prereqs, parse-judge-output, ...)
│   └── tests/               # 146 bats + 4 node + integration smoke
├── examples/                # curated real-paper outputs
└── docs/                    # design specs and implementation plans
```

### Contributing

This project follows test-driven development. To run the test suite:

```bash
cd paper-deepstudy
npm install      # one-time, installs bats-core
npm run test:unit
```

All structural assertions are bats-based; pure-logic helpers have node test scripts. The integration smoke test (`tests/integration/test-end-to-end.sh`) verifies file-level wiring without dispatching real sub-agents.

For non-trivial changes, the project uses the [Superpowers](https://github.com/jasonkneen/superpowers) workflow: brainstorming → spec → plan → subagent-driven implementation. Specs live in `docs/superpowers/specs/`, plans in `docs/superpowers/plans/`.

### License

MIT. See [LICENSE](LICENSE) (TBD).

### Credits

Built on top of [`claude-paper`](https://github.com/alaliqing/claude-paper) by `alaliqing`. Workflow patterns (TDD, subagent-driven development, brainstorming) come from the [`superpowers`](https://github.com/jasonkneen/superpowers) skills library.

---

## 中文

### 这是什么

`studypaper` 发布 **`paper-deepstudy`** —— 一个 Claude Code 插件,把一篇论文 PDF(或 arXiv 链接)转换成完整的学习工作区:

- **深度分析** 7 个结构化英文文件:论文画像、问题背景、形式化定义、方法精读、实验批评、先前工作时间线、图表解读。
- **对抗式审稿** —— 你提反对意见,defense sub-agent 替作者辩护,一个**盲审** judge sub-agent(它不会读到论文)只根据辩护的逻辑判定,你有最终决定权。每一轮都被保存。
- **可复现性审计** —— 7 维结构化打分(数据、代码、超参、随机种子、硬件、评估脚本、湿实验协议),GitHub 链接通过 WebFetch 验证可用性。
- **分析扩展** —— 对子话题做深度展开、与另一篇已研读的论文做正面比较、对先前工作时间线做最小侵入的增补。
- **中文学习笔记** —— 从一份统一 source 渲染出两种风格:小红书(~1000 字)和微信(~3000 字),自动挑图、3-5 个候选标题。无 emoji,转述视角,公式尽量大白话。
- **领域感知** —— 7 个领域包(`ml-pure`、`single-cell`、`protein-structure`、`protein-function`、`genomics`、`drug-discovery`、`medical-imaging`)由 Stage 0 论文画像自动选取并注入。

本插件构建在 [`claude-paper:study`](https://github.com/alaliqing/claude-paper) 之上,扩展了更深的分析、迭代审稿和双语渲染。

### 安装

在 Claude Code(CLI / IDE / Web)中执行:

```text
/plugin marketplace add chansigit/studypaper
/plugin install paper-deepstudy@studypaper
```

**前置要求:**

- 已安装 [`claude-paper`](https://github.com/alaliqing/claude-paper) 插件(plugin manifest 已声明依赖,但目前 marketplace 不会自动装依赖,需手动先装)。
- `pdftotext`(来自 `poppler-utils`)在 `PATH` 中用于全文抽取。可选;如果缺失,orchestrator 会退化成把 `paper.pdf` 直接传给 sub-agent。
  - macOS:`brew install poppler`
  - Debian/Ubuntu:`sudo apt install poppler-utils`

### 快速上手

```text
# 一键全自动(下载 + 研读 + 审稿 + 渲染笔记)
/paper:study https://arxiv.org/abs/1706.03762

# 对抗式审稿
/paper:review-round

# 子话题深度展开
/paper:deep-dive "scaled dot-product attention 推导"

# 与另一篇论文做正面比较
/paper:compare BERT --lang zh

# 可复现性审计
/paper:reproduce-check
```

所有产物落在 `~/claude-papers/papers/<slug>/`。任何命令在覆盖现有文件前都会备份成 `<file>.bak.NN`,所以可以放心迭代。

### 你会得到什么

每篇论文 12 个产物,放在 `~/claude-papers/papers/<slug>/`:

```text
analysis/
  00-paper-profile.md       # 论文类型、领域、难度(英文,YAML frontmatter)
  01-problem.md             # 问题背景与框定(英文)
  02-formalization.md       # 数学定义、损失、约束(英文)
  03-method-deep.md         # 方法精读 + rationale + 候选方案(英文)
  04-experiments.md         # 实验批评(英文)
  05-prior-work.md          # 时间线 + 对比(英文)
  06-figures.md             # 逐图解读 + 评分(英文)
review.md                   # 学术审稿风格报告(英文)
review-rounds/              # 每次 /paper:review-round 一个文件(英文)
deep-dives/                 # 每次 /paper:deep-dive 一个文件(英文)
compares/                   # 每次 /paper:compare 一个文件
reproduce-check.md          # 7 维可复现性审计(英文)
notes/
  source.md                 # 统一 source 内容(中文)
  titles.md                 # 5+5 候选标题(中文)
  xhs.md                    # 小红书渲染(中文,~1000 字)
  wechat.md                 # 微信渲染(中文,~3000 字)
```

### 命令一览

| 命令 | 用途 |
|---|---|
| `/paper:study <pdf-or-url>` | 一键全自动 pipeline |
| `/paper:rerun-stage <stage>` | 重跑单个 stage(`analysis` / `review` / `notes` / `profile`) |
| `/paper:review-round` | 对抗式审稿一轮(objection → defense → 盲审 judge → 用户) |
| `/paper:refine-notes <variant>` | 对 `xhs.md` 或 `wechat.md` 应用一条修改指令 |
| `/paper:retitle <variant>` | 重新生成 5 个候选标题 |
| `/paper:reselect-figures` | 重新选取嵌入哪些图 |
| `/paper:deep-dive <topic>` | 子话题深度展开 |
| `/paper:compare <target>` | 与另一篇论文做正面比较 |
| `/paper:add-prior-work <ref>` | 增补一条先前工作(arXiv URL / BibTeX / DOI) |
| `/paper:reproduce-check` | 7 维可复现性审计 |

不带参数运行任何命令可看 inline help,完整参考见 [`paper-deepstudy/README.md`](paper-deepstudy/README.md)。

### 示例

对真实论文跑过 pipeline 的产物:

- [`examples/string-database-2025/`](examples/string-database-2025/) —— 在《The STRING database in 2025》上跑完整 pipeline(`cs-bio` / `protein-function` 数据库类论文)。包含对抗审稿、深度展开、跨论文比较、可复现性审计和双语笔记 —— 都是 live 集成测试生成的真实产物。

### 仓库结构

```text
studypaper/
├── .claude-plugin/
│   └── marketplace.json     # marketplace 注册(让插件可被安装的关键)
├── paper-deepstudy/         # 插件本体
│   ├── .claude-plugin/plugin.json
│   ├── commands/            # 10 个 slash 命令
│   ├── skills/              # orchestration 技能(study-deep, review-round, ...)
│   ├── prompts/             # 18 个 sub-agent 提示词
│   ├── templates/           # 所有产物的模板
│   ├── domain-packs/        # 7 个领域知识包
│   ├── scripts/             # 辅助脚本(verify-prereqs, parse-judge-output, ...)
│   └── tests/               # 146 bats + 4 node + 集成 smoke
├── examples/                # 精选真实论文产物
└── docs/                    # 设计 spec 和实现 plan
```

### 贡献

项目遵循 TDD。运行测试套件:

```bash
cd paper-deepstudy
npm install      # 一次性,装 bats-core
npm run test:unit
```

所有结构性断言基于 bats;纯逻辑 helper 有 node 测试脚本。集成 smoke test(`tests/integration/test-end-to-end.sh`)验证文件级 wiring,不会真的派 sub-agent。

非平凡改动遵循 [Superpowers](https://github.com/jasonkneen/superpowers) 工作流:brainstorming → spec → plan → subagent-driven 实现。Spec 在 `docs/superpowers/specs/`,plan 在 `docs/superpowers/plans/`。

### 许可

MIT。详见 [LICENSE](LICENSE)(待补)。

### 致谢

构建在 `alaliqing` 的 [`claude-paper`](https://github.com/alaliqing/claude-paper) 之上。工作流模式(TDD、subagent-driven 开发、brainstorming)来自 [`superpowers`](https://github.com/jasonkneen/superpowers) 技能库。
