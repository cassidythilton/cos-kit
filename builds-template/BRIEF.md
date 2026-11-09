# Build brief: {{SLUG}}

Written {{DATE}}. Cassidy approved this brief before the build started. Change it only with his yes.

| | |
|---|---|
| Problem | {{PURPOSE}} |
| Who is asking, and who owns the result | <name the person whose problem this is, and the repo owner who would adopt it> |
| Board card | <#n, or "none yet: propose one with the card skill"> |
| Pillar metric | <the number this moves, or Enables · <code>, or Engine> |
| Rung | investigate · prototype (sandbox autopilot) · candidate (draft PR to the owner's repo) |
| Done means | <the artifact and the check that proves it, in one sentence> |
| Data | <tables or lake tiers, read-only, via lake-query. Mark any canon table as aggregates only.> |
| Stewardship class | open · canon (aggregates and IDs only) · label (label images or label text). Canon and label builds get Claude-only review, per canon charter decision 14. |
| Owner repo rules | <the AGENTS.md that governs the candidate: data-org (DADR, `make gate`, `make lint-writing`), data-org-notebook (`wt/cc/<slug>`, notebook + Quarto report + numbered SQL, David merges), food-enrichment (`make check`)> |
| Out of scope | <what this build will not touch> |
| Stop and ask | prod, auth, infra, money, customer-facing output, a third failed approach, more than <N> hours |
