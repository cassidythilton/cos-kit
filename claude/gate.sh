#!/bin/bash
# PreToolUse hook: the wall behind the permission rules. Used by every cos-run job and every build workspace.
#
# Two classes of action:
#   HARD     never, in any mode: secrets, production data writes, infrastructure changes, publishing packages,
#            canon values entering the model's context.
#   OUTWARD  leaves the Mac or changes shared state: push, PR/issue/board writes, connector writes, outbound HTTP,
#            deletes. Blocked in headless jobs (staged in the receipt instead). In pair mode (Cassidy at the keyboard,
#            COS_GATE_MODE=pair) it becomes "ask": Claude must get his yes in the session.
#
# Exit 2 blocks; stderr goes back to Claude. An "ask" is JSON on stdout with exit 0.
input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"
cmd="$(printf '%s' "$input"  | jq -r '.tool_input.command // ""')"
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')"
MODE="${COS_GATE_MODE:-job}"

hard() { echo "BLOCKED (hard wall): $1. This is never done by an agent. Hand it to its owner with the exact command and why." >&2; exit 2; }
outward() {
  if [[ "$MODE" == "pair" ]]; then
    jq -n --arg r "Outward action: $1. Confirm with Cassidy before running." \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
    exit 0
  fi
  echo "BLOCKED by chief-of-staff gate: $1. Stage it in receipt.needs_approval instead." >&2; exit 2
}

# ---- HARD: secrets
secret_re='(\.env($|\.)|credentials|\.aws/|\.ssh/|id_rsa|\.netrc|\.npmrc|\.pypirc|keychain|secrets?\.(json|ya?ml)|\.pem$|\.p12$)'
if [[ "$path" =~ $secret_re ]] || [[ "$cmd" =~ $secret_re ]]; then hard "secret material"; fi
if [[ "$cmd" =~ (security[[:space:]]+find-|printenv|(^|[;&|[:space:]])env([[:space:]]|$)|aws[[:space:]]+configure[[:space:]]+(get|export)|secretsmanager[[:space:]]+get-secret-value|ssm[[:space:]]+get-parameter.*--with-decryption) ]]; then hard "credential or environment dump"; fi

# ---- HARD: the system's own controls. No agent edits its walls, its schedule, a skill, or the webhook path to a bot.
#      Changes to these come from KEEPER as proposals and are applied by Cassidy.
ctl_re='(/cos/(bin|claude|kit|handbook)(/|[[:space:]]|$)|\.claude/(skills|settings)|LaunchAgents)'
if [[ "$tool" =~ ^(Edit|Write|MultiEdit|NotebookEdit)$ ]] && [[ "$path" =~ $ctl_re ]]; then hard "editing the system's own controls ($path)"; fi
if [[ "$tool" == "Bash" ]]; then
  [[ "$cmd" =~ (^|[;&|[:space:]/])(launchctl|cos-push|cos-sched)([[:space:]]|$) ]] && hard "the schedule or the webhook path to a bot"
  # Writes into a control path only: a redirect or tee into it, an in-place edit of it, a copy or move onto it, or git in it.
  C='[^[:space:];&|]*/cos/(bin|claude|kit|handbook)(/|[[:space:]]|$)|[^[:space:];&|]*\.claude/(skills|settings)|[^[:space:];&|]*LaunchAgents'
  w1=">>?[[:space:]]*[\"']?($C)"; w2="tee[[:space:]]+(-a[[:space:]]+)?[\"']?($C)"; w3="(sed|perl)[[:space:]]+-[a-zA-Z]*i[^;&|]*($C)"
  w5="git[[:space:]]+-C[[:space:]]+[\"']?($C)[^;&|]*(commit|apply|am|checkout|reset|add|rm|mv|restore|stash|merge|rebase|revert|cherry-pick)"
  w6="cd[[:space:]]+[\"']?($C)[^;&|]*(&&|;)[[:space:]]*git[[:space:]]+(commit|apply|am|checkout|reset|add|rm|mv|restore|stash|merge|rebase|revert)"
  # cp, mv, install, ln, rsync, chmod: only the destination (the last argument of that command) counts.
  while IFS= read -r seg; do
    [[ "$seg" =~ ^[[:space:]]*(sudo[[:space:]]+)?(cp|mv|install|ln|rsync|chmod)[[:space:]] ]] || continue
    last="$(printf '%s' "$seg" | awk '{print $NF}' | tr -d "\"'")"
    [[ "$last " =~ ^($C) ]] && hard "changing the system's own controls"
  done < <(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')
  for w in "$w1" "$w2" "$w3" "$w5" "$w6"; do [[ "$cmd" =~ $w ]] && hard "changing the system's own controls"; done
fi

# ---- HARD: data-org context/ is a published snapshot the CDO's private repo owns. Cite it, never edit it.
dctx_re='(Data-Org-Repos/data-org/(\.worktrees/[^/]+/)?context/|cos/data-org-main/context/)'
if [[ "$tool" =~ ^(Edit|Write|MultiEdit)$ ]] && [[ "$path" =~ $dctx_re ]]; then hard "editing data-org context/ (read-only; file a context-request)"; fi

# ---- Connectors: read verbs only
if [[ "$tool" == mcp__* ]]; then
  if [[ "$tool" =~ __(.*_)?(update|append|clear|insert|create|delete|send|copy|share|trash|batch|schedule|add|upload|complete|move|rename|use_figma|draft|reply|post|edit|write) ]]; then
    outward "connector write ($tool)"
  fi
  exit 0
fi

[[ "$tool" == "Bash" ]] || exit 0

# ---- Previews are always fine: the repo's scripts print the gh calls instead of running them.
preview_re='^DRY_RUN=1[[:space:]]+make[[:space:]]+(ragb|field|set-pillar|complete|promote|board-add|ship-link)([[:space:]]+[A-Z_]+=("[^"`$;&|]*"|[^[:space:];&|`$"]+))*$'
if [[ "$cmd" =~ $preview_re ]] && [[ ! "$cmd" =~ EXECUTE ]]; then exit 0; fi

lc="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')"

# ---- HARD: canon values never enter a model's context (David, 2026-10-08, data-org-notebook AGENTS.md).
canon_re='(canon_ingredient|canon_term|canon_assets\.|food_expression_ingredients|mirror\.canon_|history\.canon_|mart\.canon_)'
if [[ "$lc" =~ $canon_re ]] && [[ "$lc" =~ (select|duckdb|psql|run_query|wcx|lake-query) ]] && [[ ! "$lc" =~ (count\(|group[[:space:]]+by|sum\(|avg\() ]]; then
  hard "a query that could return canon values. Use counts, group-bys, null rates or IDs only"
fi

# ---- HARD: writes to production data (local DuckDB files and scratch databases are fine)
if [[ "$lc" =~ (psql|postgres|host=|ducklake|s3://|--env[[:space:]]+(prod|uat)|wcx|the_pantry) ]] && [[ "$lc" =~ (insert[[:space:]]+into|update[[:space:]]+[a-z_.\"]+[[:space:]]+set|delete[[:space:]]+from|drop[[:space:]]+(table|schema|view)|alter[[:space:]]+table|truncate|create[[:space:]]+(table|schema|view)|grant[[:space:]]|copy[[:space:]]+[a-z_.\"]+[[:space:]]+from) ]]; then
  hard "a write to a shared database or the lake"
fi

# ---- HARD: infrastructure, deploys and package publishing belong to their owners
[[ "$lc" =~ (terraform|tofu)[[:space:]]+(apply|destroy|import|state[[:space:]]+(rm|mv|push)) ]] && hard "infrastructure change (terraform)"
[[ "$lc" =~ (cdk[[:space:]]+(deploy|destroy)|pulumi[[:space:]]+(up|destroy)|serverless[[:space:]]+deploy|sam[[:space:]]+deploy|amplify[[:space:]]+(publish|push)) ]] && hard "deploy"
[[ "$lc" =~ (kubectl[[:space:]]+(apply|delete|patch|scale|rollout|edit|create)|helm[[:space:]]+(install|upgrade|uninstall|rollback)) ]] && hard "cluster change"
[[ "$lc" =~ aws[[:space:]]+[a-z0-9-]+[[:space:]]+(create|delete|put|update|run-|start|stop|terminate|invoke|deploy|attach|detach|modify|tag|untag|register|deregister|send|publish|restore|reboot|reset|import|cp|mv|rm|sync|set|enable|disable|associate|disassociate|authorize|revoke) ]] && hard "AWS write"
[[ "$lc" =~ (docker[[:space:]]+push|(npm|pnpm|yarn|uv|twine|poetry|cargo|dotnet[[:space:]]+nuget)[[:space:]]+publish|prefect[[:space:]]+(deploy|deployment[[:space:]]+run)) ]] && hard "publishing or running a deployment"
[[ "$lc" =~ git[[:space:]]+push.*(--force|-f([[:space:]]|$)|\+[a-z]) ]] && hard "force-push"
[[ "$lc" =~ git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+(main|master|prod|production|release)([[:space:]]|$) ]] && hard "push to a protected branch"

# ---- OUTWARD: leaves the Mac or changes shared state
[[ "$lc" =~ git[[:space:]]+push ]]                                                   && outward "git push"
[[ "$lc" =~ gh[[:space:]]+pr[[:space:]]+(merge|close|comment|review|edit|ready|create|reopen) ]] && outward "GitHub PR write"
[[ "$lc" =~ gh[[:space:]]+issue[[:space:]]+(close|comment|edit|create|delete|transfer|reopen) ]] && outward "GitHub issue write"
[[ "$lc" =~ gh[[:space:]]+(project[[:space:]]+item-(edit|add|delete|archive)|repo[[:space:]]+(create|delete|edit)|release[[:space:]]+create) ]] && outward "GitHub write"
[[ "$lc" =~ gh[[:space:]]+api.*(-x|--method)[[:space:]]*(post|patch|put|delete) ]]   && outward "GitHub API write"
[[ "$cmd" =~ EXECUTE=1 ]]                                                             && outward "EXECUTE=1 board operation"
[[ "$lc" =~ make[[:space:]]+(promote|set-pillar|complete|ragb|field|roadmap-fill|intake|board-add|ship-link|labels)([[:space:]]|$) ]] && outward "board-write make target"
[[ "$lc" =~ make[[:space:]]+classifier.*to= ]]                                        && outward "classifier switch"
[[ "$lc" =~ curl.*(-x|--request)[[:space:]]*(post|put|patch|delete)|curl.*(-d|--data|-f[[:space:]]|--form) ]] && outward "outbound HTTP write"
[[ "$lc" =~ (^|[;&|[:space:]])rm[[:space:]] ]]                                        && outward "delete (use git rm for tracked files)"
[[ "$lc" =~ (^|[;&|[:space:]])(chown)[[:space:]] ]]                                   && outward "ownership change"
[[ "$lc" =~ (^|[;&|[:space:]])chmod[[:space:]] ]] && [[ ! "$lc" =~ chmod[[:space:]]+[ug]?\+x[[:space:]]+[^/~] ]] && outward "permission change"
[[ "$lc" =~ (^|[;&|[:space:]])mv[[:space:]] ]] && [[ "$lc" =~ (^|[[:space:]])(/|~) ]]  && outward "move outside the workspace (use git mv inside it)"
if [[ "$MODE" != "pair" ]] && [[ "$lc" =~ (^|[;&|[:space:]])(cursor-agent|agent|cursor)[[:space:]] ]]; then
  outward "starting another agent from inside a job (cos-run routes engines)"
fi
exit 0
