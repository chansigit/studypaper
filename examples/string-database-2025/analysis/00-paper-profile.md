---
slug: string-database-2025
title: The STRING database in 2025: protein networks with directionality of regulation
paper_type: dataset
domain: cs-bio
bio_subfield: protein-function
difficulty: intermediate
domain_packs_selected:
  - ml-pure
  - protein-function
key_baselines_detected:
  - Reactome
  - KEGG
  - BioGRID
  - IntAct
  - MINT
  - Complex Portal
  - SIGNOR
  - GeneMANIA
claims_summary:
  - STRING 12.5 introduces directed regulatory networks using fine-tuned LLM to extract regulatory interaction directionality from literature.
  - Integrates three distinct network types (functional, physical, regulatory) with mode-specific confidence scoring and benchmarking.
  - Improved enrichment analysis with adaptive FDR correction, redundancy filtering, and enriched dot-plot visualization.
  - Provides downloadable network and sequence embeddings for cross-species protein comparison and ML-ready representations.
  - Expands co-expression networks with single-cell RNA-seq data from cellxgene and EBI atlases.
---

# Paper Profile

## Why these tags

STRING is a database/dataset paper introducing major updates to a foundational protein-interaction resource. The `cs-bio` domain reflects that both computer science and biology are first-class: protein networks and systems biology (biology), a fine-tuned RoBERTa-based language model for relation extraction (ML/NLP), and enrichment analysis methods (bioinformatics). Importantly, the language model is a methodological contribution for extracting regulatory directionality from unstructured literature at scale—not merely a tool, but a core component of the 2025 update. The `protein-function` subfield is chosen because protein-protein interactions, regulatory networks, and functional associations are central; single-cell RNA-seq is integrated but auxiliary. The `ml-pure` pack is included because the regulatory network construction pipeline uses a fine-tuned transformer model with non-trivial performance engineering (F1 73.5%), and the embeddings section addresses cross-species ML transfer. Difficulty is `intermediate` for readers familiar with bioinformatics and network analysis.

## What to expect downstream

Downstream analyses should prioritize the fine-tuned LLM pipeline for regulatory relation extraction—the architecture, training data (RegulaTome), generalization across relation types, and benchmarking against curated sources (SIGNOR, KEGG, Reactome). The enrichment analysis improvements (adaptive FDR correction, similarity-based filtering) are novel statistical methodologies warranting validation on diverse query gene sets. The cross-species embedding alignment technique (FedCoder-based) is underspecified in the abstract and needs detailed scrutiny. Coverage and validation claims for single-cell co-expression expansion should be examined. The paper's practical utility hinges on regulatory network accuracy and integration; ML methodology and embedding sections are secondary but non-trivial contributions.
