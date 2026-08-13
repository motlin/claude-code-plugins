#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PLUGIN_DIR="$PROJECT_ROOT/plugins/recap"
  SKILL="$PLUGIN_DIR/skills/recap/SKILL.md"
  README="$PLUGIN_DIR/README.md"
  GUARD="$PLUGIN_DIR/scripts/recap-guard.sh"
}

# Every link line is either the None fallback or "🔗 [label](url)". A bare URL is
# not reliably autolinked by every response renderer, so it can render as
# unclickable text.
assert_link_lines_are_markdown() {
  run bash -c '
    set -euo pipefail
    status=0
    while IFS= read -r line; do
      case "$line" in
        "🔗 None") ;;
        "🔗 ["*"]("*")") ;;
        *) echo "Not a Markdown link: $line"; status=1 ;;
      esac
    done < <(rg --no-filename "^🔗 " "$@")
    exit "$status"
  ' bash "$@"

  [ "$status" -eq 0 ]
}

@test "recap SKILL.md link lines use Markdown link syntax" {
  assert_link_lines_are_markdown "$SKILL"
}

@test "recap README link lines use Markdown link syntax" {
  assert_link_lines_are_markdown "$README"
}

@test "recap guard block reason uses Markdown link syntax" {
  assert_link_lines_are_markdown "$GUARD"
}

@test "recap docs never show a bare URL on a link line" {
  run rg --no-filename "^🔗 [^\[]*https?://" "$SKILL" "$README" "$GUARD"
  [ "$status" -eq 1 ]
}

@test "recap docs require Markdown link syntax explicitly" {
  run rg "\[short label\]\(URL\)" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "recap SKILL.md keeps the None fallback" {
  run rg "^🔗 None$" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "recap SKILL.md keeps the two-line footer contract" {
  recap_lines=$(rg --count-matches "^📌 " "$SKILL")
  link_lines=$(rg --count-matches "^🔗 " "$SKILL")
  [ "$recap_lines" -ge 1 ]
  [ "$link_lines" -ge 1 ]
}
