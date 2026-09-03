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

- Decide which boundaries this thing crosses — request on the wire, command, SQL, on-disk representation, rendered output
- Pick the capture tool per step: `showboat exec` for anything a shell can show, `rodney` for a web page, `vhs` for a terminal UI, `chartroom` for charts
- List the steps as internal todos, since they will be delivered across several pauses

## Capture each step

- Build the document with `uvx showboat`, so every byte of output is recorded rather than written
- Use real data, and start from a state shown to be empty
- Reset state inside a captured step, so `showboat verify` can pass
- For a fix, capture the same command before and after so the difference is visible

## Deliver one step at a time

- Present one step, explain what to look for in its output, then stop
- Ask for sign-off with AskUserQuestion before moving on
- Never dump the whole trace at once

## Hand it over where the user is

- Render with `${CLAUDE_PLUGIN_ROOT}/scripts/demo-render.py`
- Check `${CLAUDE_PLUGIN_ROOT}/scripts/demo-presence` rather than assuming the user is at this machine
- Publish as an artifact when the Artifact tool is available, otherwise over the tailnet with `${CLAUDE_PLUGIN_ROOT}/scripts/demo-publish`, and send the file as well
- Never finish with only a local `open` and a path on this machine

## Finish

- Run `uvx showboat verify` and report the result honestly
- State plainly what the demo does not prove
