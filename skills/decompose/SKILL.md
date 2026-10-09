---
name: decompose
description: 'After `/align` wrote spec.md: "plan this", "decompose the spec", "break this into issues", or `/decompose`. Produces the plan.md that `/plan-issues` parses. Claude Code''s built-in `/plan` prefix does NOT reach this step.'
user-invocable: true
---

# decompose - turn the spec into issues

You are running the **PLAN** step of the workflow. Input is a `spec.md` written
by `align`. Output is `plan.md` in the same work unit, in the shape defined
below, which `plan-issues` parses to create a GitHub milestone and one issue per
planned issue.

**This step must not ask the user anything.** The spec is the contract; if it is
too incomplete to decompose, say so and send the user back to `/align` rather
than interrogating them here. That rule is what makes this step runnable
headlessly on either host.

## Arguments

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `<path>` | no | active work unit's `spec.md` | The spec to decompose |

If no path is given, locate the active work unit: walk up from the working
directory to a `.workspace/work/` (or `work/`) directory, then take the most
recently modified subdirectory containing a `spec.md`. If that is ambiguous,
name the candidates and pick the newest rather than asking.

## Mechanism

**Claude Code**: enter plan mode (`EnterPlanMode`) and do the exploration and
decomposition there, then write `plan.md` on exit. Plan mode is how you think;
it is not the deliverable. A plan that stays in the transcript has not run this
step.

This step is named `decompose`, not `plan`, because `/plan` is Claude Code's
built-in prefix for entering plan mode and cannot be claimed by a skill or a
command. Typing `/plan` gets you plan mode and the model's own default
planning, which is the behaviour this step exists to replace.

**Codex**: run the decomposition directly, read-only, and write `plan.md`.

Both hosts produce the same file. Nothing downstream reads anything else, so no
JSON schema and no structured-output mode is involved.

## Required shape of plan.md

`plan-issues` parses this file. Any deviation makes the next step abort.

```markdown
# Plan: <work unit name>

<one or two paragraphs: what this decomposes, and the gating order>

## <optional free-form sections: context, findings, architecture, verification>

### Milestone: `<version> - <title>`

**Issue 1 - <issue title>**

<body: files touched, the change, how it is verified, what "done" means>

**Issue 2 - <issue title>**

<body>
```

Hard rules:

- Exactly one `### Milestone:` line, with the title inside backticks.
- Every issue heading matches `**Issue <N> - <title>**` on a line of its own,
  numbered from 1 with no gaps. The separator is a plain dash; `--` and an em
  dash also parse, but write a plain dash.
- An issue's body is everything up to the next `**Issue N`, the next `## `
  heading, or end of file. Every issue needs a body; an empty one is a defect.
- Free-form sections are fine and encouraged, but they must sit **before** the
  milestone heading or under a later `## ` heading, never between two issues.

## Content rules

- **Issues are issue-sized**: one coherent change, verifiable on its own,
  landing in one or a few commits. If an issue's body needs its own milestone
  list, split it.
- **State verification per issue**, in a form that can fail. "Add tests" is not
  verification; the command to run and the expected result is.
- **Order by gating.** If issue B cannot start until issue A lands, say so in
  B's body. Do not rely on issue numbers to imply it.
- **Do not design what the spec left open.** An open question in the spec stays
  an open question; name it in the plan and say who decides.
- **State premises where the code relies on them.** Every issue whose code
  computes over data carries a `### Premises` section: one `Input: <name>` per
  input, then a table `| Question | Answer | Kind |` answering each question in
  the set (`verification premises check` prints any it is missing): what a record
  means, what an absent record means, ordering and spacing, entity identity, when
  each value was known and actionable, and which institution's rules decide
  these. An issue that simulates trading writes `Simulates trading: yes` and also
  answers when information arrives, when an order can be placed and what price
  was achievable. Kind is `definitional` (settled by the spec's term table) or
  `empirical` (to be tested); `not-applicable: <reason>` needs no kind. An issue
  computing over no data writes `Premises: none - <reason>`.
- **List claims.** A number, comparison or property the issue's output asserts to
  a reader goes in a `### Claims` table `| Id | Claim | How it could be false |`.
- **Declare closure.** Each issue ends with `Closes: <items>` (or `Closes: none`)
  and, if it only advances some, `Advances: <items>`. A premise item is
  `<input-slug>.<question>`; a claim item is its Id. Every item is closed by
  exactly one issue: the earliest one where its test can run.

## Before you finish

Validate the file. The check is deterministic and lives beside this skill:

```bash
python3 "<skill-dir>/check_plan.py" <work-unit>/plan.md
verification premises check <work-unit>/plan.md
verification claims list <work-unit>/plan.md
verification closure check <work-unit>/plan.md
```

The three `verification` checks need the `verification` plugin; if it is not
installed, say so in the report rather than skipping silently.

It exits non-zero and names the offending line on a shape violation. Fix the
file and re-run until it passes. Do not hand off a plan that fails it, because
`plan-issues` will abort on the same content and the failure will surface later
with less context.

## Output to the user

Report: the plan path, the milestone title, the issue count, and that
`check_plan.py` passed. Then name the next step:

```
/plan-issues --repo <owner>/<name>        # dry-run
/plan-issues --repo <owner>/<name> --apply
```
