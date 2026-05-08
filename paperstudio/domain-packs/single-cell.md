# Pack: single-cell

Papers about single-cell RNA sequencing (scRNA-seq), single-cell ATAC-seq, multi-omics, and foundation models for cellular data. Often paired with `ml-pure` when the contribution is methodological.

## Core problems

- Dimensionality reduction / latent embedding for sparse, high-dimensional gene-by-cell counts
- Batch effect correction (donor / experiment / platform)
- Cell-type annotation (supervised, unsupervised, transfer)
- Gene regulatory network inference
- Trajectory inference / pseudotime
- Multi-modal integration (RNA + ATAC + protein)
- Foundation models for cells (Geneformer / scGPT-style)

## Key baselines

- **Seurat** (Satija et al., 2015+): R toolkit, PCA + clustering + marker-based annotation.
- **Scanpy** (Wolf et al., 2018): Python equivalent, the de facto pipeline.
- **scVI** (Lopez et al., 2018, Nat Methods): VAE for counts; latent space + batch covariate; standard deep baseline.
- **Harmony** (Korsunsky et al., 2019, Nat Methods): batch correction in PCA space, fast and strong.
- **Geneformer** (Theodoris et al., 2023, Nature): transformer foundation model on Genecorpus-30M.
- **scGPT** (Cui et al., 2024, Nat Methods): generative foundation model for single-cell.
- **scFoundation** (Hao et al., 2024, Nat Methods): another foundation model with attention over genes.

## Common datasets

- **Tabula Sapiens / Tabula Muris**: cross-tissue scRNA atlases (human / mouse), 100k+ cells.
- **PBMC (10x Genomics)**: 3k / 10k peripheral blood mononuclear cells; the "MNIST of single-cell".
- **Human Cell Atlas (HCA)**: large multi-tissue reference.
- **Genecorpus-30M**: 30M cells used for Geneformer pretraining.
- **CELLxGENE**: hosted atlas with standardized metadata.

## Standard metrics

- **ASW (Average Silhouette Width)**: cluster compactness; biology-vs-batch separation.
- **iLISI / cLISI**: integration vs cell-type preservation; report both.
- **kBET**: batch-mixing test based on neighborhoods.
- **NMI / ARI** vs known cell-type labels: clustering agreement; sensitive to label resolution.
- **Top-k accuracy** for cell-type prediction: report per-cell-type breakdown — rare types are often where models fail.
- **Pearson correlation on imputed counts**: imputation; held-out gene comparison.

## Reviewer checklist

- [ ] Is scVI (or equivalent deep baseline) compared against?
- [ ] Are batch-effect / integration metrics reported (iLISI / kBET / ASW per batch)?
- [ ] Are rare cell types broken out, not just hidden in macro-averages?
- [ ] Was the test atlas held out at the donor or batch level (not random cell split)?
- [ ] Are cell-type labels from a defensible source (manual annotation by experts, not propagated from the same model)?
- [ ] Are claims tied to biology (specific marker genes, pathways) or only to embedding metrics?
- [ ] Is wet-lab validation (if any) at the level the claim requires? (e.g. perturbation prediction needs perturbation experiment)
- [ ] Is the data cleaning pipeline disclosed (filters on n_genes, mt%, doublet removal)?
- [ ] Is the model size / compute commensurate with claimed gains, vs simpler baselines?
- [ ] Are foundation-model claims backed by zero-shot or fair fine-tuning, not just held-out performance with leakage?
