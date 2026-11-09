# {{SLUG}}: how to verify it

This is the build's verification map. `./verify` implements it, and the verifier agent reads it after every build job.
Write it before the code. Update it when a flow, an input or a control changes. Keep any check that once caught a real
regression, even after the bug is fixed.

## Start-up

| | |
|---|---|
| Start command | <e.g. `uv run python -m src.app` or none> |
| Ready when | <the log line, port or file that means it's up> |
| Access needed | <lake-query (read-only), aws sso profile, VPN, none> |
| Golden set | <`tests/golden/…`, how many rows, who labeled it, the date> |

## Flows

| Flow | Entry point | Preconditions | Actions | Expected result | Failure states to check |
|---|---|---|---|---|---|
| <name> | <command, endpoint or page> | <seeded data, flags> | <steps> | <what you see, with a number> | <empty input, bad row, missing data> |

## Done-means, as checks

| Done-means line (from BRIEF.md) | `./verify` assertion | Proof kind |
|---|---|---|
| <line> | <`check` asserts …> | BEHAVIOR / QUALITY / PERFORMANCE |

## Regressions kept

| Date | What broke | The check that now catches it |
|---|---|---|
