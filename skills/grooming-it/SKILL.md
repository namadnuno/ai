---
name: grooming-it
description: Read a Jira ticket (via MCP) and/or pasted spec, ask clarifying product questions one at a time to surface ambiguities, then produce a dev-internal plan doc. Use when the user says "groom this ticket", "let's groom", "help me understand this ticket", "grooming-it", or pastes a Jira URL before starting development. Designed for bigger features where loose ends and mid-dev scope changes are the main risk.
---

# Grooming It

Read the ticket. Find the fog. Clear it before a single line is written.

## Input

1. Jira URL → fetch via MCP. Read title, description, acceptance criteria, linked tickets, comments.
2. Pasted spec → read as-is.
3. Both → merge, prefer spec for conflicts.

If neither provided, ask for one before continuing.

## Process

1. **Summarize in 3–5 sentences.** What is being built, for whom, and why. Get correction before continuing.
2. **Identify fog.** Missing acceptance criteria, undefined edge cases, design gaps, dependencies on other teams/repos, ambiguous "done" definitions.
3. **Ask clarifying questions one at a time.** Product-focused first (behavior, scope, user impact), then technical (API contracts, DB changes, cross-repo). One question — wait for answer — next question.
4. **Stop grilling when:** all load-bearing unknowns resolved OR user explicitly defers. Don't grill on nice-to-haves.
5. **Write the plan doc.**

## Clarifying question lenses

Pick what the ticket hasn't covered:

- **User story**: who does what and sees what result? One sentence.
- **Scope boundary**: what is explicitly out? Name it so it doesn't sneak back in.
- **Edge cases**: empty state, error state, permission edge, concurrent action, mobile/responsive.
- **Design**: is Figma final? Are all states designed (loading, error, empty, disabled)?
- **Dependencies**: other tickets, other repos, third-party APIs, feature flags.
- **Done definition**: what does QA sign off on? What does product sign off on?
- **Rollout**: gradual rollout, feature flag, all-at-once?

## Anti-patterns

- Asking two questions at once — one at a time, always.
- Grilling on deferred items — if user says "later", log it and move on.
- Solving during grilling — surface the problem, let user answer first.
- Validating before all load-bearing questions resolved.
- Producing the plan before summarizing and getting correction.

## Plan doc output

```markdown
# [Ticket Title]

## What
[2–3 sentence description of what ships]

## User Stories
- As [user], I want [action] so that [outcome].
- ...

## Task Breakdown
1. [Smallest shippable slice]
2. [Next slice]
...

## Edge Cases
- [Case] → [expected behavior]
- ...

## What to Test
- [Scenario] → [expected result]
- ...

## Open Questions
- [Question] — deferred / owner: [person]

## Deferred
- [Item explicitly out of scope]
```

Keep each section tight. This is a dev reference, not a product doc — no fluff, no restating the obvious. Clean enough that an LLM can reformat it for product later.
