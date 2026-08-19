#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS_DIR="$PROJECT_ROOT/plugins/markdown-tasks/scripts"
  LLM_DIR="$BATS_TEST_TMPDIR/.llm"
  TODO="$LLM_DIR/todo.md"
  mkdir -p "$LLM_DIR"
  unset CLAUDE_CODE_SESSION_ID
  TODAY="$(date +%Y-%m-%d)"
}

@test "recovers a blocked task into todo.md and removes it from the archive" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [x] Finished task
- [!] Blocked task
      First context line
      Second context line
      Blocked: the API returned 500 on every attempt
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"- [ ] Blocked task"* ]]
  [[ "$output" == *"First context line"* ]]
  [[ "$output" == *"Second context line"* ]]
  [[ "$output" == *"Blocked: the API returned 500 on every attempt"* ]]
  [[ "$output" == *"Recovered $TODAY"* ]]

  run cat "$LLM_DIR/2025-11-19-todo.md"
  [[ "$output" == *"- [x] Finished task"* ]]
  [[ "$output" != *"Blocked task"* ]]
  [[ "$output" != *"First context line"* ]]
}

@test "the recovered stamp is the last line of the task" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] Blocked task
      Context line
      Blocked: ran out of disk
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run tail -n 1 "$TODO"
  [ "$output" = "  Recovered $TODAY" ]
}

@test "the recovered stamp names the session when CLAUDE_CODE_SESSION_ID is set" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] Blocked task
      Context line
EOF

  CLAUDE_CODE_SESSION_ID=abc-123 run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run tail -n 1 "$TODO"
  [ "$output" = "  Recovered $TODAY session abc-123" ]
}

@test "--dry-run reports counts and rewrites nothing" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] First blocked task
      Context one
- [!] Second blocked task
      Context two
EOF
  cat >"$LLM_DIR/2025-12-04-todo.md" <<'EOF'
- [!] Third blocked task
EOF
  before_archive="$(cat "$LLM_DIR/2025-11-19-todo.md")"

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"2025-11-19-todo.md"*"2"* ]]
  [[ "$output" == *"2025-12-04-todo.md"*"1"* ]]
  [[ "$output" == *"3"* ]]

  [ "$(cat "$LLM_DIR/2025-11-19-todo.md")" = "$before_archive" ]
  [ ! -f "$TODO" ]
}

@test "recovers blocked tasks from every archive and leaves emptied files in place" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] First blocked task
      Context one
EOF
  cat >"$LLM_DIR/2025-12-04-todo.md" <<'EOF'
- [!] Second blocked task
      Context two
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  [ -f "$LLM_DIR/2025-11-19-todo.md" ]
  [ -f "$LLM_DIR/2025-12-04-todo.md" ]

  run cat "$TODO"
  [[ "$output" == *"- [ ] First blocked task"* ]]
  [[ "$output" == *"- [ ] Second blocked task"* ]]
}

@test "reinstates a blocked task already living in todo.md" {
  cat >"$TODO" <<'EOF'
- [!] Blocked task
      Context line
- [ ] Open task
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" != *"- [!]"* ]]
  [[ "$output" == *"- [ ] Open task"* ]]
  [[ "$output" == *"- [ ] Blocked task"* ]]
}

@test "appends recovered tasks below existing open tasks" {
  cat >"$TODO" <<'EOF'
- [ ] Existing open task
      Existing context
EOF
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] Blocked task
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run python "$SCRIPTS_DIR/task_get.py" "$TODO"
  [[ "$output" == *"- [ ] Existing open task"* ]]
  [[ "$output" != *"Blocked task"* ]]
}

@test "keeps every Blocked line so repeat round trips stay readable" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] Blocked task
      Context line
      Blocked: first failure
      Recovered 2025-12-04
      Blocked: second failure
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run cat "$TODO"
  [[ "$output" == *"Blocked: first failure"* ]]
  [[ "$output" == *"Recovered 2025-12-04"* ]]
  [[ "$output" == *"Blocked: second failure"* ]]
  [[ "$output" == *"Recovered $TODAY"* ]]
}

@test "a second run recovers nothing and duplicates nothing" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [!] Blocked task
      Context line
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run grep --count "Blocked task" "$TODO"
  [ "$output" = "1" ]
}

@test "leaves completed and open tasks in the archive untouched" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
# Sprint

- [x] Finished task
      Finished context

- [!] Blocked task
      Blocked context

- [ ] Never started task
      Pending context
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]

  run cat "$LLM_DIR/2025-11-19-todo.md"
  [[ "$output" == *"# Sprint"* ]]
  [[ "$output" == *"- [x] Finished task"* ]]
  [[ "$output" == *"Finished context"* ]]
  [[ "$output" == *"- [ ] Never started task"* ]]
  [[ "$output" == *"Pending context"* ]]
  [[ "$output" != *"Blocked context"* ]]
}

@test "exits zero when there is nothing to recover" {
  cat >"$LLM_DIR/2025-11-19-todo.md" <<'EOF'
- [x] Finished task
EOF

  run python "$SCRIPTS_DIR/task_unblock.py" "$LLM_DIR"
  [ "$status" -eq 0 ]
  [ ! -f "$TODO" ]
}

@test "exits non-zero when the directory does not exist" {
  run python "$SCRIPTS_DIR/task_unblock.py" "$BATS_TEST_TMPDIR/missing"
  [ "$status" -eq 1 ]
}
