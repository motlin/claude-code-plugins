---
description: Demo working software with real IO captured deterministically
arguments:
    - name: target
      description: What to demo — a feature, a fix, a command, a page (optional)
      required: false
---

🎬 Demo what was built, by showing real data crossing real boundaries.

ALWAYS use the `demo:demo` skill.

The user asked to see: `$ARGUMENTS`

If that is empty, demo the work done so far in this session.

## Plan the trace

- Decide which boundaries this thing crosses — request on the wire, command, SQL, on-disk shape, rendered output
- Pick a slug for the demo and keep the whole trace under it
- List the steps as internal todos, since they will be delivered across several pauses

## Capture each step

- Run every step through `${CLAUDE_PLUGIN_ROOT}/scripts/demo-capture` so its output is recorded, not authored
- Attach screenshots and other files with `${CLAUDE_PLUGIN_ROOT}/scripts/demo-attach`
- Use real data, and start from a state shown to be empty
- For a fix, capture the same command before and after so the difference is visible

## Deliver one step at a time

- Present one step, explain what to look for in its output, then stop
- Ask for sign-off with AskUserQuestion before moving on
- Never dump the whole trace at once

## Finish

- Render with `${CLAUDE_PLUGIN_ROOT}/scripts/demo-render.py` and open the page
- State plainly what the demo does not prove
