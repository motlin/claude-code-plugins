#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PLUGIN_DIR="$PROJECT_ROOT/plugins/orchestration"
  SKILL="$PLUGIN_DIR/skills/memory-placement/SKILL.md"
}

@test "memory-placement SKILL.md exists with matching frontmatter name" {
  run rg "^name: memory-placement$" "$SKILL"
  [ "$status" -eq 0 ]
}

# Claude Code loads only the skills plugin.json lists explicitly.
@test "orchestration plugin.json registers the memory-placement skill" {
  run jq --exit-status '.skills | index("./skills/memory-placement")' "$PLUGIN_DIR/.claude-plugin/plugin.json"
  [ "$status" -eq 0 ]
}

# The orchestration skill loads on startup, so its table is how the memory
# skill gets discovered before a memory write.
@test "orchestration skill table routes memory writes to the memory-placement skill" {
  run rg "orchestration:memory-placement" "$PLUGIN_DIR/skills/orchestration/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "orchestration README lists the memory-placement skill" {
  run rg "orchestration:memory-placement" "$PLUGIN_DIR/README.md"
  [ "$status" -eq 0 ]
}

@test "memory-placement skill sends skill-owned lessons to the plugin's git repository source" {
  run rg "edit its source in the plugin's git repository" "$SKILL"
  [ "$status" -eq 0 ]
}
