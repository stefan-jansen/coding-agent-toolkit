---
name: continue
description: This skill should be used when the user says "continue from <transition-file>", asks to "resume from the last handoff", "pick up where we left off", or runs `/continue`. Reads a transition file written by `/handoff`, runs its verification snapshot, reports drift, and surfaces the suggested next steps WITHOUT auto-executing. Host-neutral.
user-invocable: true
---

# continue — resume from a transition file

You are running the **CONTINUE** step of the roborun workflow. Your job is
to take a transition file produced by `/handoff` (or a freeform digest of
the same shape) and bring the current session up to the state described
there: confirm the working directory, run the verification snapshot, flag
any drift against expected values, and present the suggested next steps so
the user (or you) can pick one.

This step is **host-neutral**: same contract on Claude and Codex. The
shared `.workspace/transitions/` tree is the cross-host primitive — any
session on either host can resume any transition file.

`/continue` is **read + verify + present**. It does NOT auto-execute a
suggested next step — picking one is the user's call (or yours, after
presenting the options).

## Arguments

Parse these from the user's invocation (any order):

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `--from <path>` | no | most recently modified file under `.workspace/transitions/` | Transition file to resume |
| `--verify` | no | true | Run the verification snapshot and report drift |
| `--no-verify` | no | false | Skip verification; only read + present |
| `--cwd <path>` | no | the one named in the file's "Working directory" section | Override the cwd for verification |

If the user pastes `continue from <path>` as the prompt itself, treat
`<path>` as `--from`. This is the canonical "resumption" phrase that
`/handoff`'s output footer produces — recognizing it is part of the
contract.

## Resolving `--from`

If `--from` is omitted:

1. Walk `.workspace/transitions/` (newest dated subdirectory first).
2. Pick the most recently modified `.md` file.
3. If there are multiple files in the same minute, pick the
   alphabetically last (highest `HHMMSS`).
4. If `.workspace/transitions/` is empty or missing → abort with a
   suggestion to run `/handoff` first or to specify `--from`
   explicitly.

If the path doesn't exist → abort with the path the user named, and
suggest `ls .workspace/transitions/$(date -u +%Y-%m-%d)/`.

## Read the file

A `/handoff`-shaped file has these mandatory sections:

- `## ⚡ TL;DR`
- `## Working directory for the next session`
- `## Current state (cold-read map)`
- `## Suggested next steps`
- `## Important context for the next agent`
- `## Files touched this session`
- `## Continuation`

If a section is missing, the file is either freeform or a pre-skill
handoff — read what's there and proceed; do not require strict
conformance. The structure is the goal, not the gate.

## Run the verification snapshot

The "Working directory for the next session" section contains a
fenced ```bash block of read-only commands with expected values in
inline comments (e.g. `# most recent: 56403a0`). Your job is:

1. **`cd` to the named working directory** (or `--cwd` override).
2. **Run each command** in the snapshot in order.
3. **Compare the output to the inline-comment expectation**.
4. **Flag every divergence** clearly:
   - exit code != 0 → "command failed: <cmd>"
   - output != expected → "drift: <cmd>: expected `<expected>`, got `<actual>`"
   - expected value missing from output → "missing: <expected>"
   - extra entries in a list expectation → "extra: <items>"

Drift is INFORMATION, not a failure. Surface it; let the user decide
if it matters. A repo that has advanced by one commit since the
handoff is normal and benign; a milestone that was open and is now
closed may be important.

If `--no-verify` is passed, skip this step entirely and go straight to
"Present".

## Present the state to the user

Once verification is done, write a short structured response:

```markdown
**Resuming from:** <path>
**TL;DR:** <copy the TL;DR section's first sentence>
**Working directory:** <cwd>

**Verification:**
- ✓ <cmd>: matched (<actual>)
- ⚠ <cmd>: drift (expected `<x>`, got `<y>`)
- ✗ <cmd>: failed (<error>)

**Suggested next steps:**
1. <copy the first suggested step's headline>
2. <second>
3. <third>

**Important context highlights:**
- <copy 1-2 most load-bearing context points; reference the file for the rest>

What do you want to pick up?
```

The user then names one of the steps (or types a different
instruction), and you proceed from there. Do NOT silently start the
first suggested step — the verification gate exists to give the user
a chance to redirect if drift changed the picture.

## When NO suggested step matches the current intent

If the user's actual ask doesn't match any of the listed next steps,
that's fine — the digest is a starting point, not a contract. Note
the deviation in the next handoff (so the trail stays honest) and
proceed with what the user asked for.

## Dry-run

If `--dry-run` is passed, print the verification commands and the
parsed sections but do not actually run any commands. Useful when the
user wants to know what `/continue` would do without touching state.

## Idempotency

- Re-running with the same `--from` path → re-verify and re-present.
  Useful when the user wants a fresh look at drift after some time
  has passed.
- The verification commands MUST be read-only (this is enforced by
  `/handoff`'s contract). If a snapshot command does anything
  destructive, that is a bug in the handoff, not in `/continue` —
  surface it as a friction.

## Failure modes — fail loud

- `--from` path does not exist → list the most recent transition
  files as candidates, abort.
- Working directory in the file does not exist → abort, suggest the
  user check whether the repo was moved or deleted.
- Verification command in the snapshot is not actually read-only
  (e.g. `git pull`, `gh pr merge`) → refuse to run it; flag it as a
  bug in the handoff that produced this file.
- The file is not in `.workspace/transitions/` and not a freeform
  digest the user passed deliberately → warn that resumption from a
  non-canonical location is fragile, then proceed.

## After presenting

Wait for the user (or for your own judgement, if running headlessly)
to pick a suggested step or name a different one. Then exit the
`/continue` flow and start that work using the appropriate verb
(`/next-issue`, `/ship`, `/plan-issues`, etc.) or freeform action.

There is no implicit "continue with step #1" — the explicit pick is
the contract.

## Output to the transition file

`/continue` does NOT write to `.workspace/transitions/` itself. The
session that's resuming will produce its own handoff when it ends.
Writing one at `/continue` time would be premature.

## Failure modes (recap, fail loud)

Fail loud: missing file, missing cwd, destructive snapshot, ambiguous
`--from`. Do not auto-resolve drift; do not auto-pick a next step;
do not assume the user wants to skip verification.
