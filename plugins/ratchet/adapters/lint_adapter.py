#!/usr/bin/env python3

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path, PurePosixPath


TOOL = sys.argv[1] if len(sys.argv) > 1 else ""
OPERATION = sys.argv[2] if len(sys.argv) > 2 else ""
RULE = sys.argv[3] if len(sys.argv) > 3 else None
REPOSITORY_ROOT = Path.cwd().resolve()


def fail(message):
    print(f"{TOOL} adapter: {message}", file=sys.stderr)
    return 2


def run(command, environment=None):
    try:
        return subprocess.run(
            command,
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            env=environment,
            check=False,
        )
    except OSError as error:
        raise RuntimeError(f"unable to start {command[0]}: {error}") from error


def discover(pathspecs, excluded_prefixes=()):
    completed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", *pathspecs],
        cwd=REPOSITORY_ROOT,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode(errors="replace").strip()
        raise RuntimeError(f"file discovery failed: {diagnostic}")
    files = []
    for raw_path in completed.stdout.split(b"\0"):
        if not raw_path:
            continue
        path = raw_path.decode("utf-8")
        pure_path = PurePosixPath(path)
        if pure_path.is_absolute() or ".." in pure_path.parts:
            raise RuntimeError(f"discovered path escapes repository: {path}")
        if any(
            path == prefix
            or path.startswith(f"{prefix}/")
            or ("/" not in prefix and prefix in pure_path.parts)
            for prefix in excluded_prefixes
        ):
            continue
        if not (REPOSITORY_ROOT / path).is_file():
            raise RuntimeError(f"discovered path is not a file: {path}")
        files.append(path)
    return sorted(set(files))


def emit_scan(exit_code, exit_kind, report_format, files, counts):
    envelope = {
        "schemaVersion": 1,
        "tool": TOOL,
        "adapterVersion": 1,
        "run": {
            "toolExitCode": exit_code,
            "exitKind": exit_kind,
            "reportFormat": report_format,
            "filesDiscovered": len(files),
            "filesInvoked": len(files),
            "coverageProof": "explicit-argv",
        },
        "counts": dict(sorted(counts.items())),
    }
    print(json.dumps(envelope, separators=(",", ":"), ensure_ascii=False))


def atomic_write(path, content):
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def strip_jsonc(content):
    output = []
    index = 0
    in_string = False
    escaped = False
    while index < len(content):
        character = content[index]
        next_character = content[index + 1] if index + 1 < len(content) else ""
        if in_string:
            output.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            index += 1
            continue
        if character == '"':
            in_string = True
            output.append(character)
            index += 1
            continue
        if character == "/" and next_character == "/":
            index += 2
            while index < len(content) and content[index] not in "\r\n":
                index += 1
            continue
        if character == "/" and next_character == "*":
            closing = content.find("*/", index + 2)
            if closing < 0:
                raise RuntimeError("unterminated block comment in JSONC configuration")
            index = closing + 2
            continue
        output.append(character)
        index += 1
    return re.sub(r",\s*([}\]])", r"\1", "".join(output))


def load_jsonc(path):
    try:
        return json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"unable to parse {path}: {error}") from error


def emit_status(rule, enforced, source):
    print(
        json.dumps(
            {
                "schemaVersion": 1,
                "tool": TOOL,
                "rule": rule,
                "enforced": enforced,
                "source": source,
            },
            separators=(",", ":"),
        )
    )


def shellcheck_scan():
    files = discover(
        ["plugins/*/scripts/*.sh", "plugins/*/adapters/*.sh", "test/*.sh", "test/lib/*.sh", "install-local.sh"]
    )
    completed = run(["shellcheck", "--format=json", "--", *files])
    if completed.returncode not in {0, 1}:
        raise RuntimeError(
            f"shellcheck exited {completed.returncode}: {completed.stderr.strip() or 'no diagnostic output'}"
        )
    try:
        findings = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("shellcheck emitted malformed JSON") from error
    if not isinstance(findings, list):
        raise RuntimeError("shellcheck JSON report is not an array")
    counts = Counter()
    for finding in findings:
        if not isinstance(finding, dict) or not isinstance(finding.get("code"), int):
            raise RuntimeError("shellcheck JSON finding has no numeric code")
        counts[f"SC{finding['code']}"] += 1
    emit_scan(completed.returncode, "findings" if findings else "clean", "shellcheck-json-v1", files, counts)


def shellcheck_disabled_rules(path):
    if not path.exists():
        return set()
    disabled = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*disable\s*=\s*(.*)$", line)
        if match:
            disabled.update(value.strip().upper() for value in match.group(1).split(",") if value.strip())
    return disabled


def shellcheck_promote(rule):
    if not re.fullmatch(r"SC[0-9]+", rule):
        raise RuntimeError(f"invalid ShellCheck rule: {rule}")
    path = REPOSITORY_ROOT / ".shellcheckrc"
    if not path.exists():
        atomic_write(path, "external-sources=false\n")
        return
    content = path.read_text(encoding="utf-8")
    output = []
    for line in content.splitlines():
        match = re.match(r"^(\s*disable\s*=\s*)(.*)$", line)
        if not match:
            output.append(line)
            continue
        remaining = [value.strip() for value in match.group(2).split(",") if value.strip().upper() != rule]
        if remaining:
            output.append(f"{match.group(1)}{','.join(remaining)}")
    atomic_write(path, "\n".join(output) + "\n")


def shellcheck_status(rule):
    path = REPOSITORY_ROOT / ".shellcheckrc"
    emit_status(rule, rule not in shellcheck_disabled_rules(path), path.name)


def markdownlint_scan():
    files = discover(
        ["*.md", "**/*.md"],
        ("node_modules", ".claude", ".llm", ".remember", "plugins/offline-claude-code-guide/docs"),
    )
    ratchet_directory = REPOSITORY_ROOT / ".ratchet"
    descriptor, report_name = tempfile.mkstemp(prefix=".markdownlint-report.", suffix=".json", dir=ratchet_directory)
    os.close(descriptor)
    report_path = Path(report_name)
    report_path.unlink()
    environment = os.environ.copy()
    environment["RATCHET_MARKDOWNLINT_REPORT"] = str(report_path)
    try:
        completed = run(["markdownlint-cli2", "--no-globs", "--", *[f":{path}" for path in files]], environment)
        if completed.returncode not in {0, 1}:
            raise RuntimeError(
                f"markdownlint-cli2 exited {completed.returncode}: "
                f"{completed.stderr.strip() or completed.stdout.strip() or 'no diagnostic output'}"
            )
        if not report_path.is_file():
            raise RuntimeError("markdownlint-cli2 JSON formatter did not produce a report")
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise RuntimeError("markdownlint-cli2 formatter emitted malformed JSON") from error
    finally:
        if report_path.exists():
            report_path.unlink()
    if not isinstance(report, dict) or report.get("formatVersion") != 1 or not isinstance(report.get("results"), list):
        raise RuntimeError("markdownlint-cli2 formatter emitted an unknown report schema")
    counts = Counter()
    for finding in report["results"]:
        rule_names = finding.get("ruleNames") if isinstance(finding, dict) else None
        if not isinstance(rule_names, list) or not rule_names or not isinstance(rule_names[0], str):
            raise RuntimeError("markdownlint-cli2 JSON finding has no rule name")
        rule = rule_names[0].upper()
        if not re.fullmatch(r"MD[0-9]+", rule):
            raise RuntimeError(f"markdownlint-cli2 emitted an invalid rule name: {rule}")
        counts[rule] += 1
    emit_scan(
        completed.returncode,
        "findings" if report["results"] else "clean",
        "markdownlint-cli2-json-v1",
        files,
        counts,
    )


def markdownlint_promote(rule):
    if not re.fullmatch(r"MD[0-9]+", rule):
        raise RuntimeError(f"invalid markdownlint rule: {rule}")
    path = REPOSITORY_ROOT / ".markdownlint.jsonc"
    content = path.read_text(encoding="utf-8")
    pattern = re.compile(rf'("{re.escape(rule)}"\s*:\s*)false\b')
    updated, replacements = pattern.subn(r"\g<1>true", content, count=1)
    configuration = load_jsonc(path)
    if replacements == 0 and configuration.get(rule) is False:
        raise RuntimeError(f"unable to edit {rule} in {path}")
    if replacements:
        atomic_write(path, updated)


def markdownlint_status(rule):
    path = REPOSITORY_ROOT / ".markdownlint.jsonc"
    configuration = load_jsonc(path)
    emit_status(rule, configuration.get(rule, configuration.get("default", True)) is not False, path.name)


def yamllint_scan():
    files = discover(["*.yaml", "*.yml", "**/*.yaml", "**/*.yml", ".yamllint"], (".serena", ".llm", ".remember", "node_modules"))
    completed = run(["yamllint", "--format=parsable", "--", *files])
    if completed.returncode not in {0, 1}:
        raise RuntimeError(
            f"yamllint exited {completed.returncode}: {completed.stderr.strip() or 'no diagnostic output'}"
        )
    counts = Counter()
    for line in completed.stdout.splitlines():
        match = re.fullmatch(r".+:[0-9]+:[0-9]+: \[(?:warning|error)\] .+ \(([^()]+)\)", line)
        if not match:
            raise RuntimeError(f"yamllint emitted an unrecognized parsable record: {line}")
        counts[match.group(1)] += 1
    emit_scan(
        completed.returncode,
        "findings" if counts else "clean",
        "yamllint-parsable-v1",
        files,
        counts,
    )


def yaml_rule_block(content, rule):
    match = re.search(rf"(?m)^    {re.escape(rule)}:(.*)$", content)
    if not match:
        return None
    start = match.start()
    following = re.search(r"(?m)^    [A-Za-z0-9_-]+:", content[match.end() :])
    end = match.end() + following.start() if following else len(content)
    return start, end, content[start:end]


def yamllint_promote(rule):
    if not re.fullmatch(r"[a-z0-9-]+", rule):
        raise RuntimeError(f"invalid yamllint rule: {rule}")
    path = REPOSITORY_ROOT / ".yamllint.yaml"
    content = path.read_text(encoding="utf-8")
    block = yaml_rule_block(content, rule)
    if block is None:
        if not content.endswith("\n"):
            content += "\n"
        atomic_write(path, f"{content}    {rule}:\n        level: error\n")
        return
    start, end, rule_content = block
    if re.search(r"(?m)^        level:\s*warning\s*$", rule_content):
        rule_content = re.sub(
            r"(?m)^(        level:)\s*warning\s*$", r"\1 error", rule_content, count=1
        )
    elif re.fullmatch(rf"{re.escape(rule)}:\s*disable", rule_content.strip()):
        rule_content = f"    {rule}:\n        level: error\n"
    elif not re.search(r"(?m)^        level:\s*error\s*$", rule_content):
        first_line_end = rule_content.find("\n")
        if first_line_end < 0:
            rule_content = f"    {rule}:\n        level: error\n"
        else:
            rule_content = f"{rule_content[:first_line_end + 1]}        level: error\n{rule_content[first_line_end + 1:]}"
    atomic_write(path, f"{content[:start]}{rule_content}{content[end:]}")


def yamllint_status(rule):
    path = REPOSITORY_ROOT / ".yamllint.yaml"
    content = path.read_text(encoding="utf-8")
    block = yaml_rule_block(content, rule)
    enforced = block is not None and (
        re.search(r"(?m)^        level:\s*error\s*$", block[2]) is not None
        or re.fullmatch(rf"{re.escape(rule)}:\s*enable", block[2].strip()) is not None
    )
    emit_status(rule, enforced, path.name)


def oxlint_executable():
    local_vite_plus = REPOSITORY_ROOT / "node_modules" / ".bin" / "vp"
    if local_vite_plus.is_file() and os.access(local_vite_plus, os.X_OK):
        return [str(local_vite_plus), "lint"]
    executable = shutil.which("oxlint")
    if executable:
        return [executable]
    raise RuntimeError("neither node_modules/.bin/vp nor oxlint is available")


def oxlint_scan():
    files = discover(
        ["*.js", "*.jsx", "*.mjs", "*.cjs", "*.ts", "*.tsx", "*.mts", "*.cts", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs", "**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
        ("node_modules",),
    )
    completed = run([*oxlint_executable(), "--format", "json", "--", *files])
    if completed.returncode not in {0, 1}:
        raise RuntimeError(
            f"oxlint exited {completed.returncode}: {completed.stderr.strip() or 'no diagnostic output'}"
        )
    try:
        report = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("oxlint emitted malformed JSON") from error
    if not isinstance(report, dict) or not isinstance(report.get("diagnostics"), list):
        raise RuntimeError("oxlint JSON report has an unknown schema")
    if report.get("number_of_files") != len(files):
        raise RuntimeError(
            f"oxlint checked {report.get('number_of_files')} files after {len(files)} were discovered"
        )
    counts = Counter()
    for finding in report["diagnostics"]:
        code = finding.get("code") if isinstance(finding, dict) else None
        if not isinstance(code, str) or not re.fullmatch(r"[a-z0-9@_-]+\([a-z0-9@/_-]+\)", code):
            raise RuntimeError(f"oxlint emitted an invalid rule code: {code}")
        counts[code] += 1
    emit_scan(completed.returncode, "findings" if counts else "clean", "oxlint-json-v1", files, counts)


def oxlint_configuration_rule(rule):
    match = re.fullmatch(r"([a-z0-9@_-]+)\(([a-z0-9@/_-]+)\)", rule)
    if not match:
        raise RuntimeError(f"invalid oxlint rule: {rule}")
    return f"{match.group(1)}/{match.group(2)}"


def oxlint_promote(rule):
    path = REPOSITORY_ROOT / ".oxlintrc.json"
    if not path.exists():
        raise RuntimeError("oxlint promotion requires a durable .oxlintrc.json configuration")
    configuration = load_jsonc(path)
    rules = configuration.setdefault("rules", {})
    if not isinstance(rules, dict):
        raise RuntimeError(".oxlintrc.json rules must be an object")
    rules[oxlint_configuration_rule(rule)] = "error"
    atomic_write(path, json.dumps(configuration, indent=2, sort_keys=True) + "\n")


def oxlint_status(rule):
    path = REPOSITORY_ROOT / ".oxlintrc.json"
    configuration = load_jsonc(path)
    severity = configuration.get("rules", {}).get(oxlint_configuration_rule(rule))
    emit_status(rule, severity in {"error", "deny", 2}, path.name)


def main():
    if TOOL not in {"shellcheck", "markdownlint", "yamllint", "oxlint"}:
        return fail(f"unknown tool: {TOOL}")
    if OPERATION == "scan" and RULE is None:
        globals()[f"{TOOL}_scan"]()
        return 0
    if OPERATION == "promote" and RULE is not None:
        globals()[f"{TOOL}_promote"](RULE)
        return 0
    if OPERATION == "promotion-status" and RULE is not None:
        globals()[f"{TOOL}_status"](RULE)
        return 0
    return fail("usage: ADAPTER scan | promote RULE | promotion-status RULE")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        sys.exit(fail(str(error)))
