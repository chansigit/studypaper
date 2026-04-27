# Pack: protein-structure

Papers about predicting or modeling protein 3D structure: monomers, complexes, conformational ensembles, and structure-aware downstream tasks (binding, design, dynamics). Almost always paired with `ml-pure` when the contribution is a new model or training recipe.

## Core problems

- Single-chain (monomer) structure prediction from sequence
- Multimer / complex structure prediction (homo- and heteromeric)
- Conformational ensembles and dynamics (vs. single static structure)
- Inverse folding (sequence given structure)
- Structure-aware function / binding-site prediction
- De novo protein design conditioned on shape or function
- Cryo-EM map interpretation and refinement

## Key baselines

- **AlphaFold2** (Jumper et al., 2021, Nature): MSA + Evoformer + structure module; the dominant accuracy baseline for monomers.
- **AlphaFold-Multimer / AlphaFold3** (2022 / 2024): extends to complexes; AF3 also handles ligands / nucleic acids.
- **RoseTTAFold / RoseTTAFold-AA** (Baek et al., 2021–2024): three-track architecture; all-atom variant for biomolecular complexes.
- **OmegaFold / ESMFold** (Wu et al., 2022 / Lin et al., 2023, Science): single-sequence (no MSA) prediction via protein language models.
- **Chai-1 / Boltz-1** (2024): open-source AF3-style multimer/ligand models.
- **RFDiffusion** (Watson et al., 2023, Nature): SE(3) diffusion for de novo design; standard generative baseline.
- **ProteinMPNN** (Dauparas et al., 2022, Science): inverse-folding standard.
- **AlphaFlow / Distributional Graphormer** (2024): conformational ensemble baselines.

## Common datasets

- **PDB**: ~220k experimentally determined structures; the field's reference truth.
- **CASP14 / CASP15 / CASP16**: blind community benchmark every 2 years; the gold standard for monomer/complex evaluation.
- **CAMEO**: weekly continuous benchmark from new PDB releases.
- **Posebusters**: ligand-pose benchmark stress-testing AF3-style claims.
- **AFDB / ESM Atlas**: 200M+ predicted structures; dataset-scale baselines for downstream tasks.
- **OpenProteinSet**: MSAs and templates derived from UniRef / BFD / MGnify, the standard input feature corpus.

## Standard metrics

- **TM-score**: global topology similarity, [0, 1]; > 0.5 ≈ same fold. Insensitive to small displacements.
- **lDDT / lDDT-Cα**: local distance difference; AlphaFold's default. Robust to domain motion. lDDT-Cα is per-residue.
- **GDT-TS / GDT-HA**: CASP traditional metric; GDT-HA is the higher-accuracy variant.
- **DockQ**: complex interface quality (Jaccard-style on contacts + RMSD on interface). Standard for multimer.
- **RMSD-Cα / heavy-atom**: report aligned region; prone to misleading results on flexible regions if not paired with TM-score / lDDT.
- **PoseBusters checks** for ligand-bound predictions: stereochemistry, steric clashes, energy ratio.

## Reviewer checklist

- [ ] Was evaluation on CASP-blind targets, or only retrospective splits? Retrospective splits leak via PDB release date.
- [ ] Was MSA depth controlled? Methods often degrade silently on shallow alignments — orphan / single-sequence performance reported?
- [ ] For multimer claims: is DockQ reported, or only TM-score on the concatenated chain (which can hide bad interfaces)?
- [ ] For "AlphaFold-quality" claims on a new method: head-to-head on the same target set, with the same MSA, or is the comparison apples-to-oranges?
- [ ] If predictions involve ligands / cofactors, are PoseBusters-style validity checks reported? AF3-style outputs can be physically implausible without these.
- [ ] Is per-residue confidence (pLDDT / PAE) calibration shown — i.e. does claimed confidence correlate with realized accuracy?
- [ ] For ensemble / dynamics claims: is the metric tied to physical observables (e.g. NMR S² order parameters, MD ensembles) or just diversity?
- [ ] For design papers: is wet-lab validation included (e.g. AlphaFold of designs, soluble expression, binding K_D), or only in-silico self-consistency?
- [ ] Compute reported reproducibly (GPU type / hours / inference latency)?
- [ ] Train/test leakage check: are PDB chains in the test set strictly disjoint from training (sequence ID < 30%, structure cluster TM-score < 0.5)?
