# Memory Index

No memory entries yet. Write project-specific persistent state here as
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
