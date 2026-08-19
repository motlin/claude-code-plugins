#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILLS_DIR="$PROJECT_ROOT/plugins/markdown-tasks/skills"
  SCRIPTS_DIR="$PROJECT_ROOT/plugins/markdown-tasks/scripts"
}

@test "markdown task skills reference existing Python scripts" {
  run bash -c '
    set -euo pipefail
    while IFS= read -r reference; do
      test -f "$1/${reference#scripts/}"
    done < <(rg --no-filename --only-matching "scripts/[a-z_]+[.]py" "$2" | sort --unique)
  ' bash "$SCRIPTS_DIR" "$SKILLS_DIR"

  [ "$status" -eq 0 ]
}

@test "markdown task execution skills use task_mark.py" {
  run rg "task_complete[.]py" \
    "$SKILLS_DIR/markdown-do-one-task/SKILL.md" \
    "$SKILLS_DIR/markdown-do-all-tasks/SKILL.md"

  [ "$status" -eq 1 ]

  run rg "task_mark[.]py" \
    "$SKILLS_DIR/markdown-do-one-task/SKILL.md" \
    "$SKILLS_DIR/markdown-do-all-tasks/SKILL.md"

  [ "$status" -eq 0 ]
}

@test "markdown-do-all-tasks reports blocked tasks before the loop starts" {
  SKILL="$SKILLS_DIR/markdown-do-all-tasks/SKILL.md"

  run rg --line-number "task_unblock[.]py .* --dry-run" "$SKILL"
  [ "$status" -eq 0 ]
  dry_run_line="${output%%:*}"

  run rg --line-number "^## Process One Task per Worker" "$SKILL"
  [ "$status" -eq 0 ]
  loop_line="${output%%:*}"

  [ "$dry_run_line" -lt "$loop_line" ]
}

@test "multi-task producer skills require chained writes" {
  for skill in markdown-plan-tasks markdown-import-plan markdown-sweep-todos; do
    run rg "one shell command" "$SKILLS_DIR/$skill/SKILL.md"
    [ "$status" -eq 0 ]

    run rg "&&" "$SKILLS_DIR/$skill/SKILL.md"
    [ "$status" -eq 0 ]
  done
}
