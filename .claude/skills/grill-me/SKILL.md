---
name: "grill-me"
description: "Interview the user relentlessly about a plan, feature or design, one question at a time, until every decision is resolved. Use when the user says 'grill me' or wants a plan stress-tested."
---

# Grill me

Your job is to reach a shared, unambiguous understanding of the user's plan before any code is written. You are the interviewer; the user makes the decisions.

## How to grill

1. Restate the plan in 2-3 sentences so the user can correct your understanding early.
2. Map the decision tree: list the open questions, grouped by area (rules, data model, UI flow, edge cases, tech choices, testing). Order them so decisions that others depend on come first.
3. Ask ONE question at a time. For each question:
   - Say why it matters (what breaks or changes depending on the answer).
   - Offer 2-3 concrete options and your recommended one, with a one-line reason.
   - Wait for the answer before moving on.
4. Follow each answer down its branch: ask the follow-up questions it creates before returning to the main list.
5. Push back. If an answer is vague, contradicts an earlier decision, or hides an edge case, say so and ask again. Do not accept "we'll figure it out later" for anything that shapes the data model or core flow.
6. If a question can be answered by reading the codebase or project docs, look it up instead of asking.
7. Keep a running decision log. Every 5-6 questions, show the user what has been decided so far.

## Finishing

Stop when no open questions remain that would change the design. Then produce:
- A concise spec: decisions made, with the reasoning behind each.
- Open questions deliberately deferred, and why deferring them is safe.
- A suggested build order of small, testable steps.

Offer to save the spec to the project so it can guide later work.