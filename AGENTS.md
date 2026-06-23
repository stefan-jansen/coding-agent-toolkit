# coding-agent-toolkit

## Purpose

Provide the workflow layer (`align` → `plan` → `plan-issues` → `next-issue` →
`ship` → `handoff` → `continue`) that turns a vague request into shipped code
on a real GitHub project, host-neutral across Claude Code and OpenAI Codex.
The actor is the agent; the toolkit supplies the verbs.

See `README.md` for current status, verb table, empirical basis, and roadmap.
See `.workspace/memory/history.md` for the internal build log and the
closed-friction backlog (project memory, not reader-facing).

## Cross-host primitive

The single contract that makes the toolkit host-neutral: **shared durable
state under `.workspace/`**, read natively by both Claude and Codex.

| Path | Role |
|---|---|
| `AGENTS.md` (this file) | Canonical project instructions. Codex reads natively; Claude includes via `CLAUDE.md`. |
| `CLAUDE.md` | One line — `@AGENTS.md`. |
| `.workspace/memory/` | Persistent project memory (load on demand). |
| `.workspace/transitions/YYYY-MM-DD/HHMMSS.md` | `/handoff` output; `/continue` resumes from any of these on either host. |
| `.workspace/work/` | Active work units (specs, plans, follow-ups). |

There is no `execute-as-host` verb. Either host calls a verb directly; the
verb writes durable state; the other host picks up by reading the same
files. That's the contract — keep it tight.

## Verb chain

```
align    →  spec.md             (forceful interrogation OR @brief.md seed)
plan     →  plan.md             (in-session plan mode + capture hook,
                                 OR `claude -p --permission-mode plan`,
                                 OR `codex exec --sandbox read-only --output-schema`)
plan-issues  →  GitHub milestone + issues  (dry-run default; --apply to create)
next-issue   →  branch, implement, test, PR  (lowest-numbered open issue in active milestone)
ship         →  squash-merge, close milestone  (verifies closing-footer coverage)
handoff      →  .workspace/transitions/YYYY-MM-DD/HHMMSS.md
continue     →  read latest transition, verify, surface next steps (no auto-execute)
```

Six verbs are skills on disk under `skills/<verb>/`. `plan` delegates to
each host's native plan mode + a capture hook because that's the right
primitive, not a shell command.

## Distribution

Three surfaces, all driven from this repository as the canonical source:

| Surface | Where | Contents |
|---|---|---|
| Canonical | `skills/<verb>/SKILL.md` here | Source of truth. |
| Claude plugins port | `~/agents/coding/plugins/workflow/skills/<verb>/SKILL.md` | Byte-identical mirror; OSS marketplace distribution. |
| Codex prompts | `codex/prompts/<verb>.md` here | Codex-shape mirror; `codex exec` calls them by name. |

When you edit a verb, **edit all three** and verify byte-identity for the
canonical ↔ plugin port (`diff -q`). The Codex prompt may shape the same
contract differently in markdown body, but YAML frontmatter must stay
strictly parseable (Codex uses strict YAML).

## Hard constraints

1. **Host-neutral state.** Durable state lives in `.workspace/`. Never seed
   `.claude/transitions/` or `.codex/state/` for new work.
2. **Statelessness.** Each verb invocation starts fresh. All carry-over is
   files.
3. **Self-containment.** Verb logic lives inline in the SKILL/prompt. No
   external script sourcing.
4. **Idempotency.** Safe to re-run. `/continue` re-verifies on each call;
   `/ship` is a no-op when already shipped.
5. **MCP optional.** Verbs use `gh` + `git` + filesystem. No MCP required.
6. **Verify durable artifacts only.** `/handoff` verification snapshots
   list commit SHAs, milestone states, branch tips, skill/prompt
   inventories — never session-relative rotating files (e.g. `HH.md`).

## Session progress tracking

Write hourly progress under `.workspace/transitions/YYYY-MM-DD/HH.md`
(the project hook auto-creates the file). Append every 15-20 min or at
milestones. Use `/handoff` at end-of-session or context-budget cliffs to
produce the durable `HHMMSS.md` snapshot that `/continue` resumes from.

## References (read on-demand)

- `README.md` — status, verb table, roadmap.
- `.workspace/memory/history.md` — chronological build log + closed-friction backlog (internal).
- `docs/planmode-probe.md` — host plan-mode empirical findings.
- `.workspace/work/` — open work units.

@.workspace/memory/MEMORY_INDEX.md
