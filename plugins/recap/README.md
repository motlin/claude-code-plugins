# recap Plugin

Ends every turn with two lines: a one-sentence recap of what the user asked for, and the URL they are most likely to want next.

```text
📌 You asked: Make Claude end every turn with a recap and a link.
🔗 [PR #42](https://github.com/motlin/claude-code-plugins/pull/42)
```

Long, multitasked sessions end in a wall of text. When you return to the terminal, the final message assumes context you no longer have — what the session was about, and the URL mentioned hundreds of lines earlier that you never scrolled back to.

## Components

- [`skills/recap/SKILL.md`](skills/recap/SKILL.md) teaches the format so the assistant writes the footer unprompted.
- [`scripts/recap-guard.sh`](scripts/recap-guard.sh) runs on the `Stop` hook and blocks the stop when the footer is missing, asking for the two lines alone. It fires at most once per turn.

Set `RECAP_GUARD=off` to disable the hook for headless or scheduled sessions.

## Installation

```bash
claude plugin install recap@motlin-claude-code-plugins
```
