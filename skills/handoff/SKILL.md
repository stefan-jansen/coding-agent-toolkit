---
name: handoff
description: This skill should be used when the user asks to "write a handoff", "produce a transition", "record where we are for the next session", "write a digest before /clear", or runs `/handoff`. Writes a durable transition file at `.workspace/transitions/YYYY-MM-DD/HHMMSS.md` that any future session on either host (Claude or Codex) can pick up cold via `/continue`. Host-neutral.
user-invocable: true
---

# handoff — write a cold-startable transition file

You are running the **HANDOFF** step of the roborun workflow. Your job is to
freeze the current session's state into a single Markdown file that lives in
the shared `.workspace/transitions/` tree so any future session on either
host can resume without re-deriving context.

This step is **host-neutral**: same contract on Claude and Codex. The shared
`.workspace/` directory is the host-swap primitive (see roborun backlog #8) —
there is no "execute as the other host" verb because the durable state is
what makes the swap work, not orchestration.

## When to use

- Approaching context limit (Claude: ~80%+; Codex: when reasoning quality
  starts to degrade).
- Switching hosts mid-feature (Claude → Codex or vice versa).
- End of day / wrapping a session before a break.
- After a milestone ships, before starting the next one.
- Before any operation that may lose state (`/clear`, `/compact`, host
  restart).

## Arguments

Parse these from the user's invocation (any order):

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `--out <path>` | no | `.workspace/transitions/$(date -u +%Y-%m-%d)/$(date -u +%H%M%S).md` | Where to write |
| `--why <reason>` | no | "session boundary" | Short label appearing in TL;DR |
| `--title <text>` | no | inferred from recent commits and tasks | H1 title |
| `--dry-run` | no | false (write) | Print the file to stdout instead of writing |

**Always write under `.workspace/transitions/`** — never under `.claude/` or
`.codex/`. The shared path is load-bearing for cross-host continuation.

## File structure (mandatory)

The file MUST have these sections, in this order. The structure is what
`/continue` reads — deviating breaks the contract.

```markdown
# Handoff: YYYY-MM-DD HH:MM UTC — <one-line summary>

## ⚡ TL;DR

<2-4 sentences. What was shipped this session. What is queued. Why the
session is ending now (`--why`).>

## Working directory for the next session

<absolute path that is the right cwd to resume from>

Verification snapshot (cold-start commands the next agent can paste):

```bash
<verifiable command 1>
<verifiable command 2>
…
```

The commands MUST be safe to run blindly (read-only) and MUST produce
output the next agent can compare against the expected values listed
inline (as comments) so drift is detectable. Example:

```bash
cd ~/agents/coding/roborun
git log --oneline -3                       # most recent: <sha>
ls skills/                                 # expect: align next-issue plan-issues ship handoff continue
```

## Current state (cold-read map)

<Subsections for each artifact line:>

### What shipped this session
- <repo> <sha> — <one-line per file/commit>

### Roborun verbs status (or "Active project state" for non-roborun
work)
| Verb | Status | Notes |
|---|---|---|
| ... | ... | ... |

### Open backlog items / known frictions
1. <num>. <one-line>. <link to README backlog if applicable>

## Suggested next steps (pick one, ordered by leverage)

1. <action>. <2 sentences of why this has the most leverage right
   now>. <expected scope, e.g. "~30 min" or "~1 day">.
2. <action>. <why>. <scope>.
3. <action>. <why>. <scope>.

Order matters: leverage first. The next agent should be able to pick #1
and act without re-deriving the ranking.

## Important context for the next agent

<3-5 numbered points. Things the cold-reader CANNOT see from the code
alone:>
1. **<short title>.** <one-paragraph explanation of the gotcha,
   decision, anti-pattern, or invariant that is not obvious from the
   code.>
2. **<title>.** <explanation>
…

## Files touched this session

```
<repo>/                                                  (commit <sha>)
  <relative path>                                        # what changed
  <relative path>                                        # what changed
```

List EVERY file written this session, grouped by repo + commit (or
"uncommitted" for working-tree changes that did not land in a commit).
This is the audit trail.

## Continuation

```
continue from <relative path to this file>
```

Use the path the user would type. If the file is at
`.workspace/transitions/2026-06-16/234043.md`, write exactly:

```
continue from .workspace/transitions/2026-06-16/234043.md
```
```

## How to populate the sections

You are the agent — produce the content from what you remember and from
the repo state at the time of writing. The skill's job is to enforce
the structure and the discipline of writing every section, not to
inspect your memory for you.

### TL;DR

Two to four sentences. NOT a summary of the entire session — a summary
of what the next session needs to know in five seconds. Use the same
phrasing the user would: "shipped X", "Y is queued", "Z is blocked on
W".

### Working directory + verification snapshot

Walk the agent through cold-start in 30 seconds. The cwd must be the
one that makes the verification commands work. The commands must be
read-only (no `git checkout`, no `gh pr merge`); they must produce
output the next agent can compare to expected values in comments. If
multiple repos are in play, list cd-then-verify for each.

The expected values inline are what makes drift detectable. Without
them, the snapshot is just "run some commands" — useless.

### Current state map

Mix of structured (tables) and prose. Tables for things with
predictable shape (verbs status, backlog items, open PRs). Prose for
the rest. Always include enough specifics (sha, PR number, milestone
title) that the next agent can grep and find the same things.

### Suggested next steps

Order by leverage, not chronology. The first item should be the one
you'd start with if you woke up cold. Include scope estimates so the
next agent can pick something that fits the time available.

### Important context

The cold-reader CANNOT see decisions made in this session, dead-ends
hit and avoided, or invariants held in your head. List the ones a
fresh agent would otherwise re-derive (badly). Limit to 3-5 points —
more than that is a sign the digest is doing too much. Anything
larger belongs in `~/agents/coding/roborun/README.md` or a memory
file, not a transition.

### Files touched

Every file. Grouped by repo + commit. Include uncommitted changes
under a separate "uncommitted" group. Note: if there are many small
edits in one file, ONE entry is fine — granularity is at the file
level, not the line level.

### Continuation marker

Always relative to the cwd you wrote in "Working directory for the
next session". This is what the user copy-pastes; it must work
verbatim.

## What NOT to include

- Implementation details that are already in the commit messages
  (the digest references them, doesn't re-derive them).
- Long-form retrospectives ("we should have done X earlier").
  Backlog goes in the README; lessons go in `lessons_learned.md`.
- Anything the next agent would derive in one `gh issue list` /
  `git log` invocation. The verification snapshot covers that;
  don't duplicate.
- Speculation about what the next agent should think. State facts
  and ranked options; let the next agent decide.

## Output

After writing the file, tell the user:

```
Handoff written: <path>
Continuation: continue from <path-from-cwd>
```

If `--dry-run`, print the file content to stdout (with a leading
`# DRY RUN — would write to <path>` comment) and do not touch the
filesystem.

## Idempotency

- Re-running with the same `--out` path → overwrite (assume the user
  wants the latest version).
- Re-running without `--out` and within the same minute → a new file
  with the next `HHMMSS`. This is intentional — handoffs are not
  unique per session; the timestamp suffix de-dupes.

## Failure modes — fail loud

- `.workspace/transitions/` does not exist → create the dated
  subdirectory and proceed (the transitions tree is project state, not
  a precondition).
- Working tree has unrelated uncommitted changes → list them under a
  "Uncommitted (orphan)" sub-bullet in "Files touched" so the next
  agent sees them; do NOT discard or commit them.
- User passes `--out` to a path outside `.workspace/transitions/` →
  warn but proceed (occasionally useful for project-specific
  handoffs); add a footer noting the non-canonical location.

## After the file is written

The session is NOT over from the skill's perspective. The user may
continue working, or `/clear`, or hand off. The skill's only output
is the file + the continuation hint. Do not write the session-end
transition file as a side-effect of `/handoff` (the user is already
asking for one, that would be circular).
