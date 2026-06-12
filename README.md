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

- [ ] Step 0: port `align` skill from relay → workflow plugin (Claude binding)
- [ ] Step 0: port `align.codex.md` → codex prompts (Codex binding)
- [ ] Step 1: dogfood `/align` on roborun itself → `spec.md`
- [ ] Step 2: dogfood native plan mode → `plan.md` (auto-captured)
- [ ] Step 3: build `/plan-issues` while running it on our own plan
- [ ] Step 4: execute issue by issue
- [ ] Step 5: ship + handoff → first refinement round

## License

MIT (see `LICENSE`).
