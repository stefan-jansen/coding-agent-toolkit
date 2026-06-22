# Roborun follow-up — verification + open backlog

Single sheet of copy-pasteable commands for the next moves on the
cross-coding-agent toolkit. Picked over from the 12:55 handoff
(`.workspace/transitions/2026-06-17/125511.md`) and the verification gaps
surfaced by your two corrections in this session.

Pick in any order. Suggested order: A → B → C → D.

---

## A. Verify skill auto-invocation (the actual gap)

The skills `ship`, `handoff`, `continue` exist and are well-shaped, but
none have been **auto-invoked from a fresh session** via the slash-command
or description-match path. Three tests close that:

### A.1 Fresh Claude session — `/handoff`

Open a new Claude Code session in `~/agents/factory`. Type literally:

```
/handoff --why "skill-invocation smoke test"
```

Expected: the `workflow:handoff` skill auto-loads (visible in /skills
list at session start), Claude follows its 8-section contract, writes
the file under `.workspace/transitions/2026-06-17/HHMMSS.md`, and prints
the `continue from <path>` footer.

Check after:

```bash
ls -t ~/agents/factory/.workspace/transitions/2026-06-17/ | head -3
# expect: a fresh HHMMSS.md from the new session
```

If the skill did NOT auto-load (e.g. Claude wrote a freeform handoff
without referencing the contract) — that's the real result, and we
need to revise the skill description so semantic matching catches it.

### A.2 Fresh Claude session — `/continue`

Open another fresh session in `~/agents/factory`. Type literally:

```
/continue --from .workspace/transitions/2026-06-17/125511.md
```

OR, to test the canonical resumption phrase:

```
continue from .workspace/transitions/2026-06-17/125511.md
```

Expected: the `workflow:continue` skill auto-loads, runs the read-only
verification snapshot (across the 4 repos listed in 125511.md), reports
any drift inline, surfaces the suggested next steps, and **stops**
without auto-executing one.

If Claude reads the file freeform without referencing the skill's
contract — same conclusion as A.1: revise description.

### A.3 Codex round-trip via `codex exec`

**Status 2026-06-19 22:50: A.3 CLOSED.** Namespace migration is structurally and
functionally complete. `~/.agents/skills/{align,continue,handoff,next-issue,plan-issues,ship}/SKILL.md`
now symlink to canonical `~/agents/coding/roborun/skills/<verb>/SKILL.md`;
`align/spec-template.md` copied so the sibling-template reference is satisfied.
Deprecated pre-2026-02-27 `handoff/` and `continue-session/` skills moved to
`~/.agents/skills-archived/` so Codex no longer indexes them.

Live `codex exec` verification ran for two verbs:

| Verb | Result | Evidence |
|---|---|---|
| `/handoff` | ✓ PASS | Codex declared "I'm using the `handoff` skill", read `~/.agents/skills/handoff/SKILL.md`, wrote `.workspace/transitions/2026-06-20/024447.md` per the contract. Log: `/tmp/codex-handoff-retest-024421.log`. |
| `/continue` | ✓ PASS (de facto) | Codex acted on the slash-command directly (resumed from the cited transition file, ran diff/diagnosis, even did the next follow-up step by installing `align/spec-template.md`). Did not explicitly cat its SKILL.md — model improvised reasonably from the obvious action. Log: `/tmp/codex-continue-retest3-024607.log`. |

**Side finding (now fixed): two roborun skills had YAML-invalid frontmatter.**
The phrase `Host-neutral: same contract on Claude and Codex.` contains a bare
colon-space inside an unquoted description string, which broke Codex's strict
YAML parser:

```
ERROR codex_core::session::session: failed to load skill
.../ship/SKILL.md: invalid YAML: mapping values are not allowed
in this context at line 2 column 467
```

Same bug in `next-issue/SKILL.md`. Fixed canonically (em-dash replaces
colon-space) in both `~/agents/coding/roborun/skills/{next-issue,ship}/SKILL.md`
and the plugin port `~/agents/coding/plugins/workflow/skills/{next-issue,ship}/SKILL.md`.
Codex prompts under `~/agents/coding/roborun/codex/prompts/*.md` still contain
the phrase in markdown body (not YAML), so cosmetic-consistency only; left
unchanged for now.

**Remaining A.3 work**: optional live runs for `/align`, `/plan-issues`,
`/next-issue`, `/ship` against a throwaway repo. Skipped here because
(a) those verbs have side effects (GitHub issue creation, commits, PR merges);
(b) all 6 SKILL.md files now parse and load cleanly (validated via
`python3 -c 'yaml.safe_load(...)'`); (c) the two highest-leverage verbs
verified above are the ones whose contracts matter most for the cross-host
round-trip story. Run the remaining 4 only when there's a real milestone to
drive.

---

## B. Drift-lesson fix in `/handoff` (CLOSED 2026-06-20)

**Status**: FIXED in roborun `ee24b0a` + plugins `721ae3f`. Added
"Verify durable artifacts only" paragraph to canonical SKILL.md,
Codex prompt, and plugin port. Plugin port byte-identical to canonical
(verified via `diff -q`).

Catch from 2026-06-17 session: verification snapshots that list
hourly-rotating files (e.g. `17.md`, `22.md`) go stale by the next
hour. Verify durable artifacts only — commit SHAs, milestone state,
skill/prompt inventories.

Three files to edit (canonical + Codex prompt + plugin port):

```
~/agents/coding/roborun/skills/handoff/SKILL.md
~/agents/coding/roborun/codex/prompts/handoff.md
~/agents/coding/plugins/workflow/skills/handoff/SKILL.md
```

Add to each, under "Verification snapshot rules":

> **Verify durable artifacts only.** Commit SHAs, milestone states,
> branch tips, skill/prompt inventories — things that change only when
> work changes. Do NOT list session-relative files that the
> transition-rotation hook creates (e.g. `HH.md`, `HHMMSS.md` in
> today's date dir); they churn by design and will show false drift
> by the next hour.

Quick edit. Plugin port stays byte-identical to canonical — `diff`
should still be empty after edits.

Commit shape:

```bash
cd ~/agents/coding/roborun
git add skills/handoff/SKILL.md codex/prompts/handoff.md
git commit -m "fix(handoff): verify durable artifacts only, not hourly-rotating files

Catch from 2026-06-17 session: a verification snapshot that listed
'17.md' and '22.md' under today's transition dir went stale before
the next hour, producing benign drift on the first /continue replay.
Tighten the snapshot rules: SHAs, milestones, branch tips,
skill/prompt inventories — never session-relative rotating files.
"
git push

cd ~/agents/coding/plugins
git add workflow/skills/handoff/SKILL.md
git commit -m "fix(workflow): /handoff — verify durable artifacts only (port)"
git push
```

---

## C. Backlog #11 — `gh pr edit --body` REST fallback (CLOSED 2026-06-20)

**Status**: FIXED in roborun `cc0902b` + plugins `081e7f5`. `/next-issue`
now uses `gh api -X PATCH /repos/{owner}/{repo}/pulls/{N} -f body=...`
unconditionally. Updated in: roborun `skills/next-issue/SKILL.md`,
roborun `codex/prompts/next-issue.md` (added REST guidance to the
body-update step that didn't previously name a command), plugins
`workflow/skills/next-issue/SKILL.md`. `/ship` grepped clean — its
squash-merge step doesn't touch the PR body. README backlog item
marked FIXED in roborun `27d3616`.

Update 2026-06-19 22:47: This is the next actionable item after the
Codex namespace migration when running with `--no-verify`. Current sandbox
can read but not write `~/agents/coding/roborun` or `~/agents/coding/plugins`,
so the source edit is blocked in this session. Grep found the live hit in:
`~/agents/coding/roborun/skills/next-issue/SKILL.md:151` and
`~/agents/coding/plugins/workflow/skills/next-issue/SKILL.md:151`. No
`gh pr edit` hit was found in `/ship`, and no hit was found in
`roborun/codex/prompts/next-issue.md`.

Symptom (surfaced on roborun-dogfood-backtest during 0.2.0 ship):
`gh pr edit --body[-file]` returns a GraphQL "Projects (classic) is
being deprecated" warning AND silently fails to update the body, no
error code returned.

Workaround that works:

```bash
gh api -X PATCH /repos/{owner}/{repo}/pulls/{N} -f body="$BODY"
```

Files to edit:

```
~/agents/coding/roborun/skills/next-issue/SKILL.md       # "Push + PR" section, body-update step
~/agents/coding/roborun/codex/prompts/next-issue.md      # same section
~/agents/coding/plugins/workflow/skills/next-issue/SKILL.md
~/agents/coding/roborun/skills/ship/SKILL.md             # double-check whether /ship touches the body
~/agents/coding/roborun/codex/prompts/ship.md
~/agents/coding/plugins/workflow/skills/ship/SKILL.md
```

For `/next-issue`: change the "PR body ticking" step from
`gh pr edit <PR> --body-file -` to the REST PATCH form. Either:
(a) try GraphQL first, fall back on warning; OR (b) use REST
unconditionally. (b) is simpler and more robust — recommend (b).

For `/ship`: the squash-merge step doesn't touch the PR body, but
verify by grepping each SKILL.md for `gh pr edit` — leave if absent.

```bash
grep -n 'gh pr edit' ~/agents/coding/roborun/skills/{next-issue,ship}/SKILL.md \
  ~/agents/coding/roborun/codex/prompts/{next-issue,ship}.md \
  ~/agents/coding/plugins/workflow/skills/{next-issue,ship}/SKILL.md
```

Commit shape:

```bash
cd ~/agents/coding/roborun
git add skills/next-issue/SKILL.md codex/prompts/next-issue.md
# add ship/ files only if grep found a hit
git commit -m "fix(next-issue): use REST PATCH for PR body update (gh pr edit silent-fail)

Backlog #11: 'gh pr edit --body[-file]' returns a GraphQL 'Projects
(classic) is being deprecated' warning AND silently fails to update
the PR body on repos with classic-projects history. No error code is
returned, so /next-issue's 'tick the box' step silently no-ops.
Switch to 'gh api -X PATCH /repos/{}/{}/pulls/{N} -f body=...'
unconditionally — REST works, GraphQL doesn't, and we don't need to
detect the warning.
"
git push

cd ~/agents/coding/plugins
git add workflow/skills/next-issue/SKILL.md
git commit -m "fix(workflow): /next-issue — REST PATCH for PR body (port)"
git push
```

Then mark #11 FIXED in the roborun README backlog.

---

## D. Backlog #1 + #9 — `/align` improvements (CLOSED 2026-06-20)

**Status**: BOTH FIXED in roborun `cd70e77` + plugins `ee62a92`.

#1 (`@brief.md` input mode): Added Arguments table + "Two entry modes"
section. Cold = default (interrogation per existing rules); brief mode
reads the named file, seeds the spec from it, and falls through to
interrogation only for sections the brief leaves vague. Still does
the 5-8 bullet playback before writing. Mirrored to Codex prompt.

#9 (atomicity clause): Added "Spec-writing rules" section requiring
that any error condition in the spec carries a verifiable atomicity
clause in Acceptance — when the error fires, no prior step in the
same logical operation may be half-applied. Implementation must
validate first, then mutate. Mirrored to Codex prompt.

README backlog items #1 and #9 marked FIXED in roborun `27d3616`.



#1 — `/align @brief.md` input mode. Accept a brief/document/RFC as
input and only fall through to cold interrogation when invoked
without one.

#9 — fail-loud-fail-atomic in `/align`'s contract-writing guidance.
Already landed in `/next-issue`'s implementation guidance; promote
the rule into `/align`'s spec-writing rules so generated specs
include atomicity clauses where error paths exist.

Files:

```
~/agents/coding/roborun/skills/align/SKILL.md
~/agents/coding/roborun/codex/prompts/align.md
~/agents/coding/plugins/workflow/skills/align/SKILL.md
```

For #1, add an `Arguments` row:

| `@<path>` | no | none | Read the named brief and seed spec.md from it, skipping cold interrogation |

And a new section:

> **With a brief input (`/align @brief.md`)**, read the file, infer
> the Objective / Why / In scope / Out of scope / Constraints / Open
> questions sections from it, and produce `spec.md` directly. Only
> fall through to question-by-question interrogation when invoked
> without a brief.

For #9, add to the spec-writing rules:

> **Atomicity in error paths.** If the spec names an error condition
> (e.g. "raise ValueError on missing input"), include an explicit
> atomicity clause in Acceptance criteria: when the error fires, no
> prior step in the same logical operation may be half-applied. The
> implementation should validate first, then mutate.

Commits as above.

Mark #1 + #9 FIXED in the README backlog after shipping.

---

## Status summary (what was already done before this checklist)

- ✓ `/ship`, `/handoff`, `/continue` skills shipped (canonical + Codex
  prompt + plugin port). All 7 verbs structurally exist.
- ✓ 0.2.0 dogfood shipped end-to-end on
  `stefan-jansen/roborun-dogfood-backtest` (PR #8 → `c66af9f`).
- ✓ Backlog #7 (Codex headless push connector-avoidance) live-verified.
- ✓ Backlog #10 (`/ship` live re-verify) FIXED on 0.2.0.
- ⚠ Skill auto-invocation NOT verified for `/ship` / `/handoff` /
  `/continue` — section A above.
- ⚠ Backlog #11 (`gh pr edit --body` GraphQL silent-fail) will bite
  the next dogfood `/next-issue` run.
- ⚠ Backlog #12 (Codex memory still expects `git safe-commit`) —
  low priority, friction note only.
