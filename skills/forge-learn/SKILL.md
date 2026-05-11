---
name: forge-learn
description: >
  Persist non-obvious insights about the codebase into the forge knowledge base (DB) so future sessions start warm.
  Trigger phrases: "save what you learned", "remember this", "log this to forge", "save context", "forge-learn",
  "save insight", "what did we learn", "persist this".
  Also auto-triggers at natural pause points: after understanding a complex module, after fixing a non-obvious bug,
  after a review session surfaces patterns.
---

# forge-learn

Saves codebase insights to the forge DB via `save_context`. Future sessions retrieve via `list_context` + `get_context`.

## When to trigger

- You just understood something non-obvious about a file or module
- A bug root cause was surprising or had hidden constraints
- A pattern or convention emerged that isn't documented
- End of a session that touched new areas of the codebase

## Process

1. Identify what was non-obvious in this session. Skip anything derivable from reading the code.
2. Pick scope: file path for file-specific insight, `__project__` for repo-level.
3. Pick key from: `overview` | `patterns` | `gotchas` | `why` | `deps`
4. Write body: 1-3 sentences. State the constraint, decision, or surprise — not what the code does.
5. Call `save_context(scope, key, body)` for each insight.
6. Confirm: "Saved N insights to forge."

## Output

```
Saved 3 insights to forge:
- forge/mcp/indexer.js / gotchas
- forge/mcp/server.js / patterns
- __project__ / why
```

## Anti-patterns

- Don't save what's obvious from reading the code (function names, file structure)
- Don't write more than 3 sentences — if it needs more, it's two separate keys
- Don't save current task state or in-progress work — insights only
- Don't use `get_context` without `list_context` first (wastes tokens on unknown scope)
