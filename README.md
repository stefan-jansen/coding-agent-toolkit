# roborun

> **WIP, private.** Cross-agent workflow toolkit for coding agents. Pairs with
> [roborev](https://github.com/stefan-jansen/roborev) (review agent) — roborun
> is the **runner**: align → plan → GitHub projection → execute → ship → handoff,
> across Claude Code and OpenAI Codex without losing context when you switch.

## What this is (and is not)

This is the workflow layer that turns a vague request into shipped code on a
real GitHub project, regardless of which coding agent is driving. It is
designed around **session continuity** as the core value — long-running work
that survives `/clear`, an agent crash, or a host swap, because the durable
state lives in `.workspace/` files that both Claude and Codex read natively.

It is **not** another agent framework, not a wrapper around `claude` / `codex`,
and not opinionated about which model you use. The actor remains the agent;
roborun provides the verbs.

## Verbs

| Verb | What it does | Cross-agent |
|---|---|---|
| `align` | Forceful spec interrogation — one question at a time until `spec.md` is verifiable | Claude skill + Codex prompt, same shared output |
| `plan` | Decompose spec into milestones + issues. In-session: native plan mode + capture hook. Headless: `claude -p --permission-mode plan` / `codex exec --sandbox read-only --output-schema` | Both host primitives empirically probed (see below) |
| `plan-issues` | Translate `plan.md` → GitHub issues + milestone via `gh` | Host-neutral (shells `gh`) |
| `next` | Pick next open issue, branch, implement, PR | Either host can drive |
| `ship` | Close milestone, final review, merge | Either host can drive |
| `handoff` | Write durable transition note for the next session | Either host can drive |
| `continue` | Resume from latest transition; validate verification commands | Either host can drive |

## Empirical basis

Plan-mode behavior across Claude and Codex was probed live, not assumed —
see [`docs/planmode-probe.md`](docs/planmode-probe.md) (TODO: copy from relay
repo). Key asymmetry: Claude has fine-grained `PostToolUse:ExitPlanMode`
hooks; Codex has only `notify` on `agent-turn-complete`. roborun bakes the
asymmetry into per-host bindings rather than pretending parity.

## Relationship to existing work

- **roborev** — sibling. Reviews code; roborun runs work. Cross-link in both READMEs.
- **relay** (0.4.0, frozen) — the design probe that taught roborun what works.
  Relay's `plan` CLI is the headless / out-of-session entry point. roborun's
  daily-driver path is **in-session via skills** (no `claude -p` subprocess
  context loss). Relay stays on PyPI as the experimental artifact.
- **coding-agent-plugins** marketplace — distribution channel for the Claude
  bindings of roborun's verbs. roborun is the canonical source; the marketplace
  plugins (`workflow`, `transition`) are the downstream Claude-side surface.
  Codex bindings ship as prompts under `.codex/prompts/`.

## Status

- [x] Step 0: port `align` skill → workflow plugin (Claude) + `~/.codex/prompts/` (Codex)
- [x] Step 1: dogfood `/align` on synthetic spec — created
      `stefan-jansen/roborun-dogfood-backtest`, wrote `spec.md` for dividend
      modeling (synthesized rather than interrogated — see backlog #1).
- [x] Step 2: dogfood native plan mode → `plan.md`. Bugs surfaced (#2, #3),
      both shipped fixes in same session.
- [ ] Step 3: build `/plan-issues` skill, run it on the dogfood plan
- [ ] Step 4: execute issue by issue (host swap + session boundary planned)
- [ ] Step 5: ship + handoff → first refinement round

## Roborun backlog (from dogfood frictions)

1. **`/align` input contract is wrong.** Cold "game of 20 questions" is
   impractical; the realistic input shape is a brief/document/RFC. Revise
   `SKILL.md` to accept `/align @brief.md` and fall through to interrogation
   only when invoked without one.
2. **Capture-plan hook payload-shape compatibility** (FIXED 2026-06-15,
   plugins commit `b017d27`). Hook now reads `tool_response.filePath` when
   `.plan` is empty; accepts `ROBORUN_WORK_UNIT` override; debug-mode
   payload logging is the v0 [API-drift detector](docs/api-drift-detection.md).
3. **Stale plugin paths in project settings** (FIXED 2026-06-15, factory
   commit `dbeac71`, intelligence commit `7c69dad`). One audit sweep found
   four stale `~/agents/plugins/` references across three files; all moved
   to `~/agents/coding/plugins/`. Worth re-running the audit periodically.
4. **`/plan-issues` skill does not exist yet.** Needs to read `plan.md`,
   parse milestone + issue headings, dry-run `gh issue create` per item.
   Up next.
5. **Cross-platform self-test** — once Codex sessions are reachable from
   this workflow, verify that the parallel handoff/continue/plan-issues
   prompts behave equivalently. Track payload shape on both sides.

## License

MIT (see `LICENSE`).
