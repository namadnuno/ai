---
name: tdd
description: Test-driven development with red-green-refactor loop. Use when user wants to build with TDD, mentions "red-green-refactor", wants test-first development, or asks to write tests before code.
---

# TDD

One test. One impl. Repeat.

## Rules

- Test behavior via public interface only. Survives refactor = good test.
- Vertical slices — one RED→GREEN at a time. Never all tests then all code.
- Minimal code to pass. Never refactor while RED.

## Process

1. **Plan** — list behaviors to test, confirm with user, prioritize
2. **Tracer bullet** — one test for most critical behavior → RED → minimal code → GREEN
3. **Loop** — `RED → GREEN → REFACTOR` per behavior until list done

## Per-cycle

- [ ] Tests behavior, not implementation
- [ ] Public interface only
- [ ] Code minimal for this test only

## Anti-patterns

- All tests before any code (horizontal slicing)
- Testing private methods/internal state
- Refactoring while RED
