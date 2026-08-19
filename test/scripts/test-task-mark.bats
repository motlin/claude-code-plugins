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

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!' --reason='ran out of ideas'
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [!] First task"* ]]
  [[ "$output" == *"- [ ] Second task"* ]]
}

@test "--marker='!' without --reason exits non-zero and leaves the file byte-identical" {
  write_todo <<'EOF'
- [ ] First task
      Context line one
- [ ] Second task
EOF
  cp "$TODO" "$TODO.expected"

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!'
  [ "$status" -eq 1 ]
  [[ "$output" == *"--reason"* ]]

  run diff "$TODO.expected" "$TODO"
  [ "$status" -eq 0 ]
}

@test "--marker='!' with a blank --reason exits non-zero and leaves the file byte-identical" {
  write_todo <<'EOF'
- [ ] First task
EOF
  cp "$TODO" "$TODO.expected"

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!' --reason='   '
  [ "$status" -eq 1 ]

  run diff "$TODO.expected" "$TODO"
  [ "$status" -eq 0 ]
}

@test "--reason appends an indented Blocked line after the last context line" {
  write_todo <<'EOF'
- [ ] First task
      Context line one
      Context line two
- [ ] Second task
      Second context
EOF

  cat >"$TODO.expected" <<'EOF'
- [!] First task
      Context line one
      Context line two
  Blocked 2020-01-02 session test-session-id: precommit failed on the parser rewrite
- [ ] Second task
      Second context
EOF

  run env CLAUDE_CODE_SESSION_ID=test-session-id \
    python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!' \
    --reason='precommit failed on the parser rewrite'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Blocked "*": precommit failed on the parser rewrite"* ]]

  run diff <(sed -E 's/Blocked [0-9]{4}-[0-9]{2}-[0-9]{2} /Blocked 2020-01-02 /' "$TODO") "$TODO.expected"
  [ "$status" -eq 0 ]
}

@test "--reason keeps trailing blank lines below the Blocked line" {
  printf -- '- [ ] First task\n      Context line one\n\n- [ ] Second task\n' >"$TODO"

  cat >"$TODO.expected" <<'EOF'
- [!] First task
      Context line one
  Blocked 2020-01-02 session test-session-id: worker left the tree dirty

- [ ] Second task
EOF

  run env CLAUDE_CODE_SESSION_ID=test-session-id \
    python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!' \
    --reason='worker left the tree dirty'
  [ "$status" -eq 0 ]

  run diff <(sed -E 's/Blocked [0-9]{4}-[0-9]{2}-[0-9]{2} /Blocked 2020-01-02 /' "$TODO") "$TODO.expected"
  [ "$status" -eq 0 ]
}

@test "--reason omits the session field when CLAUDE_CODE_SESSION_ID is unset" {
  write_todo <<'EOF'
- [ ] First task
      Context line one
EOF

  run env -u CLAUDE_CODE_SESSION_ID \
    python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!' --reason='no session here'

  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *": no session here"* ]]
  [[ "$output" != *"session"*": no session here"* ]]
}

@test "--reason on a task at end of file appends the Blocked line last" {
  printf -- '- [ ] Only task\n      Context line one\n' >"$TODO"

  run env CLAUDE_CODE_SESSION_ID=test-session-id \
    python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='!' --reason='nothing worked'
  [ "$status" -eq 0 ]

  run tail -n 1 "$TODO"
  [[ "$output" == "  Blocked "*"session test-session-id: nothing worked" ]]
}

@test "--reason is accepted for markers other than '!'" {
  write_todo <<'EOF'
- [ ] First task
      Context line one
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --marker='x' --reason='done the hard way'
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [x] First task"* ]]
  [[ "$output" == *": done the hard way"* ]]
}

@test "omitting --reason leaves the file byte-identical apart from the checkbox" {
  write_todo <<'EOF'
- [ ] First task
      Context line one

- [ ] Second task
EOF

  cat >"$TODO.expected" <<'EOF'
- [x] First task
      Context line one

- [ ] Second task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO"
  [ "$status" -eq 0 ]

  run diff "$TODO" "$TODO.expected"
  [ "$status" -eq 0 ]
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
