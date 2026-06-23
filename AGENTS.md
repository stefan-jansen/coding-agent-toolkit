# coding-agent-toolkit

Contributor / maintainer notes. For the project introduction, see
[`README.md`](README.md).

## Purpose

Provide a small set of host-neutral workflow steps — `align`, `plan`,
`plan-issues`, `next-issue`, `ship`, `handoff`, `continue` — that drive
a feature from a vague request to a merged PR on GitHub, identically
on Claude Code and OpenAI Codex. The actor is the agent; this
repository supplies the step definitions and the file-shaped contract
they share.

## Cross-host primitive

The contract that makes the toolkit host-neutral is **shared durable
state under `.workspace/`**, read natively by both Claude Code and
Codex. There is no orchestrator. Either host runs a step; the step
writes files; the other host picks the state up by reading the same
files.

| Path | Role |
|---|---|
| `AGENTS.md` (this file) | Canonical project instructions. Codex reads natively; Claude includes via `CLAUDE.md`. |
| `CLAUDE.md` | One line — `@AGENTS.md`. |
| `.workspace/memory/` | Persistent project memory; load on demand. |
| `.workspace/transitions/YYYY-MM-DD/HHMMSS.md` | `/handoff` output; `/continue` resumes from any of these on either host. |
| `.workspace/work/` | Active work units (specs, plans, follow-ups). |

Keep this contract tight. Never seed `.claude/transitions/` or
`.codex/state/` for new work; never invent a `run-as-other-host`
shortcut.

## Step chain

```
align         →  spec.md             (interrogation, or @brief.md seed)
plan          →  plan.md             (host-native plan mode, in-session
                                      or headless)
plan-issues   →  GitHub milestone + issues  (dry-run default; --apply)
next-issue    →  branch + impl + tests + PR  (lowest-numbered open
                                              issue in active milestone)
ship          →  squash-merge, close milestone  (verifies closing-footer
                                                 coverage)
handoff       →  .workspace/transitions/YYYY-MM-DD/HHMMSS.md
continue      →  read latest transition, verify, surface next steps
                 (no auto-execute)
```

Six steps live on disk under `skills/<step>/`. `plan` deliberately
delegates to each host's native plan mode plus a capture hook — that
is the right primitive, and re-implementing it as a shell command
loses the structured plan-mode output.

## Three surfaces, one source

| Surface | Location | Contents |
|---|---|---|
| Canonical | `skills/<step>/SKILL.md` here | Source of truth. |
| Claude plugin mirror | `workflow/skills/<step>/SKILL.md` in the [claude\_code\_plugins](https://github.com/stefan-jansen/coding-agent-plugins) marketplace | Byte-identical mirror; how Claude users install. |
| Codex prompt | `codex/prompts/<step>.md` here | Codex-shape mirror; `codex exec` invokes by name. |

When you edit a step, edit all three. Verify byte-identity between
canonical and the plugin mirror (`diff -q`). The Codex prompt may
shape the same contract differently in the markdown body, but its YAML
frontmatter must stay strictly parseable — Codex uses strict YAML and
will silently skip an invalid prompt.

## Hard constraints

1. **Host-neutral state.** Durable state lives in `.workspace/`. Never
   seed `.claude/transitions/` or `.codex/state/` for new work.
2. **Statelessness.** Each step invocation starts fresh. All carry-over
   is files on disk.
3. **Self-containment.** Step logic lives inline in the SKILL or prompt.
   No external script sourcing.
4. **Idempotency.** Steps are safe to re-run. `/continue` re-verifies
   on each call; `/ship` is a no-op when already shipped.
5. **MCP optional.** Steps use `gh`, `git`, and the filesystem. No MCP
   is required for a step to do its job.
6. **Verify durable artifacts only.** `/handoff` verification snapshots
   list commit SHAs, milestone states, branch tips, skill / prompt
   inventories — never session-relative rotating files (e.g. `HH.md`).

## Session progress tracking

Write hourly progress under `.workspace/transitions/YYYY-MM-DD/HH.md`
(the project hook auto-creates the file). Append every 15–20 minutes
or at milestones. Run `/handoff` at end-of-session or when approaching
a context-budget cliff to produce the durable `HHMMSS.md` snapshot that
`/continue` resumes from.

## References (read on demand)

- [`README.md`](README.md) — project introduction.
- [`docs/planmode-probe.md`](docs/planmode-probe.md) — host plan-mode
  empirical findings.
- [`docs/api-drift-detection.md`](docs/api-drift-detection.md) —
  design note on what is deliberately not built yet.
- [`docs/relay-lessons.md`](docs/relay-lessons.md) — what the
  predecessor experiment taught.
- `.workspace/memory/` — persistent project memory (indexed below).
- `.workspace/work/` — active work units.

@.workspace/memory/MEMORY_INDEX.md
