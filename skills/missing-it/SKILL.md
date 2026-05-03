---
name: missing-it
description: Mid-dev completeness audit — finds what's absent: missing tests, unhandled edge cases, incomplete error paths, forgotten states. Use when user says "what am I missing", "what's not covered", "am I forgetting anything", or invokes /missing-it. Standalone.
---

# Missing It

Code exists. Find what it doesn't handle yet.

## Input

`git diff main` or `git diff --staged`. If file mentioned, read it + direct deps.

## Lenses (report only what's absent)

- **Tests** — behaviors with no coverage
- **Edge cases** — empty, null, max, concurrent, idempotency
- **Error paths** — unhandled throws, silent failures
- **States** — loading, empty, error, partial data
- **Side effects** — rollback on failure, duplicate execution, cleanup

## Output

```
### Must handle
- [ ] [gap] — [why]

### Should handle
- [ ] [gap] — [why]

### Deferred ok
- [ ] [gap]
```

Max 8 items total. If more, ask user to focus on specific area. Skip empty buckets. Don't flag gaps already in `grill-me` deferred list.
