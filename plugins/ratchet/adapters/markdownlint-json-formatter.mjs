import fs from 'node:fs';

export default function formatter(options) {
	const reportPath = process.env.RATCHET_MARKDOWNLINT_REPORT;
	if (reportPath) {
		const report = JSON.stringify({formatVersion: 1, results: options.results});
		fs.writeFileSync(reportPath, `${report}\n`, {encoding: 'utf8', flag: 'wx'});
		return;
	}

	for (const result of options.results) {
		options.logError(
			`${result.fileName}:${result.lineNumber}:${result.errorRange?.[0] ?? 1} ${result.ruleNames.join('/')} ${result.ruleDescription}`,
		);
	}
}
