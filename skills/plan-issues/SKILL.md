---
name: plan-issues
description: This skill should be used after a `plan.md` exists in an active work unit, when the user asks to "create the issues", "open the GitHub issues from the plan", "materialize issues", or runs `/plan-issues`. Parses `plan.md`, creates the milestone, and opens one GitHub issue per `**Issue N — <title>**` heading. Default is dry-run; pass `--apply` to actually create.
user-invocable: true
---

# plan-issues — project the plan onto GitHub

You are running the **PLAN-ISSUES** step of the roborun workflow. Your job is to
turn the durable `plan.md` (produced by the headless `plan` step) into a GitHub
**milestone + one issue per planned issue**, so that subsequent `/next` work
units can be traced 1:1 to a closed issue.

This step is **host-neutral**: same contract on Claude and Codex. The verb is
`gh`. The agent (you) parses the markdown and shells `gh`.

## Arguments

Parse these from the user's invocation (any order):

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `--repo <owner/name>` | yes | — | Target GitHub repo |
| `--plan <path>` | no | active work unit's `plan.md` | Plan file to parse |
| `--milestone <title>` | no | the milestone heading in `plan.md` | Override the milestone title |
| `--apply` | no | false (dry-run) | Actually create. Without it, only print what would happen |
| `--branch <name>` | no | none | If set, ensure the branch exists locally before opening issues (so `gh issue develop` is wired). Optional. |

If `--plan` is omitted, locate the active work unit:
1. Look at the user's current working directory and walk up to a `.workspace/work/` dir.
2. Inside it, the active unit is the most recently modified subdirectory that contains a `plan.md`.
3. If ambiguous, **ask** the user which work unit, and offer the candidates.

If `--repo` is omitted, **stop and ask**. Never guess the repo.

## What "Issue N" looks like in plan.md

The roborun convention (see `align`'s sibling `plan` step) produces headings of
the form:

```
### Milestone: `<version> — <title>`

**Issue 1 — <issue title>**

<one or more paragraphs of body — files, tests, acceptance>

**Issue 2 — <issue title>**

<body>
```

Parsing rules:

- The **milestone** is the first `### Milestone: \`X — Y\`` line. The full
  backticked string (`X — Y`) is the milestone title.
- An **issue heading** matches `^\*\*Issue\s+(\d+)\s+—\s+(.+?)\*\*\s*$` —
  capture the number and the title. (Both em-dash and ASCII `--` accepted.)
- An issue's **body** is every line after its heading up to (but not
  including) the next `**Issue N —`, the next top-level heading `## `, or EOF.
  Trim leading/trailing blank lines.

If `plan.md` does not match this shape, **abort and tell the user** which line
failed and what was expected. Do not invent issues.

## Dry-run (default)

Print a structured preview, then stop. Format:

```
plan-issues — DRY RUN
  plan:      <path>
  repo:      <owner/name>
  milestone: <title>           (will create if missing)
  branch:    <name or "none">

  Issue 1 — <title>            (<N> lines of body)
  Issue 2 — <title>            (<N> lines of body)
  ...

Re-run with --apply to create.
```

Do NOT touch GitHub on a dry-run. Not even `gh api`. Pure local parsing.

## --apply

In order, with no interactive prompts:

### 1. Verify gh auth

```bash
gh auth status --hostname github.com >/dev/null 2>&1 \
  || { echo "gh not authenticated for github.com — run \`gh auth login\` first" >&2; exit 1; }
```

### 2. Create or look up the milestone

```bash
# look up by title (gh has no direct subcommand; use the API)
milestone_number=$(gh api "repos/<owner>/<repo>/milestones?state=open" \
  --jq ".[] | select(.title == \"<title>\") | .number")

if [ -z "$milestone_number" ]; then
  milestone_number=$(gh api -X POST "repos/<owner>/<repo>/milestones" \
    -f title="<title>" \
    --jq .number)
  echo "created milestone #$milestone_number: <title>"
else
  echo "found existing milestone #$milestone_number: <title>"
fi
```

Substitute `<owner>`, `<repo>`, `<title>` from the parsed args.

### 3. Create one issue per parsed block, in order

For each `Issue N — <title>` with its body:

```bash
issue_url=$(gh issue create \
  --repo <owner>/<repo> \
  --milestone <title> \
  --title "<title>" \
  --body "<body>")
echo "created: $issue_url"
```

Use `gh issue create --milestone <title>` (gh accepts the title; the API call
above only existed to create the milestone if missing).

**Codex hosts: use shell `gh` only, never the GitHub MCP connector.** When
the `plugins."github@openai-curated"` connector is enabled, Codex prefers
`codex_apps/github.create_issue` over shell `gh issue create`. The connector
tool is gated by per-tool `approval_mode` (`auto|prompt|approve`), which
headless `codex exec` cannot satisfy — the call comes back as
*"user cancelled MCP tool call"* and the issue is silently NOT created.
Shell `gh issue create` has no such gate. Same applies to milestone
creation (`gh api ... /milestones -X POST` rather than any connector tool).
Surfaced in 2026-06-20 dogfood; same root cause as backlog #7 for
`/next-issue`.

The body must include a "**Plan reference**" footer pointing at the source plan
so the connection is traceable:

```markdown
<body>

---

**Plan reference**: `<plan-path>` — Issue <N> in milestone `<title>`.
```

### 4. (Optional) branch wiring

If `--branch <name>` was given:

```bash
git rev-parse --verify "<name>" >/dev/null 2>&1 \
  || git switch -c "<name>" >/dev/null
```

Do NOT push the branch — that's `/next`'s job, not this step's.

### 5. Print summary

```
plan-issues — APPLIED
  milestone:  #<n> <title>
  issues:     #<a>, #<b>, #<c>, ...
  branch:     <name or "none">
  next:       /next  (pick the first open issue and start)
```

## Idempotency

Re-running `--apply` on the same plan against the same repo should:

- Re-use the existing milestone (matched by title).
- **Detect already-created issues** by matching the parsed `<title>` against
  open issues in the milestone via:
  ```bash
  gh issue list --repo <owner>/<repo> --milestone "<title>" --state open --json title,number,url
  ```
  Skip any whose title exactly matches one already open and print
  `skipped: #<n> <title> (already exists)`.

This makes it safe to re-run after a partial failure mid-flight.

## Failure modes — fail loud

- `plan.md` not found → print the search path, ask the user to pass `--plan`.
- Milestone heading missing → quote the first 5 lines of `plan.md`, abort.
- No `**Issue N —`` headings found → list what `**` lines DID match, abort.
- `gh` returns non-zero on issue create → abort the loop, report which issue
  number failed and why. Re-run picks up where it stopped (idempotency).

## Output to the user

At the end, write a one-line entry to the active hourly transition file at
`.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`:

```markdown
## HH:MM - plan-issues materialized
- repo: <owner>/<repo>
- milestone: <title> (#<n>)
- issues: #<a>, #<b>, ...
- branch: <name or none>
```

Then tell the user: issues are open, milestone is wired, `/next` is the next
verb. If frictions surfaced (parse ambiguity, naming clash, anything
hand-massaged), log them as a one-line entry in roborun's backlog.
