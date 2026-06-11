#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS_DIR="$PROJECT_ROOT/plugins/markdown-tasks/scripts"
  TODO="$BATS_TEST_TMPDIR/todo.md"
}

write_todo() {
  cat >"$TODO"
}

@test "default marker turns first incomplete task into [x] and echoes the block" {
  write_todo <<'EOF'
- [ ] First task
      Context line one
- [ ] Second task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- [x] First task"* ]]
  [[ "$output" == *"Context line one"* ]]

  run cat "$TODO"
  [[ "$output" == *"- [x] First task"* ]]
  [[ "$output" == *"- [ ] Second task"* ]]
}

@test "--marker='!' marks first task [!] and leaves a later [ ] untouched" {
  write_todo <<'EOF'
- [ ] First task
- [ ] Second task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!'
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [!] First task"* ]]
  [[ "$output" == *"- [ ] Second task"* ]]
}

@test "--marker='>' matches the old --progress behaviour" {
  write_todo <<'EOF'
- [ ] First task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='>'
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [>] First task"* ]]
}

@test "empty marker exits non-zero" {
  write_todo <<'EOF'
- [ ] First task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker=''
  [ "$status" -ne 0 ]
}

@test "multi-char marker exits non-zero" {
  write_todo <<'EOF'
- [ ] First task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='xx'
  [ "$status" -ne 0 ]
}

@test "space marker exits non-zero" {
  write_todo <<'EOF'
- [ ] First task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker=' '
  [ "$status" -ne 0 ]
}

@test "task_get.py skips a leading [!] task and returns the next [ ]" {
  write_todo <<'EOF'
- [!] Blocked task
      Blocked context
- [ ] Next task
      Next context
EOF

  run python "$SCRIPTS_DIR/task_get.py" "$TODO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- [ ] Next task"* ]]
  [[ "$output" != *"Blocked task"* ]]
}
