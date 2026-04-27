# Pack: protein-function

Papers about predicting protein function from sequence (and sometimes structure): GO term assignment, EC number prediction, subcellular localization, protein-protein interactions, fitness landscapes, and protein language models used as feature extractors. Pairs with `protein-structure` when structure is the primary signal and with `ml-pure` for backbone methodology.

## Core problems

- Sequence-based function annotation (GO terms, EC numbers, Pfam families)
- Subcellular localization prediction
- Protein-protein interaction (PPI) prediction
- Variant effect prediction (deep mutational scanning, missense pathogenicity)
- Fitness landscape modeling (zero-shot from a PLM, or fine-tuned)
- Protein language model (PLM) representation learning at scale
- Function-conditioned generation / design (give me a sequence with desired activity)

## Key baselines

- **ESM-1b / ESM-2 / ESM-3** (Rives et al., 2021; Lin et al., 2023; Hayes et al., 2025): the dominant PLM family. ESM-2 is the de-facto sequence encoder for downstream tasks.
- **ProtTrans / ProtT5** (Elnaggar et al., 2022): transformer family trained on UniRef; used widely as features.
- **DeepGO / DeepGOPlus / DeepGOZero** (Kulmanov et al., 2017–2024): GO-term prediction baselines; CAFA-grade.
- **NetSurfP / NetGO**: classical / hybrid baselines for surface and function annotation respectively.
- **DeepLoc 2.0** (Thumuluri et al., 2022): subcellular localization gold-standard baseline.
- **EVE / EVMutation / GEMME** (Frazer et al., 2021 etc.): variant-effect / fitness baselines using evolutionary signal.
- **AlphaMissense** (Cheng et al., 2023, Science): pathogenicity scoring of missense variants; high-impact comparison target for variant-effect work.
- **PFAM / InterProScan / HMMER**: classical sequence-search baselines that remain hard to beat at large scale.

## Common datasets

- **UniRef50 / UniRef90 / UniProt**: 50M+ sequences (UniRef50); the standard pretraining corpus.
- **CAFA challenges (CAFA3 / CAFA4 / CAFA5)**: blind community benchmark for function annotation.
- **DeepLoc 2.0 dataset**: 28k proteins with experimentally determined localization.
- **ProteinGym** (Notin et al., 2023): 217 deep mutational scans; standard variant-effect benchmark.
- **DMS datasets**: dozens of single-protein deep mutational scans (Adk, GFP, β-lactamase, etc.).
- **STRING / BioGRID**: PPI references for interaction-prediction work.
- **Pfam / SCOPe**: family / superfamily references for evaluation.

## Standard metrics

- **Fmax / AUPR** for multi-label GO prediction: CAFA standard. Fmax is the harmonic-mean-of-precision-recall maximized over thresholds.
- **Smin**: information-content-aware error metric for GO; complements Fmax.
- **Spearman ρ** for variant-effect prediction: rank correlation against experimental fitness; standard on ProteinGym.
- **AUROC** for binary classification (PPI, pathogenicity): always pair with PR-AUC under class imbalance.
- **Hit rate at top-k** for design tasks: fraction of top-k generated sequences that experimentally hit a threshold.
- **Macro-F1** when reporting per-class performance with imbalanced labels (avoid micro-F1 which hides minority-class failures).

## Reviewer checklist

- [ ] Are evaluation splits stratified by sequence identity (e.g. < 30% to training)? PLMs often leak via similarity; random splits inflate scores.
- [ ] For CAFA-style claims: is the comparison done on a blind CAFA round, or a retrospective hold-out? Retrospective tends to overstate.
- [ ] For variant-effect / fitness claims: is ProteinGym used, or a curated DMS subset? Cherry-picking a few easy DMS panels is common.
- [ ] Are zero-shot vs. supervised numbers separated clearly? PLM zero-shot scoring (probability ratio) and fine-tuned heads are different claims.
- [ ] If PPI: are baselines done with realistic negatives (e.g. random pairing) or harder negatives (e.g. homolog-balanced)?
- [ ] If subcellular localization: is the metric reported per-class? "Soluble" / "membrane" baseline accuracy is high; rare classes are where models fail.
- [ ] PLM-as-feature-extractor results: are the comparison features fair (same residue pooling, same number of layers)?
- [ ] If using ESM-3 or other foundation models, are inference cost and license terms disclosed? Many recent PLMs are gated.
- [ ] For design / generation: is wet-lab validation included for at least a small subset? In-silico self-consistency is necessary but not sufficient.
- [ ] Are statistical tests reported for ranking comparisons (Spearman significance, paired bootstrap)?
