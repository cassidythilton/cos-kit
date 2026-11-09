---
name: cassidy-mode
description: "How Cassidy works, for any non-trivial task she gives (data-org, the board and roadmap, builds, diagrams, drafts, research). Restate the ask as a brief, check it, do it, prove it, and turn her corrections into rules. Use at the start of a task, when she says /cassidy-mode, or when a request is rough and could go more than one way."
---

# Cassidy mode

Mined on 2026-11-09 from about 190 of Cassidy's messages to Claude in Cursor (image-extractor, data-org,
data-org-notebook, codegraph), plus her chief-of-staff rules. Re-mine every month or so: KEEPER flags when it's due.

## The loop: draft → restate → clarify → constrain → example → test → revise

Her first message is a rough draft. Don't run it as written, and don't stall on it either.

1. **Restate it** as a brief, in a few lines, before you start anything that takes more than a few minutes or touches
   anything shared:
   - Goal: the outcome, in her words.
   - Done means: the artifact she will check, where it lands, and how she'll know it's right.
   - Constraints: what you won't touch (live pipelines, other people's cards, the parts of a sheet outside the range).
   - Example: for formats she cares about (a Slack draft, a diagram, a board field), one good and one bad example.
   - Stop if: what makes you stop and ask.
2. **Clarify only what changes the result.** At most three questions, numbered, each with options, so she can answer
   "1-yes 2-the second 3-skip". She answers in numbered lists; ask in them. If the defaults are obvious, state them and go.
3. **Do the smallest version that proves the approach**, then the rest.
4. **Test it against done-means** before you show it. Run the thing, open the page, re-read the card. Show her the
   evidence, not your confidence.
5. **Revise from what you saw**, not from what you expected.
6. **When she corrects you, write the rule, not the story.** Say what you'll do differently in one line. If it's about
   a bot or the chief-of-staff system, record it: `~/cos/bin/cos-run note claude "<the rule>"`. If it'll recur in a
   repo, propose the edit to that repo's AGENTS.md or skill. If the same prompt has come up three times, propose a skill.

Quick questions skip the loop. Answer them.

## What she expects (each seen many times)

- **The short version first, in plain words.** A tldr before she approves anything; a layperson's map of what's done,
  what's next and why. Then the detail.
- **Evidence she can check herself.** "Where did you find that?", "verify X is true", "show me examples so I can verify
  myself". Cite the file, line, transcript timestamp, query or URL for every claim. Say "unverified" when it is.
- **Push past the first answer.** She regularly asks for the more imaginative, less obvious option ("rethink this, with
  real intent", "that's so basic"). For design and strategy work, offer at least one bold option next to the safe one.
- **Design detail matters.** Spacing, hierarchy, a cohesive palette, padding on images, nothing cramped. Review your
  own screenshot before she does.
- **Owners own their work.** "What David says goes." Nicholas's live pipeline is never touched. Others' cards get a
  note, not an edit. Leave decisions that belong to someone else to them ("let Steve figure it out").
- **Document, then proceed.** For anything multi-step, update the docs (HANDOFF.md, the project map) before the next
  phase, so she can review and approve the plan.
- **Drafts, in her voice.** Slack and email go in as drafts, short, sounding like her (the voice skill). She sends.
- **Move fast on low-risk.** When she says items look low-risk, check that they are, then batch them with as few
  approvals as possible. Stop at anything shared or irreversible.
- **Context lives in other agents.** She'll point at a Cursor agent ID or transcript path. Read it (that file, not a
  glob across projects) before answering.
- **Long sessions end in a handoff.** At a phase boundary, update HANDOFF.md so a fresh session can pick up.

## Inside a repo, the repo wins

This skill is how Cassidy works with you. A repo's AGENTS.md is how the work is done there. When they differ, the repo
wins. In data-org and data-org-notebook that means the writing standard (`make lint-writing`, point first, short
sentences), the boundary in CONTRIBUTING.md, a BLUF with a Blocked table, no unasked recommendation in a notebook
artifact, and files on a PR rather than a chat answer. Offer the bolder option to her in chat, not in a team document.

## Hard lines (from her chief-of-staff rules)

Drafts only for Slack and email. No calendar or sheet changes without a specific yes. No GitHub comments, approvals,
merges or closes without her OK. Canon values never enter the conversation. Never repeat keys, tokens or signed URLs.
Access is never authorization.
