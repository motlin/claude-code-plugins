#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path


EXIT_REGRESSION = 1
EXIT_INFRASTRUCTURE = 2
EXIT_ACCEPTANCE = 3
EXIT_PROMOTION = 4
EXIT_USAGE = 64


class RatchetError(Exception):
    def __init__(self, message, exit_code=EXIT_INFRASTRUCTURE):
        super().__init__(message)
        self.exit_code = exit_code


def require(condition, message, exit_code=EXIT_INFRASTRUCTURE):
    if not condition:
        raise RatchetError(message, exit_code)


def read_json(path, description):
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise RatchetError(f"Unable to read {description} {path}: {error}") from error


def load_configuration(repository_root):
    configuration_path = repository_root / ".ratchet" / "config.json"
    configuration = read_json(configuration_path, "ratchet configuration")
    require(configuration.get("schemaVersion") == 1, "Unsupported ratchet configuration schema")
    require(
        isinstance(configuration.get("timeoutSeconds"), int)
        and configuration["timeoutSeconds"] > 0,
        "timeoutSeconds must be a positive integer",
    )
    adapters = configuration.get("adapters")
    require(isinstance(adapters, dict) and adapters, "Ratchet configuration has no adapters")
    for tool, adapter in adapters.items():
        require(isinstance(tool, str) and tool, "Adapter tool names must be nonempty strings")
        require(isinstance(adapter, dict), f"Adapter configuration for {tool} must be an object")
        command = adapter.get("command")
        require(
            isinstance(command, list)
            and command
            and all(isinstance(part, str) and part for part in command),
            f"Adapter command for {tool} must be a nonempty string array",
        )
    return configuration


def load_baseline(repository_root, tool):
    baseline_path = repository_root / ".ratchet" / f"{tool}.json"
    baseline = read_json(baseline_path, "baseline")
    require(baseline.get("schemaVersion") == 1, f"Unsupported baseline schema for {tool}")
    require(baseline.get("tool") == tool, f"Baseline tool identity does not match {tool}")
    require(baseline.get("adapterVersion") == 1, f"Unsupported adapter version for {tool}")
    coverage = baseline.get("coverage")
    require(isinstance(coverage, dict), f"Baseline coverage for {tool} must be an object")
    require(
        isinstance(coverage.get("lastAcceptedFileCount"), int)
        and coverage["lastAcceptedFileCount"] >= 0,
        f"Baseline coverage for {tool} is invalid",
    )
    require(isinstance(coverage.get("allowEmpty"), bool), f"allowEmpty for {tool} must be boolean")
    rules = baseline.get("rules")
    require(isinstance(rules, dict), f"Baseline rules for {tool} must be an object")
    for rule, count in rules.items():
        require(isinstance(rule, str) and rule, f"Baseline for {tool} has an empty rule")
        require(
            isinstance(count, int) and not isinstance(count, bool) and count > 0,
            f"Baseline count for {tool}/{rule} must be a positive integer",
        )
    return baseline_path, baseline


def adapter_command(repository_root, configured_command):
    executable = Path(configured_command[0])
    if not executable.is_absolute():
        executable = repository_root / executable
    try:
        executable.relative_to(repository_root)
    except ValueError as error:
        raise RatchetError(f"Adapter executable escapes repository root: {executable}") from error
    require(executable.is_file(), f"Adapter executable does not exist: {executable}")
    require(os.access(executable, os.X_OK), f"Adapter executable is not executable: {executable}")
    return [str(executable), *configured_command[1:]]


def run_adapter(repository_root, configuration, tool, operation, rule=None):
    adapter = configuration["adapters"].get(tool)
    require(adapter is not None, f"Unknown ratchet tool: {tool}", EXIT_USAGE)
    command = adapter_command(repository_root, adapter["command"])
    command.append(operation)
    if rule is not None:
        command.append(rule)
    try:
        completed = subprocess.run(
            command,
            cwd=repository_root,
            capture_output=True,
            text=True,
            timeout=configuration["timeoutSeconds"],
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise RatchetError(
            f"{tool} adapter timed out after {configuration['timeoutSeconds']} seconds"
        ) from error
    if completed.returncode != 0:
        diagnostic = completed.stderr.strip() or completed.stdout.strip() or "no diagnostic output"
        raise RatchetError(f"{tool} adapter failed ({completed.returncode}): {diagnostic}")
    return completed.stdout


def validate_scan_envelope(envelope, tool, allow_empty):
    require(isinstance(envelope, dict), f"{tool} adapter report must be an object")
    require(envelope.get("schemaVersion") == 1, f"{tool} adapter report has an unknown schema")
    require(envelope.get("tool") == tool, f"{tool} adapter report has the wrong tool identity")
    require(envelope.get("adapterVersion") == 1, f"{tool} adapter report has an unknown version")
    run = envelope.get("run")
    require(isinstance(run, dict), f"{tool} adapter report has no run proof")
    require(
        isinstance(run.get("toolExitCode"), int) and not isinstance(run["toolExitCode"], bool),
        f"{tool} adapter report has an invalid tool exit code",
    )
    require(run.get("exitKind") in {"clean", "findings"}, f"{tool} adapter run was not completed")
    require(
        isinstance(run.get("reportFormat"), str) and run["reportFormat"],
        f"{tool} adapter report format is missing",
    )
    files_discovered = run.get("filesDiscovered")
    files_invoked = run.get("filesInvoked")
    require(
        isinstance(files_discovered, int)
        and not isinstance(files_discovered, bool)
        and files_discovered >= 0,
        f"{tool} adapter discovered an invalid file count",
    )
    require(
        isinstance(files_invoked, int)
        and not isinstance(files_invoked, bool)
        and files_invoked == files_discovered,
        f"{tool} adapter did not invoke its complete discovered file set",
    )
    require(run.get("coverageProof") == "explicit-argv", f"{tool} adapter lacks coverage proof")
    require(allow_empty or files_discovered > 0, f"{tool} adapter discovered zero files")
    counts = envelope.get("counts")
    require(isinstance(counts, dict), f"{tool} adapter counts must be an object")
    for rule, count in counts.items():
        require(isinstance(rule, str) and rule, f"{tool} adapter emitted an empty rule")
        require(
            isinstance(count, int) and not isinstance(count, bool) and count >= 0,
            f"{tool} adapter emitted an invalid count for {rule}",
        )
    return envelope


def scan(repository_root, configuration, tool, allow_empty):
    output = run_adapter(repository_root, configuration, tool, "scan")
    try:
        envelope = json.loads(output)
    except json.JSONDecodeError as error:
        raise RatchetError(f"{tool} adapter emitted an invalid or incomplete JSON report") from error
    return validate_scan_envelope(envelope, tool, allow_empty)


def compare(tool, baseline, envelope):
    accepted_file_count = baseline["coverage"]["lastAcceptedFileCount"]
    current_file_count = envelope["run"]["filesDiscovered"]
    states = []
    rows = []
    if current_file_count < accepted_file_count:
        states.append("infrastructure")
        rows.append((tool, "<coverage>", accepted_file_count, current_file_count, "coverage-drop"))
    elif current_file_count > accepted_file_count:
        states.append("acceptance")
        rows.append((tool, "<coverage>", accepted_file_count, current_file_count, "accept-coverage"))
    all_rules = sorted(set(baseline["rules"]) | set(envelope["counts"]))
    for rule in all_rules:
        accepted = baseline["rules"].get(rule, 0)
        current = envelope["counts"].get(rule, 0)
        if current > accepted:
            state = "regression"
        elif current == accepted:
            state = "equal"
        elif current == 0:
            state = "promote"
        else:
            state = "accept"
        rows.append((tool, rule, accepted, current, state))
        if state == "regression":
            states.append("regression")
        elif state == "promote":
            states.append("promotion")
        elif state == "accept":
            states.append("acceptance")
    return rows, states


def print_rows(rows):
    if not rows:
        return
    print("tool\trule\tbaseline\tcurrent\tstate")
    for row in rows:
        print("\t".join(str(value) for value in row))


def result_exit_code(states):
    if "infrastructure" in states:
        return EXIT_INFRASTRUCTURE
    if "regression" in states:
        return EXIT_REGRESSION
    if "promotion" in states:
        return EXIT_PROMOTION
    if "acceptance" in states:
        return EXIT_ACCEPTANCE
    return 0


def check(repository_root, configuration, requested_tool=None):
    if requested_tool is not None:
        require(requested_tool in configuration["adapters"], f"Unknown ratchet tool: {requested_tool}", EXIT_USAGE)
    tools = [requested_tool] if requested_tool else sorted(configuration["adapters"])
    all_rows = []
    all_states = []
    errors = []
    for tool in tools:
        try:
            _, baseline = load_baseline(repository_root, tool)
            envelope = scan(repository_root, configuration, tool, baseline["coverage"]["allowEmpty"])
            rows, states = compare(tool, baseline, envelope)
            all_rows.extend(rows)
            all_states.extend(states)
        except RatchetError as error:
            errors.append(str(error))
            all_states.append("infrastructure")
    print_rows(all_rows)
    sys.stdout.flush()
    for error in errors:
        print(f"ratchet: {error}", file=sys.stderr)
    for tool, rule, _, _, state in all_rows:
        if state == "accept":
            print(f"Run: just ratchet-accept {tool}", file=sys.stderr)
        elif state == "accept-coverage" or state == "coverage-drop":
            print(f"Run: just ratchet-accept-coverage {tool}", file=sys.stderr)
        elif state == "promote":
            print(f"Run: just ratchet-promote {tool} {rule}", file=sys.stderr)
    return result_exit_code(all_states)


def canonical_baseline(baseline):
    canonical = {
        "schemaVersion": baseline["schemaVersion"],
        "tool": baseline["tool"],
        "adapterVersion": baseline["adapterVersion"],
        "coverage": {
            "lastAcceptedFileCount": baseline["coverage"]["lastAcceptedFileCount"],
            "allowEmpty": baseline["coverage"]["allowEmpty"],
        },
        "rules": dict(sorted(baseline["rules"].items())),
    }
    return json.dumps(canonical, indent=2, ensure_ascii=False) + "\n"


def atomic_write(path, content):
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
        directory_descriptor = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


@contextmanager
def tool_lock(repository_root, tool):
    lock_path = repository_root / ".ratchet" / f".{tool}.lock"
    try:
        lock_path.mkdir()
    except FileExistsError as error:
        raise RatchetError(f"Another ratchet operation holds the {tool} lock") from error
    try:
        yield
    finally:
        lock_path.rmdir()


def require_unchanged_coverage(tool, baseline, envelope):
    accepted = baseline["coverage"]["lastAcceptedFileCount"]
    current = envelope["run"]["filesDiscovered"]
    require(
        current == accepted,
        f"{tool} coverage changed from {accepted} to {current}; run just ratchet-accept-coverage {tool}",
    )


def reject_regressions(tool, baseline, envelope):
    for rule in sorted(set(baseline["rules"]) | set(envelope["counts"])):
        accepted = baseline["rules"].get(rule, 0)
        current = envelope["counts"].get(rule, 0)
        require(current <= accepted, f"{tool}/{rule} increased from {accepted} to {current}", EXIT_REGRESSION)


def accept(repository_root, configuration, tool):
    with tool_lock(repository_root, tool):
        baseline_path, baseline = load_baseline(repository_root, tool)
        envelope = scan(repository_root, configuration, tool, baseline["coverage"]["allowEmpty"])
        require_unchanged_coverage(tool, baseline, envelope)
        reject_regressions(tool, baseline, envelope)
        zero_rules = [rule for rule in baseline["rules"] if envelope["counts"].get(rule, 0) == 0]
        require(
            not zero_rules,
            f"{tool} rules require promotion: {', '.join(sorted(zero_rules))}",
            EXIT_PROMOTION,
        )
        changed = False
        for rule, accepted in list(baseline["rules"].items()):
            current = envelope["counts"].get(rule, 0)
            if 0 < current < accepted:
                baseline["rules"][rule] = current
                changed = True
        if changed:
            atomic_write(baseline_path, canonical_baseline(baseline))
            print(f"Accepted guarded decreases in {baseline_path.relative_to(repository_root)}")
        else:
            print(f"No positive decreases to accept for {tool}")
    return 0


def accept_coverage(repository_root, configuration, tool):
    with tool_lock(repository_root, tool):
        baseline_path, baseline = load_baseline(repository_root, tool)
        envelope = scan(repository_root, configuration, tool, baseline["coverage"]["allowEmpty"])
        reject_regressions(tool, baseline, envelope)
        old_count = baseline["coverage"]["lastAcceptedFileCount"]
        new_count = envelope["run"]["filesDiscovered"]
        baseline["coverage"]["lastAcceptedFileCount"] = new_count
        if old_count != new_count:
            atomic_write(baseline_path, canonical_baseline(baseline))
        print(f"Accepted {tool} coverage change: {old_count} -> {new_count}")
    return 0


def validate_promotion_status(output, tool, rule, repository_root):
    try:
        status = json.loads(output)
    except json.JSONDecodeError as error:
        raise RatchetError(f"{tool} promotion status is not valid JSON") from error
    require(status.get("schemaVersion") == 1, f"{tool} promotion status has an unknown schema")
    require(status.get("tool") == tool, f"{tool} promotion status has the wrong tool identity")
    require(status.get("rule") == rule, f"{tool} promotion status has the wrong rule")
    require(status.get("enforced") is True, f"{tool}/{rule} is not durably enforced")
    source = status.get("source")
    require(isinstance(source, str) and source, f"{tool} promotion status has no enforcement source")
    source_path = repository_root / source
    try:
        source_path.resolve().relative_to(repository_root.resolve())
    except ValueError as error:
        raise RatchetError(f"{tool} promotion source escapes the repository: {source}") from error
    require(source_path.is_file(), f"{tool} promotion source does not exist: {source}")
    return source


def promote(repository_root, configuration, tool, rule):
    with tool_lock(repository_root, tool):
        baseline_path, baseline = load_baseline(repository_root, tool)
        require(rule in baseline["rules"], f"{tool}/{rule} is not present in the baseline", EXIT_USAGE)
        before = scan(repository_root, configuration, tool, baseline["coverage"]["allowEmpty"])
        require_unchanged_coverage(tool, baseline, before)
        reject_regressions(tool, baseline, before)
        require(before["counts"].get(rule, 0) == 0, f"{tool}/{rule} still has findings", EXIT_REGRESSION)
        run_adapter(repository_root, configuration, tool, "promote", rule)
        status_output = run_adapter(repository_root, configuration, tool, "promotion-status", rule)
        source = validate_promotion_status(status_output, tool, rule, repository_root)
        after = scan(repository_root, configuration, tool, baseline["coverage"]["allowEmpty"])
        require_unchanged_coverage(tool, baseline, after)
        reject_regressions(tool, baseline, after)
        require(after["counts"].get(rule, 0) == 0, f"{tool}/{rule} failed after promotion")
        del baseline["rules"][rule]
        atomic_write(baseline_path, canonical_baseline(baseline))
        print(f"Promoted {tool}/{rule} in {source} and updated {baseline_path.relative_to(repository_root)}")
    return 0


def initialize(repository_root, configuration, tool, allow_empty=False):
    baseline_path = repository_root / ".ratchet" / f"{tool}.json"
    require(not baseline_path.exists(), f"Baseline already exists for {tool}", EXIT_USAGE)
    with tool_lock(repository_root, tool):
        envelope = scan(repository_root, configuration, tool, allow_empty)
        baseline = {
            "schemaVersion": 1,
            "tool": tool,
            "adapterVersion": 1,
            "coverage": {
                "lastAcceptedFileCount": envelope["run"]["filesDiscovered"],
                "allowEmpty": allow_empty,
            },
            "rules": {rule: count for rule, count in envelope["counts"].items() if count > 0},
        }
        atomic_write(baseline_path, canonical_baseline(baseline))
        print(f"Initialized {baseline_path.relative_to(repository_root)}")
    return 0


def usage():
    print(
        "Usage: ratchet.sh check [TOOL] | accept TOOL | accept-coverage TOOL | "
        "promote TOOL RULE | initialize TOOL",
        file=sys.stderr,
    )


def main(arguments):
    repository_root = Path.cwd().resolve()
    try:
        configuration = load_configuration(repository_root)
        require(arguments, "Missing ratchet command", EXIT_USAGE)
        command = arguments[0]
        if command == "check" and len(arguments) in {1, 2}:
            return check(repository_root, configuration, arguments[1] if len(arguments) == 2 else None)
        if command == "accept" and len(arguments) == 2:
            return accept(repository_root, configuration, arguments[1])
        if command == "accept-coverage" and len(arguments) == 2:
            return accept_coverage(repository_root, configuration, arguments[1])
        if command == "promote" and len(arguments) == 3:
            return promote(repository_root, configuration, arguments[1], arguments[2])
        if command == "initialize" and len(arguments) == 2:
            return initialize(repository_root, configuration, arguments[1])
        usage()
        return EXIT_USAGE
    except RatchetError as error:
        print(f"ratchet: {error}", file=sys.stderr)
        return error.exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
