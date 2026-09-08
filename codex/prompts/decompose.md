# /decompose (Codex prompt)

Install to `~/.codex/prompts/decompose.md` so it's invocable as `/decompose` in
Codex. This is the Codex binding of the DECOMPOSE step - same contract as the
Claude `decompose` skill (`skills/decompose/SKILL.md`); both produce the same
`plan.md`. The step is not called `plan` because on Claude Code `/plan` is the
built-in plan-mode prefix; the name is kept identical on both hosts.

---

Run the DECOMPOSE step. Input is the `spec.md` written by `/align`; output is
`plan.md` in the same work unit, in the shape `/plan-issues` parses.

**Do not ask the user anything.** The spec is the contract. If it is too
incomplete to decompose, say which section is missing and send the user back to
`/align`. Explore read-only as much as you need, then write the file.

If no spec path was given, take the most recently modified work unit under
`.workspace/work/` (or `work/`) that contains a `spec.md`.

## Required shape

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

- Exactly one `### Milestone:` line, title in backticks.
- `**Issue <N> - <title>**` on its own line, numbered from 1, no gaps, plain dash.
- An issue's body runs to the next `**Issue N`, the next `## ` heading, or EOF.
  Every issue needs a body, and no `## ` section may sit between two issues.
- Free-form sections go before the milestone heading or after all the issues.

## Content rules

- One coherent, separately verifiable change per issue. If an issue needs its
  own milestone list, split it.
- State verification per issue as a command and an expected result.
- Say in the body when an issue is gated on another; numbering does not imply it.
- Do not decide what the spec left open. Name the open question and its owner.

## Before you finish

```bash
python3 <toolkit>/skills/decompose/check_plan.py <work-unit>/plan.md
```

It exits non-zero and names the offending line. Do not hand off a plan that
fails it; `/plan-issues` aborts on the same content.

Report the plan path, milestone title, issue count, and that the check passed.
Next step is `/plan-issues --repo <owner>/<name>` (dry-run), then `--apply`.
