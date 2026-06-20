# /align (Codex prompt)

Install to `~/.codex/prompts/align.md` so it's invocable as `/align` in Codex.
This is the Codex binding of the roborun ALIGN step — same contract as the
Claude `align` skill (`roborun/skills/align/SKILL.md`); both converge on the
same `spec.md`.

---

Run the ALIGN step. Extract a complete, verifiable specification of the desired
end-state — the WHAT and WHY, never the HOW — and write it to `spec.md` in the
work unit the user names (under `.workspace/work/`).

A separate headless `plan` step will turn this spec into milestones and issues and
**must not need to ask the user anything**, so kill every ambiguity now.

## Entry modes

**Cold** (default, no argument): interrogate from scratch per the rules below.

**With a brief** (`/align @brief.md`): read the named file, infer Objective, Why,
Acceptance, In scope, Out of scope, Constraints, Existing surface, and Open
questions from it, and produce `spec.md` directly. Fall back to question-by-
question interrogation only for sections the brief leaves vague or empty — not
the whole spec. Still do the 5-8 bullet playback before writing.

Rules:
- Ask **one question at a time**. React to each answer before asking the next.
- **Challenge vague answers.** Do not accept anything you couldn't write a pass/fail
  test against ("better performance" → measured how, current vs target number).
- Force at least one explicit **out-of-scope** exclusion. Ask what must NOT break.
- **Do not design.** Convert any implementation idea into a requirement instead.
- Ask at least **6** substantive questions before offering to write the spec
  (cold mode only — brief mode fills most sections from the file and only
  questions the gaps).
- Before writing, play the spec back in 5-8 bullets and get an explicit "yes".
- **Atomicity in error paths.** If the spec names an error condition, the
  Acceptance section must include an explicit atomicity clause: when the error
  fires, no prior step in the same logical operation may be half-applied.
  Implementation validates first, then mutates. State it as a verifiable check.

Write `<work-unit>/spec.md` with these sections, every one filled with verifiable
content (no TODO/??? placeholders):

Objective · Why · Acceptance criteria (numbered, each verifiable) · In scope ·
Out of scope (≥1 exclusion) · Constraints · Existing surface (must not break) ·
Open questions (each with a decision rule + owner, or marked deferred).

Finish by telling the user: spec is written. Next step is `/plan` — run
`codex exec --sandbox read-only --output-schema <plan.schema.json> "decompose @<work-unit>/spec.md"`
(or, on a Claude session, enter plan mode with the same spec). The plan step
must not need to ask the user anything — if it does, return to align.
