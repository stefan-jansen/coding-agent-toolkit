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
- [x] Step 3: built `/plan-issues` skill, ran on dogfood plan — milestone
      `0.1.0 — Dividend modeling` + 4 issues materialized.
- [x] Step 4a: Issues #1 & #2 implemented on Claude (data model + cash
      credit), 13 tests green, PR #5 open. Handoff to Codex for #3.
- [x] Step 4b: Codex implemented #3 (reinvest mode, commit `a58eafe`,
      17 tests). Driven headlessly from Claude via `codex exec`; the
      handoff digest at `094709.md` was sufficient cold-start context,
      no clarifying questions raised. Claude then took #4 (docs +
      LIMITATIONS).
- [x] Step 5: shipped. PR #5 squash-merged as `55ad3bc` to
      `roborun-dogfood-backtest/main`; all 4 issues auto-closed by the
      merge; milestone `0.1.0 — Dividend modeling` complete. First
      refinement round = the new backlog items below (#7–#9).

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
4. **`/plan-issues` skill** (SHIPPED 2026-06-15, roborun commit `943d705`,
   plugins commit `65824a0`). Reads `plan.md`, parses `### Milestone:` +
   `**Issue N —**` blocks, dry-run by default, `--apply` creates
   milestone + issues; idempotent by title match.
5. **Cross-platform self-test** — once Codex sessions are reachable from
   this workflow, verify that the parallel handoff/continue/plan-issues
   prompts behave equivalently. Track payload shape on both sides.
6. **`Closes #N` only fires on merge to default branch.** Surfaced during
   Step 4a: commits on `dogfood/dividend-modeling` carrying `Closes #1`
   and `Closes #2` did NOT close the issues at push time. GitHub fires
   keyword closing only on merge to the repo's default branch. Implication
   for the outer-objective acceptance ("every implementation step traces
   to a closed GH issue"): closure happens at PR merge, not at step
   completion. `/plan-issues` SKILL.md and a future `/next-issue` skill
   should say this explicitly. Consider: should `/next-issue` add the
   closing footer to the commit (current convention) OR also link the
   issue to the PR so GitHub shows the closes-on-merge relationship in
   the UI? `gh issue develop` does this; `gh pr create` doesn't auto-link
   beyond keyword.
7. **Codex headless push blocked by GitHub connector approval gate**
   (FIXED 2026-06-15 — surfaced Step 4b).
   *Root cause* (verified in the Step 4b JSON log): when
   `plugins."github@openai-curated"` is enabled in `~/.codex/config.toml`,
   Codex prefers the OpenAI **`codex_apps` MCP server**
   (`github_create_blob`, `github_create_pull_request`, …) over shell
   `git push` for remote writes. Those connector tools are gated by
   per-tool `approval_mode` (`auto|prompt|approve`), which is
   independent of `approval_policy`. Headless `codex exec` cannot
   satisfy "approve", so the call comes back as
   *"user cancelled MCP tool call"*. Shell `git push` is never
   attempted unless the agent is told to.
   *What didn't work*:
   - `-c 'plugins."github@openai-curated".enabled=false'` — silently
     ignored; connector stays active.
   - `-c '...approval_mode="never"'` — schema rejects (only
     `auto|prompt|approve` are valid).
   - `-c '...approval_mode="auto"'` on individual tools — still cancels
     (the gate isn't only at the named-tool level).
   *What works*: tell Codex in the prompt to use shell `git`/`gh` only
   and to avoid `codex_apps` connector tools. Verified live: with the
   instruction, Codex shells `git --version` etc. without trying the
   connector. The `/next-issue` Codex prompt now carries this
   instruction; orchestrator prompts driving `codex exec` should
   include the same paragraph.
   *Open follow-up*: there is no config-only way to disable the
   connector for one invocation. If we end up driving Codex from a
   harness, the connector-avoidance instruction must be in every
   invocation's prompt.
8. **Shared `.workspace/` is what makes host-swap work — no
   `--execute-as <host>` verb needed.** The session originally framed
   the gap as "no verb to launch the other host." That's the wrong
   level of abstraction. The actual primitive that makes a host swap
   reproducible is **shared durable storage**: `.workspace/work/*`,
   `.workspace/transitions/*`, `spec.md`, `plan.md`, the handoff digest
   — both Claude and Codex read these natively. As long as a session
   on either host can call `/continue` and find the same state, the
   "swap" is a no-op of agent identity. So roborun should:
   - **keep** the `handoff` + `continue` verbs as the cross-host
     contract, and harden them around `.workspace/` paths;
   - **not** add an `execute-as` verb — the active host (whichever
     CLI the user is in) is always the right driver;
   - **document** in `handoff` that any host can pick up, and add a
     short note about `codex exec` / `claude -p` as an *optional*
     headless invocation, not as a workflow primitive.
9. **"Fail-loud means fail-atomic" should be in the handoff/skill
   template.** During the Step 4b host-swap probe, Codex independently
   wrote a two-pass `apply_dividends` (validate all `due` events
   first, then mutate cash + ledger) so a missing-price ValueError
   leaves the backtest untouched. Claude's version mutated state then
   raised mid-loop, leaving a half-applied state. The spec didn't
   require atomicity but it's clearly the better contract under
   fail-loud. Worth a one-liner in `align`'s contract-writing guidance
   and in `next-issue`'s implementation guidance: when an error path
   raises, no prior step in the same logical operation should be
   half-applied.

## License

MIT (see `LICENSE`).
