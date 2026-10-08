import type {Register, SessionMessage} from 'claude-code';

// Draws the end-of-turn footer beneath the model's answer:
//
//     📌 You asked: <one sentence restating the user's request>
//     🔗 [label](url)             (or "🔗 None")
//
// The footer exists because long, multitasked sessions end in a wall of text,
// and the user returns without the context of what the session was about.
// Drawing it here, instead of blocking the stop until the model writes it,
// costs no extra main-model turn and never shows a stop-hook error.

const RECAP_MODEL = 'claude-haiku-4-5';

const RECAP_SYSTEM =
	'You write one line that reminds a returning user what they asked for in a coding session. ' +
	"Restate the request currently being worked, in the user's framing, as one imperative sentence. " +
	'Describe the request, not what the assistant did. Reply with the sentence alone.';

// Most specific first: the first pattern with a match anywhere in the
// conversation wins, newest match within it.
const LINKS: readonly {pattern: RegExp; label: (match: RegExpMatchArray) => string}[] = [
	{pattern: /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/pull\/(\d+)/g, label: (m) => `PR #${m[1]}`},
	{pattern: /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/actions\/runs\/\d+/g, label: () => 'CI run'},
	{pattern: /https:\/\/github\.com\/[\w.-]+\/[\w.-]+\/issues\/(\d+)/g, label: (m) => `Issue #${m[1]}`},
	{pattern: /http:\/\/(?:localhost|127\.0\.0\.1):\d+\/?[^\s)\]>'"`]*/g, label: () => 'Dev server'},
];

const hasFooter = (text: string) => /^📌 /m.test(text) && /^🔗 /m.test(text);

// Prompts the person typed: user rows with text and no tool results, with the
// engine's injected tags stripped.
const typedPrompts = (messages: readonly SessionMessage[]) =>
	messages
		.filter((m) => m.role === 'user' && m.text !== '' && (m.toolResults ?? []).length === 0)
		.map((m) =>
			m.text
				.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, '')
				.replace(/<\/?[\w-]+>/g, ' ')
				.replace(/\s+/g, ' ')
				.trim(),
		)
		.filter((text) => text !== '');

const findLink = (messages: readonly SessionMessage[]) => {
	const texts = messages.map((m) => m.text).reverse();
	for (const {pattern, label} of LINKS) {
		for (const text of texts) {
			const match = [...text.matchAll(pattern)].at(-1);
			if (match) return `[${label(match)}](${match[0]})`;
		}
	}
	return 'None';
};

export const register: Register = (on) => {
	on('turn.complete', async ($, e, next) => {
		const result = await next(e);
		if (e.agentId !== undefined || e.reason !== 'answer' || hasFooter(e.answer)) return result;

		const messages = await $.session.messages();
		const prompts = typedPrompts(messages);
		if (prompts.length === 0) return result;

		const reply = await $.model.complete({
			model: RECAP_MODEL,
			system: RECAP_SYSTEM,
			prompt: prompts
				.slice(-5)
				.map((p, i) => `Prompt ${i + 1}: ${p.slice(0, 2000)}`)
				.join('\n\n'),
			maxTokens: 120,
			timeoutMs: 10_000,
		});
		const fallback = prompts.at(-1)!.slice(0, 160);
		const recap = (reply.isAnswered && reply.text.trim().split('\n')[0]) || fallback;

		return {...result, text: `📌 You asked: ${recap}\n🔗 ${findLink(messages)}`};
	});
};
