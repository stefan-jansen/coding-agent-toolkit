# /align (Codex prompt)

Install to `~/.codex/prompts/align.md` so it's invocable as `/align` in Codex.
This is the Codex binding of the ALIGN step — same contract as the
Claude `align` skill (`skills/align/SKILL.md`); both converge on the
same `spec.md`.

---

Run the ALIGN step. Produce a complete, verifiable specification of the desired
end-state — the WHAT and WHY, never the HOW — and write it to `spec.md` in the
work unit the user names (under `.workspace/work/`).

Alignment has two sides and the spec reflects both: **intent** (what the user
wants — extracted by forceful interrogation) and **reality** (what the
environment already is — extracted by exploring first, read-only). A spec
aligned on intent but blind to reality plans against a world that doesn't
exist. Explore, then interrogate, then write.

A separate headless `plan` step will turn this spec into milestones and issues and
**must not need to ask the user anything**, so kill every ambiguity now.

## Entry modes

**Cold** (default, no argument): interrogate from scratch per the rules below.

**With a brief** (`/align @brief.md`): read the named file, infer Objective, Why,
Acceptance, In scope, Out of scope, Constraints, Existing surface, and Open
questions from it, and produce `spec.md` directly. Fall back to question-by-
question interrogation only for sections the brief leaves vague or empty — not
the whole spec. Still do the 5-8 bullet playback before writing.

**Hard guard (brief mode): MUST NOT implement.** Even when the brief reads
like a fully-actionable spec, the ONLY file you may create is
`<work-unit>/spec.md`. Do NOT edit anything under `src/`, `tests/`, or any
source-tree path; do NOT edit `pyproject.toml`, `package.json`,
`LIMITATIONS.md`, `README.md`, or any project metadata; do NOT run pytest,
ruff, ty, or any build/format tool; do NOT run `git add`/`commit`/`push` or
any state-mutating `gh` command. This applies even if the sandbox would
allow it. Implementation is `/next-issue`'s job — `/align` only produces
the spec contract.

## Explore first (read-only)

Before interrogating, survey the terrain — this is the environment half of the
old `explore` step, run as homework, not a gentle wander. READ / grep / list
widely (required), but the write guard above still holds absolutely: no edits,
no test/build/format runs, no mutating git / `gh`. Survey what the deliverable
needs — for code: repo layout, the modules/tests this touches, existing
implementations of the same shape, conventions, and project instructions
(`AGENTS.md` / `CLAUDE.md`, `.workspace/memory/`); for non-code: prior work of
the same kind, reference material, house style. Use the findings two ways:
(1) ask evidence-based questions ("you already have X doing Y — extend or
replace?") instead of cold ones, and (2) if the request collides with what
exists, raise it first. Fill Existing surface / Constraints / Environment from
what you found, not from asking the user to recall it. Brief mode explores too —
a brief states intent, not reality.

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
Out of scope (≥1 exclusion) · Constraints · Environment / prior art (what to
build on, from the explore phase) · Existing surface (must not break — verified,
not just recalled) · Open questions (each with a decision rule + owner, or
marked deferred).

Finish by telling the user: spec is written. Next step is `/plan` — run
`codex exec --sandbox read-only --output-schema <plan.schema.json> "decompose @<work-unit>/spec.md"`
(or, on a Claude session, enter plan mode with the same spec). The plan step
must not need to ask the user anything — if it does, return to align.
