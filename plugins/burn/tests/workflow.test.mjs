import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {test} from "node:test";

const SCRIPT = readFileSync(new URL("../scripts/burn-workflow.js", import.meta.url), "utf8");
const AsyncFunction = Object.getPrototypeOf(async () => {}).constructor;

const run = (track, shard) => (
{
	track,
	shard,
	invokes: `${track} {level} {paths}`,
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
		effort: "high",
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

const idea = (recommend = "keep") => (
{
	committed: true,
	recommend,
	rationale: `RATIONALE-${recommend}`,
	alternative: "ALTERNATIVE",
	summary: "built the idea",
	evidence: ["idea test output"],
	diffStat: "2 files changed",
	changesTests: false,
});

const passed = () => (
{
	passed: true,
	output: "ok",
});

const removed = (branchDeleted = false) => (
{
	worktreeRemoved: true,
	branchDeleted,
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
		"idea:": () => idea(),
		"verify:": upheld,
		"gate:": passed,
		"cleanup:": () => removed(),
		"rank-and-report": () => (
		{
			ranked: ["ranked-by-agent"],
			reportPath: "/repo/.llm/burn/2000-01-01/REPORT.md",
		}),
		...responders,
	};
	const agent = async (prompt, opts) =>
	{
		calls.push(
			{
				label: opts.label,
				effort: opts.effort,
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
				effort: "high",
				votes: 2,
			},
		},
		{
			"track:": (label) =>
				label === "track:code-review-src-a"
					?
						{
							...committed(),
							afterKept: ["delete ~/memory/a.md"],
						}
					: committed(),
		},
	);

	assert.deepEqual(labels(calls, "after-kept:"), ["after-kept:code-review-src-a"]);
	assert.match(
		prompt(calls, "after-kept:code-review-src-a"),
		/burn\/2000-01-01\/code-review-src-a in \/repo passed verification and the test gate[\s\S]*- delete ~\/memory\/a\.md/,
	);

	assert.deepEqual(
		result,
		{
			ranked: ["ranked-by-agent"],
			report: "/repo/.llm/burn/2000-01-01/REPORT.md",
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
		},
	);
	assert.deepEqual(labels(calls, "verify:code-review-src-a"), [
		"verify:code-review-src-a:1",
		"verify:code-review-src-a:2",
	]);
	assert.match(
		prompt(calls, "track:code-review-src-a"),
		/worktree add \/worktrees\/repo-burn-2000-01-01-code-review-src-a -b burn\/2000-01-01\/code-review-src-a abc123`\. If that command fails, stop: change nothing, create no other worktree, and return committed: false\./,
	);
	assert.match(prompt(calls, "gate:code-review-src-a"), /run `just test` once in the background/);
	assert.match(prompt(calls, "gate:code-review-src-a"), /wait for it to exit, however long it takes/);
	const cleanups = calls.filter((c) => c.label.startsWith("cleanup:"));
	assert.deepEqual(cleanups.length, 3);
	cleanups.forEach((c) => assert.doesNotMatch(c.prompt, /--force|branch -[dD]/));
	calls.forEach((c) => assert.match(c.prompt, /The user is away until the run ends: ask them nothing/, c.label));
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
				effort: "high",
				votes: 1,
			},
		},
		{},
	);

	assert.deepEqual(labels(calls, "track:"), ["track:code-review-src-a", "track:code-review-src-b"]);
	assert.deepEqual(result.notLaunched, ["coverage-src-a"]);
});

test("an empty, refuted, gate-failed or dead run keeps its branch unless it has no commits, and is never re-run", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [...BASE_ARGS.runs, run("coverage", "src/b")],
			tier:
			{
				runs: 4,
				effort: "high",
				votes: 1,
			},
		},
		{
			"track:": (label) =>
				label === "track:code-review-src-a"
					? empty()
					: label === "track:coverage-src-b"
						? null
						:
							{
								...committed(),
								afterKept: ["delete ~/memory/a.md"],
							},
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
			"cleanup:": (label) => removed(label === "cleanup:code-review-src-a" || label === "cleanup:coverage-src-b"),
		},
	);

	assert.deepEqual(result.outcomes, [
		{
			branch: "burn/2000-01-01/code-review-src-a",
			status: "empty",
			reason: "nothing worth committing",
			branchDeleted: true,
		},
		{
			branch: "burn/2000-01-01/code-review-src-b",
			status: "refuted",
			reason: "wrong",
			branchDeleted: false,
		},
		{
			branch: "burn/2000-01-01/coverage-src-a",
			status: "gate-failed",
			reason: "1 failed",
			branchDeleted: false,
		},
		{
			branch: "burn/2000-01-01/coverage-src-b",
			status: "failed",
			reason: "the track agent died",
			branchDeleted: true,
		},
	]);
	assert.deepEqual(labels(calls, "track:").length, 4);
	const cleanups = calls.filter((c) => c.label.startsWith("cleanup:"));
	assert.deepEqual(cleanups.map((c) => c.label).sort(), [
		"cleanup:code-review-src-a",
		"cleanup:code-review-src-b",
		"cleanup:coverage-src-a",
		"cleanup:coverage-src-b",
	]);
	cleanups.forEach((c) =>
	{
		assert.doesNotMatch(c.prompt, /--force|branch -D/);
		assert.match(c.prompt, /rev-list --count abc123\.\.burn\/2000-01-01\/[a-z-]+`/);
		assert.match(c.prompt, /git -C \/repo branch -d burn\/2000-01-01\/[a-z-]+`/);
	});
	assert.deepEqual(labels(calls, "gate:"), ["gate:coverage-src-a"]);
	assert.deepEqual(labels(calls, "after-kept:"), []);
});

test("a worktree git refuses to remove stays and is reported as unfinished", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [run("code-review", "src/a"), run("coverage", "src/a")],
		},
		{
			"track:": (label) => (label === "track:code-review-src-a" ? empty() : committed()),
			"cleanup:": () => (
			{
				worktreeRemoved: false,
				branchDeleted: false,
			}),
		},
	);

	assert.deepEqual(result.outcomes, [
		{
			branch: "burn/2000-01-01/code-review-src-a",
			status: "empty",
			reason: "nothing worth committing",
			branchDeleted: false,
			unfinishedWorktree: "/worktrees/repo-burn-2000-01-01-code-review-src-a",
		},
		{
			branch: "burn/2000-01-01/coverage-src-a",
			status: "kept",
			tested: true,
			unfinishedWorktree: "/worktrees/repo-burn-2000-01-01-coverage-src-a",
		},
	]);
	assert.match(
		prompt(calls, "rank-and-report"),
		/"unfinishedWorktree": "\/worktrees\/repo-burn-2000-01-01-code-review-src-a"/,
	);
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
			branchDeleted: false,
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

test("design questions are built once each as idea branches, deduplicated across runs and without dismissed ones", async () =>
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

	assert.deepEqual(labels(calls, "idea:"), ["idea:fix-parse", "idea:fix-kept"]);
	assert.match(
		prompt(calls, "idea:fix-parse"),
		/worktree add \/worktrees\/repo-burn-2000-01-01-idea-fix-parse -b burn\/2000-01-01\/idea-fix-parse abc123`/,
	);
	assert.match(prompt(calls, "idea:fix-parse"), /details parse/);
	assert.deepEqual(calls.find((c) => c.label === "idea:fix-parse").effort, "high");
	const report = prompt(calls, "rank-and-report");
	assert.doesNotMatch(report, /"symbol": "gone"/);
	assert.doesNotMatch(report, /merge|todo\.md/);
	assert.match(report, /You must write \/repo\/\.llm\/burn\/2000-01-01\/REPORT\.md/);
});

test("every design question is built, with no cap; a self-dropped idea keeps its branch and skips verify and gate", async () =>
{
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			runs: [run("code-review", "src/a")],
			tier:
			{
				runs: 1,
				votes: 1,
				effort: "high",
			},
		},
		{
			"track:": () => committed([finding("src/a.js", "a"), finding("src/b.js", "b"), finding("src/c.js", "c")]),
			"idea:": (label) => (label === "idea:fix-a" ? idea("drop") : idea("keep")),
		},
	);

	assert.deepEqual(labels(calls, "idea:"), ["idea:fix-a", "idea:fix-b", "idea:fix-c"]);
	assert.deepEqual(labels(calls, "verify:idea-"), ["verify:idea-fix-b:1", "verify:idea-fix-c:1"]);
	assert.deepEqual(labels(calls, "gate:idea-"), ["gate:idea-fix-b", "gate:idea-fix-c"]);
	assert.match(prompt(calls, "verify:idea-fix-b:1"), /recommends keeping it/);
	assert.match(prompt(calls, "verify:idea-fix-b:1"), /RATIONALE-keep/);
	assert.deepEqual(result.outcomes, [
		{
			branch: "burn/2000-01-01/code-review-src-a",
			status: "kept",
			tested: true,
		},
		{
			branch: "burn/2000-01-01/idea-fix-a",
			status: "idea-dropped",
			reason: "RATIONALE-drop",
			branchDeleted: false,
		},
		{
			branch: "burn/2000-01-01/idea-fix-b",
			status: "kept",
			tested: true,
			recommend: "keep",
		},
		{
			branch: "burn/2000-01-01/idea-fix-c",
			status: "kept",
			tested: true,
			recommend: "keep",
		},
	]);
	assert.match(prompt(calls, "cleanup:idea-fix-a"), /Keep the branch burn\/2000-01-01\/idea-fix-a/);
});

test("a report agent that does not return the REPORT.md path leaves the report null", async () =>
{
	const {result} = await runWorkflow(
		BASE_ARGS,
		{
			"rank-and-report": () => (
			{
				ranked: ["ranked-by-agent"],
				reportPath: "",
			}),
		},
	);

	assert.deepEqual(
		{
			ranked: result.ranked,
			report: result.report,
		},
		{
			ranked: ["ranked-by-agent"],
			report: null,
		},
	);
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
	assert.match(p, /Invoke: coverage high src\/a, unattended/);
	assert.deepEqual(calls.find((c) => c.label === "track:coverage-src-a").effort, "high");
	assert.match(p, /INSTRUCTIONS-coverage/);
	assert.match(p, /Evidence rule: EVIDENCE-RULE-coverage/);
	assert.match(p, /Fix every problem whose fix needs no decision/);
	assert.match(p, /Drop every problem nothing in this repository can fix/);
	assert.match(p, /Return as findings only design questions/);
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
