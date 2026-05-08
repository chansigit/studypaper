# Pack: ml-pure

General machine-learning papers without a strong domain-specific component (NLP, CV, RL, generic deep learning). Use as a fallback or in combination with a more specific pack.

## Core problems

- Supervised classification / regression
- Self-supervised representation learning
- Generative modeling (text, image, multimodal)
- Sequence modeling
- Reinforcement learning / decision making

## Key baselines

- **Transformer** (2017): attention-based seq2seq backbone, displaced RNNs for long-range dependencies.
- **ResNet** (2015): residual connections, default vision backbone for many years.
- **BERT / GPT family**: pretrained-then-finetuned (BERT) vs autoregressive (GPT) — should be cited as baselines for any new LM.
- **CLIP**: contrastive image–text pretraining, default zero-shot vision baseline.
- **Diffusion models** (DDPM): generative baseline for continuous data.

## Common datasets

- **ImageNet-1k**: 1.28M training images, 1000 classes; classification standard.
- **GLUE / SuperGLUE**: NLU benchmark suite.
- **COCO**: object detection / captioning, 118k train images.
- **C4 / The Pile**: large pretraining corpora.

## Standard metrics

- **Accuracy / Top-k accuracy**: assumes balanced classes; report per-class breakdown when imbalanced.
- **AUROC**: misleading under heavy class imbalance — also report PR-AUC.
- **F1 / macro-F1**: prefer macro-F1 when class imbalance matters.
- **Perplexity**: language modeling; comparable only when same tokenizer & corpus.
- **FID / IS**: generative quality; FID is sensitive to feature extractor choice.

## Reviewer checklist

- [ ] Are baselines from the last 18 months included?
- [ ] Is the comparison fair (same training data, compute, hyperparameter budget)?
- [ ] Is variance reported across seeds (≥3)?
- [ ] Are ablations decisive — does each removed component clearly hurt?
- [ ] Are claims commensurate with evidence (no "SOTA" without head-to-head)?
- [ ] Are failure cases shown?
- [ ] Is compute / data scale reported reproducibly?
- [ ] Code & weights released, or release planned with a license?
