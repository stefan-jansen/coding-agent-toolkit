# Detecting Claude Code / Codex API drift

We integrate with Claude Code and Codex through hook payloads (`PostToolUse`,
`PreToolUse`, `SessionStart`, etc.) and through structured CLI output. Both
surfaces are versioned by the host vendor, evolve without notice, and have
already broken us once (see Bug #2, 2026-06-15 — the `ExitPlanMode`
PostToolUse payload moved plan content from `tool_response.plan` into a file
referenced by `tool_response.filePath`; the capture hook silent-exited for
weeks before we noticed).

This doc records the lightweight, hand-runnable drift detector we built into
the workflow plugin's hooks, and the heavier self-test we owe ourselves
once the toolkit has earned a CI footprint.

## v0 — defensive logging (now)

Every hook accepts an opt-in env flag that snapshots its payload to disk:

```bash
export ROBORUN_DEBUG_HOOKS=1
export ROBORUN_DEBUG_DIR=$HOME/.claude/hooks/debug  # default
```

With the flag set, each hook firing writes the full stdin payload to
`$ROBORUN_DEBUG_DIR/<hookname>-<timestamp>.json`. Hooks that recognize the
payload still do their normal job. Hooks that don't ALSO log a warning
listing the top-level `tool_response` keys actually seen, so you can spot
the shape change immediately.

**Use it**:

1. Set the env vars in your shell before starting a session you intend to
   reason about (`export ROBORUN_DEBUG_HOOKS=1` in `.bashrc` is fine —
   files are small, off by default elsewhere).
2. After a new Claude Code release, run one plan-mode cycle, one handoff,
   one `/continue` — the operations whose hooks we depend on.
3. Diff the resulting payload files against the previous capture:
   `diff <(jq -S . old.json) <(jq -S . new.json)`. Any key add/remove/rename
   means the hook needs an update.

**Why it's enough for now**: zero infrastructure, runs only when you ask
for it, surfaces both silent-fail bugs (Case 4 in
`plugins/workflow/hooks/capture-plan.sh`'s smoke test) and shape changes.
Costs nothing when off.

**What it doesn't do**: catch drift you don't think to look for. The user
has to remember to set the flag and check the files.

## v1 — self-test harness (deferred)

Once the toolkit has CI (currently it doesn't — it's a private WIP repo with no
GH Actions configured), the right shape is a small Python script that:

1. Spawns `claude -p --permission-mode plan --setting-sources ... "<canned prompt>"`
   in a temp dir with the capture hook wired
2. Asserts that `~/.claude/plans/<slug>.md` and the work-unit `plan.md`
   appeared, with the expected shape
3. Repeats for Codex's `codex exec --sandbox read-only --output-schema ...`
4. Runs weekly on cron, opens a toolkit issue on drift

This is gold-plating until the toolkit is on the daily path. File as a
backlog item; revisit after the dogfood is in routine use.

## v2 — host-side hook fixtures (speculative)

If Anthropic or OpenAI ever publish hook-payload reference fixtures
(they don't today, as far as we can tell), we wire the self-test against
those instead of our captured snapshots. Cheaper, more authoritative,
breaks loudly the moment the vendor changes the contract. Track via the
toolkit reference link list.
