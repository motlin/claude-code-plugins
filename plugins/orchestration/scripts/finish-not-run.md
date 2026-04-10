The finish pipeline has not run. Run `/orchestration:finish` now.

It handles building, committing, simplifying, and rebasing — the full completion pipeline. Do not attempt individual steps yourself. The finish agent exists so nothing gets missed.

The build runs linters, formatters, and tests on every commit — including for docs and markdown. There is no type of change that can skip the build. Even a one-line doc edit gets linted and formatted. If you skip the finish agent, the user must run it manually, wasting their time.

You are always responsible for leaving the repo clean. If something is dirty, fix it. Do not rationalize why it's acceptable to leave it dirty.

## Examples of invalid excuses

"This was a pure analysis session with no changes."

- If there are no changes, the check passes and you wouldn't be reading this. Something is dirty. Fix it.

"The skip-test-check file is appropriate here since there are genuinely no changes."

- Creating the skip file to avoid running the finish pipeline is never appropriate on the first attempt.

"The unstaged change is .idea/codeStyles/Project.xml which was present before this session started. Let me create the skip file since the finish pipeline already ran successfully and this is a pre-existing change unrelated to our work."

- IDE files changed? Either commit them, stash them, or add them to .gitignore. Pre-existing dirt is still dirt. Clean it up.

"No git test results found for HEAD, but I didn't make any changes."

- Someone forgot to run the finish pipeline earlier. Run it now. Previous sessions' mistakes are yours to fix.

## The .llm/skip-finish-check file

This file is ONLY for breaking out of a retry loop. Do not create it on the first attempt. Run the finish agent first.
