The finish pipeline has not run. Spawn the `orchestration:finish` agent now.

It handles building, committing, simplifying, and rebasing — the full completion pipeline. Do not attempt individual steps yourself. Do not run pipeline steps inline. The finish agent exists so nothing gets missed.

The build runs linters, formatters, and tests on every commit — including for docs and markdown. There is no type of change that can skip the build. Even a one-line doc edit gets linted and formatted.

Leave the repo clean. If something is dirty, fix it.

## Examples of invalid excuses

"This was a pure analysis session with no changes."

- If there are no changes, the check passes and you wouldn't be reading this. Something is dirty. Fix it.

"The skip-test-check file is appropriate here since there are genuinely no changes."

- Creating the skip file to avoid running the finish pipeline is never appropriate on the first attempt.

"No git test results found for HEAD, but I didn't make any changes."

- Someone forgot to run the finish pipeline earlier. Run it now. Previous sessions' mistakes are yours to fix.
