export const meta = {
	name: 'upstream-sync',
	description:
		'Serial, recursive feature-by-feature investigation of an upstream web app vs a local clone; writes feature files with TDD tasks',
	whenToUse:
		'Parity investigation between a local app and the upstream product it mirrors, launched by the upstream-sync skill with its args',
	phases: [
		{title: 'Broad', detail: 'local inventory + upstream survey seed the queue'},
		{title: 'Investigate', detail: 'one browser investigator per feature, serial, recursive'},
		{title: 'Critic', detail: 'completeness critic adds missed features'},
		{title: 'Synthesize', detail: 'SUMMARY.md roadmap'},
	],
};

// args (see the upstream-sync skill for how to fill them):
//   dir, upstreamName, upstreamUrl, localName, localUrl, localSource,
//   context, safety, approvedExceptions, acknowledgeSurveyIncidents,
//   surveyFocus, inventoryFocus, maxInvestigations, maxCriticRounds,
//   registryEvery
const A = args || {};
const DIR = A.dir;
const MAX_INVESTIGATIONS = A.maxInvestigations ?? 150;
const MAX_CRITIC_ROUNDS = A.maxCriticRounds ?? 3;
const REGISTRY_EVERY = A.registryEvery ?? 6;
// Only mode: re-investigate these features (e.g. ones a run reported as
// failed) without the broad phase or critic rounds, then merge their rows
// into the existing features.md instead of rewriting it.
const ONLY = Array.isArray(A.only) && A.only.length ? A.only : null;

const BROWSER = `Use the claude-in-chrome tools (load every one you need in ONE ToolSearch call: tabs_context_mcp, tabs_create_mcp, tabs_close_mcp, navigate, computer, read_page, get_page_text, javascript_tool, find). Call tabs_context_mcp first, open your OWN tabs, close them when done. Investigations run one at a time because they share the browser.`;

const SAFETY = `${A.safety || ''}

Read ${DIR}/README.md first and follow its protocol exactly. Report anything you changed that the safety rules forbid in safetyIncidents, after undoing it if you can.`;

const FEATURE = {
	type: 'object',
	properties: {
		slug: {type: 'string', description: 'kebab-case, unique'},
		name: {type: 'string'},
		priority: {type: 'string', enum: ['P1', 'P2', 'P3']},
		notes: {type: 'string', description: 'where it lives upstream, why it matters, related slugs'},
	},
	required: ['slug', 'name', 'priority', 'notes'],
};

const SURVEY_SCHEMA = {
	type: 'object',
	properties: {
		features: {type: 'array', items: FEATURE},
		safetyIncidents: {type: 'array', items: {type: 'string'}},
	},
	required: ['features', 'safetyIncidents'],
};

const INVESTIGATION_SCHEMA = {
	type: 'object',
	properties: {
		localStatus: {type: 'string', enum: ['missing', 'partial', 'equivalent', 'better-locally', 'not-applicable']},
		featureFile: {type: 'string'},
		summary: {type: 'string', description: 'one or two sentences: biggest gaps'},
		taskCount: {type: 'number'},
		discovered: {
			type: 'array',
			items: FEATURE,
			description: 'new features/sub-features found, not already in the queue',
		},
		safetyIncidents: {type: 'array', items: {type: 'string'}},
		sandboxClean: {type: 'boolean'},
	},
	required: ['localStatus', 'featureFile', 'summary', 'taskCount', 'discovered', 'safetyIncidents', 'sandboxClean'],
};

const CRITIC_SCHEMA = {
	type: 'object',
	properties: {missing: {type: 'array', items: FEATURE}},
	required: ['missing'],
};

const queue = [];
const seen = new Set();
const incidents = [];
const order = [];

function enqueue(f, source) {
	const slug = (f.slug || '').toLowerCase().trim();
	if (!slug || seen.has(slug)) return false;
	seen.add(slug);
	queue.push({...f, slug, notes: source ? `${f.notes} · from ${source}` : f.notes, status: 'todo'});
	return true;
}

function nextTodo() {
	for (const p of ['P1', 'P2', 'P3']) {
		const item = queue.find((q) => q.status === 'todo' && q.priority === p);
		if (item) return item;
	}
	return null;
}

const cell = (s) => String(s).replace(/\|/g, '/').replace(/\n/g, ' ');

function queueTable() {
	return queue
		.map(
			(q, i) =>
				`| ${i + 2} | ${q.slug} | ${cell(q.name)} | ${q.priority} | ${q.status}${q.result ? ' (' + q.result.localStatus + ')' : ''} | ${cell(q.result ? q.result.summary + ' · ' + q.result.featureFile : q.notes)} |`,
		)
		.join('\n');
}

async function writeRegistry(label) {
	if (ONLY) return;
	await agent(
		`Overwrite ${DIR}/features.md with exactly this content (no other changes, no commentary):

# Feature registry and investigation queue

Owned by the orchestrating workflow; investigators report discoveries in structured output instead of editing this file.
Status: \`todo\` → \`done\` / \`failed\`. Priority: P1 / P2 / P3.

## Queue

| # | Slug | Feature | Priority | Status | Notes |
|---|------|---------|----------|--------|-------|
| 0 | local-inventory | Map of everything the local app already has | P1 | done | local-inventory.md |
| 1 | upstream-survey | Broad survey of ${A.upstreamName} | P1 | done | upstream-survey.md |
${queueTable()}

Reply "ok".`,
		{label: `registry:${label}`, phase: 'Investigate', effort: 'low'},
	);
}

function outcome(stopped, inventory, summary) {
	return {
		stopped,
		incidents,
		investigations: order.length,
		criticRounds,
		investigated: order,
		notInvestigated: queue.filter((q) => q.status === 'todo').map((q) => q.slug),
		failed: queue.filter((q) => q.status === 'failed').map((q) => q.slug),
		byStatus: queue.reduce((m, q) => {
			if (q.result) m[q.result.localStatus] = (m[q.result.localStatus] || 0) + 1;
			return m;
		}, {}),
		inventoryDigest: inventory,
		summaryDigest: summary,
	};
}

// ---------- Broad ----------
let criticRounds = 0;
let inventory = null;
let survey = null;
if (ONLY) {
	ONLY.forEach((f) => enqueue(f, 'only'));
	log(`Only mode: ${queue.map((q) => q.slug).join(', ')}`);
} else {
	phase('Broad');
	[inventory, survey] = await parallel([
		() =>
			agent(
				`Build a complete inventory of the LOCAL app: ${A.localName}, source at ${A.localSource}. Do NOT use any browser; read code only. Context: ${A.context || ''}
${A.inventoryFocus || ''}
Write ${DIR}/local-inventory.md with file:line refs covering every route/view, layout region, component, menu, dialog, setting, keyboard shortcut and its handler, theming/CSS variables and class-naming scheme, and API endpoint. Mark which pieces are local-only extras that upstream lacks. Return a 15-line plain-text digest of the most important facts.`,
				{label: 'local-inventory', phase: 'Broad'},
			),
		() =>
			agent(
				`${SAFETY}

You are the BROAD SURVEY investigator for ${A.upstreamName} at ${A.upstreamUrl}. ${BROWSER}
Context: ${A.context || ''}
Survey EVERY surface without going deep: navigation, every menu and each of its entries (open, read, close with Escape), every dialog, the keyboard shortcuts list (capture it in full), search, settings sections, empty states, and narrow-viewport differences.
${A.surveyFocus || ''}
Capture stylesheet URLs and :root CSS custom properties to ${DIR}/dumps/ (create it). Skim the local source at ${A.localSource} to know what exists locally.

Write ${DIR}/upstream-survey.md: a structured map of every upstream surface with the full shortcut list. Return the feature queue: one entry per investigable feature or sub-feature (aim for 30-60, each small enough for one investigator session). Priority: P1 = core features users see on every page; P2 = secondary surfaces; P3 = rare features, or upstream-only ones with likely no local meaning.`,
				{label: 'upstream-survey', phase: 'Broad', schema: SURVEY_SCHEMA},
			),
	]);

	if (survey) {
		survey.features.forEach((f) => enqueue(f, 'survey'));
		incidents.push(...survey.safetyIncidents.map((s) => `survey: ${s}`));
	}
	log(`Queue seeded with ${queue.length} features`);
	if (survey && survey.safetyIncidents.length && !A.acknowledgeSurveyIncidents) {
		log(`SAFETY INCIDENT during survey — stopping. Verify, then resume with acknowledgeSurveyIncidents: true`);
		return outcome('safety: survey', inventory, null);
	}
	await writeRegistry('seed');
}

// ---------- Investigate (serial, recursive) + Critic rounds ----------
class SafetyStop extends Error {}

async function drain() {
	while (order.length < MAX_INVESTIGATIONS) {
		const item = nextTodo();
		if (!item) return;
		order.push(item.slug);
		const others = queue
			.filter((q) => q !== item)
			.map((q) => `${q.slug} (${q.status})`)
			.join(', ');
		const prompt = `${SAFETY}
${A.approvedExceptions ? `\nUSER-APPROVED EXCEPTIONS (not safety incidents; do not undo): ${A.approvedExceptions}\n` : ''}
You are the investigator for ONE feature: **${item.name}** (slug: ${item.slug}, priority ${item.priority}).
Context from the queue: ${item.notes}
Project context: ${A.context || ''}

Read ${DIR}/README.md, ${DIR}/local-inventory.md, ${DIR}/upstream-survey.md, and any related ${DIR}/features/*.md first. ${BROWSER} Investigate this feature exhaustively on BOTH sides: upstream ${A.upstreamUrl} and local ${A.localUrl} plus source in ${A.localSource}. Goal is near-exact parity: same DOM structure, class names, CSS values, behavior and keyboard handling, minus what has no local meaning. Extract real outerHTML, matched CSS rules and computed styles (never describe from screenshots alone); save large dumps to ${DIR}/dumps/${item.slug}-*. Test every interaction, state, empty state and edge case. Every sub-surface may reveal another feature: report those in "discovered" (skip anything already queued: ${others}).

Write ${DIR}/features/${item.slug}.md following the README template, with self-contained red/green TDD proposed tasks (exact files, exact class names and values). If the feature has no local meaning, write a short file with localStatus not-applicable. Append any new general lesson to the README Tips section. Return the structured result.`;
		const opts = {label: `investigate:${item.slug}`, phase: 'Investigate', schema: INVESTIGATION_SCHEMA};
		let r = await agent(prompt, opts);
		// A null result is a dead agent (network drop, terminal API error). The
		// retry prompt differs so a resumed run doesn't replay the failure.
		if (!r) {
			log(`${item.slug}: agent failed, retrying once`);
			r = await agent(
				`${prompt}\n\nThis is a retry: an earlier attempt died mid-run. Reuse any ${DIR}/dumps/${item.slug}-* or partial feature file it left, and finish the job.`,
				opts,
			);
		}

		if (!r) {
			item.status = 'failed';
			log(`${item.slug}: agent failed twice`);
			continue;
		}
		item.status = 'done';
		item.result = r;
		let added = 0;
		r.discovered.forEach((f) => {
			if (enqueue(f, item.slug)) added++;
		});
		log(
			`[${order.length}] ${item.slug}: ${r.localStatus}, ${r.taskCount} tasks, +${added} discovered (${queue.filter((q) => q.status === 'todo').length} todo)`,
		);
		if (!r.sandboxClean) log(`${item.slug}: sandbox not clean`);
		if (r.safetyIncidents.length) {
			incidents.push(...r.safetyIncidents.map((s) => `${item.slug}: ${s}`));
			throw new SafetyStop(`safety: ${item.slug}`);
		}
		if (order.length % REGISTRY_EVERY === 0) await writeRegistry(`after-${order.length}`);
	}
}

let stopped = null;
try {
	await drain();
	while (!ONLY && criticRounds < MAX_CRITIC_ROUNDS && order.length < MAX_INVESTIGATIONS) {
		criticRounds++;
		phase('Critic');
		await writeRegistry(`critic-${criticRounds}`);
		const c = await agent(
			`You are the COMPLETENESS CRITIC for the ${A.upstreamName} → ${A.localName} parity investigation. Read ${DIR}/README.md, ${DIR}/upstream-survey.md, ${DIR}/local-inventory.md, ${DIR}/features.md and skim every ${DIR}/features/*.md and the ${DIR}/dumps listing. Do not use the browser. Which upstream surfaces, menus, menu entries, shortcuts, settings, states (empty/loading/error/offline), viewport sizes or interactions has no feature file investigated, or only skimmed? Which feature files lack real DOM/CSS evidence or tasks? Return only genuinely missing or under-investigated items as new features (re-investigations use '<old-slug>-deep' with notes saying what was missing). Return an empty list if coverage is complete.`,
			{label: `critic-${criticRounds}`, phase: 'Critic', schema: CRITIC_SCHEMA},
		);
		const added = ((c && c.missing) || []).filter((f) => enqueue(f, 'critic')).length;
		log(`Critic round ${criticRounds}: +${added}`);
		if (!added) break;
		phase('Investigate');
		await drain();
	}
} catch (e) {
	if (!(e instanceof SafetyStop)) throw e;
	stopped = e.message;
	log(`Stopped: ${stopped}`);
}

const leftover = queue.filter((q) => q.status === 'todo');
if (leftover.length)
	log(`Not investigated (cap ${MAX_INVESTIGATIONS} or stop): ${leftover.map((q) => q.slug).join(', ')}`);

// ---------- Synthesize ----------
phase('Synthesize');
await writeRegistry('final');
if (ONLY) {
	await agent(
		`Update ${DIR}/features.md in place: for each row below, replace the existing row with the same Slug (keep its # number), or append it at the end of the Queue table with the next # if no row has that slug. Change nothing else. Reply "ok".

${queueTable()}`,
		{label: 'registry-merge', phase: 'Synthesize', effort: 'low'},
	);
}
const summary = await agent(
	`Read ${DIR}/README.md, ${DIR}/features.md, ${DIR}/local-inventory.md, ${DIR}/upstream-survey.md and every ${DIR}/features/*.md. Write ${DIR}/SUMMARY.md: (1) one-paragraph state of parity, (2) table of features by local status, (3) a prioritized, deduplicated implementation roadmap grouping proposed tasks into ordered milestones (shared infrastructure and foundational DOM/CSS alignment first, then P1, P2, P3), noting cross-feature dependencies and conflicts between feature files, (4) features skipped as not-applicable, (5) open questions for the user. Do not edit anything outside ${DIR}. Return a 20-line plain-text digest.`,
	{label: 'summary', phase: 'Synthesize'},
);

return outcome(stopped, inventory, summary);
