---
name: ship
description: This skill should be used after all issues in a milestone have commits on the milestone's PR branch and the user asks to "ship the milestone", "merge the PR", "close out the milestone", or runs `/ship`. Verifies every milestone issue has a closing-footer commit on the PR branch, marks the PR ready if draft, squash-merges with branch deletion, verifies all milestone issues auto-closed, closes the milestone, and writes a transition entry. Host-neutral: same contract on Claude and Codex.
user-invocable: true
---

# ship — close out the active milestone

You are running the **SHIP** step of the roborun workflow. Your job is to take
the milestone's open PR — built up one commit at a time by `/next-issue` — and
land it on the default branch, then verify that all milestone issues auto-closed
and close the milestone.

This step is **host-neutral**: same contract on Claude and Codex. The verbs are
`gh` and `git`.

## Arguments

Parse these from the user's invocation (any order):

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `--repo <owner/name>` | no | current repo via `gh repo view --json nameWithOwner --jq .nameWithOwner` | Target GitHub repo |
| `--milestone <title>` | no | the active milestone (resolved as in `/next-issue`) | Restrict to this milestone |
| `--pr <N>` | no | the open PR whose milestone matches | Override PR pick |
| `--no-delete-branch` | no | false (delete) | Keep the feature branch after merge |
| `--no-close-milestone` | no | false (close) | Leave the milestone open after merge |
| `--dry-run` | no | false (act) | Print what would happen, change nothing |

**Default behavior** is to act, not dry-run — landing the PR is the point of
the verb. `--dry-run` is for "show me the ship checklist" without merging.

## What "active milestone" means

Same resolution as `/next-issue`:

1. List open milestones: `gh api "repos/<owner>/<repo>/milestones?state=open" --jq '.[].title'`.
2. One open → pick it.
3. Multiple → ask the user, listing them with open-issue counts.
4. Zero → tell the user there's nothing to ship and stop.

## What "the milestone's PR" means

```bash
gh pr list --repo <owner>/<repo> --state open \
  --json number,headRefName,milestone,isDraft,title \
  --jq '.[] | select(.milestone.title == "<title>")'
```

- Exactly one open PR with that milestone → use it.
- More than one → ask the user which to ship.
- Zero → suggest `/next-issue` (no work has landed yet) and abort.

If `--pr <N>` is passed, fetch that PR and verify its milestone matches.

## Readiness checklist (pre-merge)

Ship is the gate. Verify ALL of these before merging:

1. **All milestone issues have a closing-footer commit on the PR branch.** List
   all open issues in the milestone:
   `gh issue list --repo <owner>/<repo> --milestone "<title>" --state open --json number --jq '.[].number'`.
   For each `<N>`, check that the PR commit log contains `Closes #<N>` (or
   `Fixes #<N>`, `Resolves #<N>`):
   `gh pr view <PR> --json commits --jq '.commits[].messageBody' | grep -Ei "(closes|fixes|resolves) #<N>\b"`.
   If any issue is missing its closing footer → list the gaps, suggest
   `/next-issue` to address them, abort.
2. **Mergeable.** `gh pr view <PR> --json mergeable,mergeStateStatus`. If
   `mergeable` is `CONFLICTING` or `mergeStateStatus` is `DIRTY` or `BLOCKED`,
   surface the state and abort (resolution is out of band).
3. **Status checks green** (if any). `gh pr checks <PR>`. If any check is
   failing or pending, surface and abort. If the repo has zero checks
   configured, skip this gate.
4. **PR body checklist consistent.** Optional: read the PR body. If it
   contains a `- [ ] #<N>` for a milestone issue, that's a hint the PR isn't
   ready — surface and ask whether to proceed anyway. The closing-footer
   check above is the load-bearing gate; the checkboxes are a courtesy.

If any gate fails and the user has not passed `--force`, abort with a clear
explanation of which gate failed.

## Mark ready (if draft)

If `gh pr view <PR> --json isDraft --jq .isDraft` is `true`:

```bash
gh pr ready <PR>
```

If already ready, skip.

## Squash merge

The roborun convention is **one PR per milestone, squashed into one commit on
the default branch**. The squash subject defaults to the PR title (which by
`/next-issue` convention is the milestone title). The squash body should
preserve every `Closes #<N>` footer so GitHub closes all milestone issues.

```bash
gh pr merge <PR> --squash \
  $( [ "<no-delete-branch>" = "false" ] && echo "--delete-branch" )
```

`gh pr merge --squash` opens an editor by default for the squash message. To
keep this non-interactive, build the squash body explicitly:

```bash
# Collect all Closes footers from the PR commits
FOOTERS=$(gh pr view <PR> --json commits \
  --jq '.commits[].messageBody' | grep -Ei '^(closes|fixes|resolves) #[0-9]+' | sort -u)

# Use the PR title as subject; one short paragraph + all footers as body
gh pr merge <PR> --squash \
  --subject "<PR title>" \
  --body "<one-line summary>

$FOOTERS" \
  $( [ "<no-delete-branch>" = "false" ] && echo "--delete-branch" )
```

Capture the resulting merge commit SHA:

```bash
MERGE_SHA=$(gh pr view <PR> --json mergeCommit --jq .mergeCommit.oid)
```

## Post-merge verification

1. **All milestone issues now closed.** Re-list:
   `gh issue list --repo <owner>/<repo> --milestone "<title>" --state open --json number`.
   Expect an empty array. If anything is still open, the squash body may have
   lost a footer — surface the open issue list, close manually with
   `gh issue close <N> --reason completed --comment "Shipped in <MERGE_SHA>"`,
   and add a roborun backlog entry noting the footer-preservation bug.
2. **Default branch advanced.** `git fetch origin && git log -1 origin/<default> --format='%H %s'` —
   verify the most recent commit is the merge.
3. **Local default branch synced.** If the user is on the default branch
   locally, `git pull --ff-only`. If they're on the now-deleted feature
   branch, `git switch <default> && git pull --ff-only && git branch -D <feature>`.

## Close the milestone (unless `--no-close-milestone`)

```bash
gh api -X PATCH "repos/<owner>/<repo>/milestones/<milestone-number>" \
  -f state=closed
```

Where `<milestone-number>` comes from:

```bash
gh api "repos/<owner>/<repo>/milestones?state=open" \
  --jq '.[] | select(.title=="<title>") | .number'
```

GitHub does NOT auto-close milestones when all their issues close — the verb
has to do this explicitly.

## Dry-run

If `--dry-run` is passed, print this and stop:

```
ship — DRY RUN
  repo:           <owner>/<repo>
  milestone:      <title>           (<k> open issues, must be 0 after closing-footer check)
  PR:             #<N> "<title>"    (draft|ready)
  branch:         <head>            (will delete: yes|no)
  close milestone: yes|no

  Readiness:
    closing footers covered: <k>/<k>     ✓ | gaps: #<n>, #<n>
    mergeable:               <MERGEABLE | CONFLICTING | UNKNOWN>
    mergeStateStatus:        <CLEAN | DIRTY | BLOCKED | …>
    checks:                  <p passing, f failing, q pending>

Re-run without --dry-run to ship.
```

Do not run `gh pr ready`, `gh pr merge`, or close the milestone in dry-run.

## Idempotency

- Re-running after the PR is already merged → detect via `gh pr view <PR> --json state --jq .state == "MERGED"`,
  skip the merge step, run the post-merge verification + milestone close
  anyway. (Useful when the previous run merged but failed before closing the
  milestone.)
- Re-running with no open PR but the milestone still has open issues → suggest
  `/next-issue`.
- Re-running with everything already done (PR merged, milestone closed) → tell
  the user there is nothing to do; suggest the next milestone or
  `/plan-issues` for new work.

## Failure modes — fail loud

- `gh` not authenticated → print `gh auth login` hint, abort.
- No active milestone → tell user, abort.
- No open PR for the milestone → suggest `/next-issue`, abort.
- Closing-footer gaps → list missing `Closes #<N>` per open issue, suggest
  `/next-issue` to fill them, abort.
- PR has conflicts / failing checks → surface state, abort.
- `gh pr merge` fails → surface stderr, abort. Do NOT retry destructively.
- Post-merge: issues still open → surface, close manually, log roborun
  backlog entry about the missing footer.

## Output to the user

After a non-dry-run ship, append to the active hourly transition file at
`.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`:

```markdown
## HH:MM - ship — milestone <title> closed
- repo: <owner>/<repo>
- PR: #<N> squash-merged as <merge-sha7>
- issues closed: #<n1>, #<n2>, …
- milestone: closed
- branch: <name> deleted
```

Then tell the user: the merge SHA, the closed issues, and what's next
(`/plan-issues` for the next milestone, or `/align` for a new scope). If
anything fell out of spec (a missing footer caught at post-merge, a milestone
that had to be hand-closed), surface it as a roborun backlog candidate for
`~/agents/coding/roborun/README.md`.
