# Plan-mode probe: Claude vs Codex (empirical)

**Date**: 2026-05-27
**Method**: on-disk inspection of `~/.claude/` and `~/.codex/` + vendored Codex docs
(`.codex/docs/config/advanced.md`). Behavioral auto-run claim noted as observed, not
re-probed live.

## Headline

The two hosts are **fundamentally asymmetric** in how plans are stored and what can
be hooked. The "harden the capture hook" approach is **Claude-only**. Codex has no
equivalent interception point — it needs the skill/prompt-driven path, with an
optional `notify` backstop.

## Side-by-side

| | Claude Code | Codex |
|---|---|---|
| **Plan artifact** | File: `~/.claude/plans/<random-slug>.md` (confirmed; e.g. `bright-sniffing-canyon.md`; has `archive/`) | **No file.** Plan is an `update_plan` tool call embedded in the session transcript |
| **Plan content shape** | Free-form markdown plan | `{"plan":[{"step":"…","status":"pending\|in_progress\|completed"}]}` — flat TODO list, no milestone/issue hierarchy |
| **Mode + gate** | Discrete plan mode; `EnterPlanMode`/`ExitPlanMode` tools; approval gate. On approve → typically bypass-permissions + **auto-run to completion** (the flow we must interrupt) | `update_plan` is just a live TODO list — **no approval gate**. Separately, **goal mode** = a budget-bounded autonomous objective |
| **Hook surface** | `PreToolUse`/`PostToolUse` on any tool incl. `ExitPlanMode` — **fine-grained** (our capture hook already uses this) | **`notify` on `agent-turn-complete` only** — the sole supported event. No PreToolUse/PostToolUse, no plan-specific hook |
| **Persistent objective state** | none persistent | `goals_1.sqlite` → `thread_goals(thread_id, objective, status∈{active,paused,blocked,usage_limited,budget_limited,complete}, token_budget, tokens_used, …)` |
| **Session transcript** | (Claude internal) | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`, records `{timestamp,type,payload}` |

## Implications for the hybrid design

**Claude — confirmed viable.** PostToolUse-on-`ExitPlanMode` fires exactly at the
plan→execute transition. That IS the interception point to (a) copy the plan into
`.workspace/work/<unit>/`, and (b) divert from auto-run to issue/PR-driven execution.
Keep + harden the existing hook.

**Codex — the hook approach does not exist.** Options:
1. **Skill/prompt-driven (primary).** A Codex prompt (`~/.codex/prompts/` or project
   `.codex/prompts/`) instructs the agent to write `spec.md`/`plan.md` into the work
   unit *as a step*. Likely MORE reliable on Codex than Claude because Codex has no
   forced bypass-and-run gate to fight.
2. **`notify` backstop.** `notify = ["python3", ".../relay-notify.py"]` fires on
   `agent-turn-complete`; the script tails the latest session `*.jsonl`, extracts the
   most recent `update_plan` arguments, and writes/updates the work-unit plan.
   Deterministic-ish but **coarse** (every turn → must dedupe/idempotent) and only
   recovers the flat TODO list, not the spec.

**Asymmetry is structural, not incidental** — bake it into the compiler/bindings:
- Claude binding: native plan mode + ExitPlanMode hook.
- Codex binding: prompt step writes the work unit (+ optional notify extractor).
- Both converge on the same `.workspace/work/<unit>/` files and the same `gh`-driven
  GitHub projection — that shared target is what makes it "one workflow, two bindings."

## Bonus finding — reuse for the "stick to the work unit" problem

Codex's `thread_goals` SQLite (objective + status + budget, surviving across turns)
is a working model for the persistence reminder we flagged as unsolved. Mirror it:
a small `.workspace/work/ACTIVE_WORK` + objective that the per-turn context injection
(transition/attention-state hook on Claude; `notify`/prompt on Codex) re-asserts:
"on unit X — do not leave unless instructed." Goal mode already proves the pattern
host-side; we replicate it host-neutrally in `.workspace/`.

## LIVE TRIAL (2026-05-27, ClaudeTester / `claude -p` v2.1.152)

Sandbox `/tmp/relay-plantrial` wired with the capture hook; ran
`claude -p "<plan task>" --permission-mode plan --setting-sources user,project,local
--output-format stream-json --verbose`. Isolation runs to attribute each result.

| Question | Answer |
|---|---|
| Does `-p --permission-mode plan` produce a plan? | **Yes.** `ExitPlanMode` is emitted. |
| Does it auto-run after the plan (headless)? | **No.** `ExitPlanMode` is the **last** tool before `result` — terminal. No human to approve ⇒ nothing executes. |
| Do PostToolUse hooks run in `-p`? | **Yes** — but only with `--setting-sources …` (project settings are NOT auto-loaded in `-p`). Confirmed via a `Bash` matcher firing. |
| Does the **ExitPlanMode** PostToolUse hook fire in `-p`? | **NO** — even though `ExitPlanMode` was called and other PostToolUse hooks fire. The capture-hook design is **interactive-only**. |
| Is the plan file written in `-p`? | **Yes** — `~/.claude/plans/plan-<prompt-slug>-<word>.md` appears. So headless capture = **read the newest plan file**, not the hook. |

### Verdicts that change the design

1. **Two capture paths, by mode:**
   - *Interactive* (human session): the `ExitPlanMode` PostToolUse hook is the
     interception window — fires on approval, before the auto-run. Use the hook.
     (Auto-run only exists interactively; not re-probed live here.)
   - *Headless/programmatic* (CI, agent-driven): the hook does **not** fire; instead
     run `claude -p --permission-mode plan` and **read the newest `~/.claude/plans/`
     file**. Clean and scriptable.
2. **`claude -p --permission-mode plan` IS a "plan-but-don't-build" primitive.**
   ExitPlanMode is terminal — nothing executes. This answers the open Codex-parity
   question *for Claude*: a Relay `plan` step can shell out to it, capture the plan
   file, structure it, and create GitHub issues — **without fighting the interactive
   approve→auto-run flow at all.** Strong candidate for the actual implementation.
3. **`-p` does not auto-load project settings** — any Relay tooling that shells out
   must pass `--setting-sources` (or `--settings`) explicitly.

### Bearing on the old terminal-steering work (WU 012)

The trial obsoletes the tmux/xdotool/screencast approach: driving an interactive TUI
in another terminal with keystroke-timing (WU 012 `tmux-claude-controller.md`, the
video demos — the "major waste of time") is unnecessary. `claude -p` + `--output-format
stream-json` gives deterministic, structured, scriptable control as a subprocess. Use
`-p` for Relay automation/testing; reserve terminal injection (tmux/CMUX) only for
recording genuine interactive demos — do not revive it as workflow infrastructure.

## CODEX plan-only — CONFIRMED (2026-05-27, codex-cli 0.134.0)

Parity is **confirmed, not assumed**. `codex exec` is the non-interactive entry; the
plan-but-don't-build primitive is:

```
codex exec --sandbox read-only -o <plan.txt> [--output-schema <schema.json>] "<prompt>"
```

Smoke test (`/tmp/relay-plantrial`, read-only, "do not write files"): produced the
plan, wrote it to the `-o` file, **left the repo untouched** (exit 0, ~10.5k tokens).

**Codex is actually better-suited than Claude for structured plan capture:**

| | Claude | Codex |
|---|---|---|
| No-write guarantee | `--permission-mode plan` (ExitPlanMode terminal) | `--sandbox read-only` (`read-only\|workspace-write\|danger-full-access`) |
| Where the plan lands | `~/.claude/plans/<random-slug>.md` — must hunt newest | **`-o/--output-last-message <FILE>`** — named file, deterministic |
| Force structured output | none (free-form md) | **`--output-schema <FILE>`** — enforce milestone/issue JSON |
| Event stream | `--output-format stream-json` | `--json` (JSONL) |
| No session persistence | (n/a) | `--ephemeral` |
| Settings load | needs `--setting-sources` | loads `~/.codex/config.toml` unless `--ignore-user-config` |

**Implication for the `plan` step**: Codex can emit the decomposition **directly as
schema-constrained JSON** → feed straight to `gh`. Claude path produces free-form md →
needs a structuring pass. Both converge on `.workspace/work/<unit>/plan.{md,json}`.
Bonus: `codex exec review` is a built-in non-interactive code review (relevant to the
future cross-model review step).

## Still open (needs INTERACTIVE trial — `-p` cannot exercise it)

- Confirm Claude's post-approval auto-run behavior **with our hook firing mid-flow** —
  does the PostToolUse hook reliably land before execution proceeds? (ClaudeTester.)
- Does Codex goal mode expose its objective to a `notify` script, or only via SQLite?
- Whether a Codex prompt can reliably halt before execution the way Claude plan mode's
  gate does (i.e., is there a Codex "plan-but-don't-build" stance we can prompt).
