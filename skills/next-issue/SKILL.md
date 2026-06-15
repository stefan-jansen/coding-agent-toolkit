---
name: next-issue
description: This skill should be used after `/plan-issues` has materialized issues on GitHub and the user asks to "implement the next issue", "pick up the next ticket", "do the next one", or runs `/next-issue`. Picks the lowest-numbered open issue in the active milestone, branches if needed, implements per the issue body, runs tests, commits with `Closes #N`, and pushes. Host-neutral: same contract on Claude and Codex.
user-invocable: true
---

# next-issue — implement the next open issue in the milestone

You are running the **NEXT-ISSUE** step of the roborun workflow. Your job is to
take ONE open GitHub issue (the next in line for the active milestone) and ship
the implementation as commits on a feature branch, so that the PR for the
milestone moves forward by exactly one issue.

This step is **host-neutral**: same contract on Claude and Codex. The verbs are
`gh`, `git`, and whatever the project's test runner is (`uv run pytest`, `npm
test`, etc.).

## Arguments

Parse these from the user's invocation (any order):

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `--repo <owner/name>` | no | current repo via `gh repo view --json nameWithOwner` | Target GitHub repo |
| `--milestone <title>` | no | the most recently active milestone with open issues | Restrict picking to this milestone |
| `--issue <N>` | no | lowest-numbered open issue in milestone | Explicitly target one |
| `--branch <name>` | no | reuse current branch if it matches the milestone's PR; otherwise `feat/<milestone-slug>` | Feature branch name |
| `--dry-run` | no | false (act) | Print what would happen, change nothing |

**Default behavior** is to act, not dry-run — implementing code is the point of
the verb. `--dry-run` is for "show me what's next" without starting work.

Unlike `/plan-issues`, `next-issue` mutates the working tree by design. Use
`--dry-run` to preview the pick without touching code.

## What "active milestone" means

If `--milestone` is not given, resolve it like this:

1. List open milestones in the repo:
   `gh api "repos/<owner>/<repo>/milestones?state=open" --jq '.[].title'`
2. If exactly one is open → pick it.
3. If multiple → ask the user, listing them with their open-issue count from
   `gh issue list --milestone "<title>" --state open --json number`.
4. If zero → tell the user there's nothing to pick up and stop. Suggest
   `/plan-issues` or a new milestone.

## What "next issue" means

Lowest-numbered open issue in the chosen milestone:

```bash
gh issue list --repo <owner>/<repo> --milestone "<title>" --state open \
  --json number,title,body,labels --jq 'sort_by(.number)|.[0]'
```

If `--issue <N>` is passed, fetch that specific one and verify it is still open
and in the chosen milestone. If not, abort with the reason.

## Branch resolution (idempotent)

The roborun convention is **one PR per milestone**, with one commit per issue.
So the branch is the same across all `next-issue` runs within a milestone.

1. Look for an existing open PR whose head matches the milestone slug — e.g.
   `dogfood/dividend-modeling`. Search:
   `gh pr list --repo <owner>/<repo> --state open --json number,headRefName,milestone --jq '.[] | select(.milestone.title == "<title>")'`
2. If found and the local branch matches, **stay on it**. If found and the
   local branch differs, `git fetch origin <head>` then `git switch <head>`.
3. If no PR yet, derive the branch name:
   - If the user passed `--branch`, use it.
   - Else `feat/<milestone-slug>` where the slug is the milestone title
     lowercased, non-alphanumerics replaced with `-`, collapsed runs of `-`,
     trimmed.
   - Create the branch if missing: `git switch -c <branch>` from the default
     branch.

Never commit to the default branch (`main` / `master`). If you can't resolve a
feature branch, abort.

## Implementation contract

You are the agent — the implementation is **what you do, not what the skill
tells you**. The skill's job is to set the boundaries.

1. **Read the issue body** for the contract: files to touch, tests to add,
   acceptance criteria, error semantics. Also read any `plan.md` /
   `spec.md` it references via the "Plan reference" footer.
2. **Honor fail-loud-means-fail-atomic.** If your implementation has an error
   path that raises, no prior step in the same logical operation should be
   half-applied. Prefer a validation pre-pass before any state mutation.
   (This rule emerged from the 2026-06-15 host-swap probe — see roborun
   backlog #9.)
3. **Run tests before committing.** Use the project's test runner. If the
   suite has a fast subset, run that during iteration and the full suite
   once before commit. If anything fails, fix or abort — never commit red.
4. **One issue = one commit.** Squash any incremental commits into a single
   commit before push, with the message format below.

## Commit message format

```
<type>(<scope>): <imperative summary>

<one or two paragraphs explaining the change and why it's shaped this way>

Closes #<N>.
```

`<type>` follows conventional commits (`feat`, `fix`, `docs`, `refactor`,
`test`, `chore`). `<scope>` is the area, lowercased.

**Important caveat about `Closes #N`**: GitHub only fires keyword closing when
the commit lands on the **default branch**. On a feature branch with an open
PR, the issue stays open until the PR merges (then all `Closes #N` footers in
the squashed/merged commits fire at once). This is the roborun convention —
the closing footer is the trace, not the trigger. Do NOT manually close the
issue with `gh issue close` — that breaks the merge-time trace.

## Push + PR

```bash
git push -u origin <branch>     # first push
git push                        # subsequent pushes (PR auto-updates)
```

If no PR exists yet for this branch, open one as **draft** targeting the
default branch:

```bash
gh pr create --draft \
  --title "<milestone title>" \
  --body "<body listing all milestone issues as a checklist>"
```

PR body template:

```markdown
Milestone: `<title>`

- [<x or space>] #<n1> <issue 1 title>
- [<x or space>] #<n2> <issue 2 title>
- ...

Each box is ticked when its commit lands on this branch (the `Closes #N`
footer fires when this PR merges to <default branch>).
```

If a PR exists, **update its body** to tick the box for the just-implemented
issue: read the body, replace `- [ ] #<N>` with `- [x] #<N>`, write back via
`gh pr edit <num> --body-file -`.

## Dry-run

If `--dry-run` is passed, print this and stop:

```
next-issue — DRY RUN
  repo:        <owner>/<repo>
  milestone:   <title>           (<k> open issues)
  picking:     #<N> <title>
  branch:      <name>            (exists / will create)
  PR:          #<n> (draft) | will create

  Body of issue (truncated to 30 lines):
  ...

Re-run without --dry-run to implement.
```

Do not run tests or touch files in dry-run.

## Idempotency

- Re-running with the same issue still open → re-implement (the user
  presumably wants to). If you suspect they meant "next *next*", ask.
- Re-running after a commit landed (issue still open because PR not merged) →
  detect that the most recent commit on the branch has the closing footer
  for the chosen issue and ask whether to skip to the next-next issue or
  amend.

## Failure modes — fail loud

- `gh` not authenticated → print `gh auth login` hint, abort.
- No active milestone → suggest `/plan-issues`, abort.
- All issues in milestone closed → tell user, suggest `/ship`.
- Test suite fails after implementation → leave the working tree untouched,
  do not commit, surface the failing output to the user.
- Branch is on default branch and you would have to commit there → abort.

## Output to the user

At the end (non-dry-run), write a one-line entry to the active hourly
transition file at `.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`:

```markdown
## HH:MM - next-issue #<N> shipped
- repo: <owner>/<repo>
- milestone: <title>
- issue: #<N> <title>
- commit: <sha7>
- branch: <name>
- PR: #<n> (draft)
- tests: <count> passed
```

Then tell the user: which issue shipped, what's next (the next open issue, or
`/ship` if the milestone is empty), and any frictions worth backlog entries
in `~/agents/coding/roborun/README.md`.
