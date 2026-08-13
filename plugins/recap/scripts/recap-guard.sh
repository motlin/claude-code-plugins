#!/usr/bin/env bash
# Stop hook: enforces the end-of-turn recap footer.
#
# Every turn that hands control back to the user must end with two lines:
#
#     📌 You asked: <one sentence restating the user's original request>
#     🔗 [label](url)             (or "🔗 None")
#
# The footer exists because long, multitasked sessions end in a wall of text.
# When the user returns to the terminal, the last message assumes context they
# no longer have: what the session was about, and the URL mentioned hundreds of
# lines earlier.
#
# The recap skill teaches the format; this hook is the backstop. When the footer
# is missing, the hook blocks the stop and asks for the footer alone.

set -Eeuo pipefail

# Escape hatch for headless and cron sessions, where a blocked stop only burns
# tokens on a recap nobody reads.
if [[ "${RECAP_GUARD:-}" == "off" ]]; then
    exit 0
fi

json=$(cat)

# Prevent infinite loops: if the hook already fired once this turn, let the
# assistant stop. One correction per turn is enough.
hook_active=$(echo "$json" | jq --raw-output '.stop_hook_active // false')

if [[ "$hook_active" == "true" ]]; then
    exit 0
fi

message=$(echo "$json" | jq --raw-output '.last_assistant_message // empty')

if [[ -z "$message" ]]; then
    exit 0
fi

# Both markers must start a line, so prose that merely mentions them does not
# satisfy the check.
if printf '%s\n' "$message" | grep -q '^📌 ' && printf '%s\n' "$message" | grep -q '^🔗 '; then
    exit 0
fi

read -r -d '' reason <<'EOF' || true
RECAP FOOTER MISSING. Do not redo the work and do not summarize what you did. Send only the two footer lines:

📌 You asked: <one sentence restating the user's original request, in their framing>
🔗 [short label](URL)

The 🔗 line carries the URL the user is most likely to want next (pull request, issue, CI run, deployed site, dev server, doc). Always Markdown link syntax, never a bare URL — a bare URL can render as text the user cannot click. It may come from far earlier in the conversation — the user has not scrolled up. Try hard to find one; write "🔗 None" only when nothing applies.
EOF

jq --null-input --arg reason "$reason" '{
    decision: "block",
    reason: $reason
}'
