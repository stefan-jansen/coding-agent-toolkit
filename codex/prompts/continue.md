# /continue (Codex prompt)

Install to `~/.codex/prompts/continue.md` so it's invocable as `/continue`
in Codex. This is the Codex binding of the roborun CONTINUE step — same
contract as the Claude `continue` skill (`roborun/skills/continue/SKILL.md`).

---

Run the CONTINUE step. Read a transition file written by `/handoff` (or a
freeform digest of the same shape), run its verification snapshot, report
any drift against expected values, and surface the suggested next steps
WITHOUT auto-executing one. Host-neutral.

`/continue` is **read + verify + present**. Do NOT silently start the
first suggested step — the verification + present gate exists so the user
(or you, with explicit reasoning) picks one after seeing drift.

## Arguments

Parse from the user's invocation (any order):

- `--from <path>` — defaults to the most recently modified file under
  `.workspace/transitions/`.
- `--verify` — default true; run the verification snapshot.
- `--no-verify` — skip verification; only read + present.
- `--cwd <path>` — override the cwd named in the file.

If the user pastes `continue from <path>` as the prompt itself, treat
`<path>` as `--from`. That phrase is what `/handoff` writes as its
Continuation footer — recognizing it is part of the contract.

## Resolve `--from`

Omitted:
1. Walk `.workspace/transitions/` newest-dated subdir first.
2. Pick newest `.md` file.
3. Tie → alphabetically last (highest `HHMMSS`).
4. Empty tree → abort with a `/handoff` suggestion or ask for
   `--from`.

Non-existent path → abort, list the most recent transition files as
candidates.

## Read the file

A `/handoff`-shaped file has 8 mandatory sections (see the
`/handoff` prompt for the list). If a section is missing, the file
is freeform or pre-skill — read what's there and proceed; do not
require strict conformance. Structure is the goal, not the gate.

## Verification snapshot

The "Working directory for the next session" section contains a
```bash block of READ-ONLY commands with expected values in inline
comments. Job:

1. `cd` to the named working directory (or `--cwd` override).
2. Run each command in order.
3. Compare output to inline-comment expectation.
4. Flag every divergence clearly:
   - exit code != 0 → "command failed: <cmd>"
   - output != expected → "drift: <cmd>: expected `<x>`, got `<y>`"
   - expected missing from output → "missing: <expected>"
   - extra entries → "extra: <items>"

Drift is INFORMATION, not failure. Surface it; let the user judge if
it matters. A repo advanced by one commit since the handoff is
normal; a milestone that was open and is now closed may be important.

**Use shell tools only** — `git`, `gh`, `ls`, `cat`, etc. Do NOT call
`codex_apps` / GitHub connector tools; the snapshot is designed to be
runnable in any sandboxed `codex exec` / `claude -p` invocation.

If a snapshot command does anything destructive (`git pull`, `gh pr
merge`, etc.), REFUSE to run it. Flag it as a bug in the handoff that
produced this file, not in `/continue`.

`--no-verify` skips the snapshot entirely.

## Present

Write a short structured response:

```markdown
**Resuming from:** <path>
**TL;DR:** <first sentence of the file's TL;DR>
**Working directory:** <cwd>

**Verification:**
- ✓ <cmd>: matched (<actual>)
- ⚠ <cmd>: drift (expected `<x>`, got `<y>`)
- ✗ <cmd>: failed (<error>)

**Suggested next steps:**
1. <first step headline>
2. <second>
3. <third>

**Important context highlights:**
- <1-2 most load-bearing points from the file; reference the file for the rest>

What do you want to pick up?
```

The user (or you, with explicit reasoning) picks a step. Then exit
`/continue` and start that work via the appropriate verb
(`/next-issue`, `/ship`, `/plan-issues`, etc.) or freeform action.

If the user's actual ask doesn't match any listed step, that's fine
— the digest is a starting point, not a contract. Note the deviation
in the NEXT `/handoff` so the trail stays honest, then proceed.

## Dry-run

`--dry-run` → print the verification commands + parsed sections; do
not run any commands.

## Idempotency

Re-running with same `--from` → re-verify and re-present. Useful when
checking drift after time has passed.

## Failure modes — fail loud

- `--from` does not exist → list recent candidates, abort.
- Working directory in file does not exist → abort, suggest checking
  whether the repo moved.
- Destructive snapshot command → refuse, flag as bug.
- Non-canonical location (not under `.workspace/transitions/`) →
  warn that resumption from outside the canonical path is fragile,
  then proceed.

## Output to the transition tree

`/continue` does NOT write to `.workspace/transitions/`. The session
that's resuming will produce its own handoff when it ends. Writing
one at `/continue` time would be premature.

## After presenting

Wait for the user (or your own explicit decision) to pick a
suggested step. There is no implicit "continue with step #1" — the
explicit pick is the contract.
