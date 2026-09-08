#!/usr/bin/env python3
"""Validate that a plan.md is in the shape /plan-issues parses.

Exits 0 and prints a summary when the file parses; exits 1 and names the
offending line otherwise. The parse rules here and the ones documented in
plan-issues/SKILL.md are the same rules; change both together.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MILESTONE = re.compile(r"^###\s+Milestone:\s*`(.+?)`\s*$")
# Separator: plain dash (preferred), double dash, or em dash.
ISSUE = re.compile(r"^\*\*Issue\s+(\d+)\s+(?:-|--|—)\s+(.+?)\*\*\s*$")
SECTION = re.compile(r"^##\s+\S")


def check(lines: list[str]) -> list[str]:
    errors: list[str] = []

    milestones = [(i + 1, m.group(1)) for i, l in enumerate(lines) if (m := MILESTONE.match(l))]
    if not milestones:
        near = [i + 1 for i, l in enumerate(lines) if l.lstrip().startswith("### Milestone")]
        where = f" (closest: line {near[0]})" if near else ""
        errors.append(f"no '### Milestone: `<version> - <title>`' heading found{where}")
    elif len(milestones) > 1:
        where = ", ".join(f"line {n}" for n, _ in milestones)
        errors.append(f"{len(milestones)} milestone headings, expected exactly 1 ({where})")

    issues = [(i + 1, int(m.group(1)), m.group(2)) for i, l in enumerate(lines) if (m := ISSUE.match(l))]
    if not issues:
        errors.append("no '**Issue N - <title>**' headings found")
        near = [i + 1 for i, l in enumerate(lines) if l.lstrip().startswith("**Issue")]
        if near:
            errors.append(f"  lines starting with '**Issue' that did not parse: {near}")
        return errors

    numbers = [n for _, n, _ in issues]
    if numbers != list(range(1, len(numbers) + 1)):
        first_bad = next(
            (ln for (ln, n, _), want in zip(issues, range(1, len(numbers) + 1)) if n != want),
            issues[0][0],
        )
        errors.append(
            f"line {first_bad}: issue numbers are {numbers}, expected 1..{len(numbers)} with no gaps"
        )

    if milestones:
        m_line = milestones[0][0]
        early = [ln for ln, _, _ in issues if ln < m_line]
        if early:
            errors.append(f"issue heading(s) before the milestone heading at line(s) {early}")

    # Every issue needs a non-empty body, and no '## ' section may sit between two issues.
    starts = [ln for ln, _, _ in issues]
    for idx, (ln, num, title) in enumerate(issues):
        end = starts[idx + 1] - 1 if idx + 1 < len(starts) else len(lines)
        body = [l for l in lines[ln:end] if l.strip()]
        if not body:
            errors.append(f"line {ln}: issue {num} ('{title}') has an empty body")
        if idx + 1 < len(starts):
            interrupting = [ln + 1 + j for j, l in enumerate(lines[ln:end]) if SECTION.match(l)]
            if interrupting:
                errors.append(
                    f"line {interrupting[0]}: '## ' section between issue {num} and issue {num + 1}; "
                    "plan-issues would truncate the body there"
                )
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_plan.py <path/to/plan.md>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"check_plan: no such file: {path}", file=sys.stderr)
        return 2
    try:
        lines = path.read_text().splitlines()
    except OSError as exc:
        print(f"check_plan: cannot read {path}: {exc}", file=sys.stderr)
        return 2

    errors = check(lines)
    if errors:
        print(f"check_plan: FAIL {path}", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1

    milestone = next(m.group(1) for l in lines if (m := MILESTONE.match(l)))
    count = sum(1 for l in lines if ISSUE.match(l))
    print(f"check_plan: OK {path}")
    print(f"  milestone: {milestone}")
    print(f"  issues:    {count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
