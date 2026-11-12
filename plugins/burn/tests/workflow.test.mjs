import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {test} from "node:test";

const SCRIPT = readFileSync(new URL("../scripts/burn-workflow.js", import.meta.url), "utf8");
const AsyncFunction = Object.getPrototypeOf(async () => {}).constructor;

const run = (track, shard) => (
{
	track,
	shard,
	invokes: `${track} {paths}`,
	evidence: `EVIDENCE-RULE-${track}`,
	instructions: `INSTRUCTIONS-${track}`,
});

const BASE_ARGS =
{
	repo: "/repo",
	base: "abc123",
	date: "2000-01-01",
	runDir: "/repo/.llm/burn/2000-01-01",
	worktreeRoot: "/worktrees",
	ledger: "/plugin/scripts/ledger.py",
	reportTemplate: "/plugin/skills/burn/references/report-template.md",
	testCommand: "just test",
	gitTest: false,
	tier:
	{
		runs: 3,
		maxBranches: 3,
		votes: 1,
	},
	runs: [run("code-review", "src/a"), run("code-review", "src/b"), run("coverage", "src/a")],
	dismissed: [],
};

const finding = (path, symbol) => (
{
	path,
	symbol,
	title: `Fix ${symbol}`,
	details: `details ${symbol}`,
});

const committed = (findings = []) => (
{
	committed: true,
	summary: "fixed things",
	evidence: ["test output"],
	diffStat: "1 file changed",
	changesTests: false,
	findings,
});

const empty = (findings = []) => (
{
	...committed(findings),
	committed: false,
	diffStat: "",
});

const upheld = () => (
{
	refuted: false,
	reason: "sound",
});

const passed = () => (
{
	passed: true,
	output: "ok",
});

// Runs the workflow script with stubbed hooks. `responders` maps a label (or
// label prefix ending in ':') to a function returning the agent's result.
async function runWorkflow(args, responders)
{
	const calls = [];
	const phases = [];
	const exportsBox = {};
	const all =
	{
		"track:": () => committed(),
		"verify:": upheld,
		"gate:": passed,
		"rank-and-report": () => (
		{
			ranked: ["ranked-by-agent"],
			queued: 0,
		}),
		...responders,
	};
	const agent = async (prompt, opts) =>
	{
		calls.push(
			{
				label: opts.label,
				prompt,
			},
		);
		const key = Object.keys(all).find((k) => (k.endsWith(":") ? opts.label.startsWith(k) : opts.label === k));
		if (!key) return "ok";
		return all[key](opts.label);
	};
	const parallel = async (thunks) => Promise.all(thunks.map((t) => t().catch(() => null)));
	const body = SCRIPT.replace("export const meta =", "__exports.meta =");
	const fn = new AsyncFunction("agent", "parallel", "phase", "log", "args", "__exports", body);
	const result = await fn(
		agent,
		parallel,
		(t) => phases.push(t),
		() => {},
		args,
		exportsBox,
	);
	return {
		result,
		calls,
		phases,
		meta: exportsBox.meta,
	};
}

const labels = (calls, prefix) => calls.filter((c) => c.label.startsWith(prefix)).map((c) => c.label);
const prompt = (calls, label) => calls.find((c) => c.label === label).prompt;

test("each run gets its branch, verify votes and a gate; kept worktrees are removed after the report, branches stay", async () =>
{
	const {result, calls, phases, meta} = await runWorkflow(
		{
			...BASE_ARGS,
			tier:
			{
				runs: 3,
				maxBranches: 3,
				votes: 2,
			},
		},
		{},
	);

	assert.deepEqual(
		result,
		{
			ranked: ["ranked-by-agent"],
			queued: 0,
			outcomes: [
				{
					branch: "burn/2000-01-01/code-review-src-a",
					status: "kept",
					tested: true,
				},
				{
					branch: "burn/2000-01-01/code-review-src-b",
					status: "kept",
					tested: true,
				},
				{
					branch: "burn/2000-01-01/coverage-src-a",
					status: "kept",
					tested: true,
				},
			],
			notLaunched: [],
			findings: 0,
		},
	);
	assert.deepEqual(labels(calls, "verify:code-review-src-a"), [
		"verify:code-review-src-a:1",
		"verify:code-review-src-a:2",
	]);
	assert.match(
		prompt(calls, "track:code-review-src-a"),
		/worktree add \/worktrees\/burn-2000-01-01-code-review-src-a -b burn\/2000-01-01\/code-review-src-a abc123/,
	);
	assert.match(prompt(calls, "gate:code-review-src-a"), /run `just test` once/);
	const cleanups = calls.filter((c) => c.label.startsWith("cleanup:"));
	assert.deepEqual(cleanups.length, 3);
	cleanups.forEach((c) => assert.doesNotMatch(c.prompt, /branch -D/));
	assert.deepEqual(
		[...new Set(phases)].filter((p) => !meta.phases.some((m) => m.title === p)),
		[],
	);
});

test("the tier's run count holds, and the dropped runs are reported", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			tier:
			{
				runs: 2,
				maxBranches: 5,
				votes: 1,
			},
		},
		{},
	);

	assert.deepEqual(labels(calls, "track:"), ["track:code-review-src-a", "track:code-review-src-b"]);
	assert.deepEqual(result.notLaunched, ["coverage-src-a"]);
});

test("launches stop at the branch cap, but a run that leaves no branch frees its slot", async () =>
{
	const capped = await runWorkflow(
		{
			...BASE_ARGS,
			tier:
			{
				runs: 3,
				maxBranches: 2,
				votes: 1,
			},
		},
		{},
	);
	assert.deepEqual(labels(capped.calls, "track:"), ["track:code-review-src-a", "track:code-review-src-b"]);
	assert.deepEqual(capped.result.notLaunched, ["coverage-src-a"]);

	const freed = await runWorkflow(
		{
			...BASE_ARGS,
			tier:
			{
				runs: 3,
				maxBranches: 2,
				votes: 1,
			},
		},
		{
			"track:": (label) => (label === "track:code-review-src-a" ? empty() : committed()),
		},
	);
	assert.deepEqual(labels(freed.calls, "track:"), [
		"track:code-review-src-a",
		"track:code-review-src-b",
		"track:coverage-src-a",
	]);
	assert.deepEqual(freed.result.notLaunched, []);
});

test("an empty, refuted, gate-failed or dead run deletes its branch once and is never re-run", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [...BASE_ARGS.runs, run("coverage", "src/b")],
			tier:
			{
				runs: 4,
				maxBranches: 4,
				votes: 1,
			},
		},
		{
			"track:": (label) =>
				label === "track:code-review-src-a" ? empty() : label === "track:coverage-src-b" ? null : committed(),
			"verify:": (label) =>
				label.startsWith("verify:code-review-src-b")
					?
						{
							refuted: true,
							reason: "wrong",
						}
					: upheld(),
			"gate:": () => (
			{
				passed: false,
				output: "1 failed",
			}),
		},
	);

	assert.deepEqual(result.outcomes, [
		{
			branch: "burn/2000-01-01/code-review-src-a",
			status: "empty",
			reason: "nothing worth committing",
		},
		{
			branch: "burn/2000-01-01/code-review-src-b",
			status: "refuted",
			reason: "wrong",
		},
		{
			branch: "burn/2000-01-01/coverage-src-a",
			status: "gate-failed",
			reason: "1 failed",
		},
		{
			branch: "burn/2000-01-01/coverage-src-b",
			status: "failed",
			reason: "the track agent died",
		},
	]);
	assert.deepEqual(labels(calls, "track:").length, 4);
	const deletions = calls.filter((c) => c.label.startsWith("cleanup:") && /branch -D/.test(c.prompt));
	assert.deepEqual(deletions.map((c) => c.label).sort(), [
		"cleanup:code-review-src-a",
		"cleanup:code-review-src-b",
		"cleanup:coverage-src-a",
		"cleanup:coverage-src-b",
	]);
	assert.deepEqual(labels(calls, "gate:"), ["gate:coverage-src-a"]);
});

test("a dead verifier counts as refuting", async () =>
{
	const {result} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [run("code-review", "src/a")],
		},
		{
			"verify:": () => null,
		},
	);

	assert.deepEqual(result.outcomes, [
		{
			branch: "burn/2000-01-01/code-review-src-a",
			status: "refuted",
			reason: "no verifier upheld it",
		},
	]);
});

test("without a test command there is no gate and kept branches are untested", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [run("code-review", "src/a")],
			testCommand: null,
		},
		{},
	);

	assert.deepEqual(labels(calls, "gate:"), []);
	assert.deepEqual(result.outcomes, [
		{
			branch: "burn/2000-01-01/code-review-src-a",
			status: "kept",
			tested: false,
		},
	]);
});

test("with git-test configured the gate runs it across the branch's commits", async () =>
{
	const {calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [run("code-review", "src/a")],
			gitTest: true,
		},
		{},
	);

	assert.match(
		prompt(calls, "gate:code-review-src-a"),
		/run `git test run abc123\.\.burn\/2000-01-01\/code-review-src-a` once/,
	);
});

test("queued findings reach the report once, deduplicated across runs and without dismissed ones", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [run("code-review", "src/a"), run("code-review", "src/b")],
			dismissed: [
				{
					track: "code-review",
					path: "src/b/y.js",
					symbol: "gone",
				},
			],
		},
		{
			"track:": (label) =>
				label === "track:code-review-src-a"
					? empty([finding("src/a/x.js", "parse"), finding("src/a/x.js", "parse")])
					: committed([
							finding("src/a/x.js", "parse"),
							finding("src/b/y.js", "gone"),
							finding("src/b/y.js", "kept"),
						]),
		},
	);

	assert.deepEqual(result.findings, 2);
	const report = prompt(calls, "rank-and-report");
	assert.deepEqual(report.match(/"symbol": "parse"/g).length, 1);
	assert.deepEqual(report.match(/"symbol": "kept"/g).length, 1);
	assert.doesNotMatch(report, /"symbol": "gone"/);
	assert.match(report, /ledger\.py --ledger \/repo\/\.llm\/burn\/ledger\.json merge/);
	assert.match(report, /## burn 2000-01-01/);
});

test("dismissed findings reach only their own track's prompts", async () =>
{
	const {calls} = await runWorkflow(
		{
			...BASE_ARGS,
			dismissed: [
				{
					track: "coverage",
					path: "src/a/x.js",
					symbol: "DISMISSED-SYMBOL",
				},
			],
		},
		{},
	);

	assert.match(prompt(calls, "track:coverage-src-a"), /src\/a\/x\.js DISMISSED-SYMBOL/);
	assert.doesNotMatch(prompt(calls, "track:code-review-src-a"), /DISMISSED-SYMBOL/);
});

test("track prompts carry the track's invocation, instructions and evidence rule", async () =>
{
	const {calls} = await runWorkflow(BASE_ARGS, {});

	const p = prompt(calls, "track:coverage-src-a");
	assert.match(p, /Invoke: coverage src\/a, unattended/);
	assert.match(p, /INSTRUCTIONS-coverage/);
	assert.match(p, /Evidence rule: EVIDENCE-RULE-coverage/);
});

test("coverage is recorded for every run that finished, including empty ones, but not dead ones", async () =>
{
	const {calls} = await runWorkflow(
		BASE_ARGS,
		{
			"track:": (label) =>
				label === "track:code-review-src-a"
					? empty()
					: label === "track:code-review-src-b"
						? null
						: committed(),
		},
	);

	const report = prompt(calls, "rank-and-report");
	assert.match(report, /\[\{"track":"code-review","shard":"src\/a"\},\{"track":"coverage","shard":"src\/a"\}\]/);
});
