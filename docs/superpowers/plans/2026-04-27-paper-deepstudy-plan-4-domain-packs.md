# paper-deepstudy Plan 4: Additional Domain Packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 5 more domain packs to `paper-deepstudy/domain-packs/` so the auto-run pipeline produces domain-aware analysis and review for protein-structure, protein-function, genomics, drug-discovery, and medical-imaging papers (in addition to Plan 1's `ml-pure` and `single-cell`).

**Architecture:** Each domain pack is a single markdown file conforming to the `_template.md` schema (Pack/Core problems/Key baselines/Common datasets/Standard metrics/Reviewer checklist). The orchestration skill (`paper-profiler` in Plan 1) already detects and selects packs at runtime; adding packs requires only the file under `paper-deepstudy/domain-packs/<slug>.md` plus a structural test. No code changes needed.

**Tech Stack:**
- Markdown (knowledge files)
- Bats (structural unit tests)
- Plan 4 inherits Plan 1+2's plugin layout — no new tools, scripts, or commands.

**Key design decisions (carried from spec §7):**
- **Static knowledge files, not code.** Each pack is curated by hand. The reviewer checklists are the load-bearing section — they shape what `experiment-critic` and `prior-work-historian` look for.
- **Evolvable.** Easy to update / add as the field changes; no schema migration.
- **Quality bar per pack:** must enable a domain-aware reviewer to spot weak baselines, missing benchmarks, and overstated claims for that subfield.

---

## File Structure

The plugin source lives at `/Users/chensijie/Projects/studypaper/paper-deepstudy/`:

```
paper-deepstudy/
├── domain-packs/
│   ├── _template.md                (Plan 1)
│   ├── ml-pure.md                  (Plan 1)
│   ├── single-cell.md              (Plan 1)
│   ├── protein-structure.md        (NEW — Task 1)
│   ├── protein-function.md         (NEW — Task 2)
│   ├── genomics.md                 (NEW — Task 3)
│   ├── drug-discovery.md           (NEW — Task 4)
│   └── medical-imaging.md          (NEW — Task 5)
└── tests/
    ├── unit/
    │   └── test-domain-packs.bats  (modified — append 5 @tests, one per new pack)
    └── integration/
        └── test-end-to-end.sh      (no change — its check #5 currently lists ml-pure, single-cell, _template; would not require updating since it's not exhaustive. We'll extend it for completeness, see Task 6.)
```

Every pack follows the schema from `_template.md`:

```markdown
# Pack: <name>

<one-paragraph summary>

## Core problems
- ...

## Key baselines
- **<Baseline>** (<year>): <one-line description>
- ...

## Common datasets
- **<Dataset>**: <task definition; rough scale; standard split>
- ...

## Standard metrics
- **<Metric>**: <how computed; caveats>
- ...

## Reviewer checklist
- [ ] <Question>
- ...
```

---

## Pre-flight

1. Plan 2 must be merged to `main` (this branch should be off the post-Plan-2 main).
2. Existing tests pass:
   ```bash
   cd paper-deepstudy && npm run test:unit && cd ..
   paper-deepstudy/tests/integration/test-end-to-end.sh
   ```
   Expect 60 bats + 2 node + integration smoke pass.

---

### Task 1: protein-structure domain pack

**Files:**
- Create: `paper-deepstudy/domain-packs/protein-structure.md`
- Modify: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "protein-structure.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/protein-structure.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

Run: `bats paper-deepstudy/tests/unit/test-domain-packs.bats`
Expected: 1 new failure.

- [ ] **Step 3: Write the pack**

`paper-deepstudy/domain-packs/protein-structure.md`:

```markdown
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
```

- [ ] **Step 4: Run, verify pass**

Run: `bats paper-deepstudy/tests/unit/test-domain-packs.bats`
Expected: all tests pass (existing 3 + 1 new = 4).

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/domain-packs/protein-structure.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): protein-structure domain pack"
```

---

### Task 2: protein-function domain pack

**Files:**
- Create: `paper-deepstudy/domain-packs/protein-function.md`
- Modify: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "protein-function.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/protein-function.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the pack**

`paper-deepstudy/domain-packs/protein-function.md`:

```markdown
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
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/domain-packs/protein-function.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): protein-function domain pack"
```

---

### Task 3: genomics domain pack

**Files:**
- Create: `paper-deepstudy/domain-packs/genomics.md`
- Modify: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "genomics.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/genomics.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the pack**

`paper-deepstudy/domain-packs/genomics.md`:

```markdown
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
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/domain-packs/genomics.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): genomics domain pack"
```

---

### Task 4: drug-discovery domain pack

**Files:**
- Create: `paper-deepstudy/domain-packs/drug-discovery.md`
- Modify: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "drug-discovery.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/drug-discovery.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the pack**

`paper-deepstudy/domain-packs/drug-discovery.md`:

```markdown
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
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/domain-packs/drug-discovery.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): drug-discovery domain pack"
```

---

### Task 5: medical-imaging domain pack

**Files:**
- Create: `paper-deepstudy/domain-packs/medical-imaging.md`
- Modify: `paper-deepstudy/tests/unit/test-domain-packs.bats`

- [ ] **Step 1: Append failing test**

```bash
@test "medical-imaging.md has required sections" {
  run check_pack paper-deepstudy/domain-packs/medical-imaging.md
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Write the pack**

`paper-deepstudy/domain-packs/medical-imaging.md`:

```markdown
# Pack: medical-imaging

Papers about machine learning on medical images: radiology (CT / MRI / X-ray / mammography), pathology (whole-slide histology), ophthalmology (retinal photographs / OCT), dermatology, cardiac imaging, microscopy, and ultrasound. Often pairs with `ml-pure` for backbone methodology; rarely with bio-omics packs.

## Core problems

- Disease classification from images
- Lesion / tumor / organ segmentation
- Detection and localization of findings
- Image registration (multi-modal, longitudinal, atlas)
- Image generation / synthesis (cross-modality, super-resolution, denoising)
- Report generation from images (radiology / pathology)
- Survival / outcome prediction from images
- Federated and privacy-preserving learning
- Foundation models for medical imaging (CLIP-style multimodal)

## Key baselines

- **U-Net / nnU-Net** (Ronneberger et al., 2015; Isensee et al., 2021, Nat Methods): nnU-Net is the de-facto segmentation baseline — auto-configures and is hard to beat.
- **Swin UNETR / TransBTS / SegFormer**: transformer segmentation baselines.
- **MedSAM / SAM-Med2D / SAM-Med3D** (Ma et al., 2024+): adapted SAM for medical images; standard interactive-segmentation baseline.
- **DenseNet-121 / EfficientNet on CheXpert**: classification baselines for chest X-ray.
- **CLAM / TransMIL / DSMIL** (2020–2022): multiple-instance-learning baselines for whole-slide pathology.
- **CONCH / UNI / GigaPath / PRISM** (2024): pathology foundation models.
- **CheXzero / BiomedCLIP / MedCLIP / RadFM**: medical-imaging-text foundation models.
- **MONAI** library models: standard reference implementations.
- **Radiologist / pathologist ground truth**: the comparison that matters most for clinical claims.

## Common datasets

- **ImageNet pretraining**: not medical, but most baselines start here. Whether ImageNet pretraining helps depends on the task; ablations matter.
- **CheXpert / NIH ChestX-ray14 / MIMIC-CXR**: chest X-ray classification benchmarks.
- **TCIA**: 130+ public radiology collections; the closest thing to a hub.
- **BraTS**: brain tumor segmentation challenge (multi-modal MRI); long-running benchmark.
- **KiTS / LiTS / AMOS**: organ / tumor segmentation challenges.
- **ISIC**: dermatology classification benchmark.
- **CAMELYON16 / CAMELYON17**: pathology metastasis-detection benchmarks.
- **TCGA pathology slides**: cross-cohort cancer-pathology corpus.
- **EyePACS / Messidor / OCTID**: ophthalmology benchmarks.
- **UK Biobank / NLST / NHANES imaging subsets**: large epidemiology imaging cohorts.
- **MedNIST / DeepLesion**: smaller benchmarks useful for fast iteration.

## Standard metrics

- **Dice coefficient (DSC) / IoU**: segmentation; report per-class. Macro-Dice ≠ micro-Dice on unbalanced data.
- **Hausdorff distance (95% HD)**: segmentation surface error; pairs with Dice for clinically meaningful evaluation.
- **AUROC / AUPRC**: classification; AUPRC matters under low prevalence (most diseases).
- **Sensitivity / Specificity at clinical operating points**: more interpretable than AUROC alone for screening.
- **Free-response ROC (FROC)**: detection with variable thresholds; standard for chest X-ray / mammography detection.
- **C-index** for survival prediction.
- **BLEU / ROUGE / CIDEr / RadGraph-F1**: report-generation metrics; RadGraph-F1 is the most clinically grounded of these.
- **Reader study agreement (κ, AUC vs. radiologists)**: the strongest clinical claim.

## Reviewer checklist

- [ ] Was the test split done by **patient**, not by image? Multi-image-per-patient leakage is a classic mistake.
- [ ] For multi-site claims: was at least one site held out entirely (external validation)? In-distribution metrics inflate by 5-15 points typically.
- [ ] For "matches radiologist" claims: was a **prospective** reader study run, or only retrospective comparison? Retrospective reader studies have known biases.
- [ ] Are sensitivity / specificity at clinically reasonable operating points reported, or only AUROC? AUROC > 0.95 can hide bad operating-point behavior.
- [ ] For pathology: is staining / scanner variation accounted for (e.g. stain normalization, multi-scanner training)? Whole-slide papers leak via institutional artifacts.
- [ ] For segmentation: is nnU-Net included as a baseline? It auto-configures and routinely beats new methods that don't include it fairly.
- [ ] Class imbalance handled or hidden? Especially for rare findings, the macro / per-class breakdown matters.
- [ ] For foundation-model / CLIP-style work: is zero-shot performance reported on truly held-out conditions, or are training and eval sets entangled?
- [ ] For report generation: are the metrics (BLEU/ROUGE) supplemented by radiologist evaluation or fact-checking metrics (RadGraph-F1, F1-CheXbert)? Word-overlap metrics are notoriously misleading for clinical text.
- [ ] Privacy / IRB / data-sharing terms disclosed? Medical imaging has significant compliance footprint.
- [ ] Compute and inference latency reported, especially for clinical-deployment claims.
- [ ] Did the model see test-set institution / scanner / vendor during training? Vendor leakage is a common subtle issue.
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add paper-deepstudy/domain-packs/medical-imaging.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "feat(paper-deepstudy): medical-imaging domain pack"
```

---

### Task 6: Integration smoke test extension

**Files:**
- Modify: `paper-deepstudy/tests/integration/test-end-to-end.sh`

- [ ] **Step 1: Read current state of integration test**

The existing check #5 lists 3 packs (`ml-pure single-cell _template`). Extend to include the 5 new ones.

- [ ] **Step 2: Modify the script**

Find this block in `paper-deepstudy/tests/integration/test-end-to-end.sh`:

```bash
# 5. Domain packs exist
for d in ml-pure single-cell _template; do
  if [ ! -f "$ROOT/domain-packs/$d.md" ]; then
    echo "FAIL: domain pack missing: $d.md"; fail=1
  fi
done
```

Replace with:

```bash
# 5. Domain packs exist
for d in ml-pure single-cell protein-structure protein-function genomics drug-discovery medical-imaging _template; do
  if [ ! -f "$ROOT/domain-packs/$d.md" ]; then
    echo "FAIL: domain pack missing: $d.md"; fail=1
  fi
done
```

- [ ] **Step 3: Run, verify pass**

```bash
paper-deepstudy/tests/integration/test-end-to-end.sh
```
Expected: `Integration smoke test: PASSED`.

- [ ] **Step 4: Commit**

```bash
git add paper-deepstudy/tests/integration/test-end-to-end.sh
git commit -m "test(paper-deepstudy): integration smoke covers all 7 domain packs"
```

---

### Task 7: README + paper-profiler prompt updates

**Files:**
- Modify: `paper-deepstudy/README.md`
- Modify: `paper-deepstudy/prompts/paper-profiler.md`

The paper-profiler prompt's `AVAILABLE_PACKS` example currently lists only `ml-pure, single-cell, protein-structure, ...` — but our actual packs in main-after-Plan-1 were just `ml-pure` and `single-cell`. After Plan 4 the profiler should know about all 7 packs by name. README's roadmap section should mark Plan 4 done.

- [ ] **Step 1: Append failing tests**

Append to `paper-deepstudy/tests/unit/test-domain-packs.bats`:

```bash
@test "paper-profiler prompt mentions all 7 domain packs in AVAILABLE_PACKS examples" {
  for pack in ml-pure single-cell protein-structure protein-function genomics drug-discovery medical-imaging; do
    grep -qF "$pack" paper-deepstudy/prompts/paper-profiler.md || { echo "missing pack reference: $pack"; return 1; }
  done
}
```

(NOTE: this test runs from repo root, so use the full relative path `paper-deepstudy/...` — but `test-domain-packs.bats` doesn't have a `setup()` block stripping `paper-deepstudy/` prefix. Verify: read the top of `test-domain-packs.bats` to confirm. If it does have `setup()`, use just `prompts/paper-profiler.md` instead.)

Actually, re-checking: `test-domain-packs.bats` was created in Plan 1 Task 3 and updated in Plan 1's holistic-fix commit `621c32e` to use `setup()` cd-ing to plugin root. So inside the bats file, paths should be relative to `paper-deepstudy/`. Use `prompts/paper-profiler.md`:

```bash
@test "paper-profiler prompt mentions all 7 domain packs in AVAILABLE_PACKS examples" {
  for pack in ml-pure single-cell protein-structure protein-function genomics drug-discovery medical-imaging; do
    grep -qF "$pack" prompts/paper-profiler.md || { echo "missing pack reference: $pack"; return 1; }
  done
}
```

- [ ] **Step 2: Run, verify fail**

```bash
bats paper-deepstudy/tests/unit/test-domain-packs.bats
```
Expected: 1 new failure (current paper-profiler.md only mentions some packs).

- [ ] **Step 3: Update paper-profiler.md**

Read `paper-deepstudy/prompts/paper-profiler.md`. Find this line:

```
- `AVAILABLE_PACKS`: list of available domain pack slugs (e.g. `ml-pure`, `single-cell`, `protein-structure`, ...).
```

Replace with:

```
- `AVAILABLE_PACKS`: list of available domain pack slugs. Currently shipping: `ml-pure`, `single-cell`, `protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`.
```

- [ ] **Step 4: Update README.md**

Read `paper-deepstudy/README.md`. Find the Roadmap line for Plan 4:

```
- **Plan 4:** five more domain packs (`protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`).
```

Replace with:

```
- **Plan 4 (this branch):** five more domain packs (`protein-structure`, `protein-function`, `genomics`, `drug-discovery`, `medical-imaging`). ✓
```

- [ ] **Step 5: Run, verify pass**

```bash
bats paper-deepstudy/tests/unit/test-domain-packs.bats
paper-deepstudy/tests/integration/test-end-to-end.sh
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add paper-deepstudy/prompts/paper-profiler.md paper-deepstudy/README.md paper-deepstudy/tests/unit/test-domain-packs.bats
git commit -m "docs(paper-deepstudy): paper-profiler and README know about all 7 domain packs"
```

---

## Self-Review checklist (run after Plan 4 complete)

- [ ] All 5 new domain pack files exist under `paper-deepstudy/domain-packs/`.
- [ ] Each new pack has all 6 required sections (`# Pack:`, `## Core problems`, `## Key baselines`, `## Common datasets`, `## Standard metrics`, `## Reviewer checklist`).
- [ ] `cd paper-deepstudy && npm run test:unit` passes (bats now covers 8 domain pack tests + paper-profiler check, plus all prior tests).
- [ ] `paper-deepstudy/tests/integration/test-end-to-end.sh` passes; check #5 verifies all 7 packs.
- [ ] paper-profiler prompt's `AVAILABLE_PACKS` description lists all 7 shipped packs.
- [ ] README's roadmap marks Plan 4 done with ✓.
- [ ] No Claude co-author on any commit.
- [ ] Each commit is one pack (or one consolidation), not "5 packs in one commit".

---

## Quality bar for content

The reviewer checklists in each pack are the load-bearing section — they're injected into `experiment-critic` and used by `prior-work-historian`. A pack passes the quality bar when:

- A domain-aware reviewer reading the checklist would say "yes, those are the questions I'd ask".
- The key baselines list contains the dominant 5-10 methods of the last 3 years; missing any of `AlphaFold2`, `ESM-2`, `Enformer`, `nnU-Net`, `DiffDock` etc. in their respective packs is a defect.
- Datasets cover both the historical benchmarks (CASP, MoleculeNet, BraTS) and the current standards (PoseBusters, ProteinGym, CAMELYON17).
- Metrics include known-pitfall annotations (e.g. "AUROC misleading under imbalance — also report AUPRC").

If a future code reviewer flags any of these as weak, add to the pack rather than starting a new plan — domain packs are explicitly evolvable per spec §7.1.

---

## Live test recipe (manual, post-implementation)

After all 7 tasks ship:

1. Find a paper in one of the 5 new domains (e.g. AlphaFold3 paper for `protein-structure`, an Enformer-style paper for `genomics`, a DiffDock-style paper for `drug-discovery`).
2. Run `/paper:study <pdf|url>` on it.
3. Verify Stage 0 produces `analysis/00-paper-profile.md` with the right `domain_packs_selected` (e.g. `protein-structure` + `ml-pure` for AlphaFold3).
4. Verify the resulting `analysis/04-experiments.md` "Critique" section references questions from the new pack's reviewer checklist.
5. Verify `analysis/05-prior-work.md` lists baselines from the new pack's "Key baselines" list (e.g. RoseTTAFold, ESMFold for protein-structure).

If the auto-run skips a relevant pack or doesn't use its checklist, file as a follow-up issue — not a Plan 4 blocker, since paper-profiler may need prompt iteration to recognize edge cases.
