#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS_DIR="$PROJECT_ROOT/plugins/markdown-tasks/scripts"
  TODO="$BATS_TEST_TMPDIR/todo.md"

  cat >"$TODO" <<'EOF'
- [x] Done task
      Done context
- [ ] First task
      First context
- [!] Blocked task
      Blocked context
- [>] Claimed task
      Claimed context
- [ ] Second task
      Second context

- [ ] Third task
EOF
}

@test "no arguments still returns only the first incomplete task" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] First task\n      First context')" ]
}

@test "--index returns the Nth incomplete task, skipping [x], [!], and [>]" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --index 2
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] Second task\n      Second context')" ]
}

@test "--index 1 matches the no-argument behaviour" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --index 1
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] First task\n      First context')" ]
}

@test "--index past the last incomplete task exits 1 with a message" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --index 4
  [ "$status" -eq 1 ]
  [ "$output" = "Error: --index 4 is out of range; 3 incomplete tasks" ]
}

@test "--index 0 exits 1" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --index 0
  [ "$status" -eq 1 ]
}

@test "--range returns each selected task separated by a blank line" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --range 2-3
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] Second task\n      Second context\n\n- [ ] Third task')" ]
}

@test "--range stops at the last incomplete task" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --range 1-10
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] First task\n      First context\n\n- [ ] Second task\n      Second context\n\n- [ ] Third task')" ]
}

@test "--range starting past the last incomplete task exits 1" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --range 4-6
  [ "$status" -eq 1 ]
  [ "$output" = "Error: --range 4-6 is out of range; 3 incomplete tasks" ]
}

@test "--range with start after end exits 1" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --range 3-2
  [ "$status" -eq 1 ]
}

@test "--range that is not START-END exits 1" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --range 2
  [ "$status" -eq 1 ]
}

@test "--limit returns the first N incomplete tasks" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --limit 2
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] First task\n      First context\n\n- [ ] Second task\n      Second context')" ]
}

@test "--limit larger than the queue returns every incomplete task" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --limit 10
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [ ] First task\n      First context\n\n- [ ] Second task\n      Second context\n\n- [ ] Third task')" ]
}

@test "--limit on a list with no incomplete tasks prints nothing" {
  printf -- '- [x] Done\n- [!] Blocked\n' >"$TODO"

  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --limit 5
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "selection options are mutually exclusive" {
  run python "$SCRIPTS_DIR/task_get.py" "$TODO" --index 1 --limit 2
  [ "$status" -ne 0 ]
}
