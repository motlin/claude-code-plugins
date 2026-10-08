import {describe, expect, test} from 'claude-code/testing';

const USAGE = {
	input_tokens: 10,
	output_tokens: 5,
	cache_creation_input_tokens: 0,
	cache_read_input_tokens: 0,
};

const ANSWER = 'All conflicts resolved and the rebase finished.';

const turn = (fields: Record<string, unknown> = {}) => ({
	answer: ANSWER,
	durationMs: 1,
	isAborted: false,
	turnId: 't1',
	reason: 'answer' as const,
	...fields,
});

const user = (text: string) => ({role: 'user' as const, text, toolUses: []});
const assistant = (text: string) => ({role: 'assistant' as const, text, toolUses: []});

describe('recap footer', () => {
	test('draws the recap and the newest pull request link beneath the answer', async ($, on) => {
		on('session.messages', () => ({
			value: [
				user('<command-message>git:conflicts</command-message> Fix the merge conflicts'),
				assistant('Opened https://github.com/motlin/claude-code-plugins/pull/42 for review.'),
				assistant(ANSWER),
			],
		}));
		on('model.complete', () => ({
			value: {isAnswered: true, text: 'Fix all merge conflicts and continue the git rebase.', usage: USAGE},
		}));
		on('turn.complete', ($, e) => ({text: e.answer}));

		const result = await $.turn.complete(turn());

		expect(result.text).toBe(
			'📌 You asked: Fix all merge conflicts and continue the git rebase.\n' +
				'🔗 [PR #42](https://github.com/motlin/claude-code-plugins/pull/42)',
		);
	});

	test('falls back to the latest typed prompt when the recap call fails', async ($, on) => {
		on('session.messages', () => ({
			value: [user('Fix the merge conflicts\n<system-reminder>noise</system-reminder>'), assistant(ANSWER)],
		}));
		on('model.complete', () => ({
			value: {isAnswered: false, reason: 'empty-reply', usage: USAGE},
		}));
		on('turn.complete', ($, e) => ({text: e.answer}));

		const result = await $.turn.complete(turn());

		expect(result.text).toBe('📌 You asked: Fix the merge conflicts\n🔗 None');
	});

	test('leaves an answer that already ends with the footer alone', async ($, on) => {
		const answer = `${ANSWER}\n\n📌 You asked: Fix the merge conflicts.\n🔗 None`;
		on('turn.complete', ($, e) => ({text: e.answer}));

		const result = await $.turn.complete(turn({answer}));

		expect(result.text).toBe(answer);
	});

	test("leaves a subagent's turn alone", async ($, on) => {
		on('turn.complete', ($, e) => ({text: e.answer}));

		const result = await $.turn.complete(turn({agentId: 'a1'}));

		expect(result.text).toBe(ANSWER);
	});
});
