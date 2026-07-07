# coding-agent-toolkit

Take a piece of work from rough idea to merged PR — with the same
workflow on Claude Code and OpenAI Codex, and durable state on disk so
either agent picks up where the other left off.

`coding-agent-toolkit` is seven workflow steps — invoked as slash
commands in Claude Code or prompts in Codex — that handle the structure
*around* building the thing: pinning down what "done" means, breaking it
into chunks, projecting the plan onto GitHub for review and version
control, and carrying context across sessions and hosts. The agent does
the work; the toolkit keeps the state.

## What you get

- **A spec-first workflow, projected onto GitHub.**
  `align → plan → plan-issues → next-issue → ship` turns a rough request
  into a milestone, issues, branches, and merged PRs — a trail humans can
  review, not an opaque agent transcript.
- **The same workflow on Claude Code and OpenAI Codex.** Every step ships
  as both a Claude skill and a Codex prompt; shared state under
  `.workspace/` is read natively by both, so you can swap hosts
  mid-feature without re-explaining.
- **Session continuity that doesn't go stale.** `handoff` writes a
  snapshot of read-only checks with expected values; `continue` replays
  it and flags what changed — so work survives context limits, restarts,
  `/clear`, and day boundaries.
- **Not just code.** The same chain drives a research report, a course
  module, or a long-form post. `Closes #N` closes an issue about a
  chapter draft as cleanly as one about a bug fix.
- **Optional code-review surfacing.** If you use
  [roborev](https://github.com/kenn-io/roborev), open reviews on the
  current branch show up when a session starts.

## The seven steps

```
align ──▶ plan ──▶ plan-issues ──▶ next-issue ──▶ ship
spec.md   plan.md   milestone       branch, impl,   squash-merge,
                    + issues        tests, PR       close milestone

handoff / continue — at any session, host, or day boundary
```

| Step | Does |
|---|---|
| `align` | Interrogates the request into `spec.md`, a verifiable end-state — one question at a time, or seeded from a brief and asking only what the brief left open. |
| `plan` | Breaks the spec into issue-sized chunks with dependencies (`plan.md`), using the host's native plan mode. |
| `plan-issues` | Creates a GitHub milestone and one issue per chunk. Dry-run by default; `--apply` to write. |
| `next-issue` | Takes the lowest-numbered open issue in the active milestone → branch, implementation, tests, PR. |
| `ship` | Squash-merges the PR and closes the milestone, after verifying every issue has a closing-footer commit. |
| `handoff` | Writes a transition file: prose summary plus a bash snapshot of read-only checks with inline `# expect:` values. |
| `continue` | Replays a transition's snapshot, flags any drift, and surfaces next steps and open code reviews. Never auto-executes. |

`Closes #N` in PR bodies is the bubble-up signal: a merged PR closes its
issue, and the last issue closing closes the milestone. GitHub is the
state machine; the file each step writes on disk is the contract the next
step (or the next agent) reads instead of re-deriving state.

## Quick start

**Claude Code** — copy or symlink `skills/` into your project's
`.claude/skills/`, or install the `workflow` plugin from the
[coding-agent-plugins](https://github.com/stefan-jansen/coding-agent-plugins)
marketplace, which mirrors these skills.

**OpenAI Codex** — point your prompts directory at `codex/prompts/`, or
copy the files in.

Then invoke the steps in order on a new piece of work —
`/align`, `/plan`, `/plan-issues`, `/next-issue`, `/ship` — and
`/handoff` / `/continue` at the boundaries of long-running work. The
`SKILL.md` in each `skills/<step>/` directory is that step's
authoritative documentation. There is no separate runtime to install.

## Cross-agent state

Swapping between Claude Code and Codex works because there is no
orchestrator — the shared state is the filesystem, and both hosts read it
natively. The next session, whichever host it runs on, picks up by
reading what the previous one wrote.

| Path | Contents |
|---|---|
| `AGENTS.md` | Canonical project instructions. Codex reads it natively; Claude includes it via a one-line `CLAUDE.md`. |
| `.workspace/memory/` | Persistent project memory — facts that survive a `/clear`. |
| `.workspace/transitions/` | Session handoffs (`handoff` / `continue`). |
| `.workspace/work/<unit>/` | Active work units: specs, plans, references, follow-up notes. |

There is deliberately no "execute as the other host" command — wrapping
`claude -p` or `codex exec` in a subprocess just to pass file paths
through loses context on every call. That was the lesson from the
[relay experiment](docs/relay-lessons.md) this toolkit replaces.

## Session continuity

A prose handoff goes stale silently: the next session can't tell whether
what it describes is still true. `handoff` fixes that by pairing the
prose with a fenced bash block of read-only commands, each carrying an
inline `# expect: <value>`. The next session — same agent or different,
same host or different — runs:

```
continue from .workspace/transitions/YYYY-MM-DD/HHMMSS.md
```

`continue` executes each command, compares the output to the expected
value, and flags every divergence. Drift is information, not failure — a
repo one commit ahead is fine; a milestone that has since closed may
matter. It surfaces suggested next steps but does not act on them.

## Code review (optional)

If you use [roborev](https://github.com/kenn-io/roborev), `continue` and
an optional Claude Code `SessionStart` hook surface any open reviews on
the current branch — silent when roborev isn't installed, when the branch
is clean, or when the daemon doesn't answer within half a second.

Turning it on takes two steps, and the first is enough on its own:

1. **Install roborev** (its own instructions). A `roborev` binary on
   `PATH` is all `continue` needs, on either host.
2. **For the session-start summary in Claude Code**, enable the `roborev`
   plugin from the
   [coding-agent-plugins](https://github.com/stefan-jansen/coding-agent-plugins)
   marketplace in your project's `.claude/settings.json`:

   ```json
   { "enabledPlugins": { "roborev@local": true } }
   ```

## Repository layout

```
skills/                  Canonical Claude skill source (one dir per step)
  align/  continue/  handoff/  next-issue/  plan-issues/  ship/
codex/prompts/           Codex prompt mirror (one file per step)
docs/
  planmode-probe.md      Empirical findings on host plan-mode behaviour
  api-drift-detection.md A design note on what is deliberately not built yet
  relay-lessons.md       What the predecessor experiment taught
AGENTS.md                Canonical project instructions
CLAUDE.md                @AGENTS.md (one line)
LICENSE                  MIT
```

## Background

- **[relay](docs/relay-lessons.md)** was a Python CLI that tried to
  orchestrate Claude Code and Codex as subprocess backends from the
  outside. Its step chain and the GitHub-as-projection convention
  survived; the orchestrator-from-outside premise did not.
- **[claude-code-toolkit](https://github.com/stefan-jansen/claude-code-toolkit)**
  is a broader, Claude-only collection of patterns and plugins, now
  superseded by this. This toolkit is narrower — seven steps, two hosts,
  one job.
- It is a sibling, not a competitor, to
  [roborev](https://github.com/kenn-io/roborev): roborev reviews code,
  this toolkit drives work. The two compose.

## Status and contributing

Pre-1.0. The step contracts are stable enough to use daily, but their
shape may still shift in response to friction surfaced in real work.
Issues and PRs welcome — the [planmode-probe](docs/planmode-probe.md) and
[api-drift-detection](docs/api-drift-detection.md) notes are the best
starting point for understanding the design choices.

## License

MIT — see [`LICENSE`](LICENSE).
