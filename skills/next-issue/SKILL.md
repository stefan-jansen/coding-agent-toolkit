---
name: next-issue
description: 'After `/plan-issues`: "implement the next issue", "pick up the next ticket", "do the next one", or `/next-issue`. Implements the lowest-numbered open issue in the active milestone and commits with a closing footer.'
user-invocable: true
---

# next-issue — implement the next open issue in the milestone

You are running the **NEXT-ISSUE** step of the workflow. Your job is to
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

Lowest-numbered open issue in the chosen milestone **that this branch has not
already shipped**:

```bash
gh issue list --repo <owner>/<repo> --milestone "<title>" --state open \
  --json number,title,body,labels --jq 'sort_by(.number)|.[0]'
```

**AN ISSUE STAYS OPEN UNTIL THE PR MERGES** — that is the convention, see below —
so "lowest open" starts pointing at work already on the branch the moment one
issue ships. Skipping it is not optional: re-running `/next-issue` immediately
after a success otherwise re-implements the issue that just landed. Filter the
candidates by looking for their closing footer in the branch's own commits:

```bash
git log --format=%B "<branch>" | grep -qE "^Closes #<N>\.?$"   # -> already shipped, skip
```

Skip rather than amend: the commit footer is the trace and rewriting history to
move a checkbox buys nothing. If every open issue in the milestone is already on
the branch, say so and point at `/ship` — do not re-do one to have something to do.

If `--issue <N>` is passed, fetch that specific one and verify it is still open
and in the chosen milestone. If it is already shipped on the branch, say so
explicitly and ask whether to re-implement or move on; never silently redo it.

## Remotes — the GitHub remote is NOT always `origin`

Resolve it once, up front, and use it everywhere below:

```bash
GH_REMOTE=$(git remote -v | awk '/github\.com[:/]/ {print $1; exit}')
[ -n "$GH_REMOTE" ] || { echo "no git remote points at github.com — abort" >&2; exit 1; }
```

**Do not assume `origin` is GitHub.** Repos in this workflow keep `origin` as a
local bare mirror for fast local fetches and point `github` at the real repo —
crypto-datawarehouse on 2026-09-20 had `origin` =
`/Users/…/Projects/crypto-datawarehouse.git` and `github` =
`git@github.com:…`. A hardcoded `git push origin <branch>` then "succeeds" against
the mirror, and the failure only surfaces later as a PR that cannot be opened.
`git push` alone is safe *after* an upstream is set, but the first push must name
the remote explicitly.

## Branch resolution (idempotent)

The convention is **one PR per milestone**, with one commit per issue.
So the branch is the same across all `next-issue` runs within a milestone.

1. Look for an existing open PR whose head matches the milestone slug — e.g.
   `dogfood/dividend-modeling`. Search:
   `gh pr list --repo <owner>/<repo> --state open --json number,headRefName,milestone --jq '.[] | select(.milestone.title == "<title>")'`
2. If found and the local branch matches, **stay on it**. If found and the
   local branch differs, `git fetch "$GH_REMOTE" <head>` then `git switch <head>`,
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
   (This rule emerged from the 2026-06-15 host-swap probe; see the toolkit
   backlog in `.workspace/memory/history.md`.)
3. **Run tests before committing.** Use the project's test runner. If the
   suite has a fast subset, run that during iteration and the full suite
   once before commit. If anything fails, fix or abort — never commit red.
4. **One issue = one commit.** Squash any incremental commits into a single
   commit before push, with the message format below.

## Acceptance that needs a real run

Some issues can only be accepted by evidence the agent cannot produce: a CI log,
a scheduled job, a production run. #47 in crypto-datawarehouse asked for five
`…: done in …m` lines from a workflow run — the code could be written and the
arithmetic pinned in tests, but the log does not exist until something runs.

Do not paper over that. In order:

1. **Split the acceptance.** Pin in tests everything that IS testable — the
   arithmetic, the wiring, the coupling between files — and say which half is
   pinned and which half is owed. A test asserting the numbers is real evidence;
   do not let it borrow the authority of the run it is standing in for.
2. **State the gap plainly** in the report: what the acceptance asks for, why the
   agent cannot produce it, and what would. "Not yet evidenced" is a correct and
   complete answer. "Done" is not, and neither is a commit message that reads as
   if the log existed.
3. **Name the trigger and every side effect.** Either it is already scheduled (say
   when it fires) or it needs a manual dispatch — then give the exact command, the
   expected runtime, and what it will mutate: cost, the stores it writes, and
   whether it commits to the default branch.
4. **Never close the issue on the strength of the code alone.** The `Closes #N`
   footer fires on merge, and a merge does not make an unrun acceptance pass.
5. **When authorised to dispatch, verify the dispatched ref carries the work.**
   A dispatch with no explicit ref runs the DEFAULT branch — the pre-merge code —
   so it reports on the old behaviour while looking like a green light for the new
   one. Check `head_sha` equals the branch tip before reading anything into the
   result, and prefer a command that cannot silently do the wrong thing:

   ```bash
   git push -u "$GH_REMOTE" <branch>          # the ref must exist remotely first
   gh workflow run <wf>.yml --ref <branch> -f <inputs...>
   gh api repos/<owner>/<repo>/actions/runs/<id> --jq '.head_branch, .head_sha'
   ```

   **AND A NEW WORKFLOW CANNOT BE DISPATCHED AT ALL UNTIL IT IS ON THAT DEFAULT
   BRANCH.** `gh workflow run <new>.yml --ref <branch>` fails with
   *"HTTP 404: workflow … not found on the default branch"* — `--ref` selects
   which version to RUN, it does not make an unmerged workflow addressable. This
   bites the moment you write the diagnostic workflow that would have evidenced
   the acceptance: it is unusable for exactly that until it merges. So either put
   the measurement in a workflow that already exists on the default branch, or
   accept that the acceptance waits for the merge — and say which in the report
   rather than discovering it at dispatch time:

   ```bash
   gh workflow list --all       # what is actually addressable right now
   ```

An acceptance that cannot be evidenced yet is a legitimate state to hand over, as
long as the next reader can see which half is proven and which half is owed.

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
the squashed/merged commits fire at once). This is the convention —
the closing footer is the trace, not the trigger. Do NOT manually close the
issue with `gh issue close` — that breaks the merge-time trace.

## Push + PR

```bash
git push -u "$GH_REMOTE" <branch>   # first push — NAME THE REMOTE, see above
git push                            # subsequent pushes (PR auto-updates)
```

Then **link the PR to the milestone**. `gh pr create` does not do it, and the
milestone's progress view is the one place the whole unit is visible:

```bash
gh api -X PATCH "/repos/<owner>/<repo>/issues/<num>" --input - <<< '{"milestone": <milestone-number>}'
```

Use the ISSUES endpoint with a JSON body. `-X PATCH /pulls/<num> -F milestone=<n>`
returns HTTP 200 with `milestone: null` and applies nothing — a silent no-op of
exactly the kind the body-update note below warns about. The milestone counter
will then include the PR itself (`open_issues` goes up by one); the per-issue
list, not the counter, is the load-bearing check.

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

**To regenerate the checklist, filter out pull requests.** Now that this PR is
linked to the milestone (above), the milestone's issue list contains the PR
itself, so a naive regeneration adds `- [ ] #<this-pr> <milestone title>` to its
own body:

```bash
gh api "repos/<owner>/<repo>/issues?milestone=<num>&state=all&per_page=30" \
  --jq '[.[] | select(.pull_request == null)] | sort_by(.number)[] | "- [\(if .number <= <last-done> then "x" else " " end)] #\(.number) \(.title)"'
```

Tick by number against the commits actually on the branch, not by whether the
issue is still open — an issue shipped on this branch stays open until the merge,
so "open" is true for work that is already done.

If a PR exists, **update its body** to tick the box for the just-implemented
issue: read the body, replace `- [ ] #<N>` with `- [x] #<N>`, write back via
the REST API:

```bash
gh api -X PATCH "/repos/<owner>/<repo>/pulls/<num>" -f body="$NEW_BODY"
```

Do **not** use `gh pr edit --body[-file]` for this step. On repos with
classic-projects history GitHub returns a GraphQL "Projects (classic) is
being deprecated" warning AND silently fails to update the body, with no
non-zero exit. The REST PATCH form above bypasses GraphQL entirely and
works on every repo.

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

```bash
mkdir -p ".workspace/transitions/$(date +%Y-%m-%d)"    # the hour changes; the dir may not exist
```

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

If the repo does not already ignore `.workspace/transitions/`, say so — the step
writes there on every run, and an unignored `.workspace/` otherwise turns up as
`?? .workspace/` in every `git status` and risks being swept into an unrelated
`git add -A`. Do not add the ignore rule silently; report it and let the user
choose, because it is their .gitignore.

Then tell the user: which issue shipped, what's next (the next open issue, or
`/ship` if the milestone is empty), and any frictions worth backlog entries.

### Where frictions actually go

Append them to the **`## Backlog (open)` section of
`~/coding-agent-toolkit/.workspace/memory/history.md`**, one line each, dated:

```markdown
- 2026-09-20 — `next-issue`: `<verb>` hardcodes `origin`, which is a local mirror
  in some repos; resolve the github.com remote instead.
```

The toolkit's README has no Roadmap section and its old "Currently #5, #6, #12"
pointer is stale, so that reference resolved to nothing and frictions went
unrecorded. The memory file is the backlog. Frictions worth recording are the
ones that cost this run something real — a wrong target, a silent write, a
re-pick — not stylistic preferences.
