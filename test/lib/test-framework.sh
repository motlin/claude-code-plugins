#!/bin/bash

set -Eeuo pipefail

TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

success_marker="✓"
failure_marker="✗"

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${success_marker} ${CURRENT_TEST}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ${failure_marker} ${CURRENT_TEST}"
    echo "    Expected: ${expected}"
    echo "    Actual:   ${actual}"
    [ -n "$message" ] && echo "    ${message}"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"

  if echo "$haystack" | grep -qF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${success_marker} ${CURRENT_TEST}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ${failure_marker} ${CURRENT_TEST}"
    echo "    Expected to find: ${needle}"
    echo "    In: ${haystack}"
    [ -n "$message" ] && echo "    ${message}"
  fi
}

assert_exit_code() {
  local expected_code="$1"
  local actual_code="$2"
  local message="${3:-}"

  if [ "$expected_code" -eq "$actual_code" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${success_marker} ${CURRENT_TEST}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ${failure_marker} ${CURRENT_TEST}"
    echo "    Expected exit code: ${expected_code}"
    echo "    Actual exit code:   ${actual_code}"
    [ -n "$message" ] && echo "    ${message}"
  fi
}

assert_json_field() {
  local json="$1"
  local field="$2"
  local expected="$3"
  local message="${4:-}"

  local actual
  actual=$(echo "$json" | jq --raw-output "$field")

  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ${success_marker} ${CURRENT_TEST}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ${failure_marker} ${CURRENT_TEST}"
    echo "    Field: ${field}"
    echo "    Expected: ${expected}"
    echo "    Actual:   ${actual}"
    [ -n "$message" ] && echo "    ${message}"
  fi
}

test() {
  CURRENT_TEST="$1"
}

run_test_file() {
  local test_file="$1"
  local filename
  filename=$(basename "$test_file")

  echo ""
  echo "Running ${filename}..."

  bash "$test_file"
  local result=$?

  if [ $result -ne 0 ]; then
    ((TESTS_FAILED++))
  else
    ((TESTS_PASSED++))
  fi

  return $result
}

print_summary() {
  local total=$((TESTS_PASSED + TESTS_FAILED))

  echo ""
  echo "========================================"
  echo "Test Results"
  echo "========================================"
  echo "Total:  ${total}"
  echo "Passed: ${TESTS_PASSED}"
  echo "Failed: ${TESTS_FAILED}"
  echo ""

  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo "${success_marker} All tests passed!"
    return 0
  else
    echo "${failure_marker} Some tests failed"
    return 1
  fi
}
