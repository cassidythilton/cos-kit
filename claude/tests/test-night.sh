#!/bin/bash
# test-night.sh: the night shift's tests (plan 2026-11-19, change 8).
# Sourced by install.sh (it uses that file's pass, fail and $KIT), or run alone: bash claude/tests/test-night.sh
# Every case runs cos-night in a throwaway HOME with a stub in place of cos-run. No model runs, nothing is spent, and
# the real ~/cos is never read or written.

_nt_alone=0
if ! declare -F pass >/dev/null 2>&1; then
  _nt_alone=1; ok=0; bad=0
  pass() { printf '  ✓ %s\n' "$1"; ok=$((ok+1)); }
  fail() { printf '  ✗ %s\n' "$1"; bad=$((bad+1)); }
fi
_nt_kit="${KIT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_nt_bin="$_nt_kit/claude/cos-night"
_nt_real="$HOME"
_nt_q0=0; [[ -e "$_nt_real/cos/state/night-queue.json" ]] && _nt_q0=1
NT="$(mktemp -d "${TMPDIR:-/tmp}/cos-night-test.XXXXXX")"

echo "Night shift (cos-night, in a throwaway home with a stub runner)"

# The stub: records each call, writes a run file with a cost, a receipt and a while-you-slept note. STUB_SLEEP makes
# it hang with a child process, to prove the time cap kills the whole process group. Costs come from $HOME/costs,
# one line per call in order (default 1.00).
cat > "$NT/stub-runner" <<'STUB'
#!/bin/bash
lane="$1"; job="$2"; out="$HOME/cos/outbox/$job"; mkdir -p "$out"
echo "$lane $job" >> "$HOME/runner.calls"
n="$(wc -l < "$HOME/runner.calls" | tr -d ' ')"
cost="$(sed -n "${n}p" "$HOME/costs" 2>/dev/null)"; cost="${cost:-1.00}"
echo "step 1 of 2 done" > "$out/progress.md"
if [[ "${STUB_SLEEP:-0}" != 0 ]]; then sleep "$STUB_SLEEP" & echo $! > "$HOME/stub-child.pid"; wait; fi
printf '{"total_cost_usd": %s}\n' "$cost" > "$out/run.json"
printf '{"job":"%s","lane":"%s","cost_usd":%s,"receipt":{"status":"done","summary":"Did the thing.\\nIt matters.\\nReady."}}\n' "$job" "$lane" "$cost" > "$out/receipt.json"
printf '1. Drafted it.\n2. It saves you an hour.\n3. Ready for you.\nDecision: share, revise or drop.\n' > "$out/while-you-slept.md"
STUB
chmod +x "$NT/stub-runner"

_nt_newh() {  # a fresh throwaway home; refuses to be the real one
  NH="$(mktemp -d "$NT/h.XXXXXX")"; mkdir -p "$NH/cos/state"
  [[ "$NH" != "$_nt_real" && "$NH" == "$NT"/* ]] || { fail "test home is not a throwaway folder"; return 1; }
  cp "$_nt_kit/handbook/night-budget.json" "$NH/budget.json"
}
_nt_budget() {  # _nt_budget '<jq filter>' edits this home's budget
  jq "$1" "$NH/budget.json" > "$NH/budget.tmp" && mv "$NH/budget.tmp" "$NH/budget.json"
}
nt() {  # nt <NOW> cos-night args...
  local when="$1"; shift
  env HOME="$NH" COS_NIGHT_NO_SEED="${NT_SEED_OFF:-1}" COS_NIGHT_NOW="$when" COS_NIGHT_RUNNER="$NT/stub-runner" COS_NIGHT_POWER="${NT_POWER:-ac}" \
    COS_NIGHT_NO_CAFFEINATE=1 COS_NIGHT_SECS_PER_MIN="${NT_SPM:-60}" COS_NIGHT_KILL_GRACE=1 \
    COS_NIGHT_BUDGET="$NH/budget.json" COS_NIGHT_BRIEFS="$_nt_kit/claude/briefs" \
    COS_NIGHT_LEDGER="$_nt_kit/claude/cos-ledger" COS_LEDGER_DIR="$NH/cos/state/ledger" \
    STUB_SLEEP="${NT_SLEEP:-0}" "$_nt_bin" "$@"
}
EVE=2026-11-19T17:00; TEN=2026-11-19T22:00; MORN=2026-11-20T06:00
_nt_calls() { [[ -f "$NH/runner.calls" ]] && wc -l < "$NH/runner.calls" | tr -d ' ' || echo 0; }

# --- parse, files, recipes
python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$_nt_bin" 2>/dev/null && pass "cos-night parses" || fail "cos-night syntax"
jq -e '.per_night.usd == 25 and .per_night.minutes == 180 and .per_week.usd == 100 and .per_night.max_jobs == 4
       and .per_night.max_large == 1 and .kinds.prototype.max_per_week == 0 and .kinds["pr-reviews"].max_prs == 5
       and (.kinds | length) == 9' "$_nt_kit/handbook/night-budget.json" >/dev/null 2>&1 \
  && pass "night-budget.json: \$25 and 3 h a night, \$100 a week, nine kinds, prototypes off until Cassidy turns them on" || fail "night-budget.json missing or wrong"
_nt_missing=""
for k in meeting-prep call-follow-through board-cleanup pr-reviews data-answer write-up decision-doc system-fix prototype; do
  f="$_nt_kit/claude/briefs/night-$k.md"
  { [[ -f "$f" ]] && grep -q "Nothing leaves the Mac" "$f" && grep -q "Canon values never" "$f" && grep -q "Nicholas" "$f" \
    && grep -q "while-you-slept.md" "$f" && grep -q "progress.md" "$f"; } || _nt_missing="$_nt_missing $k"
done
[[ -z "$_nt_missing" ]] && pass "nine night recipes, each with the hard lines and the morning note" || fail "night recipes missing or incomplete:$_nt_missing"

# --- propose: small first, then medium, at most one large, inside the night's money, time and job count
_nt_newh
for a in "meeting-prep|Thu meetings: 9:00 ops, 2:00 David 1:1" "pr-reviews|PRs waiting on me" "prototype|scan demand loader" \
         "write-up|available foods rubric" "call-follow-through|Wed calls" "board-cleanup|weekly sweep" "meeting-prep|second list" \
         "data-answer|NFP15 coverage" "prototype|second build"; do nt "$EVE" add "${a%%|*}" "${a#*|}" --from ops >/dev/null; done
NP="$(nt "$EVE" propose)"
if jq -e '.total_usd <= 25 and .total_min <= 180 and (.items|length) <= 4
          and ([.items[] | select(.size == "large")] | length) <= 1
          and ([.items[0:3][] | .size] == ["small","small","small"])
          and ([.items[] | select(.kind == "meeting-prep")] | length) == 1' <<<"$NP" >/dev/null 2>&1; then
  pass "propose: small jobs first, at most 4 jobs, within \$25 and 180 min ($(jq -r '"\(.items|length) jobs, $\(.total_usd), \(.total_min) min"' <<<"$NP"))"
else fail "propose broke a budget rule: $(jq -c '{n: (.items|length), total_usd, total_min, kinds: [.items[].kind]}' <<<"$NP" 2>/dev/null || echo "$NP")"; fi
jq -e '.text | test("needs your yes") and test("Reply")' <<<"$NP" >/dev/null 2>&1 && pass "propose: plan text asks for his yes" || fail "propose: no plain-words plan"

_nt_newh; _nt_budget '.per_night.max_jobs = 9 | .kinds.prototype.max_per_week = 2'
nt "$EVE" add prototype "one" >/dev/null; nt "$EVE" add prototype "two" >/dev/null; nt "$EVE" add write-up "w" >/dev/null
NP="$(nt "$EVE" propose)"
jq -e '([.items[] | select(.size == "large")] | length) == 1 and ([.waiting[] | select(.why | test("one large"))] | length) == 1' <<<"$NP" >/dev/null 2>&1 \
  && pass "propose: one large job a night; the second waits" || fail "propose: one-large rule broken: $(jq -c '[.items[].kind]' <<<"$NP")"

_nt_newh; _nt_budget '.per_night.max_jobs = 9 | .per_night.usd = 10'
nt "$EVE" add pr-reviews "p" >/dev/null; nt "$EVE" add write-up "w" >/dev/null; nt "$EVE" add meeting-prep "m" >/dev/null
NP="$(nt "$EVE" propose)"
jq -e '.total_usd <= 10 and ([.waiting[] | select(.kind == "pr-reviews" and (.why | test("money")))] | length) == 1' <<<"$NP" >/dev/null 2>&1 \
  && pass "propose: stays inside the night's money (\$$(jq -r .total_usd <<<"$NP") of \$10)" || fail "propose: over the night's money: $(jq -c '{total_usd, w: .waiting}' <<<"$NP")"

_nt_newh; _nt_budget '.per_night.max_jobs = 9 | .per_night.minutes = 60'
for k in meeting-prep call-follow-through board-cleanup write-up; do nt "$EVE" add "$k" "x" >/dev/null; done
NP="$(nt "$EVE" propose)"
jq -e '.total_min <= 60 and ([.waiting[] | select(.kind == "write-up" and (.why | test("time")))] | length) == 1' <<<"$NP" >/dev/null 2>&1 \
  && pass "propose: stays inside the night's minutes ($(jq -r .total_min <<<"$NP") of 60)" || fail "propose: over the night's minutes: $(jq -c '{total_min, w: .waiting}' <<<"$NP")"

# --- nothing runs unapproved
_nt_newh
nt "$EVE" add meeting-prep "m" >/dev/null; nt "$EVE" add board-cleanup "b" >/dev/null; nt "$EVE" propose >/dev/null
nt "$TEN" run >/dev/null 2>&1
[[ "$(_nt_calls)" == 0 ]] && pass "run: nothing approved, nothing ran" || fail "run started a job nobody approved"
nt "$EVE" add write-up "added after the plan" >/dev/null
nt "$EVE" approve 2 >/dev/null
nt "$TEN" run >/dev/null 2>&1
[[ "$(_nt_calls)" == 1 ]] && grep -q "night-board-" "$NH/runner.calls" && pass "run: only the approved item ran (1 of 2 planned; one added later didn't)" \
  || fail "run: expected only the approved item, got: $(cat "$NH/runner.calls" 2>/dev/null | tr '\n' ';')"
grep -q "^investigate night-board-20261119-" "$NH/runner.calls" 2>/dev/null && [[ -f "$NH/cos/state/night/20261119/$(awk '{print $2}' "$NH/runner.calls").md" ]] \
  && pass "run: called the runner as <lane> <job> <brief file>, foreground" || fail "run: runner call shape wrong: $(cat "$NH/runner.calls" 2>/dev/null)"
grep -q '"event":"end"' "$NH/cos/state/ledger/night.jsonl" 2>/dev/null && pass "run: each job is in the night ledger" || fail "run: no night ledger line"

# --- a job past its time cap is stopped, with everything it started, and reported partial
_nt_newh; _nt_budget '.kinds["meeting-prep"].minutes = 20'
nt "$EVE" add meeting-prep "m" >/dev/null; nt "$EVE" propose >/dev/null; nt "$EVE" approve all >/dev/null
t0=$SECONDS; NT_SPM=0.1 NT_SLEEP=60 nt "$TEN" run >/dev/null 2>&1; dt=$((SECONDS - t0))
ncpid="$(cat "$NH/stub-child.pid" 2>/dev/null)"
NR="$(tail -1 "$NH/cos/state/night-runs.jsonl" 2>/dev/null)"
if [[ $dt -lt 15 ]] && jq -e '.status == "partial" and .killed == true and .cost_source == "cap" and .cost_usd == 3' <<<"$NR" >/dev/null 2>&1; then
  pass "time cap: the job was stopped at its limit (${dt}s), marked partial, counted at its \$3 cap"
else fail "time cap not enforced (${dt}s): $NR"; fi
[[ -n "$ncpid" ]] && ! kill -0 "$ncpid" 2>/dev/null && pass "time cap: the job's own child process was stopped too" || fail "time cap: a child process outlived the job ($ncpid)"
nt "$MORN" report 2>/dev/null | grep -q "stopped at its 20 min limit. What it got done: step 1 of 2 done" \
  && pass "report: a stopped job says what it got done" || fail "report: the partial job doesn't say what it got done"

# --- spending stops at the nightly cap
_nt_newh
for k in meeting-prep call-follow-through board-cleanup pr-reviews; do nt "$EVE" add "$k" "x" >/dev/null; done
nt "$EVE" propose >/dev/null; nt "$EVE" approve all >/dev/null
printf '23.00\n1\n1\n1\n' > "$NH/costs"
nt "$TEN" run >/dev/null 2>&1
nheld="$(jq '.nights["20261119"].held | length' "$NH/cos/state/night-queue.json" 2>/dev/null)"
[[ "$(_nt_calls)" == 1 && "$nheld" == 3 ]] && jq -e '.nights["20261119"].held[0].why | test("tonight.s money")' "$NH/cos/state/night-queue.json" >/dev/null 2>&1 \
  && pass "nightly cap: after \$23 spent, no job whose cap is over the \$2 left started (3 held)" || fail "nightly cap: calls=$(_nt_calls) held=$nheld"
jq -e '[.items[] | select(.status == "queued")] | length == 3' "$NH/cos/state/night-queue.json" >/dev/null 2>&1 \
  && pass "nightly cap: held items go back in the queue" || fail "nightly cap: held items lost"
NREP="$(nt "$MORN" report 2>/dev/null)"
grep -qE '^Last night: 1 job, \$23\.00, [0-9]+ h [0-9]+ min\.$' <<<"$NREP" && pass "report: \"Last night: 1 job, \$23.00, H h M min.\"" || fail "report: totals line missing: $(grep 'Last night' <<<"$NREP")"
grep -qE '^This week so far: \$23\.00 of \$100\.00\.$' <<<"$NREP" && pass "report: week to date against \$100" || fail "report: week line missing"
NRJ="$NH/cos/outbox/night-20261119/receipt.json"
jq -e '.job == "night-20261119" and .lane == "night" and .receipt.status == "partial" and (.receipt.summary | test("While you slept"))
       and (.receipt.open_questions | type == "array" and length == 1) and (.receipt.open_questions[0] | test("share, revise or drop"))' "$NRJ" >/dev/null 2>&1 \
  && pass "report: receipt.json in the kit shape, ready for cos-push" || fail "report: receipt.json wrong: $(head -c 300 "$NRJ" 2>/dev/null)"
! grep -qE '/cos/|night-[a-z]+-2026' <<<"$NREP" && pass "report: no file paths or job ids in his words" || fail "report: leaks paths or job ids"

# --- spending stops at the weekly cap
_nt_newh
nt "$EVE" add meeting-prep "m" >/dev/null; nt "$EVE" add board-cleanup "b" >/dev/null
nt "$EVE" propose >/dev/null; nt "$EVE" approve all >/dev/null
echo '{"night":"20261117","id":"n0","kind":"write-up","job":"x","status":"done","cost_usd":98.5,"minutes":40}' > "$NH/cos/state/night-runs.jsonl"
nt "$TEN" run >/dev/null 2>&1
[[ "$(_nt_calls)" == 0 ]] && jq -e '.nights["20261119"].held[0].why | test("week")' "$NH/cos/state/night-queue.json" >/dev/null 2>&1 \
  && pass "weekly cap: with \$98.50 spent this week, nothing started" || fail "weekly cap: calls=$(_nt_calls)"
_nt_newh
nt "$EVE" add meeting-prep "m" >/dev/null
echo '{"night":"20261116","id":"n0","kind":"write-up","job":"x","status":"done","cost_usd":98.5,"minutes":40}' > "$NH/cos/state/night-runs.jsonl"
NP="$(nt "$EVE" propose)"
jq -e '(.items | length) == 0' <<<"$NP" >/dev/null 2>&1 && pass "weekly cap: propose plans nothing the week can't pay for" || fail "weekly cap: propose ignored the week"

# --- battery: refuse, run nothing, say so in the morning
_nt_newh
nt "$EVE" add meeting-prep "m" >/dev/null; nt "$EVE" propose >/dev/null; nt "$EVE" approve all >/dev/null
NT_POWER=battery nt "$TEN" run >/dev/null 2>&1; nrc=$?
[[ $nrc -ne 0 && "$(_nt_calls)" == 0 ]] && pass "battery: refused (exit $nrc), nothing ran" || fail "battery: ran on battery (exit $nrc, calls $(_nt_calls))"
nt "$MORN" report 2>/dev/null | grep -q "on battery" && jq -e '.receipt.status == "blocked"' "$NH/cos/outbox/night-20261119/receipt.json" >/dev/null 2>&1 \
  && pass "battery: the morning report says the Mac was on battery" || fail "battery: the report doesn't say why nothing ran"
grep -q '"event":"refused"' "$NH/cos/state/ledger/night.jsonl" 2>/dev/null && pass "battery: the refusal is in the ledger" || fail "battery: refusal not ledgered"

# --- quiet night
_nt_newh
nt "$MORN" report >/dev/null 2>&1
jq -e '.receipt.summary == "NO CHANGE"' "$NH/cos/outbox/night-20261119/receipt.json" >/dev/null 2>&1 \
  && pass "report: a night with nothing planned says NO CHANGE (not pushed)" || fail "report: quiet night not NO CHANGE"

# --- the real ~/cos was never touched
if [[ $_nt_q0 -eq 0 && -e "$_nt_real/cos/state/night-queue.json" ]]; then fail "the tests wrote the real ~/cos/state/night-queue.json"
else pass "the real ~/cos was not touched"; fi

# --- the Mac queues what it can see a need for (Nov 20)
_nt_newh; mkdir -p "$NH/cos/state" "$NH/cos/zoom"
echo '{"open": {"k": {"title": "the 4 PM capture failed"}}}' > "$NH/cos/state/health.json"
echo '{"items": {"review:wisecodeai/data-org#805": {"kind": "review", "repo": "wisecodeai/data-org", "number": 805, "status": "open"}}}' > "$NH/cos/state/obligations.json"
NP="$(NT_SEED_OFF=0 nt "$EVE" propose)"
jq -e '[.items[].kind] | (index("board-cleanup") != null) and (index("pr-reviews") != null) and (index("system-fix") != null)' <<<"$NP" >/dev/null 2>&1 \
  && pass "night: the Mac queues board cleanup, PR reviews and a system fix when it sees the need" || fail "night: no seeded items ($(jq -c '[.items[].kind]' <<<"$NP"))"
NP2="$(NT_SEED_OFF=0 nt "$EVE" propose)"
[[ "$(jq '[.items[] | select(.kind == "board-cleanup")] | length' <<<"$NP2")" == 1 ]] && pass "night: seeding never queues the same kind twice" || fail "night: seeded a duplicate"

rm -rf "$NT"
unset -f _nt_newh _nt_budget nt _nt_calls
if [[ $_nt_alone -eq 1 ]]; then echo "Result: $ok passed, $bad failed"; [[ $bad -eq 0 ]]; fi

