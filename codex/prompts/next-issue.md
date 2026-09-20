# /next-issue (Codex prompt)

Install to `~/.codex/prompts/next-issue.md` so it's invocable as `/next-issue`
in Codex. This is the Codex binding of the NEXT-ISSUE step — same
contract as the Claude `next-issue` skill
(`skills/next-issue/SKILL.md`).

---

Run the NEXT-ISSUE step. Pick ONE open issue from the active milestone of the
current GitHub repo, implement it on a feature branch, commit with `Closes #N`,
and push. Host-neutral: same contract on Claude and Codex.

## Arguments

Parse from the user's invocation (any order):

- `--repo <owner/name>` — defaults to current repo from
  `gh repo view --json nameWithOwner --jq .nameWithOwner`.
- `--milestone <title>` — defaults to the most recently active open milestone.
- `--issue <N>` — defaults to the lowest-numbered open issue in the milestone.
- `--branch <name>` — defaults to reusing the milestone's existing PR branch,
  else `feat/<milestone-slug>` from the default branch.
- `--dry-run` — print what would happen; touch nothing.

**Act by default** (no `--apply` flag). `--dry-run` is the preview.

## Resolve milestone

```bash
gh api "repos/<owner>/<repo>/milestones?state=open" --jq '.[].title'
```

- One open → pick it.
- Multiple → ask, list with open-issue counts.
- Zero → suggest `/plan-issues`, abort.

## Pick issue

```bash
gh issue list --repo <owner>/<repo> --milestone "<title>" --state open \
  --json number,title,body --jq 'sort_by(.number)|.[0]'
```

If `--issue <N>` given, fetch that one and verify it's in the milestone + open.
If its `Closes #N` footer is ALREADY in the branch's commits, it has shipped;
skip it rather than re-implementing (issues stay open until the PR merges).

**Skip already-shipped issues when picking the next one.** "Lowest-numbered
open" otherwise points at work already on the branch:

```bash
git log --format=%B "<branch>" | grep -qE "^Closes #<N>\.?$"   # -> shipped, skip
```

If every open issue is already on the branch, say so and point at `/ship`.

## Remotes — the GitHub remote is NOT always `origin`

Resolve it once and use it for every fetch/push:

```bash
GH_REMOTE=$(git remote -v | awk '/github\.com[:/]/ {print $1; exit}')
[ -n "$GH_REMOTE" ] || { echo "no git remote points at github.com" >&2; exit 1; }
```

Some repos keep `origin` as a LOCAL BARE MIRROR and point `github` at the real
repo. A hardcoded `git push origin` then "succeeds" against the mirror and only
fails later, when the PR cannot be opened.

## Branch (one PR per milestone, one commit per issue)

1. Look up an existing PR for this milestone:
   `gh pr list --state open --json number,headRefName,milestone --jq '.[] | select(.milestone.title == "<title>")'`
2. If found → `git fetch "$GH_REMOTE" <headRefName>` + `git switch <headRefName>`.
3. Else → derive `feat/<milestone-slug>` (lowercase, non-alphanum → `-`,
   trim). `git switch -c <branch>` from the default branch.

Never commit to default branch.

## Implement

You ARE the implementation. Read the issue body — files, tests, acceptance.
Read any `plan.md` / `spec.md` referenced via the body's "Plan reference"
footer. Then write the code.

**Fail-loud means fail-atomic**: when an error path raises (e.g. `ValueError`
on missing input), no prior step in the same logical operation should be
half-applied. Prefer a validation pre-pass before any state mutation.

## Test

Run the project's test runner (`uv run pytest -q`, `npm test`, etc.). Full
suite green before commit. If anything is red, fix or abort — never commit
red.

## Commit (one per issue)

```
<type>(<scope>): <imperative summary>

<one or two paragraphs of why>

Closes #<N>.
```

`<type>` follows conventional commits. **Important caveat**: `Closes #N` only
fires at PR merge to the default branch. On a feature branch the issue stays
open. Do NOT `gh issue close` manually — the closing trace happens at merge.

## Acceptance that needs a real run

Some issues can only be accepted by evidence the agent cannot produce — a CI log,
a scheduled job, a production run. Do not paper over that:

1. **Split it.** Pin in tests what IS testable (arithmetic, wiring, the coupling
   between files) and say which half is pinned and which is owed. A test asserting
   the numbers is real evidence; it does not stand in for the run.
2. **State the gap plainly.** What the acceptance asks for, why you cannot produce
   it, and what would. "Not yet evidenced" is complete; "done" is not.
3. **Name the trigger and its side effects.** Already scheduled (say when), or an
   exact dispatch command plus expected runtime and what it mutates — cost, stores
   written, whether it commits to the default branch.
4. **Never close the issue on the code alone.** A merge does not make an unrun
   acceptance pass.
5. **When authorised to dispatch, verify the ref.** A dispatch with no explicit
   ref runs the DEFAULT branch — pre-merge code — reporting on old behaviour while
   looking like a green light for the new. Check `head_sha` before reading
   anything into the result:

```bash
gh workflow run <wf>.yml --ref <branch> -f <inputs...>
gh api repos/<owner>/<repo>/actions/runs/<id> --jq '.head_branch, .head_sha'
```

## Push + PR

**Use shell `git` and `gh` only.** Do NOT call `codex_apps` / GitHub
connector tools (`github_create_blob`, `github_create_pull_request`,
`github_create_commit`, etc.) — they are gated by per-tool
`approval_mode` and cannot be used in headless / non-interactive runs.
Connector preference is a documented Codex behaviour that the
orchestration prompt must explicitly suppress.

```bash
git push -u "$GH_REMOTE" <branch>   # first push — NAME THE REMOTE
git push                            # subsequent
```

Link the PR to the milestone — `gh pr create` does not do it. Use the ISSUES
endpoint with a JSON body; `PATCH /pulls/<n> -F milestone=<n>` returns 200 and
applies nothing:

```bash
gh api -X PATCH "/repos/<owner>/<repo>/issues/<num>" --input - <<< '{"milestone": <n>}'
```

If no PR yet, open a draft PR with body listing all milestone issues as a
checkbox list and tick the just-implemented one. If PR exists, edit its body
to tick the box for this issue.

**Filter pull requests out when regenerating that checklist.** Once the PR is
linked to the milestone, the milestone's issue list includes the PR itself, so a
naive regeneration adds the PR's own number to its own body:

```bash
gh api "repos/<owner>/<repo>/issues?milestone=<num>&state=all&per_page=30" \
  --jq '[.[] | select(.pull_request == null)] | sort_by(.number)[]'
```

Tick by number against the commits on the branch — an issue shipped on the branch
stays open until the merge, so "still open" does not mean "not done".

To update the body, use the REST API:

```bash
gh api -X PATCH "/repos/<owner>/<repo>/pulls/<num>" -f body="$NEW_BODY"
```

Do **not** use `gh pr edit --body[-file]`. On repos with classic-projects
history it returns a GraphQL "Projects (classic) is being deprecated"
warning AND silently fails to update the body with no non-zero exit. The
REST PATCH form bypasses GraphQL and works on every repo.

## Dry-run

```
next-issue — DRY RUN
  repo:        <owner>/<repo>
  milestone:   <title>           (<k> open issues)
  picking:     #<N> <title>
  branch:      <name>            (exists / will create)
  PR:          #<n> (draft) | will create

  Body of issue (first 30 lines):
  ...

Re-run without --dry-run to implement.
```

No tests, no file writes, no `gh` writes.

## Output

After a non-dry-run shipment, append to
`.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`:

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

Tell the user: which issue shipped, what's next (next open issue, or `/ship`
if milestone is empty), and any frictions worth backlog entries in
`~/agents/coding/coding-agent-toolkit/README.md`.

## Failure modes

Fail loud. `gh` unauth → abort with `gh auth login` hint. No active milestone →
suggest `/plan-issues`. All milestone issues closed → suggest `/ship`. Tests
red → leave tree dirty, surface output, no commit. On default branch with no
feature branch resolvable → abort.
