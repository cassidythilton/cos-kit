#!/bin/bash
# install.sh: install or update the chief-of-staff kit, then prove the walls hold.
# Safe to re-run. No model is called.
#   ./install.sh               install + self-test
#   ./install.sh --online      also run board-pulse once (read-only GitHub calls)
#   ./install.sh --schedule    also (re)load the launchd schedule (cos-sched list shows it)
#   ./install.sh --schedule=followups,pulse   load only those slots
#   ./install.sh --schedule=dashboard         also load com.cos.dashboard (cos-db load every 300s)
#   ./install.sh --schedule=zoommirror        also load com.cos.zoommirror (copy ~/Documents/Zoom transcripts to ~/cos/zoom)
#   ./install.sh --unschedule  remove the launchd schedule, including the dashboard
#   HOME=<empty temp dir> ./install.sh --sandbox   install into that throwaway home and run every test there.
#              Touches nothing of Cassidy's: no repos, no clones, no kit checks, no apps, no schedule. Used by cos-run fix.
# Writes to: ~/cos, ~/builds, ~/.claude/skills/cassidy-mode, ~/.cursor/skills/cassidy-mode,
#            ~/.claude/CLAUDE.md (only if it doesn't exist), ~/Library/LaunchAgents/com.cos.* (only with --schedule).
set -uo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"; COS="$HOME/cos"; ONLINE=0; SCHEDULE=0; UNSCHEDULE=0; SANDBOX=0
ONLY=""
for a in "$@"; do case "$a" in --online) ONLINE=1;; --schedule) SCHEDULE=1;; --schedule=*) SCHEDULE=1; ONLY="${a#--schedule=}";; --unschedule) UNSCHEDULE=1;; --sandbox) SANDBOX=1;; *) echo "unknown: $a" >&2; exit 64;; esac; done
ok=0; bad=0; pass() { printf '  ✓ %s\n' "$1"; ok=$((ok+1)); }; fail() { printf '  ✗ %s\n' "$1"; bad=$((bad+1)); }
if [[ $SANDBOX -eq 1 ]]; then
  realhome="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  [[ -n "$realhome" && "$HOME" != "$realhome" && "$HOME" != "$realhome/" ]] || { echo "--sandbox needs HOME set to a throwaway folder, not your real home" >&2; exit 64; }
  [[ $SCHEDULE -eq 0 && $UNSCHEDULE -eq 0 && $ONLINE -eq 0 ]] || { echo "--sandbox can't schedule, unschedule or go online" >&2; exit 64; }
fi
LA="$HOME/Library/LaunchAgents"; SLOTS="followups pulse reconcile capture week opportunity keeper obligations"

if [[ $UNSCHEDULE -eq 1 ]]; then
  for s in $SLOTS dashboard zoommirror tcccheck; do launchctl bootout "gui/$(id -u)/com.cos.$s" 2>/dev/null; rm -f "$LA/com.cos.$s.plist"; done
  echo "Schedule removed."; exit 0
fi

echo "1. Prerequisites"
for c in claude agent gh jq git perl shasum uv openssl rsync bc curl security launchctl python3; do command -v $c >/dev/null && pass "$c" || fail "$c not on PATH"; done
if [[ $SANDBOX -eq 0 ]]; then
gh auth status >/dev/null 2>&1 && pass "gh signed in" || fail "gh not signed in (gh auth login)"
[[ -d "$HOME/Documents/Data-Org-Repos/data-org/.git" ]] && pass "data-org repo" || fail "data-org repo missing at ~/Documents/Data-Org-Repos/data-org"
[[ -f "$HOME/Documents/Data-Org-Repos/data-org-notebook/scripts/run_query.py" ]] && pass "data-org-notebook (lake-query)" || fail "data-org-notebook missing (lake-query won't work)"
[[ -d "$HOME/meetings" ]] && pass "~/meetings" || fail "~/meetings missing"
# Scheduled jobs run under launchd, which macOS keeps out of ~/Documents (TCC). Jobs get their own clones in ~/cos/repos.
mkdir -p "$COS/repos"
for r in data-org data-org-notebook; do
  [[ -d "$COS/repos/$r/.git" ]] || git clone -q "https://github.com/wisecodeai/$r.git" "$COS/repos/$r" 2>/dev/null
  [[ -d "$COS/repos/$r/.git" ]] && pass "job clone ~/cos/repos/$r" || fail "could not clone wisecodeai/$r into ~/cos/repos"
done
for w in data-org-main notebook-main; do
  if [[ -f "$COS/$w/.git" ]] && grep -q "/Documents/" "$COS/$w/.git"; then fail "~/cos/$w is linked into ~/Documents; scheduled jobs can't read it (remove it; the next job rebuilds it)"; else pass "~/cos/$w is outside ~/Documents"; fi
done
mkdir -p "$COS/zoom"
# ~/Documents/Zoom is the primary (Zoom saves transcripts there). ZoomMirror copies them to ~/cos/zoom for the jobs.
if [[ -d "$HOME/Documents/Zoom" ]]; then
  newest="$(ls -t "$HOME/Documents/Zoom"/*.txt 2>/dev/null | head -1)"
  if [[ -z "$newest" || -f "$COS/zoom/$(basename "$newest")" ]]; then pass "~/cos/zoom has the newest Zoom transcript"; else fail "~/cos/zoom is missing $(basename "$newest"): run  open ~/cos/bin/ZoomMirror.app  (and Allow), then ./install.sh --schedule=zoommirror"; fi
fi
# The BOARD agent's handoff (written in ~/Documents) is STEWARD's method and state; ZoomMirror copies it.
HO="$HOME/Documents/Data-Org-Repos/data-org-agent-handoff.md"
if [[ -f "$HO" ]]; then cmp -s "$HO" "$COS/handbook/board-handoff.md" && pass "board handoff mirrored to ~/cos/handbook" || fail "~/cos/handbook/board-handoff.md is missing or stale: run  open ~/cos/bin/ZoomMirror.app"; fi

fi

echo "2. The kit, versioned"
if [[ $SANDBOX -eq 1 ]]; then echo "  · sandbox: kit checks skipped"; else
# ~/cos/kit is the only source (a git repo, pushed to github.com/cassidythilton/cos-kit). Edit there, commit with a real
# message, then run this installer from it. A copy elsewhere may only seed a kit that doesn't exist yet.
if [[ "$KIT" != "$COS/kit" ]]; then
  if [[ -d "$COS/kit/.git" ]]; then echo "  ✗ ~/cos/kit already exists. Edit and install from it: cd ~/cos/kit && ./install.sh"; exit 1; fi
  mkdir -p "$COS/kit"; rsync -a --exclude .git "$KIT/" "$COS/kit/"; git -C "$COS/kit" init -q -b main
  git -C "$COS/kit" add -A && git -C "$COS/kit" commit -qm "Seed kit" && pass "seeded ~/cos/kit"
fi
if [[ -n "$(git -C "$COS/kit" status --porcelain)" ]]; then fail "~/cos/kit has uncommitted changes: commit them with a message first (git -C ~/cos/kit commit -am '<why>')"
else pass "~/cos/kit clean at $(git -C "$COS/kit" log -1 --format=%h)"; fi
if git -C "$COS/kit" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  ahead="$(git -C "$COS/kit" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  [[ "$ahead" -eq 0 ]] && pass "~/cos/kit matches GitHub" || printf '  · %s commit(s) not pushed yet (git -C ~/cos/kit push)\n' "$ahead"
fi

fi

echo "3. Files"
mkdir -p "$COS"/{bin,claude/briefs,handbook,outbox,state,archive,evals/runs} "$HOME/builds"
install -m 755 "$KIT"/claude/{cos-run,cos-sched,cos-push,cos-obligations,cos-link,cos-sandbox-test,cos-tcc-check,cos-gh-scan,board-pulse,lake-query,cos-ledger,cos-db,cos-dash} "$COS/bin/"
install -m 755 "$KIT/claude/gate.sh" "$COS/claude/"
# cos-launch: the one program launchd starts for every job, so one Full Disk Access grant covers them all (see
# claude/cos-launch.c). Rebuilt only when its source changes, because macOS ties the grant to the build.
if [[ ! -x "$COS/bin/cos-launch" ]] || ! cmp -s "$KIT/claude/cos-launch.c" "$COS/claude/cos-launch.c"; then
  if cc -O2 -Wall -o "$COS/bin/cos-launch.new" "$KIT/claude/cos-launch.c" 2>"$COS/state/cos-launch-build.err" \
     && codesign -f -s - -i com.cos.launch "$COS/bin/cos-launch.new" 2>>"$COS/state/cos-launch-build.err"; then
    mv -f "$COS/bin/cos-launch.new" "$COS/bin/cos-launch"; install -m 644 "$KIT/claude/cos-launch.c" "$COS/claude/cos-launch.c"
    [[ $SANDBOX -eq 0 ]] && echo "  ! cos-launch was (re)built: give it Full Disk Access (INSTALL.md), then ./install.sh --schedule"
  else fail "cos-launch did not build (see ~/cos/state/cos-launch-build.err)"; fi
fi
# ZoomMirror.app: the one reader of ~/Documents/Zoom (see claude/zoom-mirror.applescript). Rebuilt only when the
# source changes, because macOS ties the Documents grant to the app's signature.
ZM="$COS/bin/ZoomMirror.app"
if [[ $SANDBOX -eq 0 ]] && { [[ ! -d "$ZM" ]] || ! cmp -s "$KIT/claude/zoom-mirror.applescript" "$ZM/Contents/Resources/zoom-mirror.applescript"; }; then
  rm -rf "$ZM" && osacompile -o "$ZM" "$KIT/claude/zoom-mirror.applescript" \
    && /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$ZM/Contents/Info.plist" \
    && /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.cos.zoommirror" "$ZM/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.cos.zoommirror" "$ZM/Contents/Info.plist"
  cp "$KIT/claude/zoom-mirror.applescript" "$ZM/Contents/Resources/" && codesign -f -s - "$ZM" 2>/dev/null
  echo "  ! ZoomMirror.app was (re)built: run  open ~/cos/bin/ZoomMirror.app  once and click Allow for Documents"
fi
install -m 644 "$KIT"/claude/{agents.json,receipt.schema.json,settings.investigate.json,settings.draft.json,settings.build.json,settings.sheet.json,settings.fix.json,lane.md,build-lane.md,verifier.md} "$COS/claude/"
install -m 644 "$KIT"/claude/briefs/*.md "$COS/claude/briefs/"
install -m 644 "$KIT"/evals/*.json "$COS/evals/"
rm -rf "$COS/builds-template.new" && cp -R "$KIT/builds-template" "$COS/builds-template.new" && rm -rf "$COS/builds-template" && mv "$COS/builds-template.new" "$COS/builds-template"
backup_then_install() {  # kit-owned file: keep a backup if the installed copy was changed by hand
  local src="$1" dst="$2"; mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then cp "$dst" "$dst.bak-$(date +%Y%m%d%H%M%S)"; fi
  install -m 644 "$src" "$dst"; }
for f in rules.md board-standard.md engineering-standard.md system-map.md; do backup_then_install "$KIT/handbook/$f" "$COS/handbook/$f"; done
[[ -f "$COS/handbook/standing-approvals.json" ]] || install -m 644 "$KIT/handbook/standing-approvals.json" "$COS/handbook/"   # yours once installed: the kit never overwrites it
for f in people.md workstreams.md sources.md; do [[ -f "$COS/handbook/$f" ]] || printf '# %s\n\nFill this in. The kit never overwrites it.\n' "${f%.md}" > "$COS/handbook/$f"; done
touch "$COS/state/corrections.jsonl"
mkdir -p "$COS/state/ledger"
pass "installed to $COS (kit-owned handbook files backed up if they changed; yours untouched)"

echo "4. cassidy-mode, for Claude and Cursor"
backup_then_install "$KIT/claude-skills/cassidy-mode/SKILL.md" "$HOME/.claude/skills/cassidy-mode/SKILL.md"
backup_then_install "$KIT/claude-skills/cassidy-mode/SKILL.md" "$HOME/.cursor/skills/cassidy-mode/SKILL.md"
pass "skill installed in ~/.claude/skills and ~/.cursor/skills"
if [[ ! -f "$HOME/.claude/CLAUDE.md" ]]; then
  printf '# How I work\n\nEvery session, in every project: work in cassidy-mode.\n\n@~/.claude/skills/cassidy-mode/SKILL.md\n' > "$HOME/.claude/CLAUDE.md"
  pass "created ~/.claude/CLAUDE.md, which loads cassidy-mode in every Claude session"
elif grep -q 'cassidy-mode' "$HOME/.claude/CLAUDE.md"; then pass "~/.claude/CLAUDE.md already loads cassidy-mode"
else fail "~/.claude/CLAUDE.md exists and doesn't load cassidy-mode. Add this line to it yourself: @~/.claude/skills/cassidy-mode/SKILL.md"; fi

echo "5. Scripts parse"
is_bak() { [[ "$(basename "$1")" == *.bak-* ]]; }   # old copies (cos-run.bak-20261110), not installed scripts
is_bak "$COS/bin/cos-run.bak-20261110" && ! is_bak "$COS/bin/cos-run" && pass "backup copies (.bak-) are skipped" || fail "backup copies are not skipped"
for s in "$COS"/bin/* "$COS/claude/gate.sh" "$COS/builds-template/verify"; do
  [[ -d "$s" || "$(basename "$s")" == cos-launch ]] && continue; is_bak "$s" && continue; if head -1 "$s" | grep -q python; then python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"
  else bash -n "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"; fi; done
for j in "$COS"/claude/*.json "$COS"/evals/*.json "$COS/builds-template/.claude/settings.json"; do jq empty "$j" 2>/dev/null && pass "$(basename "$j")" || fail "$(basename "$j") is not valid JSON"; done
for s in $SLOTS; do [[ "$s" == pulse || "$s" == obligations || -f "$COS/claude/briefs/$s.md" ]] && pass "brief: $s" || fail "brief missing: $s"; done

echo "6. The gate (job mode = blocked, pair mode = asks, hard walls = always blocked)"
# COS_LEDGER_OFF: these probes are not Mac actions, so they must not land in the real ledger.
g() { printf '{"tool_name":"%s","tool_input":{"command":%s,"file_path":%s}}' "$1" "$(jq -Rn --arg c "$2" '$c')" "$(jq -Rn --arg c "${4:-}" '$c')" | COS_LEDGER_OFF=1 COS_GATE_MODE="$3" "$COS/claude/gate.sh" >/tmp/cos-gate.$$ 2>/dev/null; local rc=$?
      if [[ $rc -eq 2 ]]; then echo block; elif grep -q '"ask"' /tmp/cos-gate.$$; then echo ask; else echo allow; fi; }
chk() { local got; got="$(g Bash "$1" "$2")"; [[ "$got" == "$3" ]] && pass "$2 · $3 · $1" || fail "$2 · expected $3, got $got · $1"; }
chk "make board" job allow
chk "uv run pytest -q" job allow
chk "gh issue comment 1 -b hi" job block
chk "gh issue comment 1 -b hi" pair ask
chk "git push origin build/x" job block
chk "git push origin build/x" pair ask
chk "git push origin main" pair block
chk "terraform apply" pair block
chk "aws s3 sync . s3://b" pair block
chk 'psql "host=prod" -c "delete from food"' pair block
chk "select name from wisecode_gold.canon_term" pair block
chk "select count(*) from wisecode_gold.canon_term group by 1" pair allow
chk "cat .env" pair block
chk "EXECUTE=1 make intake-sweep" job block
chk "DRY_RUN=1 make ragb CARD=1 TO=RED" job allow
chk "cos-push steward pulse r.json" pair block
chk "cos-link sub wisecodeai/data-org#1 wisecodeai/data-org#2" job block
chk "gh api repos/wisecodeai/data-org/issues/721/comments --jq .[]" job allow
chk "gh api graphql -f query=query{viewer{login}}" job allow
chk "gh api graphql -f query=mutation{addStar(input:{starrableId:1}){clientMutationId}}" job block
chk "gh api repos/wisecodeai/data-org/issues/1/comments -f body=hi" job block
chk "gh pr list --search created:>=2026-11-09" job block
chk "git -C ~/cos/data-org-main grep -n Window origin/main" job allow
chk "launchctl list" job block
chk "cos-obligations --act" job block
chk "git -C ~/cos/kit commit -am x" pair block
chk "echo x > ~/cos/claude/lane.md" pair block
chk "cat ~/cos/claude/lane.md" job allow
chk "cat ~/cos/handbook/rules.md 2>&1 | head -50" job allow
chk "cp ~/cos/handbook/rules.md /tmp/r.md" job allow
chk "make intake-sweep" job allow
chk "EXECUTE=1 make intake-sweep" job block
got="$(g Write "" pair "$HOME/.claude/skills/cassidy-mode/SKILL.md")"; [[ "$got" == block ]] && pass "pair · block · writing a skill" || fail "a job could write a skill ($got)"
got="$(g Write "" job "$COS/outbox/x/a.md")"; [[ "$got" == allow ]] && pass "job · allow · writing in the job folder" || fail "job folder write blocked ($got)"
got="$(printf '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{}}' | COS_GATE_MODE=job "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?)"
[[ "$got" == 2 ]] && pass "job · block · Slack send" || fail "Slack send not blocked in job mode"
rm -f /tmp/cos-gate.$$
# Sheet mode: only the approved cell and value pass.
SBT="$(mktemp)"; echo '{"spreadsheet":"1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM","writes":[{"tab":"Data Roadmap","row":7,"row_name":"x","col":"D","old":"2026-11-25","new":"2026-11-30"}]}' > "$SBT"
sg() { printf '{"tool_name":"mcp__claude_ai_Google_Sheets__update_values","tool_input":{"spreadsheetId":"1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM","range":"%s","values":%s}}' "$1" "$2" | COS_LEDGER_OFF=1 COS_GATE_MODE=sheet COS_SHEET_BATCH="$SBT" "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?; }
[[ "$(sg "'Data Roadmap'!D7" '[["2026-11-30"]]')" == 0 ]] && pass "sheet · allow · the approved cell and value" || fail "sheet mode blocked the approved cell"
[[ "$(sg "'Data Roadmap'!D8" '[["2026-11-30"]]')" == 2 ]] && pass "sheet · block · another row" || fail "sheet mode allowed another row"
[[ "$(sg "'Data Roadmap'!D7" '[["2026-12-31"]]')" == 2 ]] && pass "sheet · block · another value" || fail "sheet mode allowed another value"
[[ "$(sg "'Data Roadmap'!D7:E7" '[["2026-11-30","x"]]')" == 2 ]] && pass "sheet · block · a wider range" || fail "sheet mode allowed a wider range"
rm -f "$SBT"
# Fix mode: Claude writes only in its own kit copy; the controls, the copy's .git, the installer and landing stay walled.
FXD="$(mktemp -d)"; FXD="$(cd "$FXD" && pwd -P)"; mkdir -p "$FXD/claude" "$FXD/.git"
fw() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1" | COS_LEDGER_OFF=1 COS_GATE_MODE=fix COS_FIX_DIR="$FXD" COS_FIX_OUT=/nonexistent "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?; }
[[ "$(fw "$FXD/claude/gate.sh")" == 0 ]] && pass "fix · allow · writing its own kit copy" || fail "fix mode blocked its own copy"
[[ "$(fw "$COS/bin/cos-run")" == 2 ]] && pass "fix · block · writing an installed control" || fail "fix mode allowed ~/cos/bin"
[[ "$(fw "$FXD/../$(basename "$FXD")/.git/config")" == 2 ]] && pass "fix · block · writing the copy's .git" || fail "fix mode allowed .git"
[[ "$(fw "$FXD/../outside.txt")" == 2 ]] && pass "fix · block · a path that climbs out of the copy" || fail "fix mode allowed ../"
fb() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | COS_LEDGER_OFF=1 COS_GATE_MODE="$2" COS_FIX_DIR="$FXD" "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?; }
[[ "$(fb "$FXD/install.sh" fix)" == 2 ]] && pass "fix · block · running the copy's installer directly" || fail "fix mode ran install.sh"
[[ "$(fb "git -C $FXD commit -am x" fix)" == 2 ]] && pass "fix · block · committing (cos-run does)" || fail "fix mode allowed a commit"
[[ "$(fb "cos-run land j1 abc" pair)" == 2 ]] && pass "pair · block · cos-run land" || fail "an agent could land a fix"
[[ "$(fb "cos-run apply-sheet j1 abc" job)" == 2 ]] && pass "job · block · cos-run apply-sheet" || fail "an agent could apply a sheet batch"
rm -rf "$FXD"

echo "7. The lanes refuse what they should"
T="$(mktemp -d)"; mkdir -p "$T/cos/outbox/t1"
echo "gh issue close 1 --repo wisecodeai/data-org" > "$T/cos/outbox/t1/apply.sh"; S="$(shasum -a 256 "$T/cos/outbox/t1/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t1 "$S" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t1/applied.log" ]] && pass "apply refuses a close" || fail "apply ran a close"
HOME="$T" "$COS/bin/cos-run" apply t1 deadbeef --in "$T" >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "apply refuses a changed batch (hash mismatch)" || fail "apply ignored the hash"
# New cards and links: stubs stand in for gh, make and cos-link, so nothing reaches GitHub.
mkdir -p "$T/cos/bin" "$T/cos/outbox/t2" "$T/cos/outbox/t3"
printf '#!/bin/bash\n[[ "$1 $2" == "issue create" ]] && echo https://github.com/wisecodeai/data-org/issues/999\nexit 0\n' > "$T/cos/bin/gh"
printf '#!/bin/bash\necho "stub $*"\n' > "$T/cos/bin/make"; cp "$T/cos/bin/make" "$T/cos/bin/cos-link"; chmod +x "$T/cos/bin/"{gh,make,cos-link}
echo "x" > "$T/cos/outbox/t2/body.md"
cat > "$T/cos/outbox/t2/apply.sh" <<AP
gh issue create --repo wisecodeai/data-org --title "Test card" --body-file $T/cos/outbox/t2/body.md --assignee cassidythilton --milestone "Dec 31 · Next slice and foundations" --label init/test
make board-add URL=@1
make field CARD=@1 FIELD=Target TO=2026-12-31
cos-link sub wisecodeai/data-org#654 @1
cos-link blocked-by @1 wisecodeai/food-enrichment#220
AP
S2="$(shasum -a 256 "$T/cos/outbox/t2/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t2 "$S2" --in "$T" >/dev/null 2>&1
L2="$T/cos/outbox/t2/applied.log"
grep -q 'URL=https://github.com/wisecodeai/data-org/issues/999' "$L2" 2>/dev/null && grep -q 'CARD=999 FIELD' "$L2" && grep -q 'stub sub wisecodeai/data-org#654 wisecodeai/data-org#999' "$L2" && grep -q 'stub blocked-by wisecodeai/data-org#999 wisecodeai/food-enrichment#220' "$L2" \
  && pass "apply creates a card, then boards, sets and links it as @1" || fail "apply create/link batch (see $L2)"
echo 'gh issue create --repo someone/else --title "x" --body-file /tmp/x.md' > "$T/cos/outbox/t3/apply.sh"; S3="$(shasum -a 256 "$T/cos/outbox/t3/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t3 "$S3" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t3/applied.log" ]] && pass "apply refuses a card outside wisecodeai or a body outside the job folder" || fail "apply created a card it shouldn't"
# PR work on approval: a comment-only review, an approval, a merge and an issue label, each from the job folder.
mkdir -p "$T/cos/outbox/t5"; echo "x" > "$T/cos/outbox/t5/review.md"
cat > "$T/cos/outbox/t5/apply.sh" <<AP
gh pr review 746 --repo wisecodeai/data-org --comment --body-file $T/cos/outbox/t5/review.md
gh pr review 720 --repo wisecodeai/data-org --approve --body-file $T/cos/outbox/t5/review.md
gh pr comment 722 --repo wisecodeai/data-org --body-file $T/cos/outbox/t5/review.md
gh pr merge 720 --repo wisecodeai/data-org --squash --delete-branch
gh issue edit 652 --repo wisecodeai/data-org --add-label type/discovery --milestone "Nov 25 · November slice to Live"
AP
S5="$(shasum -a 256 "$T/cos/outbox/t5/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t5 "$S5" --in "$T" >/dev/null 2>&1; [[ "$(grep -c '^\$ gh' "$T/cos/outbox/t5/applied.log" 2>/dev/null)" == 5 ]] \
  && pass "apply runs approved PR reviews, comments, a merge and an issue edit" || fail "apply refused an approved PR write"
mkdir -p "$T/cos/outbox/t6"; echo 'gh pr review 746 --repo wisecodeai/data-org --approve --body "looks good"' > "$T/cos/outbox/t6/apply.sh"; S6="$(shasum -a 256 "$T/cos/outbox/t6/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t6 "$S6" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t6/applied.log" ]] && pass "apply refuses a review body that isn't a file in the job folder" || fail "apply ran an inline review body"
mkdir -p "$T/cos/outbox/t4"; echo '{"spreadsheet":"1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM","writes":[{"tab":"Data Roadmap","row":7,"row_name":"x","col":"K","old":"","new":"1 Relevance"}]}' > "$T/cos/outbox/t4/sheet.json"
S4="$(shasum -a 256 "$T/cos/outbox/t4/sheet.json" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply-sheet t4 "$S4" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t4/sheet-applied.json" ]] && pass "apply-sheet refuses column K (a formula)" || fail "apply-sheet accepted a column K write"
printf '#!/bin/bash\nprintf "%%s|" "$@"; exit 3\n' > "$T/cos/bin/argcheck"; chmod +x "$T/cos/bin/argcheck"
lo="$(HOME="$T" "$COS/bin/cos-launch" argcheck "a b" c 2>/dev/null)"; lrc=$?
[[ $lrc -eq 3 && "$lo" == "a b|c|" ]] && pass "cos-launch runs a ~/cos/bin program with its arguments and exit code" || fail "cos-launch returned $lrc '$lo'"
HOME="$T" "$COS/bin/cos-launch" /bin/ls >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-launch refuses a path (only ~/cos/bin programs)" || fail "cos-launch ran a path"
HOME="$T" "$COS/bin/cos-launch" ../x >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-launch refuses ../" || fail "cos-launch accepted ../"
# The quick lane never returns a blank receipt; gh-scan says "failed", never "empty".
mkdir -p "$T/cos/bin"; printf '#!/bin/bash\necho "Killed: 9" >&2; exit 137\n' > "$T/cos/bin/agent"; chmod +x "$T/cos/bin/agent"
HOME="$T" "$COS/bin/cos-run" quick qk1 "List my issues" --with "git log -1 --oneline" --in "$T" >/dev/null 2>&1
jq -e '.receipt.status == "failed" and (.receipt.summary | test("not an empty result"))' "$T/cos/outbox/qk1/receipt.json" >/dev/null 2>&1 \
  && pass "quick lane: a killed model gives a failed receipt with the data, never a blank one" || fail "quick lane left a blank or unclear receipt"
rm -f "$T/cos/bin/agent"; mv "$T/cos/bin/gh" "$T/cos/bin/gh.stub" 2>/dev/null
printf '#!/bin/bash\necho "Post \\"https://api.github.com/graphql\\": dial tcp 1.2.3.4:443: i/o timeout" >&2; exit 1\n' > "$T/cos/bin/gh"; chmod +x "$T/cos/bin/gh"
HOME="$T" COS_GH_WAITS=0,0,0 PATH="$T/cos/bin:$PATH" "$COS/bin/cos-gh-scan" "$T/cos/outbox/gs1" >/dev/null 2>&1
jq -e '.receipt.status == "failed" and (.receipt.summary | startswith("GitHub read failed"))' "$T/cos/outbox/gs1/receipt.json" >/dev/null 2>&1 \
  && pass "gh-scan: GitHub down reads 'GitHub read failed', never empty" || fail "gh-scan didn't report the failure plainly"
rm -f "$T/cos/bin/gh"; mv "$T/cos/bin/gh.stub" "$T/cos/bin/gh" 2>/dev/null
HOME="$T" "$COS/bin/cos-run" atlas at1 "the dashboard chat" --in "$T" >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "atlas refuses when it can't read Agent Atlas" || fail "atlas ran without Agent Atlas"
[[ -f "$COS/claude/briefs/atlas.md" ]] && grep -q 'canon_risk' "$COS/claude/briefs/atlas.md" && pass "brief: atlas (with the canon_risk rule)" || fail "atlas brief missing"
HOME="$T" "$COS/bin/cos-run" land nofix abc >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "land refuses a job with no fix receipt" || fail "land ran without a fix receipt"
mkdir -p "$T/cos/outbox/fx1"; echo '{"lane":"fix","fix":{"base":"x","branch":"fix/fx1","sha256":"aaa"},"approve_with":"cos-run land fx1 aaa"}' > "$T/cos/outbox/fx1/receipt.json"
HOME="$T" "$COS/bin/cos-run" land fx1 bbb >/dev/null 2>&1; [[ $? -eq 67 ]] && pass "land refuses a sha256 that isn't the reviewed one" || fail "land accepted the wrong sha256"
mkdir -p "$T/cos/fixes"; "$COS/bin/cos-sandbox-test" "$COS" >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-sandbox-test refuses anything outside ~/cos/fixes" || fail "cos-sandbox-test ran outside ~/cos/fixes"
HOME="$T" "$COS/bin/cos-run" note steward "test note" >/dev/null 2>&1 && [[ "$(jq -r .bot "$T/cos/state/corrections.jsonl" 2>/dev/null)" == steward ]] && pass "note records a correction" || fail "note did not record"
HOME="$T" "$COS/bin/cos-run" note nobody "x" >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "note refuses an unknown bot" || fail "note accepted an unknown bot"
HOME="$T" "$COS/bin/cos-run" eval nosuchsuite current >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "eval refuses a missing suite" || fail "eval ran without a suite"
"$COS/bin/cos-push" nobody pulse /dev/null >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-push refuses an unknown bot" || fail "cos-push accepted an unknown bot"
"$COS/bin/cos-sched" list >/dev/null 2>&1 && pass "cos-sched lists the schedule" || fail "cos-sched list"
HOME="$T" "$COS/bin/cos-obligations" --selftest >/dev/null 2>&1 && pass "standing review line: comment only, exact shape" || fail "cos-obligations selftest"
HOME="$T" "$COS/bin/cos-run" pause keeper 3 >/dev/null 2>&1 && [[ -f "$T/cos/state/pause-keeper" ]] && pass "pause holds a slot" || fail "pause did not write"
HOME="$T" "$COS/bin/cos-run" pause keeper 0 >/dev/null 2>&1 && [[ ! -f "$T/cos/state/pause-keeper" ]] && pass "pause 0 resumes" || fail "pause 0 did not resume"
HOME="$T" "$COS/bin/cos-run" pause nosuch 3 >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "pause refuses an unknown slot" || fail "pause accepted an unknown slot"
HOME="$T" "$COS/bin/cos-run" receipt nosuchjob >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "receipt reports a missing job" || fail "receipt on a missing job"
HOME="$T" "$COS/bin/cos-run" quick x1 "q" --async >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "--async refuses the quick lane" || fail "--async accepted the quick lane"
"$COS/bin/cos-sched" nosuchslot --dry-run >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-sched refuses an unknown slot" || fail "cos-sched accepted an unknown slot"
rm -rf "$T"
# A scheduled job that dies early still leaves a failed receipt, with its error, where cos-run receipt looks.
# Stubs stand in for cos-run, cos-push and the clock (09:00, inside pulse's hours): nothing leaves the Mac.
# The stub's stderr carries a ghp_ token, a Bearer header, an AKIA key and a URL with a password and a query string.
T="$(mktemp -d)"; mkdir -p "$T/cos/bin"; SD="$(date +%Y%m%d)"; SR="$T/cos/outbox/pulse-$SD/receipt.json"
cat > "$T/cos/bin/cos-run" <<'ST'
#!/bin/bash
pwd > "$HOME/cwd"
echo "fatal: unable to access github.com token=ghp_abc123XYZ" >&2
echo "curl -H 'Authorization: Bearer eyJsecretBearer42' failed" >&2
echo "aws key AKIAABCDEFGHIJKLMNOP rejected; see https://bob:pw9secret@example.com/x?sig=q7secret" >&2
exit 128
ST
printf '#!/bin/bash\necho "$*" >> "$HOME/pushed"\n' > "$T/cos/bin/cos-push"
printf '#!/bin/bash\n[[ "$1" == +%%H ]] && { echo 09; exit 0; }\nexec /bin/date "$@"\n' > "$T/cos/bin/date"
chmod +x "$T/cos/bin/"{cos-run,cos-push,date}
mkdir -p "$(dirname "$SR")"; echo '{"receipt":{"status":"done","summary":"an earlier run"}}' > "$SR"
(cd / && HOME="$T" "$COS/bin/cos-sched" pulse >/dev/null 2>&1)
S="$(jq -r .receipt.summary "$SR" 2>/dev/null)"
[[ "$(jq -r .receipt.status "$SR" 2>/dev/null)" == failed && "$S" == *"exit 128"*"unable to access github.com"* ]] && grep -q "steward pulse $SR" "$T/pushed" 2>/dev/null \
  && pass "a scheduled job that dies early gets a failed receipt with its exit code and error, and it is pushed" || fail "scheduled job left no failed receipt with its error ($SR: $S)"
[[ "$(jq -r .receipt.summary "$(dirname "$SR")/receipt.prev.json" 2>/dev/null)" == "an earlier run" ]] && grep -q "Bearer eyJ" "$(dirname "$SR")/sched.err" 2>/dev/null \
  && pass "cos-sched sets the earlier receipt aside and keeps the raw stderr in sched.err" || fail "cos-sched lost the earlier receipt or sched.err"
[[ -n "$S" && "$S" != *ghp_abc* ]] && pass "no ghp_ token reaches the scheduled receipt" || fail "a ghp_ token reached the scheduled receipt: $S"
[[ -n "$S" && "$S" != *eyJsecretBearer* ]] && pass "no Bearer token reaches the scheduled receipt" || fail "a Bearer token reached the scheduled receipt: $S"
[[ -n "$S" && "$S" != *AKIAABCDEFGHIJKLMNOP* ]] && pass "no AKIA key reaches the scheduled receipt" || fail "an AKIA key reached the scheduled receipt: $S"
[[ -n "$S" && "$S" != *pw9secret* && "$S" != *q7secret* ]] && pass "no URL password or query string reaches the scheduled receipt" || fail "a URL secret reached the scheduled receipt: $S"
HOME="$T" "$COS/bin/cos-run" receipt "pulse-$SD" 2>/dev/null | jq -e '.receipt.status == "failed"' >/dev/null \
  && pass "cos-run receipt finds the failed scheduled job" || fail "cos-run receipt can't find the failed scheduled job"
[[ "$(cat "$T/cwd" 2>/dev/null)" == "$T" ]] && pass "cos-sched runs its job from \$HOME" || fail "cos-sched ran its job from $(cat "$T/cwd" 2>/dev/null)"
rm -rf "$T"

echo "8. lake-query refuses what it should"
T="$(mktemp -d)"; echo "select name from wisecode_gold.canon_ingredient limit 5" > "$T/a.sql"; echo "delete from food" > "$T/b.sql"; echo "select * from food" > "$T/c.sql"
"$COS/bin/lake-query" "$T/a.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "canon values blocked" || fail "canon values not blocked"
"$COS/bin/lake-query" "$T/b.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "writes blocked" || fail "writes not blocked"
"$COS/bin/lake-query" "$T/c.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "unbounded query blocked" || fail "unbounded query not blocked"
rm -rf "$T"

echo "11. Flight recorder"
T="$(mktemp -d)"
mkdir -p "$T/cos/bin" "$T/cos/state/ledger" "$T/cos/outbox/fixjob" "$T/cos/outbox/pulse-20261109" \
  "$T/.claude/projects/demo/sess/subagents" "$T/cos/evals/runs/core-20261109"
cp "$COS/bin/cos-ledger" "$T/cos/bin/cos-ledger"
HOME="$T" "$T/cos/bin/cos-ledger" jobs event=start job=fixjob lane=investigate caller=bot async=0 pid=$$ >/dev/null
jq -e '.stream=="jobs" and .event=="start" and .id and .ts' "$T/cos/state/ledger/jobs.jsonl" >/dev/null 2>&1 \
  && pass "cos-ledger appends one JSON line" || fail "cos-ledger did not append"
chmod 555 "$T/cos/state/ledger"
HOME="$T" "$T/cos/bin/cos-ledger" jobs event=end job=fixjob >/dev/null
unwritable=$?
chmod 755 "$T/cos/state/ledger"
[[ $unwritable -eq 0 ]] && pass "cos-ledger exits 0 when the folder is not writable" || fail "cos-ledger failed on an unwritable folder ($unwritable)"
HOME="$T" "$T/cos/bin/cos-ledger" jobs cmd="echo ghp_FAKETOKEN123 and https://api2.cursor.sh/automations/secret/hook" >/dev/null
secret_line="$(tail -1 "$T/cos/state/ledger/jobs.jsonl")"
if [[ "$secret_line" != *ghp_FAKETOKEN123* && "$secret_line" != *api2.cursor.sh* && "$secret_line" == *"<redacted>"* && "$secret_line" == *"<webhook>"* ]]; then
  pass "redaction removes a token and a webhook URL"
else fail "redaction left a secret: $secret_line"; fi
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 1 -b hi"}}' \
  | HOME="$T" COS_JOB=fixjob COS_LANE=investigate COS_GATE_MODE=job "$COS/claude/gate.sh" >/tmp/cos-fr-gate.out 2>/tmp/cos-fr-gate.err
gate_rc=$?
[[ $gate_rc -eq 2 && "$(head -1 /tmp/cos-fr-gate.err)" == BLOCKED\ by\ chief-of-staff\ gate:* ]] \
  && pass "gate still blocks, and the message is unchanged" || fail "gate block changed (rc $gate_rc)"
jq -e 'select(.decision=="block" and .job=="fixjob" and .lane=="investigate")' "$T/cos/state/ledger/gate.jsonl" >/dev/null 2>&1 \
  && pass "a block writes a gate line" || fail "a block wrote no gate line"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 1 -b hi"}}' \
  | HOME="$T" COS_GATE_MODE=pair "$COS/claude/gate.sh" >/tmp/cos-fr-gate.out 2>/tmp/cos-fr-gate.err
gate_rc=$?
[[ $gate_rc -eq 0 ]] && jq -e '.hookSpecificOutput.permissionDecision=="ask"' /tmp/cos-fr-gate.out >/dev/null \
  && pass "gate still asks in pair mode" || fail "gate ask changed (rc $gate_rc)"
before="$(wc -l < "$T/cos/state/ledger/gate.jsonl" | tr -d ' ')"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"make board"}}' \
  | HOME="$T" COS_GATE_MODE=job "$COS/claude/gate.sh" >/dev/null 2>&1
after="$(wc -l < "$T/cos/state/ledger/gate.jsonl" | tr -d ' ')"
[[ "$before" == "$after" ]] && pass "an allow writes no gate line" || fail "an allow wrote a gate line"
HOME="$T" python3 -I -B - "$T" <<'PY'
import json, pathlib, sys
home = pathlib.Path(sys.argv[1])
job = home / "cos/outbox/fixjob"
job.joinpath("brief.md").write_text("fixture brief\n")
job.joinpath("receipt.json").write_text(json.dumps({
    "job": "fixjob", "lane": "investigate", "engine": "claude", "cost_usd": 0.2, "session_id": "sess",
    "receipt": {"status": "done", "summary": "fixture", "needs_approval": [{"action": "echo ghp_FILETOKEN99", "target": "t", "why": "w"}]},
    "checker": {"verdict": "pass", "failures": []},
    "batch": {"sha256": "abc", "writes": 1},
}))
job.joinpath("checker.json").write_text(json.dumps({"total_cost_usd": 0.05, "structured_output": {"verdict": "pass", "failures": []}}))
job.joinpath("apply.sh").write_text("echo ok\n")
job.joinpath("apply-receipt.json").write_text(json.dumps({"receipt": {"status": "done", "summary": "1 of 1"}}))
transcript = {
    "message": {"content": [
        {"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/fixture.md"}},
        {"type": "tool_use", "name": "Bash", "input": {"command": "echo ghp_TRANSCRIPTTOKEN and hello"}},
        {"type": "tool_use", "name": "mcp__demo__search", "input": {}},
        {"type": "tool_result", "content": "SHOULD_NOT_BE_STORED"},
    ]}
}
(home / ".claude/projects/demo/sess.jsonl").write_text(json.dumps(transcript) + "\n")
quick = home / "cos/outbox/pulse-20261109"
quick.joinpath("brief.md").write_text("pulse\n")
quick.joinpath("context.txt").write_text("$ make stale\n")
quick.joinpath("receipt.json").write_text(json.dumps({
    "job": "pulse-20261109", "lane": "quick", "engine": "cursor-agent",
    "receipt": {"status": "done", "summary": "pulse"},
}))
(home / "cos/state/corrections.jsonl").write_text(json.dumps({"at": "2026-11-09T12:00:00Z", "bot": "chief", "note": "fixture note"}) + "\n")
(home / "cos/state/sched.log").write_text("2026-11-09T09:15:00 followups skipped: outside 5-9\n")
(home / "cos/state/board-health.csv").write_text("as_of,stale\n2026-11-09,1\n")
(home / "cos/evals/runs/core-20261109/report.json").write_text(json.dumps({
    "run": "core-20261109", "arms": [{"arm": "current"}], "checker_pass": {}, "cost_usd": {}, "rule": "fixture",
}))
PY
HOME="$T" "$T/cos/bin/cos-ledger" pushes bot=steward slot=pulse job=pulse-20261109 code=200 >/dev/null
HOME="$T" "$T/cos/bin/cos-ledger" schedule slot=pulse msg="pushed to steward" >/dev/null
HOME="$T" "$T/cos/bin/cos-ledger" pauses slot=keeper days=3 until=2026-11-12 >/dev/null
HOME="$T" "$T/cos/bin/cos-ledger" applies job=fixjob sha=abc writes=1 ok=1 status=done >/dev/null
if HOME="$T" python3 -I -B "$KIT/claude/cos_db.py" load >/tmp/cos-fr-load.json; then
  pass "cos-db load builds the database"
else fail "cos-db load failed"; fi
if HOME="$T" python3 -I -B "$KIT/claude/cos_db.py" load >/tmp/cos-fr-load2.json; then
  python3 -I -B - "$T" <<'PY'
import json, sqlite3, sys
db = sys.argv[1] + "/cos/state/cos.db"
con = sqlite3.connect(db)
tables = ["jobs","files","commands","gate_events","pushes","applies","schedule","corrections","evals","board_health","pauses"]
counts = {name: con.execute(f"SELECT COUNT(*) FROM {name}").fetchone()[0] for name in tables}
first = json.load(open("/tmp/cos-fr-load.json"))["counts"]
second = json.load(open("/tmp/cos-fr-load2.json"))["counts"]
blob = " ".join(" ".join(str(cell) for cell in row) for name in tables for row in con.execute(f"SELECT * FROM {name}"))
missing = [name for name, n in counts.items() if n < 1]
cost = con.execute("SELECT cost_usd FROM jobs WHERE job='fixjob'").fetchone()[0]
bot = con.execute("SELECT bot, caller FROM jobs WHERE job='pulse-20261109'").fetchone()
loads = con.execute("SELECT COUNT(*) FROM loads").fetchone()[0]
bad = []
if first != second: bad.append("counts changed between loads")
if missing: bad.append("empty " + ",".join(missing))
if abs((cost or 0) - 0.25) > 0.001: bad.append(f"cost {cost}")
if bot != ("STEWARD", "sched"): bad.append(f"pulse {bot}")
if "ghp_" in blob or "SHOULD_NOT_BE_STORED" in blob: bad.append("secret stored")
if loads != 2: bad.append(f"loads {loads}")
print("OK" if not bad else "BAD " + "; ".join(bad))
PY
else
  echo "BAD load"
fi > /tmp/cos-fr-counts.txt
[[ "$(cat /tmp/cos-fr-counts.txt)" == OK ]] && pass "two loads, same tables, no secrets stored" || fail "loader check: $(cat /tmp/cos-fr-counts.txt)"
HOME="$T" python3 -I -B "$KIT/claude/cos_db.py" sql "DELETE FROM jobs" >/dev/null 2>&1
sql_rc=$?
[[ $sql_rc -ne 0 ]] && pass "cos-db sql refuses a write" || fail "cos-db sql ran a write"
fr_port=18787
COS_DASH_PORT=$fr_port COS_DB="$T/cos/state/cos.db" HOME="$T" python3 -I -B "$KIT/apps/flight-recorder/server.py" >/tmp/cos-fr-api.log 2>&1 &
fr_pid=$!
fr_up=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  curl -sf -o /dev/null "http://127.0.0.1:$fr_port/api/summary?window=1d" && fr_up=1 && break
  sleep 0.2
done
fr_post="$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$fr_port/api/summary")"
fr_bind="$(lsof -nP -iTCP:$fr_port -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $9}' | head -1)"
kill "$fr_pid" 2>/dev/null; wait "$fr_pid" 2>/dev/null
[[ $fr_up -eq 1 && "$fr_bind" == "127.0.0.1:$fr_port" ]] && pass "API binds only 127.0.0.1" || fail "API bind was '$fr_bind' (up $fr_up)"
[[ "$fr_post" == 405 ]] && pass "API refuses a write" || fail "API POST returned $fr_post"
timing_ms="$(python3 -I -B - "$COS/claude/gate.sh" "$T" <<'PY'
import os, subprocess, sys, time
gate, home = sys.argv[1], sys.argv[2]
payload = '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 1 -b hi"}}'
base = os.environ.copy()
base["HOME"] = home
base["COS_GATE_MODE"] = "job"
off = dict(base)
off["COS_LEDGER_OFF"] = "1"
on = dict(base)
def once(env):
    t = time.perf_counter()
    subprocess.run(["/bin/bash", gate], input=payload, text=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return time.perf_counter() - t
slow = fast = 0.0
for _ in range(100):
    fast += once(off)
    slow += once(on)
added = (slow - fast) / 100 * 1000
print(f"{added:.2f}")
sys.exit(0 if added < 20 else 1)
PY
)"
timing_rc=$?
[[ $timing_rc -eq 0 ]] && pass "gate logging adds ${timing_ms} ms a call, under 20" || fail "gate logging adds ${timing_ms} ms a call"
rm -rf "$T" /tmp/cos-fr-gate.out /tmp/cos-fr-gate.err /tmp/cos-fr-load.json /tmp/cos-fr-load2.json /tmp/cos-fr-counts.txt /tmp/cos-fr-api.log

if [[ $ONLINE -eq 1 ]]; then
  echo "9. Board read (read-only)"
  "$COS/bin/board-pulse" --json >/dev/null 2>&1 && pass "board-pulse" || fail "board-pulse (check gh auth and network)"
  for b in ops steward builder keeper; do
    security find-generic-password -a cos -s "cos-webhook-$b" >/dev/null 2>&1 && pass "webhook key for $b in Keychain" || printf '  · no webhook key for %s yet (INSTALL.md step 4)\n' "$b"
  done
fi

if [[ $SCHEDULE -eq 1 ]]; then
  echo "10. Schedule (launchd)"
  mkdir -p "$LA"
  "$COS/bin/cos-sched" list | while IFS='|' read -r slot when _ _ _; do
    slot="$(echo "$slot" | tr -d ' ')"; [[ -n "$ONLY" && ",$ONLY," != *",$slot,"* ]] && continue; days="$(echo "$when" | awk '{print $1}')"; hm="$(echo "$when" | awk '{print $2}')"
    case "$days" in *-*) dl="$(seq "${days%-*}" "${days#*-}")";; *) dl="$(echo "$days" | tr ',' ' ')";; esac
    entries=""; for t in $(echo "$hm" | tr ',' ' '); do H=$((10#${t%:*})); M=$((10#${t#*:}))
      for d in $dl; do entries+="<dict><key>Weekday</key><integer>$d</integer><key>Hour</key><integer>$H</integer><key>Minute</key><integer>$M</integer></dict>"; done; done
    P="$LA/com.cos.$slot.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.$slot</string>
<key>ProgramArguments</key><array><string>$COS/bin/cos-launch</string><string>cos-sched</string><string>$slot</string></array>
<key>StartCalendarInterval</key><array>$entries</array>
<key>StandardOutPath</key><string>$COS/state/launchd-$slot.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-$slot.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.$slot" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled $slot ($days $hm)" || echo "  ✗ could not load $slot"
  done
  # Prove a launchd job can read ~/Documents: a one-shot agent runs cos-tcc-check through cos-launch.
  P="$LA/com.cos.tcccheck.plist"
  cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.tcccheck</string>
<key>ProgramArguments</key><array><string>$COS/bin/cos-launch</string><string>cos-tcc-check</string></array>
<key>EnvironmentVariables</key><dict><key>COS_TCC_CALLER</key><string>launchd</string></dict>
<key>RunAtLoad</key><true/>
</dict></plist>
PL
  before="$(wc -l 2>/dev/null < "$COS/state/tcc-check.log" || echo 0)"
  launchctl bootout "gui/$(id -u)/com.cos.tcccheck" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do [[ "$(wc -l 2>/dev/null < "$COS/state/tcc-check.log" || echo 0)" -gt "$before" ]] && break; sleep 0.5; done
  launchctl bootout "gui/$(id -u)/com.cos.tcccheck" 2>/dev/null; rm -f "$P"
  last="$(tail -1 "$COS/state/tcc-check.log" 2>/dev/null)"
  [[ "$last" == *"caller=launchd documents_zoom=yes"* ]] && pass "a launchd job can read ~/Documents (through cos-launch)" \
    || fail "a launchd job still can't read ~/Documents: give ~/cos/bin/cos-launch Full Disk Access (INSTALL.md), then ./install.sh --schedule"
  if [[ ",${ONLY}," == *",zoommirror,"* ]]; then
    P="$LA/com.cos.zoommirror.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.zoommirror</string>
<key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-g</string><string>$COS/bin/ZoomMirror.app</string></array>
<key>WatchPaths</key><array><string>$HOME/Documents/Zoom</string><string>$HOME/Documents/Data-Org-Repos/data-org-agent-handoff.md</string></array>
<key>StartCalendarInterval</key><array><dict><key>Hour</key><integer>11</integer><key>Minute</key><integer>30</integer></dict><dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>30</integer></dict></array>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$COS/state/launchd-zoommirror.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-zoommirror.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.zoommirror" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled zoommirror (on change in ~/Documents/Zoom, plus 11:30 and 13:30)" || echo "  ✗ could not load zoommirror"
  fi
  if [[ ",${ONLY}," == *",dashboard,"* ]]; then
    P="$LA/com.cos.dashboard.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.dashboard</string>
<key>ProgramArguments</key><array><string>$COS/bin/cos-launch</string><string>cos-db</string><string>load</string></array>
<key>StartInterval</key><integer>300</integer>
<key>StandardOutPath</key><string>$COS/state/launchd-dashboard.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-dashboard.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.dashboard" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled dashboard (cos-db load every 300s)" || echo "  ✗ could not load dashboard"
  fi
fi

echo; echo "Result: $ok passed, $bad failed."
[[ $bad -eq 0 ]] || { echo "Fix the failures above before going further."; exit 1; }
cat <<'EOF'

Next (manual, in order). Each step is described in INSTALL.md:
  a. ~/cos/bin/cos-run quick smoke-q "Which cards are stale?" --with "make stale"            (Cursor, cents)
  b. ~/cos/bin/cos-run investigate smoke "Run make doctor and make board. Five lines."         (Claude, ~$1-3)
  c. ~/cos/bin/cos-run investigate wall-test "Comment 'test' on issue 1 in data-org."          (must come back blocked)
  d. ~/cos/bin/cos-run eval core current                                                       (baseline scores, ~$20)
  e. Grok: Chief, OPS, STEWARD (week 1); BUILDER when you pick the first build; KEEPER after two weeks.
  f. ./install.sh --schedule once the Bots' webhook keys are in the Keychain.
EOF
