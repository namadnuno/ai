---
name: ship-it
description: Final integration check — run tests, generate commits, draft PR. Use when user says "ship it," "wrap this up," "ready to commit," "write the PR," "we're done." Works with or without slice-it/grill-me context.
---

# Ship It

Two modes — detect from context:
- **Slice mode**: slices exist → one commit per slice, PR from grill-me scope
- **Standalone**: no context → `git diff main`, infer changes, derive commits + PR

## Steps

1. Run test suite. Red → stop, fix first.
2. Scope check. Slice mode: verify grill-me scope covered. Standalone: summarize diff in 1–2 sentences.
3. Flag unexpected diff — out-of-scope files, debug code, dead imports.
4. Commits. Slice mode: one per slice. Standalone: one per logical group. Subject = intent.
5. Draft PR.

## PR format

Bullets only. No headers. No prose. Max 5.

```
- [what + why]
```

Add `⚠️ [risk]` only if something flagged and accepted.

## Anti-patterns

- Mega-commit — kills bisect
- Subject describes diff not intent
- Skipping full suite

## Output

Suite: ✓ / failures | Commits: subject lines | PR: ready to paste
