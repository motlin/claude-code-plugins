# Upstream sync investigation (started {{DATE}})

Goal: bring {{LOCAL_NAME}} ({{LOCAL_URL}}, source in `{{LOCAL_SOURCE}}`) to near-exact parity with {{UPSTREAM_NAME}} ({{UPSTREAM_URL}}): same features, DOM structure, class names and CSS values, minus anything with no local meaning.

{{CONTEXT}}

Statuses: `missing`, `partial`, `equivalent`, `better-locally` (a local extra or a local improvement worth keeping), `not-applicable` (upstream-only, e.g. cloud, billing, collaboration).

This effort is investigation only: feature files with proposed red/green TDD tasks. Nobody edits the local source or tests during it.

## Data safety

{{SAFETY}}

Rules that apply to every project:

- Never change settings, themes, account, sharing or billing on either side.
- Open menus, dialogs and pickers freely, but close them ONLY with Escape. A click inside an open list selects an item.
- Upstream UI preferences often live in localStorage or IndexedDB. If you toggle one to test it, restore the original value before finishing.
- Before any write action (typing, clicking, pressing a key), re-read `location.href` in the same step and act only on a page the rules allow. Pages can be bridged to live processes (a claude.ai session may drive a local terminal), and a screenshot taken before an earlier action doesn't show where the next one lands.
- If you change something the rules forbid, undo it at once and report it in `safetyIncidents`. The orchestrator halts the run on any incident.

## Protocol for investigator subagents

Investigations run ONE AT A TIME because they share the browser. Each agent:

- Reads this README, `features.md`, `local-inventory.md` and `upstream-survey.md` first.
- Investigates exactly its assigned feature on BOTH sides:
    - Upstream: {{UPSTREAM_URL}} in its OWN new browser tab, closed when done (in Claude Code, the claude-in-chrome tools: call tabs_context_mcp first, then create a tab). Extract real `outerHTML`, matched CSS rules and computed styles by running JavaScript in the page; never describe from screenshots alone. Save large dumps to `dumps/<slug>-*.html|json|txt`. Fetch and grep the upstream JS bundle to decode behavior that is hard to trigger, and save excerpts to `dumps/`.
    - Local: the source in `{{LOCAL_SOURCE}}` and the running app at {{LOCAL_URL}} (its own tab, closed when done).
- Writes `features/<slug>.md` using the template below.
- Does NOT edit `features.md`; the orchestrating workflow owns the queue. It reports discovered features in its structured output instead.
- Does NOT edit the local source, tests, or anything outside this directory.

## Feature file template

```
# <Feature name>
Slug: <slug> · Status: done · Investigated: <date>
Upstream location: <where in UI / how to reach it>
Local status: missing | partial | equivalent | better-locally | not-applicable
Local-only adaptation: <how it maps to the local app, or "n/a">

## Upstream behavior
<precise behavior: triggers, states, keyboard, empty states, edge cases>

## Upstream DOM/CSS
<key structure + exact class names + computed styles; reference dumps/>

## Local today
<files:lines, what exists, how it differs>

## Gaps
- <bullet per concrete difference>

## Proposed tasks
- <self-contained task: files to touch, behavior, red/green TDD tests>

## Discovered features
- <slug>: <one line>
```

## Tips (agents: append new lessons here)

- claude-in-chrome: javascript_tool output is capped at about 1000 characters. For large dumps, write the text into a hidden element and read it with get_page_text, or chunk it.
- Synthetic KeyboardEvents dispatched from JS usually don't trigger app handlers. Press real keys with the computer tool's `key` action.
- claude-in-chrome: if the Chrome tab group vanishes, call tabs_context_mcp with createIfEmpty and continue in a fresh tab; report orphaned tab IDs.
- Navigation can create data. Some buttons that look read-only (a "Today" button, a "new draft" route) create records as a side effect. Read the bundle before clicking anything that might.
- A local dev server hot-reloads, so local behavior can change under you if someone edits the source during the run. Report anything that looks like that.
- Registry rows from runs before declines counted as failures can say `done` while holding a placeholder ("NOT INVESTIGATED… the user asked …"). Treat a `done` row as real only when its feature file exists.
