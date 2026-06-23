# Lessons from relay (2026-05-28 → 2026-06-12)

> What the relay experiment taught roborun. Relay shipped four releases
> (`relay-workflow` 0.1.0 → 0.4.0) over two weeks as a host-neutral
> cross-agent workflow CLI. It was deliberately frozen and the GitHub
> repos taken down — the load-bearing findings are recorded here so
> the iteration isn't lost.

## What relay was

A Python CLI that tried to orchestrate Claude Code and OpenAI Codex from
the outside: `relay plan` → `relay project` → **`relay implement`** →
`relay ship`. Local files in `.workspace/work/<unit>/` as the source of
truth; GitHub (epic / milestones / issues) as the projection. The
implementation verb spawned `claude -p` or `codex exec` subprocesses and
fed them prompts and tool outputs.

## The three load-bearing lessons

### 1. Subprocess-driven implementation doesn't survive iteration

**What we tried.** `relay implement` invoked `claude -p` (Claude Code in
headless mode) or `codex exec` once per issue, fed in the spec and the
prior turn's output, and looped until the issue closed.

**Why it didn't work.** `claude -p` and `codex exec` start a fresh
conversation each time. There is no carry-over of context, no model
short-term memory, no ability to "pick up where we left off" inside one
issue. Every subprocess re-derives the project state from scratch. The
overhead dominated the actual work — and recovery from a single failed
turn was strictly worse than just doing the work in a foreground session.

**What roborun does instead.** Implementation runs in the foreground
Claude or Codex session as a skill (`next-issue`). The agent that wrote
the spec is the agent that implements it; durable state lives in
`.workspace/`, which both hosts read natively. No subprocess. Relay 0.4.0
admitted this explicitly by deleting `relay implement` in a breaking
release — kept `plan` / `project` / `ship` because those are bounded
one-shots where headless is fine, removed the only verb that needed
conversational context to survive subprocess boundaries.

### 2. The cross-host primitive is shared durable storage, not an orchestrator

**What we tried.** Build "the thing that drives Claude or Codex,"
where the CLI is the orchestrator and the hosts are interchangeable
backends.

**Why it didn't work.** Both Claude and Codex already read project files
natively. Wrapping a subprocess just to pass file paths through is
moving bits the LLM can already see. The wrapper added latency, lost
context, and forced every workflow change through a Python release.

**What roborun does instead.** The cross-host primitive is the
`.workspace/` directory itself. Any session on either host can read it,
write to it, and `/continue` from a transition file another host wrote.
The verbs are skills (Claude) and mirrored prompts (Codex). There is no
"execute as the other host" verb — the file is the swap.

### 3. Host asymmetries are real and shouldn't be papered over

**What we tried.** Pretend the two hosts had parity at every step so the
CLI could call them the same way.

**Why it didn't work.** Claude has fine-grained `PostToolUse:ExitPlanMode`
hooks; Codex has only `notify` on `agent-turn-complete`. Claude's
`claude -p --output-format json` returns plan content reliably (2.1+);
Codex's `--sandbox read-only --output-schema` gives a cleaner JSON shape
and `-o <FILE>` is deterministic. Treating them as interchangeable made
the relay docs and demos misleading.

**What roborun does instead.** Per-host bindings, empirically probed
([`planmode-probe.md`](planmode-probe.md)). Same verb contract, two
implementations, the asymmetry surfaced in the README's "host
recommendation matrix" rather than hidden. A Claude session uses
`PostToolUse:ExitPlanMode` + the workflow plugin's `capture-plan.sh`;
a Codex session uses `--sandbox read-only --output-schema`. The verb is
the same; the binding is honest.

## What survived

- **The `.workspace/` convention** — `memory/`, `transitions/`, `work/`.
  Roborun uses the same layout because both hosts already read it.
- **GitHub-as-projection** — `align` → `plan` → `plan-issues` (epic /
  milestone / issues) → `next-issue` → `ship`. Roborun's verb names came
  from relay's pipeline shape.
- **`docs/planmode-probe.md`** — the empirical findings on host
  asymmetries are still the canonical reference and now live in this
  repo.
- **`Closes #N` as the bubble-up signal** — PR body keyword closes issue
  on merge, milestone closes when all its issues close. Both relay and
  roborun rely on this; it's the lightest-weight way to make GitHub the
  state machine.

## What did not survive

- `relay implement` (deleted in 0.4.0; replaced by in-session
  `/next-issue` skill).
- The `relay-workflow` PyPI package (4 releases, ~zero installs outside
  the author).
- The `relay compile` / `relay sync` skill-bridge — relay vendored
  `skill-compiler` because "same shape, two hosts" applies to skills
  too. Roborun keeps Claude skills (`skills/`) and Codex prompts
  (`codex/prompts/`) side-by-side as separate artifacts; a runtime
  compiler is the wrong altitude when the source-of-truth pair is small
  and edited together.
- The standalone CLI as the entry point. Roborun's daily-driver path is
  in-session skills; headless invocation is `claude -p` / `codex exec`
  against the same skills, not a wrapper.

## TL;DR for next time

If you find yourself building "the thing that orchestrates an agent from
the outside," ask first whether the agent could just read the files
directly. In 2026 it almost always can — and the subprocess wrapper
becomes a context-loss tax with no offsetting benefit.
