---
name: ship-it
description: Final integration check after all slices are done — run full test suite, verify end-to-end behavior matches the original scope, generate commit messages per slice, and draft a PR description. Use after the last slice from slice-it has passed review-it, or when the user says "ship it," "wrap this up," "ready to commit," "write the PR," "we're done." Pairs with grill-me, slice-it, review-it — closes the loop. Default to triggering when all planned slices are done.
---

# Ship It

Slices are individually green. Now check the feature is whole and hand it off cleanly.

## Order

1. **Full test suite.** Not just the last slice's verify line. Catches regressions across files the slices didn't touch.
2. **End-to-end check against original scope.** Open grill-me's build plan. Walk the Scope paragraph — does the feature do all of it? Does it correctly *not* do the Deferred items?
3. **Diff vs base branch.** Anything in the diff that isn't in any slice? Flag.
4. **Commit hygiene.** Default: one commit per slice. Squash only when slices touched the same lines. Subject = slice goal.
5. **Draft the PR description.**

## PR description template

```
## What
[Scope paragraph from grill-me, past tense]

## How
[One bullet per slice — goal, not steps]

## Deferred
[Deferred list from grill-me, verbatim]

## Risks accepted
[Anything review-it flagged that the user chose to live with]

## Verify
[All slice verify lines — reviewer can re-run them]
```

## Anti-patterns

- One mega-commit. Kills bisect, makes review impossible.
- Commit subjects that describe the diff ("update X.ts") instead of intent ("add avatar upload endpoint").
- Skipping the full suite because slice tests passed — slice tests are local, the suite catches blast radius.
- Hiding deferred items from the PR. Future-you needs the trail.
- Refactors that weren't in any slice, unnamed in the PR.

## Output

- Suite status: ✓ or list of failures
- Commit list: subject lines, in order
- PR description, ready to paste
- Follow-up issues to file (Deferred items that should be tracked)
