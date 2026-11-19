#!/bin/bash
# Tests for claude/cos-memory (plan 2026-11-19, change 11).
# install.sh can `source` this file: it uses pass "<msg>" / fail "<msg>" and $KIT if they exist, and defines
# simple ones when run on its own (bash claude/tests/test-memory.sh). Everything runs against a temp HOME;
# the real ~/cos is never written. Bash 3.2 safe.

if ! type pass >/dev/null 2>&1; then
  ok=0; bad=0
  pass() { printf '  ok   %s\n' "$1"; ok=$((ok+1)); }
  fail() { printf '  FAIL %s\n' "$1"; bad=$((bad+1)); }
  _mem_standalone=1
fi
: "${KIT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
: "${COS:=$HOME/cos}"

cos_memory_tests() {
  local T M out rc id1 id2 f i n before after real_before real_after body rules_at facts_at receipt
  M="$KIT/claude/cos-memory"
  T="$(mktemp -d)"
  [ -x "$M" ] || { fail "memory: $M is missing or not executable"; return; }
  # The real store must come out of this exactly as it went in.
  real_before="$(ls -la "$COS/memory" 2>/dev/null | md5 -q 2>/dev/null || ls -la "$COS/memory" 2>/dev/null | cksum)"
  mem() { HOME="$T" COS_MEMORY_TODAY=2026-11-19 "$M" "$@"; }

  # --- propose and accept
  out="$(mem propose "Drafts only for Slack and email; he sends." --kind rule --bots all --source "test" 2>&1)"; rc=$?
  id1="$(printf '%s\n' "$out" | sed -n 's/^proposed \([rf]-[0-9a-f]*\).*/\1/p')"
  if [ $rc -eq 0 ] && [ -n "$id1" ] && mem list --status proposed | grep -q "^$id1 "; then
    pass "memory: propose adds a proposed rule ($id1)"
  else fail "memory: propose didn't add a proposal: $out"; fi
  [ -d "$T/cos/memory/.git" ] && pass "memory: store created as its own git repo on first use" \
    || fail "memory: no git repo at the temp store"
  mem accept "$id1" >/dev/null 2>&1 && mem list --status active | grep -q "^$id1 " \
    && pass "memory: accept makes it active" || fail "memory: accept didn't make $id1 active"
  mem accept "$id1" >/dev/null 2>&1 && fail "memory: accepting twice should refuse" \
    || pass "memory: accepting an active entry is refused"
  id2="$(mem propose "Use the Dropped lane, never Park." --kind rule --bots steward --source test 2>/dev/null | sed -n 's/^proposed \([rf]-[0-9a-f]*\).*/\1/p')"
  mem reject "$id2" >/dev/null 2>&1 && mem show "$id2" | grep -q '"status": "retired"' \
    && pass "memory: reject retires a proposal" || fail "memory: reject didn't retire $id2"

  # --- refusals
  out="$(mem propose "Review PR 805 by Friday" --kind open --bots chief --source test 2>&1)"; rc=$?
  if [ $rc -ne 0 ] && printf '%s' "$out" | grep -q "read live"; then pass "memory: open items refused with a clear message"
  else fail "memory: open item not refused (rc=$rc): $out"; fi
  out="$(mem propose "The sweep ran at 4:30" --kind history --bots chief --source test 2>&1)"; rc=$?
  [ $rc -ne 0 ] && printf '%s' "$out" | grep -qi "ledgers" && pass "memory: history refused with a clear message" \
    || fail "memory: history not refused: $out"
  out="$(mem propose "the key is ghp_abcdefghijklmnop" --kind fact --bots chief --source test 2>&1)"; rc=$?
  [ $rc -ne 0 ] && ! printf '%s' "$out" | grep -q "ghp_" && pass "memory: a token is refused and not echoed" \
    || fail "memory: token text was stored or echoed"
  mem propose "Drafts only for Slack and email, he sends" --kind rule --bots ops --source test >/dev/null 2>&1 \
    && fail "memory: a near-duplicate proposal should be refused" || pass "memory: near-duplicate proposal refused"
  mem propose "x" --kind rule --bots nobody --source test >/dev/null 2>&1 \
    && fail "memory: unknown bot accepted" || pass "memory: unknown bot refused"

  # --- render: rules first, under the cap, only this Bot's entries
  mem propose "Steward-only rule about sheet batches." --kind rule --bots steward --source test --pin >/dev/null 2>&1
  i=1
  while [ $i -le 40 ]; do
    mem propose "Chief rule$i: always restate req$i as brief$i before lane$i starts, with cap$i." \
      --kind rule --bots chief --source "test $i" >/dev/null 2>&1
    mem propose "Fact number $i: person$i owns system$i and decision$i was recorded in doc$i." \
      --kind fact --bots chief --source "test $i" --review-by 2027-02-01 >/dev/null 2>&1
    i=$((i+1))
  done
  mem accept $(mem list --status proposed | awk '{print $1}') >/dev/null 2>&1
  n="$(mem list --status active --bot chief | wc -l | tr -d ' ')"
  [ "$n" -ge 81 ] && pass "memory: 81+ active entries for chief ($n)" || fail "memory: expected 81+ chief entries, got $n"
  f="$T/out/chief.md"
  out="$(mem render chief --out "$f" 2>&1)"; rc=$?
  if [ $rc -eq 0 ] && [ -f "$f" ]; then
    body="$(cat "$f")"
    n=${#body}
    [ "$(wc -c < "$f" | tr -d ' ')" -le 6000 ] && pass "memory: render stays under 6000 characters ($n)" \
      || fail "memory: render is over the cap ($(wc -c < "$f"))"
    rules_at="$(grep -n '^## Rules' "$f" | cut -d: -f1)"; facts_at="$(grep -n '^## Facts' "$f" | cut -d: -f1)"
    if [ -n "$rules_at" ] && { [ -z "$facts_at" ] || [ "$rules_at" -lt "$facts_at" ]; }; then
      pass "memory: rules come before facts"
    else fail "memory: rules aren't first (rules line $rules_at, facts line $facts_at)"; fi
    grep -q "Drafts only for Slack and email" "$f" && pass "memory: an 'all' rule reaches chief's block" \
      || fail "memory: the 'all' rule is missing from chief's block"
    grep -q "Steward-only" "$f" && fail "memory: steward's rule leaked into chief's block" \
      || pass "memory: another Bot's rule stays out"
    grep -q "left out to stay under" "$f" && printf '%s' "$out" | grep -q "left out for size" \
      && pass "memory: what's left out for size is said" || fail "memory: no note about what was left out"
  else fail "memory: render failed: $out"; fi
  mem render steward >/dev/null 2>&1
  [ -f "$T/cos/grok-live/apply/steward-remember-20261119.md" ] && grep -q "Steward-only" "$T/cos/grok-live/apply/steward-remember-20261119.md" \
    && pass "memory: render writes grok-live/apply/<bot>-remember-<date>.md by default" \
    || fail "memory: default render path missing"

  # --- clean: merges a duplicate, retires an expired fact, flags a contradiction, lists GitHub facts
  # A duplicate can only reach active through import (propose refuses one), so plant it in the store the way
  # an older import would have, as one commit.
  python3 -I - "$T/cos/memory/entries.jsonl" <<'PY'
import json, sys
p = sys.argv[1]
rows = [json.loads(l) for l in open(p) if l.strip()]
base = {"kind": "rule", "bots": ["ops"], "source": "test", "status": "active", "review_by": None}
rows.append(dict(base, id="r-dup001", text="Never post the brief in your own chat; send it to CHIEF.", added="2026-11-10"))
rows.append(dict(base, id="r-dup002", text="Never post the brief in your own chat, send it to CHIEF!", added="2026-11-14", bots=["keeper"]))
rows.append(dict(base, id="r-con001", text="Never run the weekly Slack digest routine for Cassidy.", added="2026-11-11"))
rows.append(dict(base, id="r-con002", text="Always run the weekly Slack digest routine for Cassidy.", added="2026-11-15"))
rows.append(dict(base, id="f-old001", kind="fact", text="Kevin owns the image extractor.", added="2026-08-01", review_by="2026-11-01"))
rows.append(dict(base, id="f-gh0001", kind="fact", text="Matt owns the accuracy work.", added="2026-11-18",
                 review_by="2027-02-01", source="https://github.com/wisecodeai/data-org/issues/750"))
open(p, "w").write("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows))
PY
  git -C "$T/cos/memory" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qam "test: plant entries" 2>/dev/null
  before="$(cksum < "$T/cos/memory/entries.jsonl")"
  mem clean --dry-run >/dev/null 2>&1
  after="$(cksum < "$T/cos/memory/entries.jsonl")"
  [ "$before" = "$after" ] && [ ! -d "$T/cos/outbox/memory-clean-20261119" ] \
    && pass "memory: clean --dry-run changes nothing" || fail "memory: clean --dry-run changed the store or wrote a receipt"
  out="$(mem clean 2>&1)"; rc=$?
  [ $rc -eq 0 ] || fail "memory: clean failed: $out"
  mem show r-dup001 | grep -q '"merged into r-dup002"' && mem show r-dup002 | grep -q '"keeper"' \
    && mem show r-dup002 | grep -q '"ops"' \
    && pass "memory: clean merges a near duplicate (newer kept, both Bots kept)" || fail "memory: duplicate not merged"
  mem show f-old001 | grep -q '"status": "retired"' && mem show f-old001 | grep -q "review-by" \
    && pass "memory: clean retires a fact past its review-by date" || fail "memory: expired fact not retired"
  mem show r-con001 | grep -q '"status": "active"' && mem show r-con002 | grep -q '"status": "active"' \
    && printf '%s' "$out" | grep -q "r-con001 vs r-con002" \
    && pass "memory: clean flags a contradiction and changes neither" || fail "memory: contradiction not flagged: $out"
  printf '%s' "$out" | grep -q "f-gh0001" && pass "memory: clean lists facts that point at a GitHub card" \
    || fail "memory: GitHub-sourced fact not listed"
  receipt="$T/cos/outbox/memory-clean-20261119/receipt.json"
  if python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1])); r = d["receipt"]
assert d["job"] == "memory-clean-20261119" and d["lane"] == "memory"
assert r["status"] == "done" and "merged 1" in r["summary"] and "retired 1" in r["summary"]
assert any("r-con001" in q for q in r["open_questions"])
' "$receipt" 2>/dev/null; then pass "memory: clean writes the receipt in the kit's shape"
  else fail "memory: receipt missing or wrong at $receipt"; fi

  # --- undo through the store's git history
  out="$(mem undo 2>&1)"
  after="$(cksum < "$T/cos/memory/entries.jsonl")"
  [ "$before" = "$after" ] && printf '%s' "$out" | grep -q "clean" \
    && pass "memory: undo puts the store back as it was before clean" || fail "memory: undo didn't restore: $out"
  mem history -n 1 | grep -q 'Revert' && pass "memory: the undo is itself a commit (can be undone)" \
    || fail "memory: no revert commit in history"
  mem show f-old001 | grep -q '"status": "active"' && pass "memory: the retired fact is active again after undo" \
    || fail "memory: f-old001 not back after undo"

  # --- import: splits, folds duplicates, refuses open items and one-offs, runs once
  mkdir -p "$T/fx"
  cat > "$T/fx/chief-remember.md" <<'MD'
Source: test export
- (2026-11-01) The user's name is Cassidy, and he uses he/him pronouns.
- (2026-11-02) Cassidy's colleague Jeff is the eng lead over the app team.
- (2026-11-13) Nov 13, 2026 4:00 PM MT: the obligations webhook came in done with 6 replies open.
- (2026-11-14) Open follow-ups I track for Cassidy live in ops/open-followups.md.
- (2026-11-14) Cassidy (Nov 14, 2026): answer like a person, plain words first [cut off by search]
## Shared user memory (seen by all of Cassidy's Bots)
- (2026-11-09) [via STEWARD] Never send Slack messages or emails for Cassidy. Only prepare drafts, which he sends himself.
MD
  cat > "$T/fx/ops-remember.md" <<'MD'
- (2026-11-09) [profile] Never send Slack messages or emails for Cassidy. Only prepare drafts, which he sends himself!
MD
  printf '%s\n' '{"ts":"2026-11-18T00:00:00Z","id":"abc","bot":"chief","note":"data-org#740: Cassidy approved a writing-lint waiver for lines 3-15."}' \
    '{"ts":"2026-11-10T00:00:00Z","id":"def","bot":"claude","note":"Run bash -n on gate.sh before installing it."}' > "$T/fx/corr.jsonl"
  out="$(mem import --remember-dir "$T/fx" --corrections "$T/fx/corr.jsonl" 2>&1)"; rc=$?
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q "NOT imported" \
     && printf '%s' "$out" | grep -q "open item" && printf '%s' "$out" | grep -q "one-off"; then
    pass "memory: import lists open items and dated one-offs as NOT imported"
  else fail "memory: import didn't list what it skipped: $out"; fi
  printf '%s' "$out" | grep -q "1 duplicates folded" && pass "memory: import folds an obvious duplicate" \
    || fail "memory: import didn't fold the duplicate: $(printf '%s' "$out" | head -1)"
  mem list --status proposed | grep -q "Run bash -n on gate.sh" && mem list --status proposed | grep "Run bash -n" | grep -q " rule " \
    && pass "memory: a correction comes in as a proposed rule" || fail "memory: correction not imported as a rule"
  mem list --status proposed | grep -q "obligations webhook" && fail "memory: a dated one-off was imported" \
    || pass "memory: no dated one-off among the proposals"
  mem import --remember-dir "$T/fx" --corrections "$T/fx/corr.jsonl" >/dev/null 2>&1 \
    && fail "memory: a second import should refuse" || pass "memory: import runs once (second run refused)"

  # --- status
  out="$(mem status 2>&1)"
  printf '%s' "$out" | grep -q "^chief " && printf '%s' "$out" | grep -q "proposed" \
    && pass "memory: status shows counts per Bot" || fail "memory: status output wrong: $out"

  # --- the real store was not touched
  real_after="$(ls -la "$COS/memory" 2>/dev/null | md5 -q 2>/dev/null || ls -la "$COS/memory" 2>/dev/null | cksum)"
  [ "$real_before" = "$real_after" ] && pass "memory: the real ~/cos/memory was not touched" \
    || fail "memory: the real ~/cos/memory changed during the tests"
  rm -rf "$T"
  unset -f mem
}

cos_memory_tests

if [ -n "${_mem_standalone:-}" ]; then
  printf '\nmemory tests: %d passed, %d failed\n' "$ok" "$bad"
  [ "$bad" -eq 0 ]
fi
