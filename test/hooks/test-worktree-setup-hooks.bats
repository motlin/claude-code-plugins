#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "worktree-setup hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json"
}

@test "worktree-setup hooks.json has WorktreeCreate event" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json")
  [[ "$hooks" =~ "WorktreeCreate" ]]
}

@test "worktree-setup hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json" "WorktreeCreate")
  for command in $commands; do
    resolved_command="${command//\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_ROOT/plugins/worktree-setup}"
    if [ ! -f "$resolved_command" ]; then
      echo "Script not found: $resolved_command"
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "worktree-setup hooks use command type" {
  hook_type=$(jq --raw-output '.hooks.WorktreeCreate[0].hooks[0].type' "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json")
  [ "$hook_type" = "command" ]
}

# 🧪 Behavioral tests: the harness hands the hook only {cwd, name} and reads
# the worktree path back from stdout, so the hook has to create the worktree.

hook_script() {
  echo "$PROJECT_ROOT/plugins/worktree-setup/scripts/on-worktree-create.sh"
}

make_source_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init --quiet --initial-branch=main
  git -C "$repo" config user.name "Test"
  git -C "$repo" config user.email "test@example.com"
  echo "secret.local" >"$repo/.gitignore"
  echo "tracked" >"$repo/README.md"
  git -C "$repo" add .gitignore README.md
  git -C "$repo" commit --quiet --message "Initial commit"
  echo "local-only" >"$repo/secret.local"
}

isolated_home() {
  local base_ref="$1"
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home/.claude"
  jq --null-input --arg base_ref "$base_ref" '{worktree: {baseRef: $base_ref}}' >"$home/.claude/settings.json"
  echo "$home"
}

@test "worktree-setup creates the worktree at .claude/worktrees/<name> when the input has no path" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd, name: "feature-x"}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  expected="$source/.claude/worktrees/feature-x"
  [ "$output" = "$expected" ]
  [ -d "$expected" ]
  physical_path="$(command cd "$expected" && pwd -P)"
  git -C "$source" worktree list --porcelain | grep --fixed-strings --quiet "worktree $physical_path"
  [ "$(git -C "$expected" rev-parse --abbrev-ref HEAD)" = "feature-x" ]
}

@test "worktree-setup prints only the worktree path on stdout" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd, name: "feature-x"}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$stderr" == *"Worktree setup complete"* ]]
}

@test "worktree-setup copies gitignored files into the worktree it created" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd, name: "feature-x"}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  [ "$(cat "$source/.claude/worktrees/feature-x/secret.local")" = "local-only" ]
}

@test "worktree-setup reuses an existing branch with the worktree name" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  git -C "$source" branch existing-branch
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd, name: "existing-branch"}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  [[ "$stderr" == *"on existing branch existing-branch"* ]]
  [ "$(git -C "$source/.claude/worktrees/existing-branch" rev-parse --abbrev-ref HEAD)" = "existing-branch" ]
}

@test "worktree-setup branches from origin/HEAD when baseRef is fresh" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  origin="$BATS_TEST_TMPDIR/origin.git"
  git init --quiet --bare "$origin"
  git -C "$source" remote add origin "$origin"
  git -C "$source" push --quiet origin main
  git -C "$source" remote set-head origin main
  remote_head="$(git -C "$source" rev-parse origin/main)"
  echo "ahead" >"$source/ahead.txt"
  git -C "$source" add ahead.txt
  git -C "$source" commit --quiet --message "Local commit ahead of origin"
  home="$(isolated_home fresh)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd, name: "fresh-branch"}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  [[ "$stderr" == *"from origin/main"* ]]
  [ "$(git -C "$source/.claude/worktrees/fresh-branch" rev-parse HEAD)" = "$remote_head" ]
}

@test "worktree-setup branches from HEAD when baseRef is head" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  local_head="$(git -C "$source" rev-parse HEAD)"
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd, name: "head-branch"}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  [[ "$stderr" == *"from HEAD"* ]]
  [ "$(git -C "$source/.claude/worktrees/head-branch" rev-parse HEAD)" = "$local_head" ]
}

@test "worktree-setup decorates a pre-created worktree when the input carries a path" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  precreated="$BATS_TEST_TMPDIR/precreated"
  git -C "$source" worktree add --quiet "$precreated" -b precreated
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" --arg path "$precreated" '{cwd: $cwd, name: "precreated", worktree_path: $path}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 0 ]
  [ "$output" = "$precreated" ]
  [ "$(cat "$precreated/secret.local")" = "local-only" ]
}

@test "worktree-setup fails when the input has neither a path nor a name" {
  source="$BATS_TEST_TMPDIR/source"
  make_source_repo "$source"
  home="$(isolated_home head)"
  input="$(jq --null-input --arg cwd "$source" '{cwd: $cwd}')"

  run --separate-stderr env HOME="$home" "$(hook_script)" <<<"$input"

  [ "$status" -eq 1 ]
  [[ "$stderr" == *"could not determine worktree directory"* ]]
}
