# recap

Ends every turn with a one-sentence recap of the user's request and a Markdown link to the URL they most likely want next.

- `recap:recap` skill: the footer format
- `turn.complete` function hook (`mod/register.ts`, Claude Code only): when an answer ends without the footer, draws it beneath the answer. Claude Haiku writes the recap from the prompts you typed; the link is the newest pull request, CI run, issue, or dev server URL in the conversation. Nothing blocks the stop, so a missed footer costs no extra turn. Codex gets the skill alone.
