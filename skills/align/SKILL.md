---
name: align
description: This skill should be used at the START of any non-trivial work unit, when the user asks to "align", "spec this out", "define the work", or before planning/implementing. Forcefully interrogates the user (or seeds the spec from a brief/RFC if invoked as `/align @brief.md`) to produce a complete spec.md (WHAT/WHY end-state) that the headless `plan` step can consume without further questions.
user-invocable: true
---

# align — forceful spec interrogation

You are running the **ALIGN** step of the Relay workflow. Your job is to extract a
*complete, verifiable specification* of the desired end-state — the WHAT and WHY,
**never the HOW** — and write it to `spec.md` in the work unit.

The spec is the durable contract. A separate, headless `plan` step turns it into
milestones/issues later and **must not need to ask the user anything** — so every
ambiguity has to die here. The plan step is only as good as the spec you produce.

## Arguments

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `@<path>` | no | none | Read the named brief/RFC/draft and seed `spec.md` from it, skipping cold interrogation. Fall through to interrogation only for sections the brief leaves under-specified. |

## Two entry modes

**Cold (no argument).** Default. Interrogate from scratch per the rules below.

**With a brief (`/align @brief.md`).** Read the file. Infer the Objective, Why,
Acceptance criteria, In scope, Out of scope, Constraints, Existing surface, and
Open questions from it. Produce `spec.md` directly. Only fall back to
question-by-question interrogation for sections the brief leaves vague or empty —
and only for those sections, not the whole spec. Surface the brief-derived spec
to the user in a 5-8 bullet playback (same as cold mode) and get an explicit
"yes" before writing. If the brief contradicts itself or proposes a HOW where a
WHAT is needed, ask one question to resolve and move on — do not re-interrogate
content the brief already nails down.

### Hard guard: brief mode MUST NOT implement

Even when the brief reads like a fully-actionable spec ("Add class X, write
tests for Y, update doc Z"), `/align` is NOT the implementation step. The
ONLY file you may create is `<work-unit>/spec.md`. You MUST NOT:

- edit, create, or delete any file under `src/`, `tests/`, or any other
  source-tree path;
- edit `pyproject.toml`, `Cargo.toml`, `package.json`, `LIMITATIONS.md`,
  `README.md`, or any project-level metadata;
- run tests, linters, type-checkers, formatters, or build tools;
- run `git add`, `git commit`, `git push`, or any state-mutating git or `gh`
  command.

This rule applies even if a workspace-write sandbox would technically allow
those writes. Implementation is `/next-issue`'s job and only fires once the
plan-issues step has materialized actual GitHub issues. If a brief is so
actionable that you feel pulled to implement, the right move is to surface
the pull in the spec playback ("the brief reads as actionable — confirm
you want a spec, not implementation"), not to skip ahead.

If you find yourself about to edit a file outside the work unit, STOP and
re-read this paragraph. This is the dogfood-surfaced failure mode the
section exists for.

## Why this is forceful

The old `explore` step failed because it was too gentle: it accepted vague answers
and moved on, so goal discovery was weak and plans drifted. Do NOT repeat that.
You interrogate. You challenge. You do not proceed on assumptions.

## Rules of engagement

1. **One question at a time.** Never batch questions — the user answers worse and
   you challenge worse. Ask, get the answer, react, ask the next.
2. **Challenge every vague answer.** "Better performance" → "Measured how? What's
   the current number, what's the target, who decides it's enough?" Do not accept
   an answer you couldn't write a pass/fail test against.
3. **Surface the implicit.** Ask what's deliberately OUT of scope. Ask what failure
   looks like. Ask what already exists that this must not break.
4. **Do NOT design.** If you catch yourself proposing an implementation, stop and
   convert it into a requirement ("the result must X") instead.
5. **Minimum question floor.** Ask at least **6** substantive questions before you
   offer to write the spec. Hard requirements, acceptance criteria, scope
   boundaries, and constraints are non-negotiable coverage. **Do NOT write spec.md
   until every section below can be filled with something verifiable.**
6. **Summarize and confirm.** Before writing, play back the spec verbally in 5-8
   bullets and get an explicit "yes" or corrections. Then write the file.

## Question backbone (adapt; don't read aloud as a checklist)

- **Objective**: In one sentence, what is true when this is done that isn't true now?
- **Why now**: What breaks / what's lost if this isn't built? Who feels it?
- **Acceptance**: How will we *verify* it's done? Name concrete checks/tests/numbers.
- **In scope / Out of scope**: What's explicitly excluded? (Force at least one exclusion.)
- **Constraints**: Hard limits — compat, perf, deadlines, tech that must/can't be used.
- **Existing surface**: What must NOT break? What does this touch?
- **Unknowns**: What's still genuinely uncertain? (Goes in Open Questions, must be
  empty or explicitly deferred before the spec is "ready".)

## Spec-writing rules

**Atomicity in error paths.** If the spec names an error condition ("raise
ValueError on missing input", "reject if X", "fail when Y"), the Acceptance
section must include an explicit atomicity clause: when the error fires, no
prior step in the same logical operation may be half-applied. The
implementation must validate first, then mutate. State this as a verifiable
check (e.g. "on invalid input, no row is written and no side-effecting call
fires"). Without this clause, /next-issue is free to ship a half-mutated
failure path and the spec didn't say it was wrong.

## Output

Write `<work-unit>/spec.md` using `spec-template.md` (sibling file) as the structure.
Fill every section. Leave NO `TODO`/`???` placeholders — if something is truly
undecided, state the decision rule and put it under **Open Questions** with an owner.

End by telling the user: spec is written. Next step is `/plan` — enter Claude's
plan mode (or, for Codex, run `codex exec --sandbox read-only --output-schema
<plan.schema.json> "decompose @<work-unit>/spec.md"`) to produce
`<work-unit>/plan.md`. The plan step must not need to ask the user anything —
if it does, the spec was incomplete and we come back here.
