#!/usr/bin/env python3

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath


TOOL = sys.argv[1] if len(sys.argv) > 1 else ""
OPERATION = sys.argv[2] if len(sys.argv) > 2 else ""
RULE = sys.argv[3] if len(sys.argv) > 3 else None
REPOSITORY_ROOT = Path.cwd().resolve()
CONFIGURATION_PATH = REPOSITORY_ROOT / ".ratchet" / "vitest-adapter.json"
RULES = {"SKIPPED_TESTS", "ZERO_TEST_FILES"}


def fail(message):
    print(f"{TOOL} adapter: {message}", file=sys.stderr)
    return 2


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def read_json(path, description):
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"unable to read {description} {path}: {error}") from error


def repository_path(value, description):
    require(isinstance(value, str) and value, f"{description} must be a nonempty string")
    path = Path(value)
    require(not path.is_absolute(), f"{description} must be repository-relative")
    resolved = (REPOSITORY_ROOT / path).resolve()
    try:
        resolved.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise RuntimeError(f"{description} escapes the repository: {value}") from error
    return resolved


def load_configuration():
    configuration = read_json(CONFIGURATION_PATH, "Vitest adapter configuration")
    require(configuration.get("schemaVersion") == 1, "unsupported Vitest adapter configuration schema")
    command = configuration.get("command")
    require(
        isinstance(command, list)
        and command
        and all(isinstance(part, str) and part for part in command),
        "Vitest command must be a nonempty string array",
    )
    executable = repository_path(command[0], "Vitest executable")
    require(executable.is_file() and os.access(executable, os.X_OK), f"Vitest executable is not executable: {command[0]}")
    for key in ("sourceFileGlobs", "testFileGlobs"):
        patterns = configuration.get(key)
        require(
            isinstance(patterns, list)
            and patterns
            and all(isinstance(pattern, str) and pattern for pattern in patterns),
            f"{key} must be a nonempty string array",
        )
    enforcement_path = repository_path(configuration.get("enforcementFile"), "enforcementFile")
    return configuration, [str(executable), *command[1:]], enforcement_path


def discover(patterns):
    completed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", *patterns],
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
        if not (REPOSITORY_ROOT / path).is_file():
            raise RuntimeError(f"discovered path is not a file: {path}")
        files.append(path)
    return sorted(set(files))


def normalized_report_path(value, description):
    require(isinstance(value, str) and value, f"{description} has no file name")
    path = Path(value)
    resolved = path.resolve() if path.is_absolute() else (REPOSITORY_ROOT / path).resolve()
    try:
        return resolved.relative_to(REPOSITORY_ROOT).as_posix()
    except ValueError as error:
        raise RuntimeError(f"{description} escapes the repository: {value}") from error


def nonnegative_integer(value, description):
    require(isinstance(value, int) and not isinstance(value, bool) and value >= 0, f"{description} must be a nonnegative integer")
    return value


def validate_test_report(report, test_files):
    require(isinstance(report, dict), "Vitest JSON report must be an object")
    for field in (
        "numFailedTests",
        "numFailedTestSuites",
        "numPassedTests",
        "numPassedTestSuites",
        "numPendingTests",
        "numPendingTestSuites",
        "numTodoTests",
        "numTotalTests",
        "numTotalTestSuites",
    ):
        nonnegative_integer(report.get(field), f"Vitest {field}")
    require(report.get("success") is True, "Vitest reported an unsuccessful test run")
    require(report["numFailedTests"] == 0 and report["numFailedTestSuites"] == 0, "Vitest report contains failures")
    results = report.get("testResults")
    require(isinstance(results, list), "Vitest JSON report has no testResults array")
    accepted_statuses = {"passed", "failed", "skipped", "pending", "todo", "disabled"}
    reported_files = []
    status_counts = {status: 0 for status in accepted_statuses}
    assertion_count = 0
    for result in results:
        require(isinstance(result, dict), "Vitest test result must be an object")
        require(result.get("status") == "passed", f"Vitest test file did not pass: {result.get('name')}")
        reported_files.append(normalized_report_path(result.get("name"), "Vitest test result"))
        assertions = result.get("assertionResults")
        require(isinstance(assertions, list), "Vitest test result has no assertionResults array")
        for assertion in assertions:
            require(isinstance(assertion, dict), "Vitest assertion result must be an object")
            status = assertion.get("status")
            require(status in accepted_statuses, f"Vitest assertion has an unknown status: {status}")
            assertion_count += 1
            status_counts[status] += 1
    require(sorted(reported_files) == test_files, "Vitest did not report the complete explicit test-file set")
    require(assertion_count == report["numTotalTests"], "Vitest total test count does not match assertion results")
    require(
        status_counts["passed"] == report["numPassedTests"],
        "Vitest passed test count does not match assertion results",
    )
    require(status_counts["failed"] == report["numFailedTests"], "Vitest failed test count does not match assertion results")
    require(
        status_counts["skipped"] + status_counts["pending"] == report["numPendingTests"],
        "Vitest pending test count does not match assertion results",
    )
    require(status_counts["todo"] == report["numTodoTests"], "Vitest todo test count does not match assertion results")
    return report["numPendingTests"] + report["numTodoTests"] + status_counts["disabled"]


def validate_coverage(report, source_files):
    coverage_map = report.get("coverageMap")
    require(isinstance(coverage_map, dict), "Vitest JSON report has no Istanbul coverage map")
    normalized_coverage = {}
    for native_path, coverage in coverage_map.items():
        normalized_path = normalized_report_path(native_path, "Vitest coverage entry")
        require(normalized_path not in normalized_coverage, f"Vitest coverage contains duplicate file: {normalized_path}")
        require(isinstance(coverage, dict), f"Vitest coverage for {normalized_path} must be an object")
        statements = coverage.get("s")
        require(isinstance(statements, dict), f"Vitest coverage for {normalized_path} has no statement counters")
        for counter in statements.values():
            nonnegative_integer(counter, f"Vitest statement count for {normalized_path}")
        normalized_coverage[normalized_path] = statements
    require(sorted(normalized_coverage) == source_files, "Vitest coverage does not match the complete explicit source-file set")
    return sum(1 for statements in normalized_coverage.values() if statements and all(count == 0 for count in statements.values()))


def enforced_rules(path):
    if not path.exists():
        return set()
    enforcement = read_json(path, "Vitest enforcement configuration")
    require(enforcement.get("schemaVersion") == 1, "unsupported Vitest enforcement schema")
    rules = enforcement.get("enforcedRules")
    require(
        isinstance(rules, list)
        and len(rules) == len(set(rules))
        and all(rule in RULES for rule in rules),
        "Vitest enforcedRules must contain unique supported rule names",
    )
    return set(rules)


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
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


def emit_scan(files, counts):
    envelope = {
        "schemaVersion": 1,
        "tool": TOOL,
        "adapterVersion": 1,
        "run": {
            "toolExitCode": 0,
            "exitKind": "findings" if any(counts.values()) else "clean",
            "reportFormat": "vitest-json-v1+istanbul-coverage-v1",
            "filesDiscovered": len(files),
            "filesInvoked": len(files),
            "coverageProof": "explicit-argv",
        },
        "counts": dict(sorted(counts.items())),
    }
    print(json.dumps(envelope, separators=(",", ":"), ensure_ascii=False))


def scan():
    configuration, command, enforcement_path = load_configuration()
    source_files = discover(configuration["sourceFileGlobs"])
    test_files = discover(configuration["testFileGlobs"])
    require(source_files, "source-file discovery returned no files")
    require(test_files, "test-file discovery returned no files")
    ratchet_directory = REPOSITORY_ROOT / ".ratchet"
    coverage_directory = Path(tempfile.mkdtemp(prefix=".vitest-coverage.", dir=ratchet_directory))
    descriptor, report_name = tempfile.mkstemp(prefix=".vitest-report.", suffix=".json", dir=ratchet_directory)
    os.close(descriptor)
    report_path = Path(report_name)
    report_path.unlink()
    arguments = [
        *command,
        "--reporter=json",
        f"--outputFile={report_path}",
        "--coverage.enabled=true",
        "--coverage.reporter=json",
        f"--coverage.reportsDirectory={coverage_directory}",
        *[f"--coverage.include={path}" for path in source_files],
        "--",
        *test_files,
    ]
    try:
        completed = subprocess.run(arguments, cwd=REPOSITORY_ROOT, capture_output=True, text=True, check=False)
        if completed.returncode != 0:
            diagnostic = completed.stderr.strip() or completed.stdout.strip() or "no diagnostic output"
            raise RuntimeError(f"Vitest exited {completed.returncode}: {diagnostic}")
        require(report_path.is_file(), "Vitest JSON reporter did not produce a report")
        report = read_json(report_path, "Vitest JSON report")
    finally:
        if report_path.exists():
            report_path.unlink()
        shutil.rmtree(coverage_directory)
    counts = {
        "SKIPPED_TESTS": validate_test_report(report, test_files),
        "ZERO_TEST_FILES": validate_coverage(report, source_files),
    }
    enforced_rules(enforcement_path)
    emit_scan(source_files, counts)


def promote(rule):
    require(rule in RULES, f"unsupported Vitest rule: {rule}")
    _, _, enforcement_path = load_configuration()
    rules = enforced_rules(enforcement_path)
    rules.add(rule)
    content = json.dumps({"schemaVersion": 1, "enforcedRules": sorted(rules)}, indent=2) + "\n"
    atomic_write(enforcement_path, content)


def promotion_status(rule):
    require(rule in RULES, f"unsupported Vitest rule: {rule}")
    _, _, enforcement_path = load_configuration()
    source = enforcement_path.relative_to(REPOSITORY_ROOT).as_posix()
    status = {
        "schemaVersion": 1,
        "tool": TOOL,
        "rule": rule,
        "enforced": rule in enforced_rules(enforcement_path),
        "source": source,
    }
    print(json.dumps(status, separators=(",", ":")))


def main():
    if TOOL != "vitest":
        return fail(f"unknown tool: {TOOL}")
    if OPERATION == "scan" and RULE is None:
        scan()
        return 0
    if OPERATION == "promote" and RULE is not None:
        promote(RULE)
        return 0
    if OPERATION == "promotion-status" and RULE is not None:
        promotion_status(RULE)
        return 0
    return fail("usage: ADAPTER scan | promote RULE | promotion-status RULE")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        sys.exit(fail(str(error)))
