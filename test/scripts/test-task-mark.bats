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

@test "--index marks the Nth incomplete task, skipping [!] and [>]" {
  write_todo <<'EOF'
- [!] Blocked task
- [ ] First task
- [>] Claimed task
- [ ] Second task
      Second context
- [ ] Third task
EOF

  cat >"$TODO.expected" <<'EOF'
- [!] Blocked task
- [ ] First task
- [>] Claimed task
- [>] Second task
      Second context
- [ ] Third task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --index 2 --marker='>'
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [>] Second task\n      Second context')" ]

  run diff "$TODO" "$TODO.expected"
  [ "$status" -eq 0 ]
}

@test "--index past the last incomplete task exits 1 and leaves the file byte-identical" {
  write_todo <<'EOF'
- [ ] First task
- [>] Claimed task
EOF
  cp "$TODO" "$TODO.expected"

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --index 2
  [ "$status" -eq 1 ]
  [ "$output" = "Error: --index 2 is out of range; 1 incomplete task" ]

  run diff "$TODO.expected" "$TODO"
  [ "$status" -eq 0 ]
}

@test "--index 0 exits 1" {
  write_todo <<'EOF'
- [ ] First task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --index 0
  [ "$status" -eq 1 ]
}

@test "--title marks the [ ] task with that exact title" {
  write_todo <<'EOF'
- [ ] First task
- [ ] Second task
      Second context
EOF

  cat >"$TODO.expected" <<'EOF'
- [ ] First task
- [>] Second task
      Second context
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --title 'Second task' --marker='>'
  [ "$status" -eq 0 ]

  run diff "$TODO" "$TODO.expected"
  [ "$status" -eq 0 ]
}

@test "--title completes a claimed [>] task out of order" {
  write_todo <<'EOF'
- [ ] First task
- [>] Claimed task
      Claimed context
EOF

  cat >"$TODO.expected" <<'EOF'
- [ ] First task
- [x] Claimed task
      Claimed context
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --title 'Claimed task'
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf -- '- [x] Claimed task\n      Claimed context')" ]

  run diff "$TODO" "$TODO.expected"
  [ "$status" -eq 0 ]
}

@test "--title blocks a claimed task with a reason" {
  write_todo <<'EOF'
- [>] Claimed task
      Claimed context
- [ ] Next task
EOF

  cat >"$TODO.expected" <<'EOF'
- [!] Claimed task
      Claimed context
  Blocked 2020-01-02 session test-session-id: worker failed
- [ ] Next task
EOF

  run env CLAUDE_CODE_SESSION_ID=test-session-id \
    python "$SCRIPTS_DIR/task_mark.py" "$TODO" --title 'Claimed task' \
    --marker='!' --reason='worker failed'
  [ "$status" -eq 0 ]

  run diff <(sed -E 's/Blocked [0-9]{4}-[0-9]{2}-[0-9]{2} /Blocked 2020-01-02 /' "$TODO") "$TODO.expected"
  [ "$status" -eq 0 ]
}

@test "--title ignores [x] and [!] tasks and exits 1 when nothing open matches" {
  write_todo <<'EOF'
- [x] Done task
- [!] Blocked task
- [ ] Open task
EOF
  cp "$TODO" "$TODO.expected"

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --title 'Done task'
  [ "$status" -eq 1 ]
  [ "$output" = "Error: no [ ] or [>] task titled 'Done task'" ]

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --title 'Blocked task'
  [ "$status" -eq 1 ]

  run diff "$TODO.expected" "$TODO"
  [ "$status" -eq 0 ]
}

@test "--title requires an exact match, not a prefix" {
  write_todo <<'EOF'
- [ ] First task with more words
EOF
  cp "$TODO" "$TODO.expected"

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --title 'First task'
  [ "$status" -eq 1 ]

  run diff "$TODO.expected" "$TODO"
  [ "$status" -eq 0 ]
}

@test "--index and --title are mutually exclusive" {
  write_todo <<'EOF'
- [ ] First task
EOF

  run python "$SCRIPTS_DIR/task_mark.py" "$TODO" --index 1 --title 'First task'
  [ "$status" -ne 0 ]
}
