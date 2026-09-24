# /plan-issues (Codex prompt)

Install to `~/.codex/prompts/plan-issues.md` so it's invocable as `/plan-issues`
in Codex. This is the Codex binding of the PLAN-ISSUES step — same
contract as the Claude `plan-issues` skill
(`skills/plan-issues/SKILL.md`); both shell `gh` and converge on the
same set of created GitHub issues + milestone.

---

Run the PLAN-ISSUES step. Parse a `plan.md` produced by the headless `plan`
step and project it onto GitHub as a milestone + one issue per `**Issue N —`
heading. Host-neutral: the verb is `gh`.

## Arguments

Parse from the user's invocation (any order):

- `--repo <owner/name>` — the work unit's repo. Resolve it, do not ask:
  `gh repo view --json nameWithOwner --jq .nameWithOwner` run inside the work
  unit. Arguments arrive as free text in practice (there is no flag channel), so
  a REQUIRED arg is a guaranteed stall. Ask only if that cannot answer, or if the
  plan spans several repos.
- `--plan <path>` — defaults to the active work unit's `plan.md`. Walk up from
  cwd to find the most-recently-modified subdirectory of `.workspace/work/`
  containing a `plan.md`. If ambiguous, ask. If NO plan exists and the invocation
  carried content, author one there in the documented shape and flag it as a
  transcription of the conversation rather than an approved artifact.
- `--milestone <title>` — defaults to the milestone heading parsed from `plan.md`.
- `--apply` — without it, dry-run (print preview, touch nothing).
- `--branch <name>` — optional. If given, create the branch locally.

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

**Use shell `gh` only — never the GitHub MCP connector.** When the
`plugins."github@openai-curated"` connector is enabled, you will prefer
`codex_apps/github.create_issue` over shell `gh issue create`. That tool is
gated by per-tool `approval_mode`, which headless `codex exec` cannot
satisfy — the call comes back as *"user cancelled MCP tool call"* and the
issue is silently NOT created. Shell `gh issue create` and `gh api ...
/milestones -X POST` have no such gate. Same rule for milestone creation,
issue body edits, and any other write operation in this skill.

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
  next:       /next-issue
```

Append a one-liner to
`.workspace/transitions/$(date +%Y-%m-%d)/$(date +%H).md`, after
`mkdir -p` of that date directory (it only exists if something already wrote
there today, so the append otherwise fails at the first hour of a new day):

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
