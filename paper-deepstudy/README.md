# paper-deepstudy

Deep paper study for ML and computational-biology papers. Layers on top of `claude-paper:study` to add:

- Deep analysis (problem framing, formal definition, methodology, experiments, prior-work timeline, figure interpretation) — English
- Iterative review with adversarial review rounds — English
- Chinese learning notes for Xiaohongshu / WeChat from a unified source

## Install (local dev)

```
# from this repo's root:
/plugin install ./paper-deepstudy
```

Requires `claude-paper:study` already installed.

## Usage

```
/paper:study <pdf-path-or-url>
```

Outputs land under `~/claude-papers/papers/<slug>/`. See `docs/superpowers/specs/2026-04-26-paper-deepstudy-design.md` for the full design.
