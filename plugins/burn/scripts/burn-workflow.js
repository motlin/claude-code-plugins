export const meta =
{
	name: "burn",
	description:
		"Fan out improvement tracks over existing code, one worktree each; build each design question they raise as an idea branch; verify, test-gate, rank and report the surviving local branches",
	whenToUse:
		"Spending spare weekly quota on real improvements, launched by the burn skill with its preflight results as args",
	phases: [
		{
			title: "Run tracks",
			detail: "one agent per track run, each in its own worktree and branch",
		},
		{
			title: "Build ideas",
			detail: "one agent per design question, each on its own idea branch with a keep or drop recommendation",
		},
		{
			title: "Verify",
			detail: "fresh-context verifiers try to refute each branch",
		},
		{
			title: "Gate",
			detail: "the test command must pass on each surviving branch",
		},
		{
			title: "Rank and report",
			detail: "rank branches, update the ledger, write REPORT.md",
		},
	],
};

// args (the burn skill's preflight fills them):
//   repo         absolute path of the repository
//   base         commit every track branch starts from
//   date         run date, YYYY-MM-DD; names branches and the run directory
//   runDir       absolute path of .llm/burn/<date>
//   worktreeRoot directory that holds the track worktrees, outside the repo
//   ledger       absolute path of scripts/ledger.py
//   testCommand  command that proves a branch green, or null when the repo has none
//   gitTest      true when git-test is configured; the gate then runs `git test run`
//   tier         { runs, votes, effort }; effort is passed to the track and idea agents and fills {level} in invokes
//   reportTemplate absolute path of skills/burn/references/report-template.md
//   runs         [{ track, shard, invokes, evidence, instructions }], in launch order
//   dismissed    [{ track, path, symbol }] findings the user dismissed
const A = args || {};
const TIER = A.tier;
const PLANNED = A.runs.slice(0, TIER.runs);
const DROPPED = A.runs.slice(TIER.runs);
const DISMISSED = A.dismissed || [];

// The user starts a burn and walks away, so every agent hears that a question
// would leave the run idle until they return.
const NO_ASK =
	"The user is away until the run ends: ask them nothing, and decide anything you would have asked about yourself.";
const ask = (prompt, opts) => agent(`${prompt}\n\n${NO_ASK}`, opts);

const FINDING =
{
	type: "object",
	properties:
	{
		path:
		{
			type: "string",
			description: "repo-relative file or directory the finding is about",
		},
		symbol:
		{
			type: "string",
			description: "function, class or rule id; never a line number",
		},
		title:
		{
			type: "string",
			description: "imperative one-line task title",
		},
		details:
		{
			type: "string",
			description:
				"self-contained body: exact files, the evidence, the change you would build, and what done looks like",
		},
	},
	required: ["path", "symbol", "title", "details"],
};

const TRACK_SCHEMA =
{
	type: "object",
	properties:
	{
		committed:
		{
			type: "boolean",
			description: "true only if the branch has at least one commit worth reviewing",
		},
		summary:
		{
			type: "string",
		},
		evidence:
		{
			type: "array",
			items:
			{
				type: "string",
			},
			description: "real command output or citations backing each change",
		},
		diffStat:
		{
			type: "string",
			description: "`git diff --shortstat <base>..HEAD`, empty when nothing was committed",
		},
		changesTests:
		{
			type: "boolean",
		},
		findings:
		{
			type: "array",
			items: FINDING,
			description: "design questions only, each built later as its own idea branch",
		},
		afterKept:
		{
			type: "array",
			items:
			{
				type: "string",
			},
			description:
				"steps outside git to carry out only once this branch is kept, such as deleting a memory the branch moved into the docs; omit when none",
		},
	},
	required: ["committed", "summary", "evidence", "diffStat", "changesTests", "findings"],
};

const IDEA_SCHEMA =
{
	type: "object",
	properties:
	{
		committed:
		{
			type: "boolean",
			description: "true only if the branch holds a complete, working implementation of the idea",
		},
		recommend:
		{
			type: "string",
			enum: ["keep", "drop"],
			description: "whether, having built it, you recommend the user keep this change",
		},
		rationale:
		{
			type: "string",
			description: "why you recommend keeping or dropping it, from what building it showed",
		},
		alternative:
		{
			type: "string",
			description: "the other answer to the question, which you did not build, in one sentence",
		},
		summary:
		{
			type: "string",
		},
		evidence:
		{
			type: "array",
			items:
			{
				type: "string",
			},
			description: "real command output backing the change and the recommendation",
		},
		diffStat:
		{
			type: "string",
			description: "`git diff --shortstat <base>..HEAD`, empty when nothing was committed",
		},
		changesTests:
		{
			type: "boolean",
		},
	},
	required: ["committed", "recommend", "rationale", "alternative", "summary", "evidence", "diffStat", "changesTests"],
};

const VERDICT_SCHEMA =
{
	type: "object",
	properties:
	{
		refuted:
		{
			type: "boolean",
		},
		reason:
		{
			type: "string",
		},
	},
	required: ["refuted", "reason"],
};

const GATE_SCHEMA =
{
	type: "object",
	properties:
	{
		passed:
		{
			type: "boolean",
		},
		output:
		{
			type: "string",
			description: "the last lines of the test output",
		},
	},
	required: ["passed", "output"],
};

const RANK_SCHEMA =
{
	type: "object",
	properties:
	{
		ranked:
		{
			type: "array",
			items:
			{
				type: "string",
			},
			description: "kept branch names, most valuable and cheapest to review first",
		},
		reportPath:
		{
			type: "string",
			description: "absolute path of the REPORT.md you wrote",
		},
	},
	required: ["ranked", "reportPath"],
};

const slug = (s) =>
	s
		.replace(/[^A-Za-z0-9]+/g, "-")
		.replace(/^-|-$/g, "")
		.toLowerCase() || "repo";

// Worktree names carry the repository name, as git:worktree's do, because
// worktreeRoot is shared by every repository beside this one and two repos
// burned on the same day would otherwise collide on the same path.
const REPO_NAME = slug(A.repo.split("/").filter(Boolean).pop() || "");

function identity(run)
{
	const name = `${run.track}-${slug(run.shard)}`;
	return {
		id: name,
		branch: `burn/${A.date}/${name}`,
		worktree: `${A.worktreeRoot}/${REPO_NAME}-burn-${A.date}-${name}`,
	};
}

const findingKey = (f) => [f.track, f.path, f.symbol].join("\0");
const dismissedKeys = new Set(DISMISSED.map(findingKey));

function trackPrompt(run, where)
{
	const invocation = run.invokes.replace("{level}", TIER.effort).replace("{paths}", run.shard);
	const dismissed = DISMISSED.filter((f) => f.track === run.track);
	return `You are the ${run.track} track of a burn run over ${A.repo}. Work only on existing code in ${run.shard}.

Create your worktree first: \`git -C ${A.repo} worktree add ${where.worktree} -b ${where.branch} ${A.base}\`. If that command fails, stop: change nothing, create no other worktree, and return committed: false. Later steps look for your work at exactly ${where.worktree}. Work and commit only inside ${where.worktree}, following the repo's commit conventions. Never push, never open a PR, never touch ${A.repo} itself.

Invoke: ${invocation}, unattended.

${run.instructions}

Evidence rule: ${run.evidence} A change without evidence is not committed.

${dismissed.length ? `The user dismissed these findings; never raise them again:\n${dismissed.map((f) => `- ${f.path} ${f.symbol}`).join("\n")}\n\n` : ""}If nothing is worth committing, commit nothing and return committed: false.

Sort every problem you find, including the ones the instructions above say to return:
- Fix every problem whose fix needs no decision on this branch, with its evidence, even when the skill you invoked would only queue it.
- Drop every problem nothing in this repository can fix, such as a third-party bug with no fixed release or work waiting on another project. Never return it.
- Return as findings only design questions: changes a reasonable maintainer could accept or reject. A later phase builds each one on its own branch, so put the change you would build in its details.`;
}

function ideaPrompt(f, where)
{
	return `You build one idea for a burn run over ${A.repo}. The ${f.track} track raised this design question and left it for you:

${f.title} (${f.path}, ${f.symbol})
${f.details}

Create your worktree first: \`git -C ${A.repo} worktree add ${where.worktree} -b ${where.branch} ${A.base}\`. If that command fails, stop: change nothing, create no other worktree, and return committed: false. Work and commit only inside ${where.worktree}, following the repo's commit conventions. Never push, never open a PR, never touch ${A.repo} itself.

Implement the change completely, as if the user had asked for it: the code, its tests, and the docs it touches, with the repo's tests passing. When the question has more than one answer, build the one you prefer and name the other as the alternative.

Building it is how you form an opinion. Once it works, judge it: does it leave the code simpler, safer or more useful, and is it worth the user's review? Recommend keep or drop, with a rationale that rests on what building it showed. Recommend drop when the change fights the design, grows the code without a matching gain, or turned out wrong, and commit the attempt anyway so the user can look.

If the idea cannot be built at all, commit nothing and return committed: false.`;
}

function verifyPrompt(run, where, result, vote)
{
	return `You are verifier ${vote + 1} of ${TIER.votes} for the burn branch ${where.branch} in ${A.repo}, made by the ${run.track} track. You have not seen how it was made.

Read \`git -C ${A.repo} diff ${A.base}..${where.branch}\` and this evidence:
${result.evidence.map((e) => `- ${e}`).join("\n")}

Summary from the track: ${result.summary}

Try to show the change is wrong, unnecessary, or changes behavior where it should not. Check that the evidence is real by rerunning what it cites where you can. Do not edit anything. Return refuted: true when you are not convinced the change is correct and worth a reviewer's time.`;
}

function ideaVerifyPrompt(where, result, vote)
{
	return `You are verifier ${vote + 1} of ${TIER.votes} for the burn idea branch ${where.branch} in ${A.repo}. An agent built it to answer a design question, and recommends keeping it because: ${result.rationale}

Read \`git -C ${A.repo} diff ${A.base}..${where.branch}\` and this evidence:
${result.evidence.map((e) => `- ${e}`).join("\n")}

Summary from the builder: ${result.summary}
The alternative it did not build: ${result.alternative}

The user decides whether the idea is wanted, so do not refute it for being a choice you would make differently. Refute it when the implementation is incomplete or wrong, when the evidence is not real, or when the diff does not support the rationale. Do not edit anything.`;
}

function gatePrompt(where)
{
	const command = A.gitTest ? `git test run ${A.base}..${where.branch}` : A.testCommand;
	return `In ${where.worktree}, run \`${command}\` once in the background, because it can outlast the foreground command time limit, and wait for it to exit, however long it takes. Report whether it passed only once it has exited; a run you stopped waiting for is not a result. Do not edit, fix, retry or commit anything.`;
}

// Steps outside git cannot ride on the branch, so they wait until the branch
// has earned its place; a refuted or gate-failed run never carries them out.
function afterKeptPrompt(where, steps)
{
	return `The burn branch ${where.branch} in ${A.repo} passed verification and the test gate. Carry out these steps its track deferred until now, then report which you completed. Do not touch the branch or ${A.repo}.
${steps.map((s) => `- ${s}`).join("\n")}`;
}

const AFTER_KEPT_SCHEMA =
{
	type: "object",
	properties:
	{
		done:
		{
			type: "boolean",
			description: "true when every step was carried out",
		},
		summary:
		{
			type: "string",
		},
	},
	required: ["done", "summary"],
};

async function keep(where, outcome, steps, tested)
{
	if (!steps || !steps.length)
		return {
			...outcome,
			status: "kept",
			tested,
		};
	const after = await ask(
		afterKeptPrompt(where, steps),
		{
			label: `after-kept:${where.id}`,
			phase: "Gate",
			schema: AFTER_KEPT_SCHEMA,
			effort: "low",
		},
	);
	return {
		...outcome,
		status: "kept",
		tested,
		afterKept:
		{
			steps,
			done: Boolean(after && after.done),
			summary: after ? after.summary : "the after-kept agent died",
		},
	};
}

const CLEANUP_SCHEMA =
{
	type: "object",
	properties:
	{
		worktreeRemoved:
		{
			type: "boolean",
			description: "true when the worktree is gone, or never existed",
		},
		branchDeleted:
		{
			type: "boolean",
		},
	},
	required: ["worktreeRemoved", "branchDeleted"],
};

// Cleanup never forces anything: a worktree with uncommitted changes stays as
// unfinished, and a branch with commits stays for the user to inspect.
function cleanupPrompt(where, keptBranch)
{
	const worktree = `If ${where.worktree} exists, run \`git -C ${A.repo} worktree remove ${where.worktree}\` with no other flags. If git refuses, leave the worktree as it is and return worktreeRemoved: false.`;
	const branch = keptBranch
		? `Keep the branch ${where.branch} and return branchDeleted: false.`
		: `Then, if the branch ${where.branch} exists and \`git -C ${A.repo} rev-list --count ${A.base}..${where.branch}\` prints 0, delete it with \`git -C ${A.repo} branch -d ${where.branch}\`. Otherwise keep it. Never delete a branch that has commits, and return whether you deleted it as branchDeleted.`;
	return `${worktree}\n\n${branch}`;
}

async function cleanup(where, keptBranch)
{
	const result = await ask(
		cleanupPrompt(where, keptBranch),
		{
			label: `cleanup:${where.id}`,
			phase: keptBranch ? "Rank and report" : "Run tracks",
			schema: CLEANUP_SCHEMA,
			effort: "low",
		},
	);
	return {
		branchDeleted: Boolean(result && result.branchDeleted),
		...(result && result.worktreeRemoved
			? {}
			:
				{
					unfinishedWorktree: where.worktree,
				}),
	};
}

// A run that ends without a kept branch cleans up and returns its outcome.
const settle = async (where, outcome) => (
{
	...outcome,
	...(await cleanup(where, false)),
});

async function trackChain(run)
{
	const where = identity(run);
	const outcome =
	{
		...where,
		track: run.track,
		shard: run.shard,
	};

	const result = await ask(
		trackPrompt(run, where),
		{
			label: `track:${where.id}`,
			phase: "Run tracks",
			schema: TRACK_SCHEMA,
			effort: TIER.effort,
		},
	);
	if (!result)
	{
		return settle(
			where,
			{
				...outcome,
				status: "failed",
				reason: "the track agent died",
			},
		);
	}
	outcome.summary = result.summary;
	outcome.evidence = result.evidence;
	outcome.diffStat = result.diffStat;
	outcome.findings = result.findings.map((f) => (
	{
		...f,
		track: run.track,
	}));
	if (!result.committed)
	{
		return settle(
			where,
			{
				...outcome,
				status: "empty",
				reason: "nothing worth committing",
			},
		);
	}

	return verifyAndGate(where, outcome, (vote) => verifyPrompt(run, where, result, vote), result.afterKept);
}

// Verify a committed branch, then gate it on the test command. A refuted or
// gate-failed branch settles; one that survives both is kept.
async function verifyAndGate(where, outcome, verify, afterKept)
{
	const votes = await parallel(
		Array.from(
			{
				length: TIER.votes,
			},
			(_, vote) => () =>
				ask(
					verify(vote),
					{
						label: `verify:${where.id}:${vote + 1}`,
						phase: "Verify",
						schema: VERDICT_SCHEMA,
					},
				),
		),
	);
	// A verifier that died counts as refuting: the branch must earn its place.
	const upheld = votes.filter((v) => v && !v.refuted).length;
	if (upheld * 2 <= TIER.votes)
	{
		return settle(
			where,
			{
				...outcome,
				status: "refuted",
				reason:
					votes
						.filter((v) => v && v.refuted)
						.map((v) => v.reason)
						.join(" / ") || "no verifier upheld it",
			},
		);
	}

	if (!A.testCommand) return keep(where, outcome, afterKept, false);
	const gate = await ask(
		gatePrompt(where),
		{
			label: `gate:${where.id}`,
			phase: "Gate",
			schema: GATE_SCHEMA,
			effort: "low",
		},
	);
	if (!gate || !gate.passed)
	{
		return settle(
			where,
			{
				...outcome,
				status: "gate-failed",
				reason: gate ? gate.output : "the gate agent died",
			},
		);
	}
	return keep(where, outcome, afterKept, true);
}

function ideaIdentity(f)
{
	const name = `idea-${slug(f.title).slice(0, 60).replace(/-$/, "")}`;
	return {
		id: name,
		branch: `burn/${A.date}/${name}`,
		worktree: `${A.worktreeRoot}/${REPO_NAME}-burn-${A.date}-${name}`,
	};
}

async function ideaChain(f)
{
	const where = ideaIdentity(f);
	const outcome =
	{
		...where,
		track: f.track,
		shard: f.path,
		kind: "idea",
		question: f.title,
	};
	const result = await ask(
		ideaPrompt(f, where),
		{
			label: `idea:${where.id.slice("idea-".length)}`,
			phase: "Build ideas",
			schema: IDEA_SCHEMA,
			effort: TIER.effort,
		},
	);
	if (!result)
	{
		return settle(
			where,
			{
				...outcome,
				status: "failed",
				reason: "the idea agent died",
			},
		);
	}
	outcome.summary = result.summary;
	outcome.evidence = result.evidence;
	outcome.diffStat = result.diffStat;
	outcome.recommend = result.recommend;
	outcome.rationale = result.rationale;
	outcome.alternative = result.alternative;
	if (!result.committed)
	{
		return settle(
			where,
			{
				...outcome,
				status: "empty",
				reason: result.rationale || "the idea could not be built",
			},
		);
	}
	// An idea its builder recommends dropping skips review: its branch stays
	// for the curious, and its slot under the branch cap goes to the next idea.
	if (result.recommend === "drop")
	{
		return {
			...outcome,
			status: "idea-dropped",
			reason: result.rationale,
			...(await cleanup(where, true)),
		};
	}
	return verifyAndGate(where, outcome, (vote) => ideaVerifyPrompt(where, result, vote), null);
}

// Every run launches at once and is never capped: spending the quota is the
// point, and each branch arrives with the evidence a reviewer needs.
async function runAll(items, chain, identify)
{
	return Promise.all(
		items.map((item) =>
			chain(item)
				.catch((e) => (
				{
					...identify(item),
					track: item.track,
					shard: item.shard || item.path,
					status: "failed",
					reason: String(e),
				}))
				.then((outcome) =>
				{
					log(`${outcome.id}: ${outcome.status}${outcome.reason ? ` (${outcome.reason})` : ""}`);
					return outcome;
				}),
		),
	);
}

phase("Run tracks");
if (DROPPED.length)
	log(`Tier allows ${TIER.runs} runs; not launched: ${DROPPED.map((r) => identity(r).id).join(", ")}`);
const trackOutcomes = await runAll(PLANNED, trackChain, identity);

const ideas = [];
const seen = new Set(dismissedKeys);
const ideaIds = new Set();
for (const o of trackOutcomes)
	for (const f of o.findings || [])
	{
		const id = ideaIdentity(f).id;
		if (seen.has(findingKey(f)) || ideaIds.has(id)) continue;
		seen.add(findingKey(f));
		ideaIds.add(id);
		ideas.push(f);
	}

// Every design question is built rather than queued or asked about; the user
// decides by looking at a working change and its builder's recommendation.
phase("Build ideas");
const ideaOutcomes = await runAll(ideas, ideaChain, ideaIdentity);

const outcomes = [...trackOutcomes, ...ideaOutcomes];
const kept = outcomes.filter((o) => o.status === "kept");

phase("Rank and report");
const covered = outcomes
	.filter((o) => o.status !== "failed" && o.kind !== "idea")
	.map((o) => (
	{
		track: o.track,
		shard: o.shard,
	}));
const runsJson = JSON.stringify(
	{
		date: A.date,
		base: A.base,
		tier: TIER,
		// Each track's findings were built as ideas, which have outcomes of their own.
		outcomes: outcomes.map(({findings: own, ...o}) => (
		{
			...o,
			...(own
				?
					{
						ideaCount: own.length,
					}
				: {}),
		})),
		notLaunched: DROPPED.map((r) => identity(r).id),
	},
	null,
	2,
);
const report = await ask(
	`You rank and report the burn run of ${A.date} over ${A.repo}. Read the template at ${A.reportTemplate} and follow it.

Phase results (write them verbatim to ${A.runDir}/runs.json first):
${runsJson}

Rank the kept branches by value to the user against review effort; read each one's diff with \`git -C ${A.repo} diff ${A.base}..<branch>\` to judge. Kept outcomes with kind "idea" are design questions for the user to decide, each with its builder's recommendation; report them as ideas, not as fixes.

Record coverage: for each of ${JSON.stringify(covered)}, run \`python3 ${A.ledger} --ledger ${A.repo}/.llm/burn/ledger.json record --track <track> --date ${A.date} <shard>\`.

You must write ${A.runDir}/REPORT.md from the template; the run is not reported until that file exists. Return its absolute path as reportPath. Do not push, open PRs, or delete any branch.`,
	{
		label: "rank-and-report",
		phase: "Rank and report",
		schema: RANK_SCHEMA,
	},
);
const reportPath = `${A.runDir}/REPORT.md`;
const reported = report && report.reportPath === reportPath;
if (!reported) log(`The report agent did not return ${reportPath}`);
const keptCleanups = await parallel(kept.map((o) => () => cleanup(o, true)));
kept.forEach((o, i) =>
{
	const left = keptCleanups[i] ? keptCleanups[i].unfinishedWorktree : o.worktree;
	if (left) o.unfinishedWorktree = left;
});

return {
	ranked: report ? report.ranked : kept.map((o) => o.branch),
	report: reported ? reportPath : null,
	outcomes: outcomes.map((o) => (
	{
		branch: o.branch,
		status: o.status,
		...(o.reason
			?
				{
					reason: o.reason,
				}
			: {}),
		...(o.status === "kept"
			?
				{
					tested: o.tested,
					...(o.kind === "idea"
						?
							{
								recommend: o.recommend,
							}
						: {}),
				}
			:
				{
					branchDeleted: o.branchDeleted,
				}),
		...(o.unfinishedWorktree
			?
				{
					unfinishedWorktree: o.unfinishedWorktree,
				}
			: {}),
	})),
	notLaunched: DROPPED.map((r) => identity(r).id),
};
