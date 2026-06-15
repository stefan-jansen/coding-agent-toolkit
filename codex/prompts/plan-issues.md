# /plan-issues (Codex prompt)

Install to `~/.codex/prompts/plan-issues.md` so it's invocable as `/plan-issues`
in Codex. This is the Codex binding of the roborun PLAN-ISSUES step — same
contract as the Claude `plan-issues` skill
(`roborun/skills/plan-issues/SKILL.md`); both shell `gh` and converge on the
same set of created GitHub issues + milestone.

---

Run the PLAN-ISSUES step. Parse a `plan.md` produced by the headless `plan`
step and project it onto GitHub as a milestone + one issue per `**Issue N —`
heading. Host-neutral: the verb is `gh`.

## Arguments

Parse from the user's invocation (any order):

- `--repo <owner/name>` — REQUIRED. Target repo.
- `--plan <path>` — defaults to the active work unit's `plan.md`. Walk up from
  cwd to find the most-recently-modified subdirectory of `.workspace/work/`
  containing a `plan.md`. If ambiguous, ask.
- `--milestone <title>` — defaults to the milestone heading parsed from `plan.md`.
- `--apply` — without it, dry-run (print preview, touch nothing).
- `--branch <name>` — optional. If given, create the branch locally.

If `--repo` is missing, STOP and ask. Never guess.

## Parse plan.md

- Milestone: first `### Milestone: \`X — Y\`` line. Backticked content is the title.
- Issues: every `**Issue N — <title>**` heading.
- Body: lines after each issue heading until the next `**Issue`, next `## `, or EOF.

If the shape doesn't match, abort and quote which line failed.

## Dry-run (default)

Print:

```
plan-issues — DRY RUN
  plan:      <path>
  repo:      <owner/name>
  milestone: <title>           (will create if missing)
  branch:    <name or "none">

  Issue 1 — <title>            (<N> body lines)
  Issue 2 — <title>            (<N> body lines)
  ...

Re-run with --apply to create.
```

Touch nothing — no `gh api` calls.

## --apply

1. `gh auth status --hostname github.com` — abort if not authenticated.
2. Look up the milestone by title via `gh api repos/<owner>/<repo>/milestones?state=open --jq '.[] | select(.title == "<title>") | .number'`. If empty, `gh api -X POST repos/<owner>/<repo>/milestones -f title="<title>"`. Print whether created or re-used.
3. For each issue block, in order:
   ```
   gh issue create --repo <owner>/<repo> --milestone "<title>" \
     --title "<title>" --body "<body + plan-reference footer>"
   ```
   Footer to append to the body:
   ```markdown

   ---

   **Plan reference**: `<plan-path>` — Issue <N> in milestone `<title>`.
   ```
4. Idempotency: before creating, `gh issue list --repo <owner>/<repo>
   --milestone "<title>" --state open --json title,number,url` and skip any
   issue whose title exactly matches one already open. Print
   `skipped: #<n> <title> (already exists)`.
5. Optional branch: if `--branch <name>` given, `git rev-parse --verify <name>
   || git switch -c <name>`. Do not push.

## Print summary

```
plan-issues — APPLIED
  milestone:  #<n> <title>
  issues:     #<a>, #<b>, #<c>, ...
  branch:     <name or "none">
  next:       /next
```

Append a one-liner to `.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`:

```markdown
## HH:MM - plan-issues materialized
- repo: <owner>/<repo>
- milestone: <title> (#<n>)
- issues: #<a>, #<b>, ...
- branch: <name or none>
```

## Failure modes

Fail loud. Print what was expected vs. what was found; never silently invent
content.
