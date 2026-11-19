#!/bin/bash
# test-packet.sh: tests for claude/cos-packet (plan changes 3 and 4: brief packets assembled on the Mac).
# Sourced by install.sh, which defines pass, fail and $KIT. Runs on its own too: bash claude/tests/test-packet.sh
# Temp HOME and stubs only: never the real ~/cos, no network, no Bot. Every outside command is a stub.
if ! declare -F pass >/dev/null; then
  KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  ok=0; bad=0; pass() { printf '  ✓ %s\n' "$1"; ok=$((ok+1)); }; fail() { printf '  ✗ %s\n' "$1"; bad=$((bad+1)); }
  PKT_STANDALONE=1
fi
echo "Brief packets (cos-packet)"
PKT="$(mktemp -d)"; PKT="$(cd "$PKT" && pwd -P)"
mkdir -p "$PKT/home/cos/state/ledger" "$PKT/home/cos/outbox" "$PKT/stub"
PH="$PKT/home"; PC="$PH/cos"; PCALLS="$PKT/calls.log"

# cos-run stub: one receipt per lane, like the real lanes. PKT_FAIL=<lane> makes that lane fail; PKT_SLOW=<lane> hangs.
cat > "$PKT/stub/cos-run" <<'STUB'
#!/bin/bash
echo "cos-run $*" >> "$PKT_CALLS"
lane="$1"; job="$2"; O="$HOME/cos/outbox/$job"
[[ "$PKT_FAIL" == "$lane" ]] && { echo "boom: $lane fell over at /Users/x/cos/outbox/$job" >&2; exit 3; }
[[ "$PKT_SLOW" == "$lane" ]] && { sleep 30; exit 0; }
case "$lane" in
  gh-scan)
    mkdir -p "$O"
    jq -n '{need: [
      ["review requested","data-org#805","Intake sweep fix: handle missing owners","by dgonzo, updated Wed Nov 18, 3:00 PM","https://github.com/wisecodeai/data-org/pull/805"],
      ["review requested","data-org#811","Review A","by dgonzo, updated Wed Nov 18, 3:00 PM","https://github.com/wisecodeai/data-org/pull/811"],
      ["review requested","data-org#812","Review B","by mmaxwell, updated Wed Nov 18, 3:00 PM","https://github.com/wisecodeai/data-org/pull/812"],
      ["review requested","data-org#813","Review C","by mmaxwell, updated Wed Nov 18, 3:00 PM","https://github.com/wisecodeai/data-org/pull/813"],
      ["mentioned you","data-org#767","Ingredient re-parse: v2 rules","nwong commented, Wed Nov 18, 5:10 PM: can you look at the parse counts?","https://github.com/wisecodeai/data-org/issues/767#issuecomment-1"]],
      fyi: [["new activity","food-enrichment#220","Denominator definition","nwong commented, Wed Nov 18, 6:00 PM: pushed","https://github.com/wisecodeai/food-enrichment/issues/220"]]}' > "$O/scan.json"
    jq -n --arg j "$job" --arg a "$O/scan.json" '{job: $j, lane: "gh-scan", receipt: {status: "done", summary: "GitHub: 5 need you", artifacts: [$a]}}' > "$O/receipt.json"
    cat "$O/receipt.json" ;;
  owed)
    jq -n '{checked_at: "2026-11-19T13:06:00+00:00", open: [
      "[#700 · Label facts timing](https://github.com/wisecodeai/data-org/issues/700) — dgonzo asked you on 2026-11-06; you haven'"'"'t answered since",
      "[#790 · Fresh ask](https://github.com/wisecodeai/data-org/issues/790) — mmaxwell-wisecode asked you on 2026-11-18; you haven'"'"'t answered since",
      "[PR #805 · Intake sweep fix](https://github.com/wisecodeai/data-org/pull/805) — dgonzo'"'"'s PR · waiting on your review"]}' ;;
  slack-read)
    mkdir -p "$O"
    jq -n --arg j "$job" '{job: $j, lane: "slack-read", receipt: {status: "done", summary: "read 6", items: [
      {where: "Steve DM", when: "Wed Nov 18, 2:10 PM", what: "Asked you to approve the GitHub app.", link: "https://wisecode.slack.com/archives/D1/p1", waiting_on_cassidy: true},
      {where: "#data-team", when: "Wed Nov 18, 3:00 PM", what: "Matt shared the test sets.", link: "https://wisecode.slack.com/archives/C1/p2", waiting_on_cassidy: false}]}}' > "$O/receipt.json"
    cat "$O/receipt.json" ;;
  mail-read)
    mkdir -p "$O"
    jq -n --arg j "$job" '{job: $j, lane: "mail-read", receipt: {status: "done", summary: "read 4", items: [
      {where: "Greta (Datasembly)", when: "Wed Nov 18, 1:00 PM", what: "Asked which retailers to add first.", link: "https://mail.google.com/mail/u/0/#inbox/abc", waiting_on_cassidy: true}]}}' > "$O/receipt.json"
    cat "$O/receipt.json" ;;
  atlas)
    mkdir -p "$O"
    jq -n --arg j "$job" '{job: $j, lane: "atlas", receipt: {status: "done", summary: "- Dashboard chat, Claude Code, data-org-notebook: did the scan-demand page. cards: 767"}}' > "$O/receipt.json"
    cat "$O/receipt.json" ;;
  receipt)
    if [[ -f "$O/receipt.json" ]]; then cat "$O/receipt.json"; else jq -n --arg j "$job" '{job: $j, status: "not found"}'; exit 66; fi ;;
  *) echo "unexpected lane $lane" >&2; exit 64 ;;
esac
STUB
cat > "$PKT/stub/cos-health" <<'STUB'
#!/bin/bash
echo "cos-health $*" >> "$PKT_CALLS"
[[ "$PKT_FAIL" == health ]] && exit 2
echo "All 31 runs in the last ${3:-12} hours worked. (40 health checks, none found a problem.)"
STUB
cat > "$PKT/stub/cos-gh" <<'STUB'
#!/bin/bash
echo "cos-gh $*" >> "$PKT_CALLS"
[[ "$PKT_FAIL" == gh ]] && { echo "gh: HTTP 502" >&2; exit 1; }
jq -n '{batch: "x", writes: 2, items: [
  {tier: 2, says: "Rewrite the description of #717 · EN40 coverage date (new text in the job folder)"},
  {tier: 0, says: "Make #718 a sub-issue of #649 · November slice"}]}'
STUB
cat > "$PKT/stub/cos-push" <<'STUB'
#!/bin/bash
echo "cos-push $*" >> "$PKT_CALLS"
STUB
chmod +x "$PKT/stub/"*

pk() {  # run cos-packet in the temp home with every outside command stubbed
  HOME="$PH" PKT_CALLS="$PCALLS" COS_PACKET_RUN="$PKT/stub/cos-run" COS_PACKET_HEALTH="$PKT/stub/cos-health" \
    COS_PACKET_PUSH="$PKT/stub/cos-push" COS_PACKET_GH="$PKT/stub/cos-gh" COS_PACKET_NOW="${PKT_NOW:-2026-11-19T06:05:00}" \
    PKT_FAIL="${PKT_FAIL:-}" PKT_SLOW="${PKT_SLOW:-}" COS_PACKET_CAP="${PKT_CAP:-}" \
    "$KIT/claude/cos-packet" "$@"
}
sect() { awk -v h="## $2" '$0==h{f=1;next} /^## /{f=0} f' "$1"; }   # one section's lines
order() { grep '^## ' "$1" | tr '\n' '|'; }

# A staged batch he was shown (previewed at this exact content) and not yet applied, and one he wasn't shown.
SB="$PC/outbox/stage-717-20261118"; mkdir -p "$SB"
echo 'gh issue edit 717 --repo wisecodeai/data-org --body-file /x/717-body.md' > "$SB/apply.sh"
echo "apply $(shasum -a 256 "$SB/apply.sh" | cut -d' ' -f1)" > "$SB/.previewed"
jq -n '{receipt: {summary: "Needs Cassidy: approve", needs_approval: [{target: "wisecodeai/data-org#717 description", why: "Changes Jan 31 to Dec 31 to match #740. More detail at /Users/cassidythilton/cos/outbox/x."}]}}' > "$SB/receipt.json"
touch -t 202611181952 "$SB/.previewed"
SU="$PC/outbox/stage-999-unseen"; mkdir -p "$SU"; echo 'make field CARD=999' > "$SU/apply.sh"; echo '{}' > "$SU/receipt.json"
echo '{"data-org#767": "Ingredient re-parse", "#717": {"name": "EN40 coverage date"}, "people": {"dgonzo": "David"}}' > "$PC/state/names.json"
mkdir -p "$PC/handbook"; cat > "$PC/handbook/people.md" <<'MD'
| Person | Handle | Role |
|---|---|---|
| David Gonzalez ("Dave", "Gonzo") | GitHub dgonzo, Slack U1 | CDO |
| Matt Maxwell | GitHub mmaxwell-wisecode, repo mmaxwell-sandbox | Live side |
MD
# A sheet-only batch he was shown: its cells are said in words, without cos-gh.
SS="$PC/outbox/sheet-row9-20261118"; mkdir -p "$SS"
echo '{"spreadsheet":"s","writes":[{"tab":"Data Roadmap","row":9,"row_name":"Label facts","col":"D","col_name":"Owner","old":"","new":"Matt"},{"tab":"Data Roadmap","row":9,"row_name":"Label facts","col":"E","old":"Nov 25","new":"Dec 2"}]}' > "$SS/sheet.json"
echo "sheet $(shasum -a 256 "$SS/sheet.json" | cut -d' ' -f1)" > "$SS/.previewed"; echo '{}' > "$SS/receipt.json"; touch -t 202611182000 "$SS/.previewed"
# Today's tier-0 work and a Slack draft (Thu Nov 19, Mountain), plus yesterday's, which must not show.
cat > "$PC/state/ledger/tier_zero.jsonl" <<'J'
{"ts":"2026-11-19T20:10:00Z","stream":"tier_zero","job":"t0-777-target","ref":"t0-a","action":"field data-org#777 Target 2026-12-31","card":"data-org#777","decision":"done","undo":"cos-run gh <job> undo t0-a"}
{"ts":"2026-11-18T20:10:00Z","stream":"tier_zero","job":"t0-old","ref":"t0-b","action":"label data-org#600 add type/intake","card":"data-org#600","decision":"done","undo":"cos-run gh <job> undo t0-b"}
{"ts":"2026-11-19T20:20:00Z","stream":"tier_zero","job":"t0-x","ref":"t0-c","action":"label data-org#601 add x","card":"data-org#601","decision":"refused"}
J
echo '{"ts":"2026-11-19T21:00:00Z","stream":"slack_drafts","job":"sd-steve","to":"Steve","status":"done","first_line":"Hi Steve, the app is ready"}' > "$PC/state/ledger/slack_drafts.jsonl"

# 1. Morning, every step works, --no-push.
: > "$PCALLS"; pk morning --no-push > "$PKT/m.out" 2> "$PKT/m.err"; rc=$?
PM="$PC/outbox/packet-morning-20261119/packet.md"; PR="$PC/outbox/packet-morning-20261119/receipt.json"
[[ $rc -eq 0 && -f "$PM" && -f "$PR" ]] && pass "packet: a morning packet is written (packet.md and receipt.json)" || fail "packet: no morning packet (rc $rc): $(head -3 "$PKT/m.err")"
[[ "$(order "$PM")" == "## Health|## Decisions|## Owed|## Slack waiting on you|## Email waiting on you|## FYI|" ]] \
  && pass "packet: morning sections in order: health, decisions, owed, Slack, FYI" || fail "packet: morning section order is $(order "$PM")"
grep -q '^cos-push' "$PCALLS" && fail "packet: --no-push still pushed" || pass "packet: --no-push doesn't push"
[[ ! -f "$PC/state/packet-last.json" ]] && pass "packet: --no-push doesn't move the last-brief time" || fail "packet: --no-push moved the last-brief time"
n="$(sect "$PM" Decisions | grep -cE '^[0-9]+\. ')"
[[ "$n" -le 5 && "$n" -ge 1 ]] && pass "packet: at most 5 decisions ($n here, from 6 candidates)" || fail "packet: $n decisions"
sect "$PM" Decisions | grep -qE '^[0-9]+\. .*\(yes / no / later\)$' && ! sect "$PM" Decisions | grep -E '^[0-9]+\. ' | grep -vq '(yes / no / later)$' \
  && pass "packet: every decision is answerable yes / no / later" || fail "packet: a decision isn't yes / no / later"
sect "$PM" FYI | grep -q 'Held for the next brief' && sect "$PM" FYI | grep -q 'PR #813' \
  && pass "packet: decisions past five are listed (linked) for the next brief, not dropped" || fail "packet: decisions past five vanished"
sect "$PM" Decisions | grep -qF '1. Make this staged change: Rewrite the description of [#717 · EN40 coverage date](https://github.com/wisecodeai/data-org/issues/717) (new text in the job folder); Make [#718](https://github.com/wisecodeai/data-org/issues/718) a sub-issue of [#649 · November slice](https://github.com/wisecodeai/data-org/issues/649)? You saw it Wed Nov 18, 7:52 PM. (yes / no / later)' \
  && grep -q "cos-gh stage-717-20261118 plain $PC/outbox/stage-717-20261118/apply.sh" "$PCALLS" && ! grep -q '#999' "$PM" \
  && pass "packet: a previewed, unapplied batch is decision 1, in cos-gh's plain words with linked cards; one never shown isn't a decision" || fail "packet: staged batches wrong: $(sect "$PM" Decisions | head -2)"
sect "$PM" Decisions | grep -qF '2. Make this staged change: the Data Roadmap sheet, "Label facts" row, Owner: "" becomes "Matt"; the Data Roadmap sheet, "Label facts" row, column E: "Nov 25" becomes "Dec 2"? You saw it Wed Nov 18, 8:00 PM.' \
  && pass "packet: a staged sheet change is said cell by cell (row name, column name or letter, old and new)" || fail "packet: sheet decision wrong: $(sect "$PM" Decisions | sed -n 3,4p)"
sect "$PM" Decisions | grep -q "Draft a reply on \[#700 · Label facts timing\](https://github.com/wisecodeai/data-org/issues/700) — David asked you" \
  && sect "$PM" Decisions | grep -qF "Review [PR #805 · Intake sweep fix](https://github.com/wisecodeai/data-org/pull/805) — David's PR" \
  && sect "$PM" Owed | grep -q '— Matt asked you on Wed Nov 18' && grep -q 'nwong commented' "$PM" && ! grep -q '— dgonzo\|mmaxwell-wisecode asked' "$PM" \
  && pass "packet: logins become first names (names.json people first, then people.md's Handle column, else the login)" || fail "packet: people names wrong"
grep -q '/Users/\|/x/717' "$PM" && fail "packet: a file path reached the packet" || pass "packet: no file paths in the packet"
sect "$PM" Decisions | grep -q '^3\. Draft a reply on \[#700 · Label facts timing\].*asked you on Fri Nov 6' && ! sect "$PM" Decisions | grep -q '#790' \
  && ! grep -q '2026-11-' <(sect "$PM" Owed) \
  && pass "packet: an owed reply older than 2 days is a decision; a fresh one isn't" || fail "packet: owed-reply decisions wrong"
[[ "$(sect "$PM" Decisions | grep -c 'pull/805')" == 1 ]] && pass "packet: an item in both GitHub and the owed list is one decision, not two" || fail "packet: duplicate decision for PR #805"
OW="$(sect "$PM" Owed | grep -v '^$')"
[[ -n "$OW" ]] && ! grep -qvE '^- \[(PR )?(#|[a-z-]+ #)[0-9]+ · [^]]+\]\(https://github\.com/[^)]+\) — ' <<<"$OW" \
  && ! grep -qiE '(^|- )[0-9]+ (repl|item|thing|owed|card|PR)' <<<"$OW" \
  && pass "packet: OWED is linked plain lines, never a count alone" || fail "packet: OWED has an unlinked line or a bare count: $OW"
grep -qF '[PR #805 · Intake sweep fix](https://github.com/wisecodeai/data-org/pull/805) — ' "$PM" \
  && grep -qF '[#767 · Ingredient re-parse](https://github.com/wisecodeai/data-org/issues/767' "$PM" \
  && grep -qF '[food-enrichment #220 · Denominator definition](https://github.com/wisecodeai/food-enrichment/issues/220) — ' "$PM" \
  && pass "packet: cards and PRs use the plain format, names.json first, else the title's head" || fail "packet: plain-format links missing"
! grep -E '\[[^]]*#[0-9]+ · [^]]{41,}\]' "$PM" >/dev/null && pass "packet: short names are at most 40 characters" || fail "packet: a short name is over 40 characters"
sect "$PM" 'Slack waiting on you' | grep -q 'Steve DM.*approve the GitHub app' && ! sect "$PM" 'Slack waiting on you' | grep -q 'test sets' \
  && pass "packet: Slack lists only what waits on him; the rest is FYI" || fail "packet: Slack section wrong"
grep -q "Google Calendar" "$PM" && pass "packet: the morning packet says the Chief adds today's meetings from Google Calendar" || fail "packet: no calendar line"
grep -q "slack-read sl-morning-20261119-0605 every DM, group DM and thread Cassidy is in with activity since Wed Nov 18, 4:12 PM MT" "$PCALLS" \
  && grep -q 'gh-scan scan-brief-20261119-0605 --state brief' "$PCALLS" && grep -q 'atlas atlas-20261119-morning-0605 since Wed Nov 18, 4:12 PM MT' "$PCALLS" \
  && grep -q 'cos-health line --hours 12' "$PCALLS" && ! grep -q 'receipt capture' "$PCALLS" \
  && pass "packet: morning runs health, GitHub, owed, Slack and chats with -HHMM job ids and the 4:12 PM window" || fail "packet: morning calls: $(tr '\n' ';' < "$PCALLS")"
jq -e '.job == "packet-morning-20261119" and .lane == "packet" and .receipt.status == "done" and (.receipt.summary|length) <= 12000 and .receipt.open_questions == []' "$PR" >/dev/null \
  && pass "packet: receipt.json has job, lane packet, status, the packet as summary and open_questions" || fail "packet: receipt.json shape"
! grep -q "What couldn't be read" "$PM" && pass "packet: no failure lines when every step worked" || fail "packet: failure lines with nothing failing"

# 2. A failing step becomes a line at the top, not silence; the rest of the packet still comes.
rm -rf "$PC/outbox/packet-morning-20261119"
PKT_FAIL=slack-read pk morning --no-push > /dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && grep -q "^## What couldn't be read" "$PM" && grep -q "^- Slack couldn't be read: it stopped with an error" "$PM" \
  && [[ "$(grep -n "^## What couldn't be read" "$PM" | cut -d: -f1)" -lt "$(grep -n '^## Health' "$PM" | cut -d: -f1)" ]] \
  && pass "packet: a failed step is a plain line at the top, above the health line" || fail "packet: failed step not at the top: $(head -8 "$PM")"
sect "$PM" 'Slack waiting on you' | grep -q "couldn't be read" && ! sect "$PM" 'Slack waiting on you' | grep -q 'Nothing in Slack' \
  && pass "packet: a failed Slack read never says 'nothing waiting'" || fail "packet: failed Slack read looked like nothing waiting"
jq -e '.receipt.status == "partial"' "$PC/outbox/packet-morning-20261119/receipt.json" >/dev/null && sect "$PM" Owed | grep -q '#700' \
  && pass "packet: one failed step makes the packet partial and keeps the other sections" || fail "packet: one failure sank the packet"
PKT_FAIL=gh pk morning --no-push > /dev/null 2>&1
grep -q "^- The plain words for a staged change couldn't be read" "$PM" && sect "$PM" Decisions | grep -qF 'Make the staged change on [#717 · EN40 coverage date](https://github.com/wisecodeai/data-org/issues/717): Changes Jan 31 to Dec 31 to match #740?' \
  && pass "packet: if cos-gh can't say a batch in words, a top line says so and the batch still shows from its summary" || fail "packet: cos-gh failure handling"
PKT_FAIL=owed pk morning --no-push > /dev/null 2>&1
grep -q "^- The owed list couldn't be read" "$PM" && sect "$PM" Owed | grep -q "not nothing owed" \
  && pass "packet: a failed owed list says not known, never 'nothing owed'" || fail "packet: failed owed list looked empty"
PKT_FAIL=health pk morning --no-push > /dev/null 2>&1
grep -q "^- The health check couldn't be read" "$PM" && pass "packet: a failed health check is a top line too" || fail "packet: failed health check was silent"
PKT_SLOW=atlas PKT_CAP=2 pk morning --no-push > /dev/null 2>&1
grep -q "^- Today's chats (Agent Atlas) couldn't be read: it didn't finish within 2 seconds" "$PM" \
  && pass "packet: a step past its time cap is stopped and named at the top" || fail "packet: time cap didn't hold"
# gh-scan exits 0 but its receipt says failed: still a failure line.
cat > "$PKT/stub/cos-run-ghfail" <<'STUB'
#!/bin/bash
if [[ "$1" == gh-scan ]]; then O="$HOME/cos/outbox/$2"; mkdir -p "$O"
  echo '{"job":"x","lane":"gh-scan","receipt":{"status":"failed","summary":"GitHub read failed: who am I: HTTP 502"}}' > "$O/receipt.json"; cat "$O/receipt.json"; exit 0; fi
exec "$(dirname "$0")/cos-run" "$@"
STUB
chmod +x "$PKT/stub/cos-run-ghfail"
HOME="$PH" PKT_CALLS="$PCALLS" COS_PACKET_RUN="$PKT/stub/cos-run-ghfail" COS_PACKET_HEALTH="$PKT/stub/cos-health" COS_PACKET_PUSH="$PKT/stub/cos-push" \
  COS_PACKET_NOW=2026-11-19T06:07:00 "$KIT/claude/cos-packet" morning --no-push > /dev/null 2>&1
grep -q "^- GitHub couldn't be read: it reported failed" "$PM" && pass "packet: a lane that exits 0 with a failed receipt is still a top line" || fail "packet: a failed receipt was taken as success"

# 3. Evening: done without asking, the 4 PM capture, push.
CP="$PC/outbox/capture-20261119"; mkdir -p "$CP"; echo 'make ragb CARD=777 RAGB=Green' > "$CP/apply.sh"
echo '{"job":"capture-20261119","lane":"investigate","receipt":{"status":"done","summary":"Capture: 3 rows. Batch staged for your yes."}}' > "$CP/receipt.json"
: > "$PCALLS"; PKT_NOW=2026-11-19T16:20:00 pk evening > /dev/null 2>&1; rc=$?
PE="$PC/outbox/packet-evening-20261119/packet.md"
[[ "$(order "$PE")" == "## Health|## Decisions|## Done without asking|## Owed|## Slack waiting on you|## Email waiting on you|## FYI|## For the Chief only (never show Cassidy): how to undo today's changes|" ]] \
  && pass "packet: evening sections in order, with done without asking after decisions" || fail "packet: evening order is $(order "$PE")"
DW="$(sect "$PE" 'Done without asking')"
grep -qF '[#777](https://github.com/wisecodeai/data-org/issues/777) — set its Target to Thu Dec 31' <<<"$DW" && grep -q '#777.*set its Target to Thu Dec 31, 1:10 PM, you can undo it' <<<"$DW" && grep -q 'Slack draft to Steve.*nothing was sent' <<<"$DW" \
  && ! grep -q '#600\|#601' <<<"$DW" \
  && pass "packet: done without asking has today's changes and drafts only (not yesterday's, not refused)" || fail "packet: done without asking wrong: $DW"
grep -q 'cos-run' <(sed '/^## For the Chief only/,$d' "$PE") && fail "packet: a lane command reached what Cassidy reads" || pass "packet: undo commands only in the Chief's section, last"
sect "$PE" Decisions | grep -q "Post today's daily logs" && grep -q 'receipt capture-20261119' "$PCALLS" && grep -q 'cos-health line --hours 14' "$PCALLS" \
  && grep -q 'atlas atlas-20261119-evening-1620 today' "$PCALLS" && grep -q 'slack-read sl-evening-20261119-1620 ' "$PCALLS" \
  && pass "packet: evening reads the 4 PM capture and offers its staged logs as a decision" || fail "packet: evening capture missing"
! grep -q 'Google Calendar' "$PE" && pass "packet: the evening packet has no calendar line" || fail "packet: calendar line in the evening"
grep -qx "cos-push chief packet $PC/outbox/packet-evening-20261119/receipt.json" "$PCALLS" && jq -e '.evening' "$PC/state/packet-last.json" >/dev/null \
  && pass "packet: without --no-push it pushes to the Chief's packet slot and records the time" || fail "packet: push call: $(grep cos-push "$PCALLS")"
rm -rf "$CP"; PKT_NOW=2026-11-19T16:25:00 pk evening --no-push > /dev/null 2>&1
grep -q "^- The 4 PM daily-log capture couldn't be read: there's no capture result for today" "$PE" \
  && pass "packet: a missing 4 PM capture is a top line" || fail "packet: missing capture was silent"

# 4. --dry-run runs nothing and writes nothing; bad arguments are refused.
rm -rf "$PC/outbox/packet-morning-20261119"; : > "$PCALLS"
pk morning --dry-run > "$PKT/d.out" 2>&1; rc=$?
[[ $rc -eq 0 && ! -s "$PCALLS" && ! -e "$PC/outbox/packet-morning-20261119" ]] && grep -q 'gh-scan scan-brief-20261119-0605' "$PKT/d.out" \
  && pass "packet: --dry-run lists the steps and runs or writes nothing" || fail "packet: --dry-run ran or wrote something"
pk noon > /dev/null 2>&1; [[ $? -eq 64 ]] && pass "packet: an unknown kind is refused" || fail "packet: accepted an unknown kind"

# 5. The summary is capped at 12,000 characters.
for i in $(seq 1 400); do echo "{\"ts\":\"2026-11-19T20:10:00Z\",\"job\":\"t$i\",\"ref\":\"r$i\",\"action\":\"field data-org#$i Target 2026-12-31 with a long explanation to fill the page up quickly\",\"card\":\"data-org#$i\",\"decision\":\"done\",\"undo\":\"cos-run gh <job> undo r$i\"}"; done >> "$PC/state/ledger/tier_zero.jsonl"
PKT_NOW=2026-11-19T16:30:00 pk evening --no-push > /dev/null 2>&1
jq -e '(.receipt.summary|length) <= 12000' "$PC/outbox/packet-evening-20261119/receipt.json" >/dev/null \
  && pass "packet: the receipt's summary stays within 12,000 characters" || fail "packet: summary over 12,000 characters"

[[ -n "${PKT_KEEP:-}" ]] && echo "kept: $PKT" || rm -rf "$PKT"
if [[ -n "${PKT_STANDALONE:-}" ]]; then echo "$ok passed, $bad failed"; [[ $bad -eq 0 ]]; fi
