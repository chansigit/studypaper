# Pack: genomics

Papers about modeling DNA / RNA sequence — variant interpretation, regulatory-element prediction, gene-expression prediction from sequence, splicing, methylation, chromatin state, and DNA / genome foundation models. Often pairs with `ml-pure`, sometimes overlaps with `single-cell` (when scRNA-seq is the readout) or `protein-function` (for variant→protein effects).

## Core problems

- Variant effect prediction at the DNA level (regulatory, splicing, coding)
- Gene-expression prediction from sequence (CRE → expression)
- Chromatin state, accessibility, and TF binding prediction
- Splicing prediction (alternative splicing, cryptic splice sites)
- DNA / RNA methylation prediction
- Long-range genome modeling (enhancer-promoter contacts, 3D structure)
- Foundation models for DNA (Nucleotide Transformer / DNABERT / HyenaDNA / Evo)
- Cell-type-specific regulatory grammar

## Key baselines

- **Enformer** (Avsec et al., 2021, Nat Methods): ~200kb-receptive-field transformer for tracks (CAGE, DNase, histone). The dominant CRE-prediction baseline.
- **Basenji / Basenji2** (Kelley, 2018+): predecessor to Enformer; CNN-only.
- **DeepSEA / DeepBind** (Zhou & Troyanskaya, 2015; Alipanahi et al., 2015): historical baselines for chromatin / TF binding.
- **SpliceAI** (Jaganathan et al., 2019, Cell): the standard splicing-prediction baseline.
- **DeepMethyl / DeepCpG**: methylation baselines.
- **Nucleotide Transformer** (Dalla-Torre et al., 2024, Nat Methods): 2.5B-parameter DNA foundation model, multi-species.
- **DNABERT-2** (Zhou et al., 2024): byte-pair-encoding DNA foundation model.
- **HyenaDNA** (Nguyen et al., 2023): 1Mb-context state-space-style DNA model.
- **Evo / Evo-2** (Nguyen et al., 2024): genome-scale generative model trained on prokaryotes (Evo) or all of life (Evo-2).
- **AlphaMissense** (Cheng et al., 2023, Science): variant pathogenicity from protein context — relevant for coding variants.

## Common datasets

- **ENCODE / Roadmap Epigenomics**: chromatin / TF / RNA tracks across many cell types — the standard supervision for CRE prediction.
- **GTEx**: tissue-specific bulk RNA-seq from ~1000 donors; the reference for tissue-specific expression QTLs.
- **gnomAD**: population variant frequencies — ~750k human exomes / genomes; standard for negative-set construction.
- **ClinVar / HGMD**: variant pathogenicity labels (with caveats — selection bias).
- **1000 Genomes / TOPMed**: population-genomics variant catalogs.
- **MPRA / STARR-seq datasets**: experimental measurements of CRE activity at thousands of variants.
- **ChIP-seq / DNase-seq / ATAC-seq tracks** (ENCODE / IHEC / 4DN): standard for chromatin baselines.
- **MANE Select / RefSeq / GENCODE**: gene model references; necessary to know which one a paper uses for splicing claims.

## Standard metrics

- **AUROC / AUPR** for binary tracks (TF binding, peak calling): always report PR-AUC, since chromatin is sparse.
- **Pearson / Spearman r** for continuous tracks (Enformer-style track regression): per-track values can vary; report average across tracks.
- **R² across genes for held-out genes**: stricter than per-position; what really matters for "predicting expression".
- **Mean squared loss / Poisson NLL** on count-based readouts (CAGE / RNA-seq).
- **Cross-tissue correlation** for tissue-specific predictions: tests whether the model is using tissue features or just average expression.
- **Top-k / hit rate** for variant prioritization: how many causal variants are in the top-k predictions per locus.
- **Effect-size correlation** between predicted and measured QTL effects (e.g. eQTL beta vs. predicted Δexpression): the most credible head-to-head for regulatory variants.

## Reviewer checklist

- [ ] For variant-effect claims: is held-out evaluation on a true OOD chromosome (e.g. chr8 held out from training), or a random split? Random splits leak heavily through linkage.
- [ ] For Enformer-style "predicting expression from sequence" claims: was evaluation across-genes (held-out genes), across-tissues, or both? Same-gene splits dramatically inflate scores.
- [ ] If predicting QTL effects: are the predictions correlated with effect *direction* and *magnitude*, not just whether something is a QTL?
- [ ] For DNA foundation models: zero-shot vs. fine-tuned numbers separated? Some claimed gains evaporate under same-budget fine-tuning of smaller baselines.
- [ ] For splicing: is SpliceAI used as a head-to-head, with the same input window?
- [ ] Are the population-frequency negatives drawn from gnomAD with appropriate AF cutoffs (common variants are usually benign)?
- [ ] For ClinVar-based eval: are conflicting / VUS variants excluded, and is the train/test split by gene rather than by variant?
- [ ] Cross-species claims: was performance reported on at least one held-out species?
- [ ] If using long-context models (HyenaDNA, Evo): does the receptive field actually help (ablate context length)?
- [ ] Compute reproducibility: model size, context length, training hardware, inference cost reported?
