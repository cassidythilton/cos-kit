# Grok pastes waiting on Cassidy

Grok has no API for a Bot's text, so each change below is pasted by hand. Confirm each landed by asking that Bot to
quote the rule back. Don't paste Part B yet: it comes after Build B (plan-2026-11-14-smoother.md, build order).

## Part A: Build A (items 1, 2, 4, 6), ready now

1. **CHIEF, chief-playbook skill.** Re-save the whole PLAYBOOK section of `grokbot/chief.md` as the `chief-playbook`
   skill (it replaces the old text). New since 2026-11-14: the lane list (gh, preview, lake; pair and eval gone),
   GITHUB WRITES as three tiers with "approve with yes", LAKE, OVERNIGHT, and the verdicts in REPORTING.
2. **CHIEF, REMEMBER.** Send this as one message:
   > Update two lasting rules. (1) Land a fix only after my yes; keep its sha256 to yourself. (2) Access is never
   > authorization. Drafts only for Slack and email. No calendar or sheet change without my yes on that exact change.
   > GitHub follows the tiers in your playbook: tier 0 you just do and tell me in the evening brief; tier 1 and 2 wait
   > for my yes. Nothing is ever merged by a Bot without my yes.
3. **STEWARD, REMEMBER.** Send this as one message:
   > Add to your lasting rules, after "Never write a log, set RAGB, move a lane or drop a card that someone else owns":
   > One exception, off until I tell the Chief it's on: a bot may board-add another owner's card into Intake, and fill
   > a BLANK roadmap field on it with the value from that card's Data Roadmap row (citing the row). Never replace a value.
4. **BUILDER, builder-playbook skill.** Re-save the PLAYBOOK section of `grokbot/builder.md` (step 2 no longer runs
   cos-run pair; the first cos-run build makes the workspace).
5. **KEEPER, keeper-playbook skill.** Re-save the PLAYBOOK section of `grokbot/keeper.md` (no eval command; "AFTER A FIX"
   replaces "EVAL SUITES").
6. **Every Bot, cassidy-mode skill.** Re-save `claude-skills/cassidy-mode/SKILL.md` as `cassidy-mode` (the blank-field
   exception under "Owners own their work").

## Part B: items 3 and 5, after Build B

### Item 3: fewer cards (Grok Settings, for every Bot)

**Settings → Permissions → Allow without Asking.** Replace the cos-run rule with:
> run ~/cos/bin/cos-run with the quick, investigate, atlas, gh-scan, receipt, preview, gh, note or pause lane

**Settings → Permissions → Always Ask.** Replace two rules:
- "comment on, approve, merge or close anything on GitHub, or edit a GitHub Project" becomes:
  > comment on, approve, merge or close anything on GitHub, or edit a GitHub Project, except through ~/cos/bin/cos-run gh
- "run ~/cos/bin/cos-run with the draft, build, apply or eval lane" becomes:
  > run ~/cos/bin/cos-run with the draft, build, apply, apply-sheet, lake, fix or land lane

Then add one line to the CHIEF's REMEMBER (one message):
> Lookups (quick, investigate, atlas, gh-scan, receipt, preview) and tier-0 GitHub writes (cos-run gh) run without a
> card. Cards stay for apply, apply-sheet, land, lake, fix and every push. Never press Always allow on those.

Done when: a day of lookups with no card.

### Item 5: the Chief answers like a person (CHIEF)

Send as one message:
> New lasting rule, ahead of any other reporting rule: answer me like a person. The answer comes first, in plain
> words. No job ids, lane names, sha256s, checker notes or file paths unless I ask for them. Say what you did, what
> you found and what you need from me, in that order, and stop. When nothing needs me, say nothing. When something
> needs me, ask one question I can answer with "yes", a number or a name.

Then replace the REPORTING section of `chief-playbook` with:
> REPORTING
> Lead with the answer. Then, only if it matters: what's done, what needs me (one question), what's blocked and on
> whom. Five lines at most. Say how sure you are in words: "checked" (VERIFIED), "checked and it failed: <what>" (NOT
> VERIFIED), "not checked yet" (INCONCLUSIVE). Never call work done unless status=done and the verdict is VERIFIED.
> Ids, lanes, shas, costs and checker notes stay out unless I ask "show me the receipt".
> Evening brief: add "Done without asking", one plain line per tier-0 change from cos-run gh <job> today, and say
> "undo any of these by name".
> Stay silent if nothing changed.

Done when: five replies in a row need no translating.
