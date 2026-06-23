# Build history (internal)

Project memory — not reader-facing. The README carries the current
state; this file is the chronological build log + the closed-friction
backlog for agents working on the toolkit.

The project was renamed from `roborun` → `coding-agent-toolkit` on
2026-06-23; "roborun" below is the prior name, kept for narrative
continuity.

## Build steps

- [x] **Step 0** — Port `align` skill → workflow plugin (Claude) +
      `~/.codex/prompts/` (Codex).
- [x] **Step 1** — Dogfood `/align` on a synthetic spec. Created
      `stefan-jansen/roborun-dogfood-backtest`, wrote `spec.md` for
      dividend modeling (synthesized rather than interrogated — see
      backlog #1).
- [x] **Step 2** — Dogfood native plan mode → `plan.md`. Bugs surfaced
      (#2, #3), both shipped fixes in same session.
- [x] **Step 3** — Built `/plan-issues` skill, ran on dogfood plan —
      milestone `0.1.0 — Dividend modeling` + 4 issues materialized.
- [x] **Step 4a** — Issues #1 & #2 implemented on Claude (data model +
      cash credit), 13 tests green, PR #5 open. Handoff to Codex for #3.
- [x] **Step 4b** — Codex implemented #3 (reinvest mode, commit
      `a58eafe`, 17 tests). Driven headlessly from Claude via `codex
      exec`; the handoff digest at `094709.md` was sufficient cold-start
      context, no clarifying questions raised. Claude then took #4 (docs
      + LIMITATIONS).
- [x] **Step 5** — Shipped. PR #5 squash-merged as `55ad3bc` to
      `roborun-dogfood-backtest/main`; all 4 issues auto-closed by the
      merge; milestone `0.1.0 — Dividend modeling` complete. First
      refinement round = the new backlog items below (#7–#9).
- [x] **Step 6** — `/ship` skill shipped. Canonical at
      `skills/ship/SKILL.md`; Codex prompt at `codex/prompts/ship.md`;
      plugin port at `~/agents/coding/plugins/workflow/skills/ship/`.
      Verifies closing-footer coverage per milestone issue, marks PR
      ready if draft, squash-merges with branch deletion (preserves all
      `Closes #N` footers in the squash body so GitHub auto-closes), and
      closes the milestone explicitly (GitHub doesn't auto-close
      milestones). Closes the verb gap from the 2026-06-15 handoff —
      align → plan → plan-issues → next-issue → ship is now end-to-end
      teachable.
- [x] **Step 7** — `/handoff` + `/continue` skills shipped — the
      cross-host primitives. Canonical at `skills/handoff/SKILL.md` and
      `skills/continue/SKILL.md`; Codex prompts at
      `codex/prompts/{handoff,continue}.md` (symlinked into
      `~/.codex/prompts/`); plugin ports at
      `~/agents/coding/plugins/workflow/skills/{handoff,continue}/`.
      `/handoff` writes a structured digest under
      `.workspace/transitions/YYYY-MM-DD/HHMMSS.md` with a load-bearing
      read-only verification snapshot (commands + expected-value
      comments); `/continue` reads it, runs the snapshot, reports drift,
      and surfaces the suggested next steps without auto-executing. Per
      backlog #8, the cross-host primitive is the shared `.workspace/`
      storage, NOT an `execute-as-host` verb — both Claude and Codex
      sessions can produce and consume these files identically. All 7
      roborun verbs (align, plan, plan-issues, next-issue, ship,
      handoff, continue) now exist as canonical+plugin+Codex bindings.
- [x] **Step 8** — 0.2.0 dogfood shipped on
      `stefan-jansen/roborun-dogfood-backtest` (2026-06-16). PR #8
      squash-merged as `c66af9f`; milestone closed via `gh api PATCH`.
      Codex driver on #6 (short-side debit implementation) live-verified
      backlog #7's connector-avoidance prompt — Codex shelled `git push`
      + `gh pr create` end-to-end without the per-tool approval gate.
      Claude driver on #7 (docs). `/ship` live-verified (backlog #10).
      Surfaced two new backlog items: #11 (`gh pr edit --body` silently
      fails on this repo) and #12 (Codex memory still expects
      `git safe-commit`).
- [x] **Step 9** — 0.3.0 dogfood shipped on
      `stefan-jansen/roborun-dogfood-backtest` (2026-06-21). PR #11
      squash-merged as `de102c5`; milestone #3 closed via `gh api
      PATCH`. End-to-end via `codex exec` for all four
      GitHub-side-effecting verbs in sequence — `/align @brief.md` →
      `/plan-issues --apply` → `/next-issue` ×2 → `/ship`. Two new
      frictions surfaced and fixed inline: `/align` brief-mode hard
      guard (roborun `300163d`) and `/plan-issues` connector-avoidance
      paragraph (roborun `29a9dc4`). Closes the cross-host gap from
      Step 7 — all four GitHub-writing verbs are now live-validated on
      Codex.

## Backlog (closed frictions from dogfood)

1. **`/align` input contract is wrong** (FIXED 2026-06-20, roborun
   commit `cd70e77`, plugins commit `ee62a92`). `/align @brief.md` reads
   the named brief and seeds `spec.md` from it directly; falls through
   to question-by-question interrogation only for sections the brief
   leaves under-specified. Hardened further 2026-06-21 (roborun commit
   `300163d`) with an explicit "MUST NOT implement" guard, after a
   Codex run bypassed the soft guard.
2. **Capture-plan hook payload-shape compatibility** (FIXED 2026-06-15,
   plugins commit `b017d27`). Hook now reads `tool_response.filePath`
   when `.plan` is empty; accepts `ROBORUN_WORK_UNIT` override;
   debug-mode payload logging is the v0
   [API-drift detector](api-drift-detection.md).
3. **Stale plugin paths in project settings** (FIXED 2026-06-15,
   factory commit `dbeac71`, intelligence commit `7c69dad`). One audit
   sweep found four stale `~/agents/plugins/` references across three
   files; all moved to `~/agents/coding/plugins/`. Worth re-running the
   audit periodically.
4. **`/plan-issues` skill** (SHIPPED 2026-06-15, roborun commit
   `943d705`, plugins commit `65824a0`). Reads `plan.md`, parses
   `### Milestone:` + `**Issue N —**` blocks, dry-run by default,
   `--apply` creates milestone + issues; idempotent by title match.
   Hardened 2026-06-21 with a connector-avoidance paragraph (roborun
   commit `29a9dc4`).
7. **Codex headless push blocked by GitHub connector approval gate**
   (FIXED 2026-06-15 — surfaced Step 4b; LIVE-VERIFIED 2026-06-16 on
   `roborun-dogfood-backtest` 0.2.0 #6 driven via `codex exec` — the
   connector-avoidance paragraph in `/next-issue` carried through,
   Codex shelled `git push` + `gh pr create` end-to-end without the
   per-tool approval gate firing).

   *Root cause* (verified in the Step 4b JSON log): when
   `plugins."github@openai-curated"` is enabled in
   `~/.codex/config.toml`, Codex prefers the OpenAI **`codex_apps` MCP
   server** (`github_create_blob`, `github_create_pull_request`, …)
   over shell `git push` for remote writes. Those connector tools are
   gated by per-tool `approval_mode` (`auto|prompt|approve`), which is
   independent of `approval_policy`. Headless `codex exec` cannot
   satisfy "approve", so the call comes back as *"user cancelled MCP
   tool call"*. Shell `git push` is never attempted unless the agent
   is told to.

   *What didn't work*:
   - `-c 'plugins."github@openai-curated".enabled=false'` — silently
     ignored; connector stays active.
   - `-c '...approval_mode="never"'` — schema rejects (only
     `auto|prompt|approve` are valid).
   - `-c '...approval_mode="auto"'` on individual tools — still
     cancels (the gate isn't only at the named-tool level).

   *What works*: tell Codex in the prompt to use shell `git`/`gh` only
   and to avoid `codex_apps` connector tools. Verified live: with the
   instruction, Codex shells `git --version` etc. without trying the
   connector. The `/next-issue`, `/ship`, and `/plan-issues` Codex
   prompts now carry this instruction; orchestrator prompts driving
   `codex exec` should include the same paragraph.

   *Open follow-up*: there is no config-only way to disable the
   connector for one invocation. If we end up driving Codex from a
   harness, the connector-avoidance instruction must be in every
   invocation's prompt.
8. **Shared `.workspace/` is what makes host-swap work — no
   `--execute-as <host>` verb needed.** The session originally framed
   the gap as "no verb to launch the other host." That's the wrong
   level of abstraction. The actual primitive that makes a host swap
   reproducible is **shared durable storage**: `.workspace/work/*`,
   `.workspace/transitions/*`, `spec.md`, `plan.md`, the handoff
   digest — both Claude and Codex read these natively. As long as a
   session on either host can call `/continue` and find the same
   state, the "swap" is a no-op of agent identity. So roborun:
   - **keeps** the `handoff` + `continue` verbs as the cross-host
     contract, hardened around `.workspace/` paths;
   - **does not** add an `execute-as` verb — the active host
     (whichever CLI the user is in) is always the right driver;
   - **documents** in `handoff` that any host can pick up, and adds a
     short note about `codex exec` / `claude -p` as an *optional*
     headless invocation, not as a workflow primitive.
9. **"Fail-loud means fail-atomic" should be in the handoff/skill
   template** (FIXED 2026-06-20, roborun commit `cd70e77`, plugins
   commit `ee62a92`). Atomicity clause now required in `/align`'s
   spec-writing rules: when a spec names an error condition, the
   Acceptance section must include a verifiable check that no prior
   step in the same logical operation is half-applied on error.
   Originally surfaced in the Step 4b host-swap probe — Codex's
   `apply_dividends` two-pass implementation (validate all `due`
   events, then mutate) was atomic; Claude's mutated-then-raised was
   not. Now both versions are required to match the Codex shape by
   the spec, not by accident. (Earlier partial landing in
   `/next-issue` SKILL.md § "Implementation contract" 2026-06-15
   still stands.)
10. **`/ship` live re-verification** (FIXED 2026-06-16 on
    `roborun-dogfood-backtest` 0.2.0). PR #8 squash-merged as
    `c66af9f`; both `Closes #N` footers preserved in the squash body,
    GitHub auto-closed #6 and #7; milestone closed via `gh api PATCH
    .../milestones/2` (as designed — GitHub doesn't auto-close
    milestones). All readiness gates fired correctly (closing-footer
    coverage, mergeable=CLEAN, no-checks-configured skip). Note:
    milestone `closed_issues` counter includes the PR itself; the
    per-issue list is the load-bearing check, not the counter.
11. **`gh pr edit --body[-file]` fails on classic-projects repos**
    (FIXED 2026-06-20, roborun commit `cc0902b`, plugins commit
    `081e7f5`). `/next-issue` now updates the PR body via
    `gh api -X PATCH /repos/{owner}/{repo}/pulls/{N} -f body=...`
    unconditionally, bypassing the GraphQL "Projects (classic) is
    being deprecated" silent-fail. Surfaced during the 0.2.0 dogfood
    ship. `/ship` grepped clean — its squash-merge step doesn't touch
    the PR body, so no change needed there.

## Backlog (open)

See [README § Roadmap](../README.md#roadmap). Currently #5, #6, #12.
