# stop-phrase-guard Plugin

A `Stop` hook that scans the assistant's last message for ownership-dodging and session-quitting phrases and forces the assistant to keep working instead of stopping.

See [`scripts/stop-phrase-guard.sh`](scripts/stop-phrase-guard.sh) for the full pattern list and corrections.

## Credits

This plugin is a fork of prior art by two other authors. Both deserve the credit:

- **benvanik's original `stop-phrase-guard.sh`** — <https://gist.github.com/benvanik/ee00bd1b6c9154d6545c63e06a317080>. Introduced the overall approach (Stop hook + pattern/correction table + block decision), the category structure, and most of the correction wording.
- **LITl-l's portable adaptation** — <https://github.com/LITl-l/dotfiles/blob/main/claude/stop-phrase-guard.sh>. Trimmed the pattern set and stripped out CLAUDE.md-specific references so the corrections stand on their own.

This plugin packages LITl-l's trimmed pattern set as a Claude Code plugin, reformatted to match this repo's conventions.

## Installation

```bash
claude plugin install stop-phrase-guard@motlin-claude-code-plugins
```
