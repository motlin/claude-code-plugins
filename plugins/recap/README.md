# recap

Ends every turn with a one-sentence recap of the user's request and a Markdown link to the URL they most likely want next.

- `recap:recap` skill: the footer format
- `Stop` hook (`scripts/recap-guard.sh`): blocks a stop missing the footer, at most once per turn. Set `RECAP_GUARD=off` to disable it for headless or scheduled sessions.
