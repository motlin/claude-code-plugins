#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS_DIR="$PROJECT_ROOT/plugins/markdown-tasks/scripts"
  LLM_DIR="$BATS_TEST_TMPDIR/.llm"
  TODO="$LLM_DIR/todo.md"
  mkdir -p "$LLM_DIR"
  TODAY="$(date +%Y-%m-%d)"
  ARCHIVE="$LLM_DIR/$TODAY-todo.md"
}

write_todo() {
  cat >"$TODO"
}

@test "carries a blocked task forward and archives the rest" {
  write_todo <<'EOF'
- [x] Finished task
      Finished context
- [!] Blocked task
      Blocked context
      Blocked: the API returned 500 on every attempt
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [!] Blocked task"* ]]
  [[ "$output" == *"Blocked context"* ]]
  [[ "$output" == *"Blocked: the API returned 500 on every attempt"* ]]
  [[ "$output" != *"Finished task"* ]]

  run cat "$ARCHIVE"
  [[ "$output" == *"- [x] Finished task"* ]]
  [[ "$output" == *"Finished context"* ]]
  [[ "$output" != *"Blocked task"* ]]
  [[ "$output" != *"Blocked context"* ]]
}

@test "keeps carried forward tasks marked [!] so task_get.py skips them" {
  write_todo <<'EOF'
- [!] Blocked task
      Blocked context
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [!] Blocked task"* ]]
  [[ "$output" != *"- [ ]"* ]]

  run python "$SCRIPTS_DIR/task_get.py" "$TODO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "carries every blocked task forward" {
  write_todo <<'EOF'
- [!] First blocked task
      Context one
- [x] Finished task
- [!] Second blocked task
      Context two
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [!] First blocked task"* ]]
  [[ "$output" == *"Context one"* ]]
  [[ "$output" == *"- [!] Second blocked task"* ]]
  [[ "$output" == *"Context two"* ]]
  [[ "$output" != *"Finished task"* ]]
}

@test "reports how many blocked tasks were carried forward" {
  write_todo <<'EOF'
- [!] First blocked task
- [!] Second blocked task
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Archived to: $ARCHIVE"* ]]
  [[ "$output" == *"2 blocked tasks"* ]]
}

@test "removes todo.md when nothing is blocked" {
  write_todo <<'EOF'
- [x] Finished task
      Finished context
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Archived to: $ARCHIVE"* ]]
  [[ "$output" == *"0 blocked tasks"* ]]

  [ ! -f "$TODO" ]

  run cat "$ARCHIVE"
  [[ "$output" == *"- [x] Finished task"* ]]
}

@test "leaves headings and completed tasks in the archive" {
  write_todo <<'EOF'
# Sprint

- [x] Finished task
      Finished context

- [!] Blocked task
      Blocked context
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]

  run cat "$ARCHIVE"
  [[ "$output" == *"# Sprint"* ]]
  [[ "$output" == *"- [x] Finished task"* ]]
  [[ "$output" != *"Blocked context"* ]]
}

@test "appends a counter when the dated archive name is taken" {
  printf '%s\n' "- [x] Older archive" >"$ARCHIVE"
  write_todo <<'EOF'
- [x] Finished task
EOF

  run python "$SCRIPTS_DIR/task_archive.py" "$TODO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Archived to: $LLM_DIR/$TODAY-todo-1.md"* ]]

  run cat "$ARCHIVE"
  [[ "$output" == *"Older archive"* ]]

  run cat "$LLM_DIR/$TODAY-todo-1.md"
  [[ "$output" == *"- [x] Finished task"* ]]
}

@test "exits non-zero when the file does not exist" {
  run python "$SCRIPTS_DIR/task_archive.py" "$LLM_DIR/missing.md"
  [ "$status" -eq 1 ]
}
