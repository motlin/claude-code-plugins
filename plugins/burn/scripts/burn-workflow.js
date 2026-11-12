export const meta =
{
	name: "burn",
	description:
		"Fan out improvement tracks over existing code, one worktree each; verify, test-gate, rank and report the surviving local branches",
	whenToUse:
		"Spending spare weekly quota on real improvements, launched by the burn skill with its preflight results as args",
	phases: [
		{
			title: "Run tracks",
			detail: "one agent per track run, each in its own worktree and branch",
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
			detail: "rank branches, queue findings, update the ledger, write REPORT.md",
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
//   tier         { runs, maxBranches, votes }
//   reportTemplate absolute path of skills/burn/references/report-template.md
//   runs         [{ track, shard, invokes, evidence, instructions }], in launch order
//   dismissed    [{ track, path, symbol }] findings the user dismissed
const A = args || {};
const TIER = A.tier;
const PLANNED = A.runs.slice(0, TIER.runs);
const DROPPED = A.runs.slice(TIER.runs);
const DISMISSED = A.dismissed || [];

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
			description: "self-contained task body: exact files, the evidence, and what done looks like",
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
			description: "real problems found but not fixed, to queue as tasks",
		},
	},
	required: ["committed", "summary", "evidence", "diffStat", "changesTests", "findings"],
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
		queued:
		{
			type: "number",
			description: "tasks appended to .llm/todo.md",
		},
	},
	required: ["ranked", "queued"],
};

const slug = (s) =>
	s
		.replace(/[^A-Za-z0-9]+/g, "-")
		.replace(/^-|-$/g, "")
		.toLowerCase() || "repo";

function identity(run)
{
	const name = `${run.track}-${slug(run.shard)}`;
	return {
		id: name,
		branch: `burn/${A.date}/${name}`,
		worktree: `${A.worktreeRoot}/burn-${A.date}-${name}`,
	};
}

const findingKey = (f) => [f.track, f.path, f.symbol].join("\0");
const dismissedKeys = new Set(DISMISSED.map(findingKey));

function trackPrompt(run, where)
{
	const invocation = run.invokes.replace("{paths}", run.shard);
	const dismissed = DISMISSED.filter((f) => f.track === run.track);
	return `You are the ${run.track} track of a burn run over ${A.repo}. Work only on existing code in ${run.shard}.

Create your worktree first: \`git -C ${A.repo} worktree add ${where.worktree} -b ${where.branch} ${A.base}\`. Work and commit only inside ${where.worktree}, following the repo's commit conventions. Never push, never open a PR, never touch ${A.repo} itself.

Invoke: ${invocation}, unattended. Ask the user nothing; turn each question you would have asked into a finding.

${run.instructions}

Evidence rule: ${run.evidence} A change without evidence is not committed.

${dismissed.length ? `The user dismissed these findings; never raise them again:\n${dismissed.map((f) => `- ${f.path} ${f.symbol}`).join("\n")}\n\n` : ""}If nothing is worth committing, commit nothing and return committed: false. Return findings only for real problems you found and chose not to fix.`;
}

function verifyPrompt(run, where, result, vote)
{
	return `You are verifier ${vote + 1} of ${TIER.votes} for the burn branch ${where.branch} in ${A.repo}, made by the ${run.track} track. You have not seen how it was made.

Read \`git -C ${A.repo} diff ${A.base}..${where.branch}\` and this evidence:
${result.evidence.map((e) => `- ${e}`).join("\n")}

Summary from the track: ${result.summary}

Try to show the change is wrong, unnecessary, or changes behavior where it should not. Check that the evidence is real by rerunning what it cites where you can. Do not edit anything. Return refuted: true when you are not convinced the change is correct and worth a reviewer's time.`;
}

function gatePrompt(where)
{
	const command = A.gitTest ? `git test run ${A.base}..${where.branch}` : A.testCommand;
	return `In ${where.worktree}, run \`${command}\` once and report whether it passed. Do not edit, fix, retry or commit anything.`;
}

function cleanupPrompt(where, keepBranch)
{
	return keepBranch
		? `Run \`git -C ${A.repo} worktree remove ${where.worktree}\`. Keep the branch ${where.branch}. Never use --force. Reply "ok".`
		: `Run \`git -C ${A.repo} worktree remove --force ${where.worktree}\` if that worktree exists, then \`git -C ${A.repo} branch -D ${where.branch}\` if that branch exists. Reply "ok".`;
}

const cleanup = (where, keepBranch) =>
	agent(
		cleanupPrompt(where, keepBranch),
		{
			label: `cleanup:${where.id}`,
			phase: keepBranch ? "Rank and report" : "Run tracks",
			effort: "low",
		},
	);

async function trackChain(run)
{
	const where = identity(run);
	const outcome =
	{
		...where,
		track: run.track,
		shard: run.shard,
	};

	const result = await agent(
		trackPrompt(run, where),
		{
			label: `track:${where.id}`,
			phase: "Run tracks",
			schema: TRACK_SCHEMA,
		},
	);
	if (!result)
	{
		await cleanup(where, false);
		return {
			...outcome,
			status: "failed",
			reason: "the track agent died",
		};
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
		await cleanup(where, false);
		return {
			...outcome,
			status: "empty",
			reason: "nothing worth committing",
		};
	}

	const votes = await parallel(
		Array.from(
			{
				length: TIER.votes,
			},
			(_, vote) => () =>
				agent(
					verifyPrompt(run, where, result, vote),
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
		await cleanup(where, false);
		return {
			...outcome,
			status: "refuted",
			reason:
				votes
					.filter((v) => v && v.refuted)
					.map((v) => v.reason)
					.join(" / ") || "no verifier upheld it",
		};
	}

	if (!A.testCommand)
	{
		return {
			...outcome,
			status: "kept",
			tested: false,
		};
	}
	const gate = await agent(
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
		await cleanup(where, false);
		return {
			...outcome,
			status: "gate-failed",
			reason: gate ? gate.output : "the gate agent died",
		};
	}
	return {
		...outcome,
		status: "kept",
		tested: true,
	};
}

// Launch track runs while kept branches plus runs in flight stay under the
// branch cap. A run that ends without a branch frees its slot for the next
// launch, so no finished branch is ever thrown away to meet the cap.
async function runAll()
{
	const queue = [...PLANNED];
	const outcomes = [];
	let held = 0;
	let inFlight = 0;
	await new Promise((resolve) =>
	{
		function launch()
		{
			while (queue.length && held < TIER.maxBranches)
			{
				const run = queue.shift();
				held++;
				inFlight++;
				trackChain(run)
					.catch((e) => (
					{
						...identity(run),
						track: run.track,
						shard: run.shard,
						status: "failed",
						reason: String(e),
					}))
					.then((outcome) =>
					{
						outcomes.push(outcome);
						log(`${outcome.id}: ${outcome.status}${outcome.reason ? ` (${outcome.reason})` : ""}`);
						inFlight--;
						if (outcome.status !== "kept") held--;
						launch();
					});
			}
			if (!inFlight) resolve();
		}
		launch();
	});
	return {
		outcomes,
		capped: queue,
	};
}

phase("Run tracks");
if (DROPPED.length)
	log(`Tier allows ${TIER.runs} runs; not launched: ${DROPPED.map((r) => identity(r).id).join(", ")}`);
const {outcomes, capped} = await runAll();
if (capped.length)
	log(`Branch cap ${TIER.maxBranches} reached; not launched: ${capped.map((r) => identity(r).id).join(", ")}`);

const order = PLANNED.map((r) => identity(r).id);
outcomes.sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));
const kept = outcomes.filter((o) => o.status === "kept");

const findings = [];
const seen = new Set(dismissedKeys);
for (const o of outcomes)
	for (const f of o.findings || [])
	{
		if (seen.has(findingKey(f))) continue;
		seen.add(findingKey(f));
		findings.push(f);
	}

phase("Rank and report");
const covered = outcomes
	.filter((o) => o.status !== "failed")
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
		// Each run's own findings are folded into the deduplicated list below,
		// so the report agent never sees a finding twice.
		outcomes: outcomes.map(({findings: own, ...o}) => (
		{
			...o,
			findingCount: own ? own.length : 0,
		})),
		notLaunched: [...capped, ...DROPPED].map((r) => identity(r).id),
		findings,
	},
	null,
	2,
);
const report = await agent(
	`You rank and report the burn run of ${A.date} over ${A.repo}. Read the template at ${A.reportTemplate} and follow it.

Phase results (write them verbatim to ${A.runDir}/runs.json first):
${runsJson}

Rank the kept branches by value to the user against review effort; read each one's diff with \`git -C ${A.repo} diff ${A.base}..<branch>\` to judge.

Queue the findings: pipe them as a JSON list, each with its track, path, symbol and title, to \`python3 ${A.ledger} --ledger ${A.repo}/.llm/burn/ledger.json merge\`. It prints only the findings never seen before, each with a fingerprint. Append each of those to ${A.repo}/.llm/todo.md as a self-contained \`- [ ]\` task under the heading \`## burn ${A.date}\`, with its details as indented lines and a final indented line \`burn: <fingerprint>\`. Add nothing for findings the ledger did not print.

Record coverage: for each of ${JSON.stringify(covered)}, run \`python3 ${A.ledger} --ledger ${A.repo}/.llm/burn/ledger.json record --track <track> --date ${A.date} <shard>\`.

Write ${A.runDir}/REPORT.md from the template. Do not push, open PRs, or delete any branch.`,
	{
		label: "rank-and-report",
		phase: "Rank and report",
		schema: RANK_SCHEMA,
	},
);
await parallel(kept.map((o) => () => cleanup(o, true)));

return {
	ranked: report ? report.ranked : kept.map((o) => o.branch),
	queued: report ? report.queued : null,
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
				}
			: {}),
	})),
	notLaunched: [...capped, ...DROPPED].map((r) => identity(r).id),
	findings: findings.length,
};
