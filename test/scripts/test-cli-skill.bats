#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# zsh resolves `command cd` to the external /usr/bin/cd, which exits 0 without
# changing the shell's directory, so whatever follows `&&` runs in the wrong
# repository. `builtin cd` changes directory in both zsh and bash.
@test "no skill, agent, or command tells agents to use command cd" {
  run grep --recursive --line-number --include='*.md' 'command cd' "$PROJECT_ROOT/plugins"

  [ "$output" = "" ]
  [ "$status" -eq 1 ]
}

@test "the cli skill's builtin cd changes directory in zsh" {
  command -v zsh >/dev/null || skip "zsh is not installed"
  grep --quiet 'Use .builtin cd. to change directories' "$PROJECT_ROOT/plugins/code/skills/cli/SKILL.md"

  run zsh -c 'builtin cd / && pwd'

  [ "$output" = "/" ]
}
