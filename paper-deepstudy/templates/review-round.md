---
round: <NN>
created_at: <iso8601-utc>
objection: |
  <verbatim user objection text>
dimension: method | experiment | claim | reproducibility | writing | bio-rigor
severity: major | minor
defense: |
  <defense agent output, verbatim>
judge_verdict: holds | partially_holds | fails
judge_reasoning: |
  <judge agent reasoning, verbatim>
user_decision: confirm | override
user_reasoning: |
  <user reasoning if override; empty if confirm>
final_verdict: holds | partially_holds | fails
final_review_snippet: |
  <text appended to review.md, or empty if dismissed>
---

# Round <NN> — <objection short title>

(Free-form notes section. Optional. Use to record any additional context the orchestrator wants to preserve about this round — e.g. references to other rounds, follow-up TODOs, screenshots paths.)
