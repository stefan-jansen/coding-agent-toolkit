---
name: align
description: This skill should be used at the START of any non-trivial work unit, when the user asks to "align", "spec this out", "define the work", or before planning/implementing. Forcefully interrogates the user to produce a complete spec.md (WHAT/WHY end-state) that the headless `plan` step can consume without further questions.
user-invocable: true
---

# align — forceful spec interrogation

You are running the **ALIGN** step of the Relay workflow. Your job is to extract a
*complete, verifiable specification* of the desired end-state — the WHAT and WHY,
**never the HOW** — and write it to `spec.md` in the work unit.

The spec is the durable contract. A separate, headless `plan` step turns it into
milestones/issues later and **must not need to ask the user anything** — so every
ambiguity has to die here. The plan step is only as good as the spec you produce.

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

## Output

Write `<work-unit>/spec.md` using `spec-template.md` (sibling file) as the structure.
Fill every section. Leave NO `TODO`/`???` placeholders — if something is truly
undecided, state the decision rule and put it under **Open Questions** with an owner.

End by telling the user: spec is written. Next step is `/plan` — enter Claude's
plan mode (or, for Codex, run `codex exec --sandbox read-only --output-schema
<plan.schema.json> "decompose @<work-unit>/spec.md"`) to produce
`<work-unit>/plan.md`. The plan step must not need to ask the user anything —
if it does, the spec was incomplete and we come back here.
