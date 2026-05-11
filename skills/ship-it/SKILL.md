---
name: ship-it
description: Draft PR title and description from current git changes. Use when user says "ship it," "wrap this up," "write the PR," "we're done," "ready to commit."
---

# Ship It

## Process

1. Run `git status` and `git diff main`. No changes → stop, tell user nothing to ship.
2. Derive conventional commit title from diff intent (not diff content).
3. Write PR description: bullets only, max 5, each = what + why.

## Output

```
<type>(<scope>): <subject>

- [what + why]
- [what + why]
```

## Anti-patterns

- Subject describes diff not intent
- More than 5 bullets
- Prose in description
