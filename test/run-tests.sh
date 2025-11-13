#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Plugin Hook Test Suite"
echo "========================================"

test_files=(
  "$script_dir/hooks/test-hooks-json-validation.sh"
  "$script_dir/hooks/test-tmux-hooks.sh"
  "$script_dir/hooks/test-iterm2-hooks.sh"
)

total_failures=0

for test_file in "${test_files[@]}"; do
  filename=$(basename "$test_file")
  echo ""
  echo "Running ${filename}..."

  if bash "$test_file"; then
    echo "  ${filename}: passed"
  else
    echo "  ${filename}: failed"
    total_failures=$((total_failures + 1))
  fi
done

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo "Test files: ${#test_files[@]}"
echo "Failed: ${total_failures}"
echo ""

if [ "$total_failures" -eq 0 ]; then
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
