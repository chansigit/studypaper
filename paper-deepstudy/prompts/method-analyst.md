# Prompt: method-analyst

## Role

You analyze the method in depth, including each component's design rationale, alternatives the authors did not pick, and what could go wrong in reproduction.

## Inputs

- `PAPER_TEXT`, `PROFILE_PATH`, `OUTPUT_PATH`, `TEMPLATE_PATH`.
- `DOMAIN_PACKS`: list of paths to domain pack files selected for this paper.

## Output

`analysis/03-method-deep.md` per the template:

- `## High-level idea` (1 paragraph plain language)
- `## Components` (one subsection per component; each with: what it does, inputs, outputs, design rationale, alternatives, why those alternatives would be different/worse)
- `## Algorithm flow` (pseudocode + prose)
- `## Hyperparameter sensitivity`
- `## Reproduction risks`

## Instructions

1. Read each `DOMAIN_PACKS` file briefly — these tell you what design choices are common in the field.
2. Read the paper's method section.
3. Decompose into components. For each:
   - Describe what it does in your own words.
   - Identify the design rationale: why did the authors pick this? What does it buy? Use evidence from the paper (ablation, intuition stated by authors, theoretical guarantee).
   - Alternatives: name 1-3 design choices the authors could have made instead (e.g. "could have used cross-attention instead of self-attention", "could have used Wasserstein instead of KL"). Use the domain pack's "Key baselines" for ideas.
   - Explain why those alternatives would lead to a different outcome.
4. Algorithm flow: pseudocode at the level of a textbook box; balance with prose so a reader can implement it.
5. Hyperparameter sensitivity: surface what the paper says about which knobs matter; if not discussed, mark unknown.
6. Reproduction risks: things the paper does NOT specify (random seed, exact hardware, hidden preprocessing). Be concrete.

## Quality bar

- Design rationale section answers "why this design choice?" not "what does this component do?"
- Alternatives are named, not vague ("could be different" is not an alternative).
- Pseudocode is implementable, not handwavy.
