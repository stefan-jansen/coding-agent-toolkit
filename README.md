# roborun

> **WIP, private.** Cross-agent workflow toolkit for coding agents. Pairs with
> [roborev](https://github.com/kenn-io/roborev) (review agent) — roborun
> is the **runner**: align → plan → GitHub projection → execute → ship → handoff,
> across Claude Code and OpenAI Codex without losing context when you switch.

## Status

**Feature-complete · 7 verbs · dual-host (Claude + Codex) · open-weight probe pending**

All seven verbs (`align`, `plan`, `plan-issues`, `next-issue`, `ship`,
`handoff`, `continue`) are live-validated on both Claude Code and OpenAI
Codex (the latter driven via `codex exec`). Three dogfood milestones
shipped end-to-end on
[`stefan-jansen/roborun-dogfood-backtest`](https://github.com/stefan-jansen/roborun-dogfood-backtest)
(0.1.0 dividend modeling, 0.2.0 short-side debit, 0.3.0 borrow-rate
model). Chronological build history and the closed-frictions backlog
are in [`docs/HISTORY.md`](docs/HISTORY.md).

## What this is (and is not)

The workflow layer that turns a vague request into shipped code on a real
GitHub project, regardless of which coding agent is driving. Designed
around **session continuity** as the core value — long-running work that
survives `/clear`, an agent crash, or a host swap, because the durable
state lives in `.workspace/` files that both Claude and Codex read
natively.

It is **not** another agent framework, not a wrapper around `claude` /
`codex`, and not opinionated about which model you use. The actor remains
the agent; roborun provides the verbs.

## Verbs

| Verb | What it does | Cross-host |
|---|---|---|
| `align` | Forceful spec interrogation — one question at a time until `spec.md` is verifiable. `/align @brief.md` seeds from a brief, falls back to interrogation for under-specified sections. | Claude skill + Codex prompt, shared output |
| `plan` | Decompose spec into milestones + issues. In-session: native plan mode + capture-plan hook. Headless: `claude -p --permission-mode plan` / `codex exec --sandbox read-only --output-schema` | Both host primitives empirically probed |
| `plan-issues` | Translate `plan.md` → GitHub milestone + issues via `gh` (dry-run default; `--apply` to create) | Host-neutral (shells `gh`) |
| `next-issue` | Pick lowest-numbered open issue in active milestone, branch, implement, test, PR | Either host can drive |
| `ship` | Verify closing-footer coverage, mark PR ready, squash-merge with branch delete, close milestone | Either host can drive |
| `handoff` | Write durable transition note + verification snapshot under `.workspace/transitions/YYYY-MM-DD/HHMMSS.md` | Either host can drive |
| `continue` | Read latest transition, run its verification snapshot, report drift, surface next steps (no auto-execute) | Either host can drive |

Six are skills on disk (`skills/<verb>/`); `plan` delegates to each host's
native plan mode + a capture hook because that's the right primitive.

## Empirical basis

Host behaviour was probed live, not assumed. Key asymmetry: Claude has
fine-grained `PostToolUse:ExitPlanMode` hooks; Codex has only `notify` on
`agent-turn-complete`. roborun bakes the asymmetry into per-host bindings
rather than pretending parity. Per backlog item #8 in
[`docs/HISTORY.md`](docs/HISTORY.md), the cross-host primitive is **shared
durable storage** (`.workspace/`), *not* an `execute-as-host` verb — both
Claude and Codex read these files natively, so any session on either host
can call `/continue` and find the same state.

## Roadmap

### Short-term (cleanup)

- **Backlog #12** — Codex memory still references deprecated
  `git safe-commit`. One-line fix in `~/.codex/AGENTS.md`.
- **`docs/planmode-probe.md`** — copy from relay repo (currently a TODO
  reference).
- **`/ship` doc note** — `gh api PATCH /repos/{}/{}/pulls/{N}/merge` is
  the permission-safe path on hosts where `gh pr merge --delete-branch`
  is blocked by sandbox policy. Codex discovered this fallback unprompted
  during the 0.3.0 ship; documenting it makes the skill self-contained.

### Medium-term (open-weight probe)

Run an existing verb under [opencode](https://opencode.ai/) configured
for an open-weight model (GLM 5.2 or DeepSeek V4 are the leading
candidates). `/continue` is the lowest-blast-radius first test — read-only,
no GitHub writes, no test runs. Measure whether the verb's instructions
carry through a different harness + a non-frontier model. Three clean
runs → invest in opencode as a first-class roborun target (likely
requires a small compiler step to handle opencode's frontmatter dialect).

*Why this matters:* the gap between frontier and open-weight cost per
successful task is forecast to keep widening through mid-2027 (see the
research summaries at
`~/applied-ai/content-marketing/source/agents/llm-costs/`), and
"unlimited" subscriptions for heavy agent use are quietly ending.
roborun's host-neutral design is the right place to absorb that shift,
and the probe doubles as course material — "same workflow, three
harnesses, model routing as a runtime choice."

### Open backlog items

See [`docs/HISTORY.md`](docs/HISTORY.md) for the full closed-friction
backlog. Currently open:

- #5 — Cross-platform self-test: parallel handoff/continue/plan-issues
  behaviour parity tracking (mostly addressed by the 0.3.0 dogfood,
  remains as a periodic check).
- #6 — `Closes #N` UX: consider linking issues to PRs via `gh issue
  develop` so GitHub shows the closes-on-merge relationship in the UI,
  not just keyword.
- #12 — see Short-term cleanup above.

## Relationship to existing work

- **roborev** — sibling. Reviews code; roborun runs work. Cross-link in
  both READMEs.
- **relay** (0.4.0, frozen) — the design probe that taught roborun what
  works. Relay's `plan` CLI is the headless / out-of-session entry point.
  roborun's daily-driver path is **in-session via skills** (no `claude
  -p` subprocess context loss). Relay stays on PyPI as the experimental
  artifact.
- **coding-agent-plugins** marketplace — distribution channel for the
  Claude bindings of roborun's verbs. roborun is the canonical source;
  the marketplace plugins (`workflow`, `transition`) are the downstream
  Claude-side surface. Codex bindings ship as prompts under
  `.codex/prompts/`.

## Repository layout

```
skills/                # canonical Claude skill source (6 verbs)
  align/   continue/   handoff/
  next-issue/  plan-issues/  ship/
codex/prompts/         # Codex prompt mirror (6 verbs)
docs/                  # HISTORY, planmode-probe (TODO), api-drift-detection
README.md              # this file
LICENSE                # MIT
```

## License

MIT (see [`LICENSE`](LICENSE)).
