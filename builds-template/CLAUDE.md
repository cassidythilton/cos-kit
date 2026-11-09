# {{SLUG}}: {{PURPOSE}}

A build workspace in Cassidy's chief-of-staff system. Start every session from the handoff, then the brief:

@HANDOFF.md
@BRIEF.md

The engineering standard applies to everything here. Read it before you plan:

@~/cos/handbook/engineering-standard.md

## This workspace

- `repos/` holds read-only reference clones. Never commit or push in them.
- `VERIFY.md` maps every flow to the check that proves it. `./verify` implements it. `./verify check` must pass before
  anything is called done, and an independent verifier re-runs it after every headless job.
- Every result carries proofs (BASELINE, BEHAVIOR, QUALITY): what ran, what was expected, what was observed, PASS / FAIL /
  NOT_RUN. In pair mode, show Cassidy the proofs before you say a slice is done.
- Nothing here is ever merged into an owner's repo by an agent. The furthest an agent goes is a draft PR, after his yes.
- Data comes only through `lake-query <file.sql>`. Canon values never enter this conversation. Credentials are never read.
- Update `HANDOFF.md` at the end of every session and at every phase boundary. Then start the next session fresh from it.
