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
