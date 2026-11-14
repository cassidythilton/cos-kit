# Engineering standard for agent builds

Every build in `~/builds/` follows this file, whether a headless job runs it or Cassidy drives it in Cursor. When this file and a repo's own `AGENTS.md` or `CLAUDE.md` disagree, the repo wins inside that repo.

## Principles

1. **Verification is the job. Writing code is the easy part.** No build is "done" until `./verify check` passes. "Should work now" is a failure state.
2. **Reproduce before you fix. Investigate before you touch.** For anything that runs in production, the first deliverable is "what I think is happening", not a change.
3. **Restate the task first.** Two lines at the top of `HANDOFF.md`: what you'll produce, and what you need to see to call it done.
4. **Outcome first.** Work backwards from the artifact and the check that proves it.
5. **The smallest change that solves the problem.** Nothing speculative. Write for a small team to maintain. Touch only what you must. No hacks: use the canonical, documented approach for the tool. (food-enrichment `AGENTS.md`)
6. **Fix the root cause, not the symptom.**
7. **Two failed attempts at the same approach: stop.** Write down what you tried and why it failed, then ask. Don't guess a third time.
8. **When you're corrected, write the general rule, not the story.** It goes in this file or the repo's `AGENTS.md`, never only in chat.
9. **Prefer the boring path:** connector before browser, an ID before a search, a script before reasoning, a check before a rule, a rule before memory.

## The autopilot ladder

Every build states its rung in `BRIEF.md`. Step back a rung the moment anything is live.

| Rung | What the agent may do | Where |
|---|---|---|
| **investigate** | read code, data and logs; report; change nothing | anywhere, read-only |
| **prototype** | build, test and commit freely; merge on green inside the sandbox | `~/builds/<slug>/` and its sandbox remote only |
| **candidate** | prepare a draft PR in the owner's repo, following that repo's rules; wait | the owner's repo, a branch named `<owner-convention>`, draft only |
| **production** | never an agent's rung | the owner merges, deploys and operates |

No rung includes merging. Lauren Tan's agents auto-merge because years of evals earned that trust. Ours haven't, and
Cassidy has ruled it out: an agent's furthest step is a draft PR.

## The proof contract (adapted from Lauren Tan's workflow and pstack)

Every build session returns evidence records in `receipt.proofs`: the requirement, the tested revision, what ran, what
was expected, what was observed, PASS / FAIL / NOT_RUN, the artifacts, and (for NOT_RUN) the blocker.

| Proof | When | What it shows |
|---|---|---|
| BASELINE | always | the code and data flow were traced; the problem reproduces at the starting commit; observations kept apart from hypotheses |
| BEHAVIOR | always | the real journey was repeated (CLI, API, query, page) and checked against done-means, including the empty state and a failure path |
| QUALITY | always | tests, types, lint, `./verify check`, and the owner repo's gate at the candidate rung |
| PERFORMANCE | the work claims speed or cost | the same workload before and after, settings stated, both profiles kept |
| SKILL | instructions changed | the instructions were run on defined tasks; conclusions limited to those tasks (`cos-run eval`) |

Decision rules: PASS, keep the evidence and continue. FAIL, find the cause, fix it, re-run what it affects. NOT_RUN,
name the blocker. Stop when a required check can't run or the scope would have to grow; return what you have.

## Three checks after every headless build job

1. **Baseline vs treatment.** `cos-run` runs today's `./verify` against the code from before the job. It should fail
   there and pass now. Passing both times means the check doesn't test the slice: not proven.
2. **The verifier.** A fresh agent that didn't write the code runs it in a throwaway copy, criterion by criterion from
   BRIEF.md and VERIFY.md, and returns the strongest level its evidence supports: live-verified, test-verified,
   check-only, verifier-blocked or verifier-failed. Reading the diff is not verification.
3. **The second opinion and the checker.** A different model family reviews the diff. The checker fails the job on a
   missing proof, a vacuous check, an unmet criterion or an unaddressed defect.

A build is **proven** when `./verify check` passes, the verifier says live-verified or test-verified, and the checker
passes. Anything less is reported as what it is.

## Every failure becomes a check; every instruction change gets an eval

- A failure seen twice becomes structure: a `./verify` assertion, a test, a golden-set row, a gate rule. Then confirm
  the new check catches the original failure. A note in chat is not a fix.
- A change to a prompt, a skill or a lane is tested before it's promoted: `cos-run eval core <proposed file>` runs the
  current and proposed versions on the same requests, blind, and a judge from a different model family scores both.
  Promote only if it scores at least as well with no must-not violations.
- When a pattern is fixed, add the eval case that would have caught it.

## Proof attached to every result

| Kind of change | Proof |
|---|---|
| UI | a screenshot or short recording from `./verify screenshot` |
| Data or pipeline | before-and-after numbers from a real run on a golden set, with the denominator stated |
| Bug fix | the reproduction failing, then the same steps passing |
| Model or classifier | precision and recall (or the agreed metric) on the golden set, plus the confusion cases, plus cost per 1,000 |
| Anything with cost | dollars per run and per 1,000 records, measured, not estimated |

Golden test sets are mandatory for data-flow work (David, Nov 5, 15:38:14). A record the build can't handle is added to the golden set with its correct answer.

## Data stewardship (David, 2026-10-08; data-org-notebook `AGENTS.md`)

- **Canon values never enter a model's context.** That covers `canon_ingredient`, `canon_term`, `canon_assets.*`, `food_expression_ingredients`, and the lake's `canon_*` copies. Counts, group-bys, null rates, schema and IDs are fine. Code may process canon on the Mac and print aggregates. A person (Amiah, Melanie) looks at the values. The gate and `lake-query` block non-aggregate canon reads.
- **The airlock (canon charter decision 14, decided).** A call that carries a canon term or label context reaches a model only through Data Org tooling built to the WISEcode AI Data Stewardship Field Guide v1.0 (Tolga, 2026-09-22), or an air-gapped model. Claude Code on Cassidy's Mac, under the notebook's rules, is that tooling. Other providers are not: canon and label builds skip the Codex review, and nothing bound for the Grok bots carries canon terms or label text. IDs and counts only. The Field Guide itself is not in either repo or in Cassidy's Drive search: get it from Tolga or David, and add its rules here.
- **Read-only, always.** Data comes through `lake-query`, which wraps `run_query.py`. `wcx` refuses writes. Prototypes write only to local DuckDB files inside the workspace.
- **Never read, print or echo credentials.** SSO profiles only. When a login is needed (`aws sso login`, VPN), stop and ask Cassidy to sign in. Never take a password.
- **Keep large outputs out of context.** LIMIT, `--save` to Parquet, summarize with code.
- **Never commit** `.env`, `results/`, `.runs/`, or data files.
- **Never share an AI conversation link** that contains WISEcode information.

## Working in an owner's repo (the candidate rung)

- Read the repo's `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md` and per-directory `CLAUDE.md` first. Follow them exactly.
- **food-enrichment** (the lake, The Pantry, refinery, FBE): `make check` is the pre-PR gate. Respect the package boundaries (`make imports`). Add changelog fragments. Bump versions as its `AGENTS.md` says. Use its `land-change`, `message-style`, `plan-doc` and `test-audit` skills. Check `plans/README.md` before building against a design.
- **data-org**: decisions are DADRs with two or more real options, ranked drivers, a stated reversibility and a revisit trigger. Branch `<name>/<issue>-<topic>`, `Tile: #n` in the PR, `make gate` and `make lint-writing`.
- **data-org** writing and boundary: every prose file passes `make lint-writing` (standards/writing.md). No personnel, compensation, individual performance, verbatim executive quotes, RAGB values or uncleared commercial claims (CONTRIBUTING.md, Boundary). `context/` is read-only: file `make context-request`, never edit. Cite the CDO's ADRs by id only. Terms are cited from `standards/glossary.md`, and a new term ships there in the same PR.
- **data-org-notebook** (David's workbench; David merges): the deliverable is a marimo notebook, a Quarto report and numbered SQL on `wt/cc/<slug>` in `.worktrees/cc/<slug>`, PR opened, never a chat essay. `uv run` only. Recon with pg_catalog. Food metrics use the eligibility denominator (`queries/lib/food_eligibility.sql`: `meets_gold_criteria = true AND fully_parsed = true`). Label findings confirmed, inferred or guessed. BLUF plus a Blocked table first. Lake numbers applied to the catalog say "projected" or "estimated". No recommendation the task didn't ask for.
- **WISEintelligence** and other product repos: investigate only, unless the owner asks. Never take over or fork a production service. Canon and the Pantry never enter the WISEintel MCP (canon charter decision 28).
- A draft PR is opened only after Cassidy's yes. Merge, deploy and operation belong to the owner.

## Build hygiene

- **One build, one workspace, one brief.** No more than two active builds at a time.
- `HANDOFF.md` is the state. Update it at every phase boundary, then start a fresh session from it instead of letting one session compact over and over.
- Small commits with plain messages. Tests next to the change.
- Each build's `./verify` is deterministic. Write it once and run it every time. No throwaway scripts in its place.
- Measure cost as you go. Record it in `HANDOFF.md`.
- Never edit `context/` in data-org. Never put personnel or individual performance anywhere in a build.

## Hard walls (enforced by `~/cos/claude/gate.sh`, in every mode)

Secrets; writes to shared databases or the lake; Terraform, CDK, Amplify, kubectl, Helm and AWS write verbs; package publishing and deployment runs; force-push; pushing to `main` or other protected branches; non-aggregate canon reads.

**Outward actions** (push, PR, issue or board writes, Slack or other connector writes, outbound HTTP writes, deletes) are blocked in headless jobs and staged for approval. In pair mode they ask Cassidy first.
