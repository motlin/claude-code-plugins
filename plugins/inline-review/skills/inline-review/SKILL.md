---
name: inline-review
description: Review a branch or PR with a panel of specialist reviewer subagents (the code-review plugin, pr-review-toolkit, the built-in /code-review, and mattpocock's code-review), verify and deduplicate their findings, label each as a Conventional Comment (issue, suggestion, question, nitpick, note, praise), and post them inline into a Plannotator review session. Use when the user wants an AI review whose questions, explanations, bugs, and nits appear inline on the diff.
---

# Inline Review

Run several specialist reviewers over one diff, merge what they find into a single set of Conventional Comments, and post the set into a Plannotator review session, where each finding appears inline on the diff line it is about.

The reviewers favor recall: each looks at the diff through one lens and reports everything it can support. This skill supplies the precision: it verifies risky findings, merges duplicates, and drops anything unsupported before anything is posted.

## Pin the target and capture the diff

The target is a PR (number or URL) or a base ref for the current branch. With a PR, read its title, body, base, and head with `gh pr view <pr> --json title,body,baseRefName,headRefOid,url`. Without one, use the base the user named, or the repository's default branch from `git symbolic-ref --quiet --short refs/remotes/origin/HEAD`.

Capture the patch once, into the scratchpad, from the merge base:

```bash
merge_base="$(git merge-base "$base" "$head")"
git diff --no-ext-diff --no-color --src-prefix=a/ --dst-prefix=b/ "$merge_base" "$head" -- > "$scratch/review.patch"
```

For a PR whose head is not checked out locally, use `gh pr diff <pr> > "$scratch/review.patch"` instead. Stop on an empty patch.

Collect the context every reviewer gets: the PR title and body (or the commit subjects), the patch path, the list of changed files, and the paths of every `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or `CODING_STANDARDS.md` at the root or in a directory containing a changed file.

## Open the Plannotator session

Reuse a session the user names. Otherwise start one in the background and read its URL from the output line `Plannotator session ready: http://localhost:<port>`:

```bash
plannotator review <pr-url-or-nothing-for-local-changes>
```

Verify the session before posting: `curl -sf "$url/api/external-annotations"` must succeed.

## Run the reviewers

Launch every reviewer that applies as parallel subagents in one message. Each gets the shared context from the capture step and the finding format below, and returns only a JSON array of findings. Tell each reviewer that the panel favors recall, that it should report every finding it can support with the code, and that verification happens later.

| Reviewer                                  | Source                             | Lens                                                                          | Applies when             |
| ----------------------------------------- | ---------------------------------- | ----------------------------------------------------------------------------- | ------------------------ |
| `code-review:bugs-diff`                   | code-review plugin, agent 3        | Obvious bugs visible in the diff alone                                        | always                   |
| `code-review:bugs-introduced`             | code-review plugin, agent 4        | Security problems and wrong logic in the changed code                         | always                   |
| `code-review:standards-docs`              | code-review plugin, agents 1 and 2 | Violations of the collected `CLAUDE.md` files, quoting the rule               | a standards file exists  |
| `claude-code:code-review`                 | built-in `/code-review`            | Correctness, plus reuse, simplification, and efficiency                       | always                   |
| `pr-review-toolkit:code-reviewer`         | pr-review-toolkit                  | Project guidelines and bugs, with confidence scores                           | always                   |
| `pr-review-toolkit:silent-failure-hunter` | pr-review-toolkit                  | Swallowed errors, empty catches, bad fallbacks                                | error handling changed   |
| `pr-review-toolkit:pr-test-analyzer`      | pr-review-toolkit                  | Missing or weak tests for the changed behavior                                | always                   |
| `pr-review-toolkit:comment-analyzer`      | pr-review-toolkit                  | Comments and docs that are wrong or will rot                                  | comments or docs changed |
| `pr-review-toolkit:type-design-analyzer`  | pr-review-toolkit                  | Invariants and encapsulation of new types                                     | types added or changed   |
| `pr-review-toolkit:code-simplifier`       | pr-review-toolkit                  | Simpler equivalent code                                                       | always                   |
| `mattpocock:standards`                    | mattpocock code-review             | Documented repo standards plus the Fowler smell baseline                      | always                   |
| `mattpocock:spec`                         | mattpocock code-review             | Missing, wrong, or unrequested behavior against the issue or PR body          | a spec exists            |
| `inline-review:reader`                    | this skill                         | Questions a careful reader would ask, and explanations of non-obvious changes | always                   |

How to launch each family:

- **code-review plugin**: the prompts are the agent briefs in that plugin's `commands/code-review.md`. Use Opus for the two bug reviewers. Drop the plugin's "high signal only" filter, because this skill verifies findings afterwards; keep its list of false positives as guidance.
- **built-in `/code-review`**: a general-purpose subagent changes into a checkout of the reviewed head, invokes the `code-review` skill at `medium` effort with the base branch or ref as its target, without `--comment` or `--fix`, and converts what it reports into the finding format. The skill reviews the checkout it runs in, so started anywhere else it reviews the wrong code. When it returns nothing, the subagent applies the same recipe itself: correctness bugs, plus reuse, simplification, and efficiency.
- **pr-review-toolkit**: use the `pr-review-toolkit:<agent>` subagent type when it is available. Otherwise read the agent definition from `plugins/pr-review-toolkit/agents/<agent>.md` in the `claude-plugins-official` marketplace under `~/.claude/plugins/marketplaces/`, and pass its body as a general-purpose subagent's prompt.
- **mattpocock code-review**: the briefs and the smell baseline are in that skill's `SKILL.md` (the `mattpocock-skills` plugin). Paste the smell baseline into the standards prompt in full. Every smell is a judgement call: label it `suggestion` or `thought` with the `non-blocking` decoration, never a blocking `issue`.
- **inline-review:reader**: ask for `question` findings where intent, a design choice, or an edge case is unclear from the diff and its surroundings; `note` findings that explain a non-obvious change to a reader of the diff (what it does and why, in two to four sentences); and `praise` only for something genuinely well done. Anchor each to the line it is about.

## The finding format

Every reviewer returns a JSON array of objects:

```json
{
  "label": "issue",
  "decorations": ["blocking"],
  "file": "src/app.py",
  "line": 42,
  "end_line": 44,
  "side": "new",
  "title": "Retries never stop when the server returns 503",
  "body": "Markdown. Explain what goes wrong, for which input, and why. Use `code`, lists, and fenced blocks.",
  "suggested_code": "Optional replacement for exactly lines 42-44, only when applying it fully fixes the finding.",
  "reasoning": "How the finding was confirmed: the call chain, the input, the line that misbehaves.",
  "pre_existing": false,
  "sources": ["code-review:bugs-introduced"]
}
```

- `label` is one Conventional Comments label: `issue` (a bug or a real problem), `suggestion` (a concrete improvement), `question` (the reviewer needs an answer), `nitpick` (trivial, preference-level), `note` (an explanation for the reader), `praise`, `thought`, `todo`, `typo`, `polish`, or `chore`.
- `decorations` is any of `blocking`, `non-blocking`, `if-minor`. A bug that must be fixed before merge is `issue` + `blocking`.
- `file` is the path as it appears after `b/` in the patch. `side` is `new` for added or context lines and `old` for deleted lines. `line` and `end_line` are line numbers on that side, inside one hunk.
- `pre_existing` marks a problem that the change did not introduce but touches.
- `sources` names the reviewers that reported it.

## Verify, merge, and rank

Run this pass once every reviewer has returned.

Verify every `issue` and every `blocking` finding with its own subagent, in parallel. Give it the shared context and the one finding, and ask it to confirm or refute the finding by reading the code, not the reviewer's argument. Use Opus for bugs and logic, and Sonnet for documented-standard findings. A verifier may downgrade the label (for example, `issue` to `question` when the behavior depends on intent) or drop the finding. Put the verifier's evidence in `reasoning`. Do not verify questions, notes, praise, or non-blocking findings; these are judged during the merge.

Merge the surviving findings:

- Treat two findings as one when they anchor to overlapping lines in the same file and describe the same problem. Keep the clearest title and body, the strongest label, and the union of `sources`. Agreement between reviewers is worth stating in `reasoning`.
- Drop findings that a linter or formatter would catch, findings about unchanged code (unless `pre_existing` and directly relevant), pure restatements of the diff, and anything vague enough that the author could not act on it.
- Keep at most one `note` per hunk, and only where the change is not self-explanatory.

Order the findings: blocking issues, then other issues, suggestions, questions, notes, nitpicks, and praise.

Write a summary of the change for the general comment that opens the review: two to five sentences on what the change does, then a short list of the blocking issues (if any) and how many findings of each label follow.

Write the review document to the scratchpad as `{"summary": "...", "findings": [...]}`.

## Post to Plannotator

Preview the payload first, then post it:

```bash
python3 {baseDir}/scripts/post_findings.py --findings "$scratch/review.json" --diff "$scratch/review.patch"
python3 {baseDir}/scripts/post_findings.py --findings "$scratch/review.json" --diff "$scratch/review.patch" --url "$url"
```

The script checks every label and decoration, keeps a finding on its line only when every line in its range appears in that side of the patch, and otherwise moves it to a whole-file comment (or a general comment when the file is not in the patch) with the location in its title. It deletes the annotations of any earlier run of this skill in the same session, posts the new ones, and then sets each one's Conventional Comments label and decorations. Fix reported input errors in the review document rather than working around the script.

Report to the user: the session URL, the number of findings per label, the blocking issues by title, and which reviewers ran or were skipped and why. Nothing is posted to GitHub; the user decides what to send from Plannotator.
