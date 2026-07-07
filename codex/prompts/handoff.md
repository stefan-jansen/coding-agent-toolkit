# /handoff (Codex prompt)

Install to `~/.codex/prompts/handoff.md` so it's invocable as `/handoff` in
Codex. This is the Codex binding of the HANDOFF step — same
contract as the Claude `handoff` skill (`skills/handoff/SKILL.md`).

---

Run the HANDOFF step. Freeze the current session's state into a single
Markdown file under `.workspace/transitions/YYYY-MM-DD/HHMMSS.md` so any
future session on either host can resume cold via `/continue`.
Host-neutral: same contract on Claude and Codex.

## Arguments

Parse from the user's invocation (any order):

- `--out <path>` — defaults to
  `.workspace/transitions/$(date -u +%Y-%m-%d)/$(date -u +%H%M%S).md`.
- `--why <reason>` — defaults to "session boundary"; surfaces in TL;DR.
- `--title <text>` — defaults to inferred from recent commits/tasks.
- `--dry-run` — print to stdout instead of writing.

**Always write under `.workspace/transitions/`** — the shared path is
load-bearing for cross-host continuation (backlog #8). Never
`.codex/transitions/` or `.claude/transitions/`.

## File structure (mandatory)

The file MUST have these sections, in this order:

1. `# Handoff: YYYY-MM-DD HH:MM UTC — <one-line summary>`
2. `## ⚡ TL;DR` — 2-4 sentences. What shipped, what's queued, why ending.
3. `## Working directory for the next session` — absolute path + a
   ```bash block of READ-ONLY verification commands with EXPECTED
   VALUES in inline comments. Drift detection depends on the comments.
4. `## Current state (cold-read map)` — what shipped, verbs/state
   table, open backlog/frictions.
5. `## Suggested next steps` — 3-5 items ordered by LEVERAGE, with
   scope estimates. The first should be what you'd start with cold.
6. `## Important context for the next agent` — 3-5 numbered gotchas,
   decisions, or invariants the cold-reader cannot see from code.
7. `## Files touched this session` — every file, grouped by repo +
   commit. Uncommitted goes under a separate group.
8. `## Continuation` — fenced block with exact `continue from <rel
   path>` text the user can copy-paste.

## Verification snapshot rules (load-bearing)

The cold-start commands MUST:
- be READ-ONLY (`git log`, `gh issue list`, `ls`, etc.) — never `git
  pull`, `gh pr merge`, or any state mutation.
- include EXPECTED VALUES as inline comments (e.g.
  `# most recent: 56403a0`). Without these, `/continue` cannot detect
  drift.
- start with `cd <abs path>` so the next agent lands in the right cwd.
- cover the load-bearing artifacts: branch tips, open PRs/issues,
  milestone state, key file presence.
- **verify durable artifacts only** — commit SHAs, milestone states,
  branch tips, PR numbers, skill/prompt inventories, file existence in
  canonical locations. Do NOT list session-relative files that the
  transition-rotation hook creates (e.g. `HH.md`, `HHMMSS.md` under
  today's date dir); they churn by design and produce benign false
  drift on the first `/continue` replay if the next session lands in
  a new hour. Cite transition files by content in "Important context"
  instead, never as a `ls` target.
- **include a mandatory staleness floor** — durable artifacts say what
  the work *is*; these four say whether the ground moved, so every
  snapshot MUST carry them, not leave them to judgment:

  ```bash
  git branch --show-current                  # expect: <branch>
  git status --porcelain                     # expect: <empty | known-dirty paths>
  gh issue list --milestone '<M>' --state open --json number,title  # expect: #<n> <title>, …
  git rev-parse --short HEAD                  # expect: <sha>  (last test: `<cmd>` green at this sha)
  ```

  branch + uncommitted tree are re-checked live; open issue anchors
  what's in flight; last test is RECORDED not re-run (tests aren't
  read-only) — pin the command, result, and valid-for `<sha>` onto the
  HEAD line so `/continue` flags a re-run once HEAD has moved. If one
  doesn't apply (non-git deliverable, no test surface), say so in the
  comment rather than dropping the line.

Example:

```bash
cd ~/agents/coding/coding-agent-toolkit
git log --oneline -3                                    # newest: <sha>
ls skills/                                              # expect: align continue handoff next-issue plan-issues ship
cd ~/agents/coding/roborun-dogfood-backtest
gh issue list --milestone '0.2.0 — Short-side dividend modeling' --state all --json number,state | jq
```

## Codex-specific reminder

**Use shell tools only** (`git`, `gh`, file writes via your normal
edit path). Do NOT call `codex_apps` / GitHub connector tools for any
state lookups in the verification snapshot — the snapshot must be
something a `claude -p` or `codex exec` run with no connector access
can execute. `/handoff` is a documentation step; it does not push,
merge, or open PRs.

## Populating the sections

You are the agent — produce the content from session memory + repo
state. The skill enforces structure and discipline, not content.

**TL;DR**: not a session summary; a 5-second briefing for the next
agent. Use the user's phrasing: "shipped X", "Y queued", "blocked on
W".

**Suggested next steps**: leverage-ordered. Include scope estimates
("~30 min", "~1 day") so the next agent can pick something that fits.

**Important context**: only things the cold-reader cannot derive from
code in one query. Decisions made, dead-ends avoided, invariants held
in your head. Limit 3-5 — more belongs in the README backlog or a
memory file, not the transition.

**Files touched**: file-level granularity (not line-level), grouped
by repo + commit. Uncommitted under a separate group.

## What NOT to include

- Implementation details already in commit messages (reference,
  don't duplicate).
- Long-form retrospectives. Lessons go elsewhere.
- Anything derivable in one `gh issue list` / `git log` — the
  verification snapshot covers that.
- Speculation about what the next agent should think. Facts +
  ranked options; let the next agent decide.

## Output

After writing the file, tell the user:

```
Handoff written: <abs path>
Continuation: continue from <path relative to next-session cwd>
```

If `--dry-run`, print the file contents (prefixed by
`# DRY RUN — would write to <path>`) and do not write.

## Idempotency

- `--out` to same path → overwrite.
- Without `--out`, twice within the same minute → second one gets the
  next `HHMMSS`. Intentional.

## Failure modes — fail loud

- `.workspace/transitions/` missing → create the dated subdir + write.
- Working tree has unrelated uncommitted changes → list under
  "Uncommitted (orphan)" in Files touched; do NOT commit them.
- `--out` outside `.workspace/transitions/` → warn but proceed; add
  a footer noting the non-canonical location.

## After writing

The session continues. `/handoff` does NOT itself end the session,
clear context, or write any other side-effect file.
