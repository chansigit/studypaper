# Pack: drug-discovery

Papers about machine learning for small-molecule and drug discovery: molecular property prediction, generative chemistry, virtual screening, docking and pose prediction, structure-based and ligand-based drug design, ADMET, and reaction prediction. Pairs with `ml-pure` for methodology and with `protein-structure` for binding-site / pose work.

## Core problems

- Molecular property prediction (ADMET, QSAR)
- Virtual screening (rank a library against a target)
- Docking / pose prediction (where does the ligand sit?)
- Structure-based design (generate ligands fitting a pocket)
- Ligand-based design (generate analogs / lead optimization)
- De novo molecular generation with property constraints
- Synthetic accessibility and retrosynthesis
- Reaction yield / outcome prediction
- Free-energy estimation (binding affinity)

## Key baselines

- **MolGAN / JTNN / GraphAF / GFlowNet variants** (2018+): older generative baselines.
- **Chemprop / D-MPNN** (Yang et al., 2019): the de-facto property-prediction baseline (still strong).
- **MoleculeNet baselines**: random forests with Morgan fingerprints — surprisingly competitive; should always be compared.
- **DiffDock / DiffDock-L** (Corso et al., 2022; 2024): SE(3) diffusion for blind docking; the dominant ML-docking baseline.
- **Pocket2Mol / TargetDiff / DecompDiff** (2022–2024): structure-conditioned generation.
- **AlphaFold3 / Boltz-1 / Chai-1** (2024): protein-ligand co-folding; new strong baselines for pose prediction.
- **AutoDock Vina / Smina / Glide**: classical docking baselines that remain competitive on PoseBusters.
- **REINVENT / Mol2Mol / Saturn**: generative baselines used in pharma pipelines.
- **GNINA**: CNN scoring for docking.
- **Equivariant Transformer / SchNet / PaiNN / MACE**: 3D-equivariant property regression baselines.

## Common datasets

- **MoleculeNet** (Wu et al., 2018): the standard benchmark suite — BBBP, Tox21, ClinTox, BACE, HIV, etc. Has known temporal / scaffold split issues; report which split is used.
- **ChEMBL**: 2M+ bioactivity measurements; the standard ligand-based corpus.
- **PubChem / ZINC22**: massive screening libraries (10⁹+ compounds); used for VS.
- **PDBbind**: protein-ligand structures with affinities; standard binding-affinity benchmark. Report core/refined/general split.
- **CASF-2016**: docking / scoring benchmark derived from PDBbind. The standard public test set for pose / scoring.
- **PoseBusters / Astex Diverse Set**: stress tests for AF3-style co-folding claims.
- **GuacaMol / MOSES**: distribution-learning and goal-directed generation benchmarks.
- **USPTO / Pistachio / Reaxys**: reaction datasets for retrosynthesis / yield prediction.

## Standard metrics

- **AUROC / AUPR** for classification (active vs. inactive); always pair given imbalance.
- **R² / RMSE / MAE** for regression on properties; report per-task on MoleculeNet.
- **Spearman ρ** for ranking-style virtual screening.
- **EF1% / EF5%** (enrichment factor at top fractions): standard VS metric.
- **DUD-E / LIT-PCBA AUROC**: VS-specific, but with known biases (DUD-E memorizes; LIT-PCBA more rigorous).
- **RMSD < 2Å pose accuracy** (top-1 / top-5): standard pose-prediction metric.
- **PoseBusters validity rate**: fraction of poses passing stereochemistry / clash / energy checks. AF3 / Boltz / Chai rocks fail this often without fix.
- **FCD (Fréchet ChemNet Distance)**: distribution-similarity for generated molecules.
- **Validity / Uniqueness / Novelty** triple for generative models.
- **Synthetic accessibility (SA score)**: cheap proxy for synthesizability.
- **TopK accuracy** for retrosynthesis: fraction of correct first-step retrosynthetic predictions.

## Reviewer checklist

- [ ] Are MoleculeNet benchmarks evaluated with **scaffold splits**, not random? Random splits drastically inflate scores by leaking similar scaffolds.
- [ ] For VS: is enrichment factor reported on a held-out target set? Are there shape / property biases between actives and decoys (DUD-E-style)?
- [ ] For docking / pose papers: PoseBusters validity reported, not just RMSD? RMSD-only allows physically impossible poses to count as "successful".
- [ ] For binding-affinity prediction: is the PDBbind split clean (no test ligands ≥ 90% Tanimoto to train)? Most papers claim refined-set R² ~0.6 but leak heavily.
- [ ] For generative chemistry claims: are the generated molecules synthesizable? Was retrosynthesis validation (e.g. AiZynthFinder) reported?
- [ ] Wet-lab follow-up: did *any* of the top-N generated / predicted compounds get tested? Pharma reviewers always ask this; in-silico-only claims are weaker.
- [ ] Free-energy claims: is the comparison vs. classical FEP / TI on a panel of mature targets? "Beats docking" is a weaker claim than "matches FEP".
- [ ] Is the chemical space disclosure realistic (e.g. drug-like Lipinski filter, no PAINS)? Papers can hit good scores by exploring nonsensical chemistry.
- [ ] Time-split evaluations (train pre-2018, test post-2020) help defuse data-leakage concerns.
- [ ] Compute / library-size disclosure: virtual screens that took 1M GPU-hours don't generalize to most pharma use.
- [ ] Code, weights, and curated datasets released? Drug-discovery reproducibility is famously poor.
