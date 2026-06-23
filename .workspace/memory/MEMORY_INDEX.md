# Memory Index

## history.md
- status: active
- last_referenced: 2026-06-23
- tokens: ~6500
- anchors: chronological build log + closed-friction backlog (formerly `docs/HISTORY.md`; moved out of reader-facing docs/ on rename)

---

Write project-specific persistent state here as
`.workspace/memory/<slug>.md` files and register them above with:

```
## <slug>.md
- status: active|dormant|deprecated|superseded-by:<slug>
- last_referenced: YYYY-MM-DD
- tokens: <count>
- anchors: -
```

The index itself is auto-loaded via `@.workspace/memory/MEMORY_INDEX.md`
from `AGENTS.md`. Individual memory files are read on demand.
