---
name: upstream-sync
description: 'Investigate a local web app against the upstream product it clones (a local claude.ai/code browser, a Workflowy replica), feature by feature, with serial browser subagents in a recursive Workflow, and produce per-feature gap files with red/green TDD tasks plus a prioritized roadmap. Use when the user wants to sync, diff, or reach parity with upstream, or to find everything upstream has that the local app lacks.'
---

# Upstream sync

Bring a local app to near-exact parity with the upstream product it mirrors: same features, DOM structure, class names and CSS values, minus anything with no local meaning. The output is investigation only, written under `.llm/upstream-sync/`. Implementation comes afterward, from the roadmap.

The engine is a Workflow script, `<plugin-root>/scripts/upstream-sync-workflow.js`. Resolve `<plugin-root>` as `${CLAUDE_PLUGIN_ROOT}`. The script runs:

- **Broad:** a code-only local inventory and a browser survey of upstream, in parallel. The survey seeds the feature queue.
- **Investigate:** one browser investigator per feature, strictly serial because they share Chrome. Priority order is P1, then P2, then P3. Each investigator writes `features/<slug>.md` and returns any new features it discovered, which join the queue, so the investigation recurses.
- **Critic:** up to `maxCriticRounds` completeness reviews, each adding missed features, until a round adds nothing.
- **Synthesize:** `SUMMARY.md`, a roadmap ordered by milestone.

The orchestrator owns `features.md` and rewrites it every `registryEvery` investigations. Investigators never edit it, so the queue never gets duplicate or conflicting rows.

## Settle the safety model before anything else

Find out whether interacting with upstream or the local app changes real data. For example, both sides may write to the user's real account, or opening a page may create a record. Ask the user with AskUserQuestion, with these options:

- **Sandbox:** create one dedicated container, such as a top-level node, a scratch project or a test document. Investigators may edit only inside it, and may only read everywhere else.
- **Strictly read-only:** no edits anywhere. Editing behavior is decoded from the DOM and the JS bundle.
- **User performs edits:** investigators stop and ask the user to take any action that mutates data.

Create the sandbox through the project's own write path (its CLI or API), never by editing a cache or database directly. Then verify that it exists, and that it exists exactly once.

Write the rules as concrete, checkable instructions. Include the sandbox's id and URL, and the shortcuts that act on the focused item, so investigators verify focus before pressing them. These rules become the `safety` arg.

## Lay out the sync directory

Create `.llm/upstream-sync/` and confirm it is gitignored. Then fill it:

- `README.md`: copy `protocol-template.md` from this skill's directory and replace every `{{PLACEHOLDER}}`. `{{CONTEXT}}` says how the local app differs from upstream on purpose: local extras to keep, upstream features that will never apply.
- `features.md`: a stub. The workflow overwrites it once the survey finishes.
- `features/` and `dumps/`: create empty.

If an earlier sync left this directory behind, read its `README.md` Tips and `SUMMARY.md` first. Carry the lessons forward instead of starting over.

## Verify the local app is running

Check that the local dev server is listening on the expected port and that an HTTP request returns a non-error response, before launching. Also confirm the user is logged in to upstream in the Chrome profile that claude-in-chrome drives.

## Launch the workflow

Call Workflow with `scriptPath: <plugin-root>/scripts/upstream-sync-workflow.js` and these `args`:

| Arg                           | Meaning                                                                                                                                         |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `dir`                         | Absolute path of the sync directory                                                                                                             |
| `upstreamName`, `upstreamUrl` | The product being cloned and where to reach it                                                                                                  |
| `localName`, `localUrl`       | The local app and its running dev URL                                                                                                           |
| `localSource`                 | Absolute path of the local source                                                                                                               |
| `context`                     | Intentional differences, as in `{{CONTEXT}}`                                                                                                    |
| `safety`                      | The concrete safety rules; this text goes into every browser prompt                                                                             |
| `surveyFocus`                 | Optional: surfaces and features to make sure the survey covers                                                                                  |
| `inventoryFocus`              | Optional: local areas to make sure the inventory covers                                                                                         |
| `approvedExceptions`          | Optional: actions the user approved after an incident; this text goes only into investigator prompts                                            |
| `acknowledgeSurveyIncidents`  | Optional: true once the user has reviewed a survey incident, so a resumed run continues                                                         |
| `only`                        | Optional: a list of `{slug, name, priority, notes}` to re-investigate, skipping the broad and critic phases and merging rows into `features.md` |
| `maxInvestigations`           | Default 150; anything left over is listed as not investigated                                                                                   |
| `maxCriticRounds`             | Default 3                                                                                                                                       |
| `registryEvery`               | Default 6; how often `features.md` is rewritten                                                                                                 |

The run is long. Tell the user the run id, that `/workflows` shows progress, and that `features.md` plus the `features/` file count are the live progress readout.

## While it runs

Don't edit the local source. The dev server hot-reloads under the investigators, and the findings would describe a moving target. Batch any bugs worth fixing until the run ends.

## When it halts on a safety incident

The workflow stops at the first reported incident. A survey incident stops it before any investigation; an investigator incident stops it after that investigation, and the summary is still written.

- Verify the damage independently through a primary source, such as the upstream API or the project's CLI. An agent's report that it undid something is not proof.
- Report what happened and what you verified, and ask the user how to continue.
- To resume, re-invoke Workflow with the persisted script path from the original result and `resumeFromRunId`, so completed agents replay from cache. Keep `safety`, `context` and the survey args unchanged: changing any text in a cached prompt re-runs that agent and everything after it. Put newly approved actions in `approvedExceptions`, and set `acknowledgeSurveyIncidents: true` when the incident came from the survey. Update the README's Tips to match the decision.

## When investigators fail

An investigator whose agent dies (a network drop, a terminal API error) is retried once automatically, with a prompt that tells it to reuse any partial dumps. If the retry dies too, the feature is marked `failed` and the run moves on. Don't stop the run to fix it: the result lists the failed slugs. After the run finishes, launch a fresh Workflow with the same args plus `only` set to those features (take name, priority and notes from `features.md`). Never run it while the main run is still going, because the two would fight over the browser.

## After the run

Read `SUMMARY.md` and the result's `notInvestigated` and `failed` lists, and report them. The usual next step is to import the roadmap into `.llm/todo.md` with the markdown-tasks import-plan skill, and work it with do-all-tasks.

Append any lesson that would help the next project to the Tips section of `protocol-template.md` in this plugin, not only to the project's README.
