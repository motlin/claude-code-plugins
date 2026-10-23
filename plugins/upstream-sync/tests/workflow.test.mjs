import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {test} from "node:test";

const SCRIPT = readFileSync(new URL("../scripts/upstream-sync-workflow.js", import.meta.url), "utf8");
const AsyncFunction = Object.getPrototypeOf(async () => {}).constructor;

const BASE_ARGS = {
	dir: "/repo/.llm/upstream-sync",
	upstreamName: "Example upstream",
	upstreamUrl: "https://example.com/app",
	localName: "local app",
	localUrl: "http://127.0.0.1:5000",
	localSource: "/repo/src",
	context: "Local is local-only.",
	safety: "SAFETY-RULES-MARKER",
};

const feature = (slug, priority) => ({slug, name: `Feature ${slug}`, priority, notes: `notes ${slug}`});

const investigation = (discovered = [], safetyIncidents = []) => ({
	investigated: true,
	localStatus: "partial",
	featureFile: "features/x.md",
	summary: "gaps",
	taskCount: 2,
	discovered,
	safetyIncidents,
	sandboxClean: true,
});

// Runs the workflow script with stubbed hooks. `responders` maps a label (or
// label prefix ending in ':' or '-') to a function returning the agent's result.
async function runWorkflow(args, responders) {
	const calls = [];
	const phases = [];
	const exportsBox = {};
	const agent = async (prompt, opts) => {
		calls.push({label: opts.label, prompt});
		const key = Object.keys(responders).find((k) =>
			/[:-]$/.test(k) ? opts.label.startsWith(k) : opts.label === k,
		);
		if (!key) return "ok";
		return responders[key](opts.label, calls.filter((c) => c.label.startsWith(key)).length);
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
	return {result, calls, phases, meta: exportsBox.meta};
}

const investigated = (calls) =>
	calls.filter((c) => c.label.startsWith("investigate:")).map((c) => c.label.slice("investigate:".length));

test("investigates by priority, recursing into discoveries, dedups slugs, then runs critic rounds until dry", async () => {
	const {result, calls, phases, meta} = await runWorkflow(BASE_ARGS, {
		"local-inventory": () => "inventory digest",
		"upstream-survey": () => ({
			features: [feature("beta", "P2"), feature("alpha", "P1"), feature("ALPHA", "P1")],
			safetyIncidents: [],
		}),
		"investigate:": (label) =>
			label === "investigate:alpha"
				? investigation([feature("delta", "P1"), feature("beta", "P1")])
				: investigation(),
		"critic-": (_label, n) => ({missing: n === 1 ? [feature("gamma", "P3")] : []}),
		summary: () => "summary digest",
	});

	assert.deepEqual(investigated(calls), ["alpha", "delta", "beta", "gamma"]);
	assert.deepEqual(result, {
		stopped: null,
		incidents: [],
		investigations: 4,
		criticRounds: 2,
		investigated: ["alpha", "delta", "beta", "gamma"],
		notInvestigated: [],
		failed: [],
		byStatus: {partial: 4},
		inventoryDigest: "inventory digest",
		summaryDigest: "summary digest",
	});
	assert.deepEqual(
		[...new Set(phases)].filter((p) => !meta.phases.some((m) => m.title === p)),
		[],
	);
});

test("a survey safety incident halts before any investigation unless acknowledged", async () => {
	const responders = {
		"upstream-survey": () => ({features: [feature("alpha", "P1")], safetyIncidents: ["changed a real node"]}),
		"investigate:": () => investigation(),
		"critic-": () => ({missing: []}),
	};

	const halted = await runWorkflow(BASE_ARGS, responders);
	assert.deepEqual(investigated(halted.calls), []);
	assert.deepEqual(halted.result.stopped, "safety: survey");
	assert.deepEqual(halted.result.notInvestigated, ["alpha"]);

	const acknowledged = await runWorkflow({...BASE_ARGS, acknowledgeSurveyIncidents: true}, responders);
	assert.deepEqual(investigated(acknowledged.calls), ["alpha"]);
	assert.deepEqual(acknowledged.result.stopped, null);
	assert.deepEqual(acknowledged.result.incidents, ["survey: changed a real node"]);
});

test("an investigator safety incident stops the queue but still writes the summary", async () => {
	const {result, calls} = await runWorkflow(BASE_ARGS, {
		"upstream-survey": () => ({features: [feature("alpha", "P1"), feature("beta", "P1")], safetyIncidents: []}),
		"investigate:": (label) =>
			label === "investigate:alpha" ? investigation([], ["edited outside sandbox"]) : investigation(),
	});

	assert.deepEqual(investigated(calls), ["alpha"]);
	assert.deepEqual(result.stopped, "safety: alpha");
	assert.deepEqual(result.incidents, ["alpha: edited outside sandbox"]);
	assert.deepEqual(result.notInvestigated, ["beta"]);
	assert.deepEqual(calls.at(-1).label, "summary");
});

test("an acknowledged investigator incident is recorded but the queue continues, so a resumed run gets past it", async () => {
	const {result, calls} = await runWorkflow(
		{...BASE_ARGS, acknowledgedIncidents: ["alpha"]},
		{
			"upstream-survey": () => ({features: [feature("alpha", "P1"), feature("beta", "P1")], safetyIncidents: []}),
			"investigate:": (label) =>
				label === "investigate:alpha" ? investigation([], ["edited outside sandbox"]) : investigation(),
			"critic-": () => ({missing: []}),
		},
	);

	assert.deepEqual(
		{investigated: investigated(calls), stopped: result.stopped, incidents: result.incidents},
		{investigated: ["alpha", "beta"], stopped: null, incidents: ["alpha: edited outside sandbox"]},
	);
});

test("a failed investigator (null result, e.g. a network drop) is retried once, then reported as failed", async () => {
	const {result, calls} = await runWorkflow(BASE_ARGS, {
		"upstream-survey": () => ({features: [feature("alpha", "P1"), feature("beta", "P1")], safetyIncidents: []}),
		"investigate:": (label, n) => {
			if (label === "investigate:alpha" && n === 1) return null;
			if (label.startsWith("investigate:beta")) return null;
			return investigation();
		},
		"critic-": () => ({missing: []}),
	});

	const alphaPrompts = calls.filter((c) => c.label === "investigate:alpha").map((c) => c.prompt);

	assert.deepEqual(investigated(calls), ["alpha", "alpha", "beta", "beta"]);
	assert.deepEqual(
		{
			investigated: result.investigated,
			failed: result.failed,
			retryPromptsDiffer: alphaPrompts[0] !== alphaPrompts[1],
		},
		{investigated: ["alpha", "beta"], failed: ["beta"], retryPromptsDiffer: true},
	);
});

test("an investigator that declines (investigated: false) counts as a failure: retried once, then failed, never done", async () => {
	const {result, calls} = await runWorkflow(BASE_ARGS, {
		"upstream-survey": () => ({features: [feature("alpha", "P1")], safetyIncidents: []}),
		"investigate:": () => ({...investigation(), investigated: false}),
		"critic-": () => ({missing: []}),
	});

	assert.deepEqual(
		{attempts: investigated(calls), failed: result.failed, byStatus: result.byStatus},
		{attempts: ["alpha", "alpha"], failed: ["alpha"], byStatus: {}},
	);
});

test("only mode re-investigates the given features, recursing into discoveries, and merges rows instead of rewriting the registry", async () => {
	const {result, calls} = await runWorkflow(
		{...BASE_ARGS, only: [feature("alpha", "P1"), feature("beta", "P2")]},
		{
			"investigate:": (label) =>
				label === "investigate:alpha" ? investigation([feature("gamma", "P3")]) : investigation(),
		},
	);
	const merge = calls.find((c) => c.label === "registry-merge");

	assert.deepEqual(
		calls.map((c) => c.label),
		["investigate:alpha", "investigate:beta", "investigate:gamma", "registry-merge", "summary"],
	);
	assert.deepEqual(
		{
			investigated: result.investigated,
			criticRounds: result.criticRounds,
			mergeNamesAll: ["alpha", "beta", "gamma"].every((s) => merge.prompt.includes(`| ${s} |`)),
		},
		{investigated: ["alpha", "beta", "gamma"], criticRounds: 0, mergeNamesAll: true},
	);
});

test("seed mode skips the broad phase, re-verifies existing feature files, recurses, and keeps critic rounds", async () => {
	const {result, calls} = await runWorkflow(
		{
			...BASE_ARGS,
			seed: [{...feature("alpha", "P1"), existing: true}, feature("beta", "P2"), feature("ALPHA", "P1")],
		},
		{
			"investigate:": (label) =>
				label === "investigate:alpha" ? investigation([feature("gamma", "P3")]) : investigation(),
			"critic-": () => ({missing: []}),
			summary: () => "summary digest",
		},
	);
	const prompt = (label) => calls.find((c) => c.label === label).prompt;
	const reverify = `A feature file from an earlier run exists at ${BASE_ARGS.dir}/features/`;

	assert.deepEqual(
		calls.map((c) => c.label),
		[
			"registry:seed",
			"investigate:alpha",
			"investigate:beta",
			"investigate:gamma",
			"registry:critic-1",
			"critic-1",
			"registry:final",
			"summary",
		],
	);
	assert.deepEqual(
		{
			investigated: result.investigated,
			criticRounds: result.criticRounds,
			alphaReverifies: prompt("investigate:alpha").includes(`${reverify}alpha.md`),
			betaReverifies: prompt("investigate:beta").includes(reverify),
		},
		{investigated: ["alpha", "beta", "gamma"], criticRounds: 1, alphaReverifies: true, betaReverifies: false},
	);
});

test("the investigation cap leaves the rest reported as not investigated", async () => {
	const {result} = await runWorkflow(
		{...BASE_ARGS, maxInvestigations: 1},
		{
			"upstream-survey": () => ({features: [feature("alpha", "P1"), feature("beta", "P2")], safetyIncidents: []}),
			"investigate:": () => investigation(),
		},
	);

	assert.deepEqual(result.investigated, ["alpha"]);
	assert.deepEqual(result.notInvestigated, ["beta"]);
});

test("safety rules reach every browser prompt; approved exceptions reach only investigators so the survey stays cached", async () => {
	const {calls} = await runWorkflow(
		{...BASE_ARGS, approvedExceptions: "EXCEPTION-MARKER"},
		{
			"upstream-survey": () => ({features: [feature("alpha", "P1")], safetyIncidents: []}),
			"investigate:": () => investigation(),
			"critic-": () => ({missing: []}),
		},
	);
	const prompt = (label) => calls.find((c) => c.label === label).prompt;

	assert.deepEqual(
		{
			surveySafety: prompt("upstream-survey").includes("SAFETY-RULES-MARKER"),
			surveyException: prompt("upstream-survey").includes("EXCEPTION-MARKER"),
			investigatorSafety: prompt("investigate:alpha").includes("SAFETY-RULES-MARKER"),
			investigatorException: prompt("investigate:alpha").includes("EXCEPTION-MARKER"),
		},
		{surveySafety: true, surveyException: false, investigatorSafety: true, investigatorException: true},
	);
});
