<!-- generated: 2026-04-27T06:31:14Z by review-round-orchestrator (paperstudio v0.1.0) [Plan 7 retrofit] -->
---
round: 1
created_at: 2026-04-27T06:31:14Z
objection: |
  STRING 12.5 reports F1=73.5% on RegulaTome regulatory-relation extraction but provides no head-to-head comparison against other biomedical relation-extraction baselines (BioBERT, PubMedBERT, GPT-4, or even the BioRED benchmark leader). Without such comparisons, readers cannot assess whether 73.5% is competitive, frontier, or 5-10 points behind a proper baseline. The headline number is therefore weakly supported.
dimension: experiment
severity: major
defense: |
  Restatement of the objection: The reviewer argues that STRING 12.5's reported F1=73.5% on regulatory relation extraction lacks head-to-head baselines (BioBERT, PubMedBERT, GPT-4) and therefore readers cannot assess whether this score is competitive or frontier-level performance.

  The case for the defense:

  First, STRING's evaluation metric is not in a vacuum—it is calibrated and operationalized within a production systems biology context. The paper states "achieved an average F1 score of 73.5% (with precision 75.2%, recall 71.8%)" on the RegulaTome held-out test set (paper §Methods). The task is multi-label extraction of eight regulatory relation types. The RegulaTome corpus (16,961 manually annotated relations across 2,500+ documents) is a gold-standard benchmark the authors developed specifically for rigorous evaluation.

  Second, the absence of competing baselines should be contextualized within STRING's methodological commitments. The paper explicitly justifies RoBERTa-large-PM-M3-Voc over alternatives. The analysis document notes BioBERT would reduce inference latency on 1.2B sentences but at the cost of lower precision/recall on novel relation types; GPT models introduce hallucination risk and prohibitive compute costs. RoBERTa represents a well-justified engineering choice for production deployment at scale.

  Third, the 73.5% F1 must be evaluated in light of how it is operationalized. The paper integrates this extraction model with three independent evidence channels (text-mining, curated databases, co-expression). Confidence scores are derived through probabilistic aggregation, calibrated against gold-standard curated relations. The 73.5% F1 on the text-mining channel is not the only signal users see; final edges are weighted by combined evidence strength. Users can filter by confidence threshold to focus on high-confidence interactions.

  Finally, the practical impact—extraction of ~43 million directed interactions (18M human)—demonstrates productive scaling. The fact that STRING has maintained and expanded this capability across decades suggests community confidence.

  Concessions: The objection is partially valid: the paper does not report head-to-head F1 comparisons to BioBERT or PubMedBERT on the same test set. Per-relation-type performance metrics are also withheld.

  Bottom line: The 73.5% F1 is a credible, well-justified baseline for production deployment in a multi-evidence integrated system; the absence of head-to-head comparisons does not undermine the core contribution of building a scalable, calibrated, multi-channel regulatory network.
judge_verdict: partially_holds
judge_reasoning: |
  The defense makes four load-bearing moves but succeeds only partially. First, it characterizes 73.5% as "credible" for a complex multi-label task (8 relation types) on a gold-standard corpus, which reframes but does not answer the objection's core: whether 73.5% is competitive against actual baselines. Second, it cites the analysis document's claim that RoBERTa yields "1–2% absolute F1 gains" over PubMedBERT, but this is a relative comparison *not* reported in the paper itself and does not establish that 73.5% beats PubMedBERT on RegulaTome. Third, it argues the 73.5% is "not the only signal" because of probabilistic aggregation with curated databases—a valid point about production design, but this concedes the core objection: the headline F1 is still unsupported by head-to-head comparison. Fourth, it appeals to user adoption and decades of STRING credibility as downstream validation, which is indirect evidence. The defense's concession paragraph acknowledges both missing head-to-head comparisons *and* withheld per-relation-type metrics, undermining the claim that readers can assess competitiveness. The argument shifts focus from "is 73.5% competitive?" to "is it good enough for production?", which sidesteps rather than defeats the objection.
user_decision: confirm
user_reasoning: ""
final_verdict: partially_holds
final_review_snippet: |
  - **Why was RoBERTa-large-PM-M3-Voc chosen over PubMedBERT, BioBERT, or other domain-adapted transformers?** Include head-to-head comparison on RegulaTome test set to justify the choice and assess whether 73.5% F1 is competitive against these baselines and GPT-4 zero-shot. ← from rounds initial analysis, 1
---

# Round 1 — STRING baseline comparison missing

This round established that the headline 73.5% F1 lacks a head-to-head comparison against BioBERT, PubMedBERT, GPT-4, or other biomedical relation-extraction baselines. The defense argued that the score is operationalized within a multi-channel production system (where edge confidence is aggregated from text-mining + curated databases + co-expression) and that RoBERTa was a justified engineering choice. The blind judge ruled `partially_holds` — the defense reframes from "is it competitive?" to "is it good enough for production?", which sidesteps rather than defeats the objection. Outcome merged with the existing Questions-to-Authors entry about model choice on review.md line ~75.
