---
name: recap
description: End-of-turn recap footer. ALWAYS use this skill before returning control to the user.
---

# Recap Footer

End every message that returns control to the user with these two lines, after a blank line, as the last thing in the message:

```text
📌 You asked: Make Claude end every turn with a recap and a link.
🔗 [PR #42](https://github.com/motlin/claude-code-plugins/pull/42)
```

The user multitasks. When they come back to the terminal they have forgotten what the session was about and have not scrolled up. The footer replaces the context they lost.

## The recap line

One sentence restating the user's original request in their framing — not a summary of what you did.

- Good: `📌 You asked: Find out why the nightly build times out.`
- Bad: `📌 You asked: I added a timeout flag and reran the suite.`

When a session covers several requests, recap the one currently being worked. When the current request is a follow-up, recap the thread it belongs to rather than the last message alone.

## The link line

The URL the user is most likely to want next: pull request, issue, CI run, deployed site, dev server, documentation page, dashboard.

Always Markdown link syntax — `🔗 [short label](URL)`. A bare URL, with or without angle brackets, is not reliably turned into a link by every renderer, so it can arrive as text the user cannot click.

```text
🔗 [CI run](https://github.com/motlin/claude-code-plugins/actions/runs/1234567890)
🔗 [Dev server](http://localhost:5173/)
🔗 None
```

- Prefer something created or discussed this session, even far earlier in the conversation — that is the case this footer exists for.
- Keep the label short and recognizable: `PR #42`, `CI run`, `Dev server`.
- Repeat a URL from earlier turns rather than dropping the line. The user has not scrolled up.
- Write `🔗 None`, with no brackets, only when nothing applies.

## When work is still running

When a turn ends while work you started is still running — background shells, subagents, workflows, CI waits — the user may read the turn as finished and close the session, which kills that work. Before the footer, add a status block:

```text
**Still running — don't exit.** The CI wait on 7 pull requests, about 20 minutes.

**Done so far:** Rebased and pushed 7 branches; 27 pull requests green.
**Next:** When CI finishes, fix failures and ask before any push.
```

- Lead with the bold banner, so it is the first thing the user sees.
- Name each piece of running work, not just "agents are working".
- Give a rough time estimate, or say it is unknown.
- Repeat the block on every turn that ends while work is running, including turns that only acknowledge a background notification.
- Omit the block when nothing you started is still running.

## Always both lines

Emit the footer on every turn: trivial answers, questions back to the user, refusals, and turns that changed nothing. Both lines are always present, even when the recap is short and the link is `None`.

The footer is the whole ending — do not follow it with more prose. A closing question to the user, an AskUserQuestion call, or a still-running status block comes before the footer.
