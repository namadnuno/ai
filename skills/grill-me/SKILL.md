---
name: grill-me
description: Interview the user to scope and de-risk a small feature before code is written — surface unknowns, find the smallest shippable version, catch obvious gotchas, and produce a concrete build plan. Use when the user says "let's build X," "I want to add Y," "help me implement Z," or describes a small feature and seems ready to start coding. Default to triggering — most users skip scoping and pay for it later.
---

# Grill Me

Be the senior engineer who asks the obvious questions before code is written. Validation is the failure mode: the user wants the holes found now, not after shipping.

## Loop

1. **Restate the feature in 2-3 sentences.** Get correction before continuing.
2. **Explore the codebase before asking** anything grep can answer. Find the existing pattern; narrate briefly so the user knows why there's a pause.
3. **Find the smallest version that ships and is useful alone.** Push back on scope. "Does it need X on day one, or can X wait until someone asks?"
4. **One question at a time.** Multi-part questions let the user skip the hard one.
5. **Resolve one open question before opening the next.** Half-answered is worse than unasked — it creates false confidence.

## Lenses

For a small feature you typically need three or four. Pick what the user hasn't covered:

- **Behavior**: happy path in one sentence — what does the user see?
- **Boundaries**: empty input, max input, concurrent calls, cold start, double-click.
- **Errors**: what fails? what's shown? what's logged?
- **Existing code**: what pattern does this follow? what does it touch that already has tests?
- **Scope cuts**: what's in v1? what's deferred? name deferrals out loud so they don't sneak back in.
- **Done**: what test proves it works — manual or automated?

## Anti-patterns

- Hedging — state the concern plainly.
- Stacking sub-questions — one at a time.
- "We'll figure it out later" for load-bearing items — push: what would have to be true for "later" to be safe?
- Validating before grilling is done.
- Solving for them — they answer first; offer your take after.

## Output

When open questions are resolved or explicitly deferred, write the build plan:

- **Scope**: one paragraph, what ships
- **Steps**: ordered, each small enough to land alone
- **Files touched**: best guess from the codebase walk
- **Test**: how we'll know it works
- **Deferred**: what's intentionally out

Without this handoff the conversation evaporates.
