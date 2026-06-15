# /next-issue (Codex prompt)

Install to `~/.codex/prompts/next-issue.md` so it's invocable as `/next-issue`
in Codex. This is the Codex binding of the roborun NEXT-ISSUE step — same
contract as the Claude `next-issue` skill
(`roborun/skills/next-issue/SKILL.md`).

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

## Branch (one PR per milestone, one commit per issue)

1. Look up an existing PR for this milestone:
   `gh pr list --state open --json number,headRefName,milestone --jq '.[] | select(.milestone.title == "<title>")'`
2. If found → `git fetch origin <headRefName>` + `git switch <headRefName>`.
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

## Push + PR

**Use shell `git` and `gh` only.** Do NOT call `codex_apps` / GitHub
connector tools (`github_create_blob`, `github_create_pull_request`,
`github_create_commit`, etc.) — they are gated by per-tool
`approval_mode` and cannot be used in headless / non-interactive runs.
Connector preference is a documented Codex behaviour that the
orchestration prompt must explicitly suppress.

```bash
git push -u origin <branch>     # first push
git push                        # subsequent
```

If no PR yet, open a draft PR with body listing all milestone issues as a
checkbox list and tick the just-implemented one. If PR exists, edit its body
to tick the box for this issue.

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
`~/agents/coding/roborun/README.md`.

## Failure modes

Fail loud. `gh` unauth → abort with `gh auth login` hint. No active milestone →
suggest `/plan-issues`. All milestone issues closed → suggest `/ship`. Tests
red → leave tree dirty, surface output, no commit. On default branch with no
feature branch resolvable → abort.
