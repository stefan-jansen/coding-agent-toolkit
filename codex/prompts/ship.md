# /ship (Codex prompt)

Install to `~/.codex/prompts/ship.md` so it's invocable as `/ship` in Codex.
This is the Codex binding of the SHIP step — same contract as the
Claude `ship` skill (`skills/ship/SKILL.md`).

---

Run the SHIP step. Land the active milestone's PR on the default branch,
verify every milestone issue auto-closed, close the milestone, and write a
transition entry. Host-neutral: same contract on Claude and Codex.

## Arguments

Parse from the user's invocation (any order):

- `--repo <owner/name>` — defaults to current repo via
  `gh repo view --json nameWithOwner --jq .nameWithOwner`.
- `--milestone <title>` — defaults to the active open milestone.
- `--pr <N>` — defaults to the open PR whose milestone matches.
- `--no-delete-branch` — keep the feature branch after merge (default: delete).
- `--no-close-milestone` — leave the milestone open after merge (default: close).
- `--dry-run` — print what would happen; touch nothing.

**Act by default** (no `--apply` flag). `--dry-run` is the preview.

## Resolve milestone

```bash
gh api "repos/<owner>/<repo>/milestones?state=open" --jq '.[].title'
```

- One open → pick it.
- Multiple → ask, list with open-issue counts.
- Zero → abort, nothing to ship.

## Resolve PR

```bash
gh pr list --repo <owner>/<repo> --state open \
  --json number,headRefName,milestone,isDraft,title \
  --jq '.[] | select(.milestone.title == "<title>")'
```

- One match → use it.
- Multiple → ask.
- Zero → suggest `/next-issue`, abort.

If `--pr <N>` given, fetch and verify its milestone matches.

## Readiness gates

ALL gates must pass before merge (or pass `--force` to override):

1. **Closing-footer coverage.** Every open milestone issue must have a
   `Closes #<N>` (or `Fixes`/`Resolves`) in some commit on the PR branch:
   `gh pr view <PR> --json commits --jq '.commits[].messageBody' | grep -Ei "(closes|fixes|resolves) #<N>\b"`.
   Gaps → list and abort.
2. **Mergeable.** `gh pr view <PR> --json mergeable,mergeStateStatus`. If
   `CONFLICTING`, `DIRTY`, or `BLOCKED` → abort.
3. **Checks green.** `gh pr checks <PR>`. Failing or pending → abort. Zero
   checks configured → skip this gate.

## Mark ready (if draft)

```bash
[ "$(gh pr view <PR> --json isDraft --jq .isDraft)" = "true" ] && gh pr ready <PR>
```

## Squash merge

**Use shell `gh` only.** Do NOT call `codex_apps` / GitHub connector tools
(`github_merge_pull_request`, `github_update_pull_request`, etc.) — they
are gated by per-tool `approval_mode` and cannot be used in headless runs.

Build a non-interactive squash message that preserves every `Closes #<N>`
footer (so GitHub closes all milestone issues on merge):

```bash
FOOTERS=$(gh pr view <PR> --json commits \
  --jq '.commits[].messageBody' \
  | grep -Ei '^(closes|fixes|resolves) #[0-9]+' | sort -u)

gh pr merge <PR> --squash \
  --subject "<PR title>" \
  --body "<one-line summary>

$FOOTERS" \
  $( [ "<no-delete-branch>" = "false" ] && echo "--delete-branch" )

MERGE_SHA=$(gh pr view <PR> --json mergeCommit --jq .mergeCommit.oid)
```

### Sandbox fallback

In some Codex sandbox modes `gh pr merge --delete-branch` is blocked
(branch-deletion classified as a write op). When that fails with a
permission error (not a real merge conflict), fall back to the
underlying API:

```bash
gh api -X PATCH "repos/<owner>/<repo>/pulls/<PR>/merge" \
  -f merge_method=squash \
  -f commit_title="<PR title>" \
  -f commit_message="<body with all Closes footers>"
gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch>"
```

Codex discovered this unprompted during the 0.3.0 dogfood ship.

## Post-merge verify

1. `gh issue list --repo <owner>/<repo> --milestone "<title>" --state open --json number`
   → expect `[]`. Any still open → close manually with
   `gh issue close <N> --reason completed --comment "Shipped in <MERGE_SHA>"`
   and note a backlog entry about the missing footer.
2. `git fetch origin && git log -1 origin/<default> --format='%H %s'` → expect
   the merge commit.
3. If user is on the deleted feature branch locally:
   `git switch <default> && git pull --ff-only && git branch -D <feature>`.

## Close the milestone (unless `--no-close-milestone`)

GitHub does NOT auto-close milestones when their issues close — do it:

```bash
NUM=$(gh api "repos/<owner>/<repo>/milestones?state=open" \
  --jq '.[] | select(.title=="<title>") | .number')
gh api -X PATCH "repos/<owner>/<repo>/milestones/$NUM" -f state=closed
```

## Dry-run

```
ship — DRY RUN
  repo:           <owner>/<repo>
  milestone:      <title>           (<k> open issues)
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

No `gh pr ready`, no `gh pr merge`, no milestone close in dry-run.

## Output

After a non-dry-run ship, append to
`.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`:

```markdown
## HH:MM - ship — milestone <title> closed
- repo: <owner>/<repo>
- PR: #<N> squash-merged as <merge-sha7>
- issues closed: #<n1>, #<n2>, …
- milestone: closed
- branch: <name> deleted
```

Tell the user: merge SHA, closed issues, what's next (`/plan-issues` for the
next milestone or `/align` for a new scope), and any backlog candidates worth
adding to `~/agents/coding/coding-agent-toolkit/README.md`.

## Idempotency

- PR already merged → skip merge, run post-merge verify + milestone close
  anyway (recovers from a previous run that crashed mid-flow).
- No open PR but milestone has open issues → suggest `/next-issue`.
- PR merged + milestone closed → tell user nothing to do, suggest
  `/plan-issues` or `/align`.

## Failure modes

Fail loud. `gh` unauth → abort with `gh auth login` hint. No active milestone →
abort. No open PR → suggest `/next-issue`. Closing-footer gaps → list missing
`Closes #<N>` per open issue, abort. Conflicts / failing checks → surface and
abort. `gh pr merge` fails → surface stderr, do not retry destructively.
Post-merge issues still open → close manually, log backlog entry.
