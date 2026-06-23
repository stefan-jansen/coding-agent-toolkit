# coding-agent-toolkit

A workflow toolkit for coding agents. It takes a piece of work from "we
should do something about X" through to a shipped artifact — usually a
merged PR, though the same steps drive non-code work too (a research
report, a course module, a long-form post). The shape is the same:
align on what "done" looks like, break it into chunks, work each chunk
to completion, hand off cleanly when the session ends.

The toolkit is built to survive the things that usually derail
long-running agent work: running out of context mid-project, switching
from Claude Code to OpenAI Codex (or back) part way through, or coming
back to half-finished work the next morning.

The agent stays in the driver's seat. The toolkit supplies the
structure — specs, plans, transition notes — that lets one session
pick up cleanly where another one left off.

## From a vague request to a shipped artifact

Coding agents are good at producing things — code, prose, plans, decks
— once they know exactly what to produce. The first half of any piece
of work — turning "users keep complaining about X, can we fix it" or
"we should publish something about Y" into a sharp spec the agent can
act on without re-asking at every step — is where sessions get long,
decisions get lost, and you end up re-explaining the same constraints
three times.

This toolkit treats GitHub as the projection surface rather than the
agent's own memory: milestones for the goal, issues for the chunks,
branches for the work, PRs for the review-and-merge. Nothing about
that machinery is code-specific — `Closes #N` in a PR body closes an
issue about a chapter draft just as cleanly as one about a bug fix.
The work progresses through a chain of steps, each of which produces a
durable artifact:

| Step | Produces |
|---|---|
| `align` | `spec.md` — a verifiable end-state. Either by interrogating you one question at a time, or by seeding from a brief and asking only the questions the brief didn't answer. |
| `plan` | `plan.md` — a milestone broken into issue-sized chunks. Runs in the host's native plan mode, in-session or headless. |
| `plan-issues` | A GitHub milestone and one issue per chunk. Default is dry-run; pass `--apply` to actually create. |
| `next-issue` | A branch, an implementation, tests, a PR. Picks the lowest-numbered open issue in the active milestone. |
| `ship` | A squash-merged PR and a closed milestone. Verifies every milestone issue has a closing-footer commit before merging. |

The artifact at each step is the contract. Picking the work up later —
or handing it to a different agent session — means reading the
artifact, not re-deriving the state. `Closes #N` in PR bodies is the
bubble-up signal: a merged PR closes the issue, and the last issue
closing closes the milestone. GitHub is the state machine.

A milestone whose issues are "draft the introduction", "draft the
middle three sections", "edit pass", "publish" closes the same way a
software milestone does. `next-issue` and `ship` drive each step
regardless of whether the artifact at the bottom is a function, a
post, or a slide deck — most of the examples below are code-flavoured
because that's still the dominant use case, but the chain itself
doesn't notice.

## Switching between Claude Code and OpenAI Codex

Each coding agent has its own session state, its own conventions for
where memory lives, and its own opinions about when to ask versus when
to act. Trying to use both on the same feature usually means
re-explaining the work every time you swap.

The swap primitive here is the filesystem, not an orchestrator. Both
Claude Code and OpenAI Codex read project files natively, so state that
lives in a file is automatically visible to both. The convention:

| Path | Contents |
|---|---|
| `AGENTS.md` | Canonical project instructions. Codex reads it natively; Claude includes it via a one-line `CLAUDE.md`. |
| `.workspace/memory/` | Persistent project memory — facts that should survive a `/clear`. |
| `.workspace/transitions/` | Session handoffs (see next section). |
| `.workspace/work/` | Active work units: specs, plans, follow-up notes. |

Each step in the chain ships as both a Claude skill
(`skills/<step>/SKILL.md`) and a Codex prompt
(`codex/prompts/<step>.md`). The skill source is canonical; the Codex
prompt is the same contract shaped for Codex's strict-YAML frontmatter.
Either host can run any step. The other host picks up by reading the
files the step left behind.

There is deliberately no "execute as the other host" command. Wrapping
`claude -p` or `codex exec` in a subprocess just to pass file paths
through loses context every invocation, and the cost stops being worth
it. (That was the lesson from the [relay
experiment](docs/relay-lessons.md), the design probe this toolkit
replaces.)

## Long-running work that outlives a single session

A multi-day project outlives any single agent session. Context budgets
run out, machines restart, you walk away on Friday and come back on
Monday. The usual fix — a prose handoff at end-of-day — goes stale
silently: the next session has no way to tell whether the state it
describes is still true when it picks the work up.

`handoff` writes a transition file under
`.workspace/transitions/YYYY-MM-DD/HHMMSS.md`. It contains the usual
prose summary plus, crucially, a fenced bash block of read-only
commands with inline `# expect: <value>` comments. The next session —
same agent or different, same host or different — invokes:

```
continue from .workspace/transitions/YYYY-MM-DD/HHMMSS.md
```

`continue` runs each command in the snapshot, compares the output to
the expected value, and flags every divergence. Drift is information,
not failure — a repo that has moved on by one commit is fine; a
milestone that was open and is now closed may be important. The user
picks a next step from the suggestions in the file; `continue` does not
auto-execute anything.

The verification snapshot is what makes the handoff durable. A prose
note tells you what someone thought was true an hour ago. A snapshot
running against the current repo tells you what is true now.

## Open code reviews on the current branch

Feature work and code review run on different cadences. A review can
arrive while you're off doing something else, and the next session that
picks up the branch needs to know about it before doing more work on
top.

If you also use [roborev](https://github.com/kenn-io/roborev) for code
review, `continue` (and an optional `SessionStart` hook in Claude Code)
surface any open reviews on the current branch when a session begins or
a transition resumes. The check is silent when roborev isn't installed,
when the branch has no open reviews, or when the review daemon doesn't
respond within half a second — so it costs nothing when you don't use
it.

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

There is no separate runtime to install. The steps are skills or
prompts, invoked the way every other skill or prompt is.

## Getting started

The canonical install is to point an agent's skills/prompts at this
repo directly:

**Claude Code.** Copy or symlink `skills/` into your project's
`.claude/skills/` directory. Alternatively, install the `workflow`
plugin from the
[claude\_code\_plugins](https://github.com/stefan-jansen/coding-agent-plugins)
marketplace, which mirrors these skills.

**OpenAI Codex.** Point your prompts directory at `codex/prompts/`, or
copy the files in.

The steps are meant to be invoked in order on a new feature
(`/align`, `/plan`, `/plan-issues`, `/next-issue`, `/ship`) and at the
boundaries of long-running work (`/handoff` and `/continue`). The
`SKILL.md` file in each `skills/<step>/` directory is the
authoritative documentation for that step.

## Background

The toolkit grew out of two earlier projects:

- **[relay](docs/relay-lessons.md)** was a Python CLI that tried to
  orchestrate Claude Code and Codex as subprocess backends from the
  outside. Its verb chain and the GitHub-as-projection convention
  survived; the orchestrator-from-outside premise did not. The full
  post-mortem is in `docs/relay-lessons.md`.
- **[claude-code-toolkit](https://github.com/stefan-jansen/claude-code-toolkit)**
  is a broader collection of Claude Code patterns and plugins. This
  toolkit is narrower — six steps, two hosts, one job.

It is a sibling, not a competitor, to
[roborev](https://github.com/kenn-io/roborev): roborev reviews code,
this toolkit drives work. The two compose, and the roborev integration
above is what that composition looks like in practice.

## Status and contributing

Pre-1.0. The step contracts are stable enough to use daily, but their
shape may still shift in response to friction surfaced in real work.
Issues and PRs welcome — the
[planmode-probe](docs/planmode-probe.md) and
[api-drift-detection](docs/api-drift-detection.md) notes are the best
starting point for understanding the design choices.

## License

MIT — see [`LICENSE`](LICENSE).
