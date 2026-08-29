#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=test/lib/codex-plugin-helpers.sh
  source "$PROJECT_ROOT/test/lib/codex-plugin-helpers.sh"
  MARKETPLACE="$PROJECT_ROOT/.claude-plugin/marketplace.json"
}

# Local plugins are listed as plain string sources. Remote sources are objects
# validated by the source repository's own CI, so they are skipped here.
local_marketplace_sources() {
  jq --raw-output '.plugins[].source | select(type == "string")' "$MARKETPLACE"
}

@test "claude plugin validate --strict marketplace.json passes" {
  run claude plugin validate --strict "$MARKETPLACE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed"* ]]
}

# Marketplace validation does not resolve source paths, so each one is validated
# directly. A source pointing at a missing directory fails here.
@test "claude plugin validate --strict passes for every marketplace source" {
  failed=()
  while IFS= read -r source; do
    if ! claude plugin validate --strict "$PROJECT_ROOT/${source#./}" >/dev/null 2>&1; then
      failed+=("$source")
    fi
  done < <(local_marketplace_sources)

  if [ "${#failed[@]}" -ne 0 ]; then
    printf 'failed marketplace sources:\n'
    printf '  %s\n' "${failed[@]}"
    return 1
  fi
}

@test "marketplace sources and plugin directories have one-to-one parity" {
  source_paths="$(local_marketplace_sources | sed 's|^\./||' | sort)"
  directory_paths="$({
    for directory in "$PROJECT_ROOT"/plugins/*/; do
      printf 'plugins/%s\n' "$(basename "$directory")"
    done
  } | sort)"

  if [ "$source_paths" != "$directory_paths" ]; then
    echo "Marketplace sources:"
    echo "$source_paths"
    echo "Plugin directories:"
    echo "$directory_paths"
    return 1
  fi
}

# Validation reports a name that collides with another entry, but not one that
# disagrees with the directory it points at or with the manifest inside it.
@test "marketplace entry names match their source directories and manifests" {
  mismatches=()
  while IFS=$'\t' read -r name source; do
    plugin_root="$PROJECT_ROOT/${source#./}"
    directory_name="$(basename "$plugin_root")"
    manifest_name="$(jq --raw-output '.name' "$plugin_root/.claude-plugin/plugin.json")"
    if [ "$name" != "$directory_name" ] || [ "$name" != "$manifest_name" ]; then
      mismatches+=("$name: directory=$directory_name manifest=$manifest_name")
    fi
  done < <(jq --raw-output \
    '.plugins[] | select(.source | type == "string") | [.name, .source] | @tsv' "$MARKETPLACE")

  if [ "${#mismatches[@]}" -ne 0 ]; then
    printf 'marketplace name mismatches:\n'
    printf '  %s\n' "${mismatches[@]}"
    return 1
  fi
}

# `claude plugin validate` checks manifest schemas only. It passes a hooks.json
# whose command points at a deleted script, so the references are checked here.
@test "hook commands reference scripts that exist" {
  missing=()
  for hooks_file in "$PROJECT_ROOT"/plugins/*/hooks/*.json; do
    while IFS= read -r line; do
      missing+=("$line")
    done < <(missing_plugin_script_references "${hooks_file%/hooks/*}" "$hooks_file")
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'missing hook script references:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

# Validation checks that command and agent directories resolve, not the script
# paths their bodies tell Claude to run. A command whose script was renamed still
# validates, and fails only when a user runs it.
@test "command and agent files reference scripts that exist" {
  missing=()
  while IFS= read -r component_file; do
    plugin_root="${component_file%/commands/*}"
    plugin_root="${plugin_root%/agents/*}"
    while IFS= read -r line; do
      missing+=("$line")
    done < <(missing_plugin_script_references "$plugin_root" "$component_file")
  done < <(find "$PROJECT_ROOT/plugins" \( -path '*/commands/*' -o -path '*/agents/*' \) -name '*.md' -type f -print)

  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'missing command and agent script references:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

# Skills carry the same unvalidated script paths as commands and agents, so a
# skill left pointing at a renamed script fails only when a user runs it.
@test "skill files reference scripts that exist" {
  missing=()
  for plugin_root in "$PROJECT_ROOT"/plugins/*/; do
    plugin_root="${plugin_root%/}"
    [ -d "$plugin_root/skills" ] || continue
    while IFS= read -r skill_file; do
      while IFS= read -r line; do
        missing+=("$line")
      done < <(missing_plugin_script_references "$plugin_root" "$skill_file")
    done < <(find "$plugin_root/skills" -name SKILL.md -type f -print)
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'missing skill script references:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

# Validation resolves the component paths a manifest declares, but not the files
# inside them, and most skills are auto-discovered rather than declared at all. A
# directory that loses its SKILL.md drops out of the `agentskills validate` glob
# rather than failing it, which leaves the skill silently unshipped.
@test "every skill directory has a SKILL.md" {
  missing=()
  for plugin_root in "$PROJECT_ROOT"/plugins/*/; do
    plugin_root="${plugin_root%/}"
    [ -d "$plugin_root/skills" ] || continue
    # Descending stops at each SKILL.md, so a skill's own subdirectories are its
    # supporting files. Of the rest, one holding files is a skill missing its
    # SKILL.md, and one holding only subdirectories is grouping them.
    while IFS= read -r skill_root; do
      [ -n "$(find "$skill_root" -mindepth 1 -maxdepth 1 -type f -print -quit)" ] || continue
      missing+=("${skill_root#"$PROJECT_ROOT/"}")
    done < <(find "$plugin_root/skills" -mindepth 1 -type d \
      \( -exec test -f '{}/SKILL.md' \; -prune -o -print \))
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'skill directories without SKILL.md:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "codex plugin versions share their claude plugin base versions" {
  for codex_manifest in "$PROJECT_ROOT"/plugins/*/.codex-plugin/plugin.json; do
    plugin_root="${codex_manifest%/.codex-plugin/plugin.json}"
    claude_manifest="$plugin_root/.claude-plugin/plugin.json"
    codex_version="$(jq --raw-output '.version' "$codex_manifest")"
    claude_version="$(jq --raw-output '.version' "$claude_manifest")"
    if [ "$codex_version" = "$claude_version" ]; then
      continue
    fi
    cachebuster="${codex_version#"$claude_version+codex."}"
    [ "$codex_version" = "$claude_version+codex.$cachebuster" ]
    [ -n "$cachebuster" ]
  done
}

# A command file that nobody declares is invisible: plugin.json enumerates
# commands explicitly, so adding the file without adding the entry ships a
# command that never loads. Compare the declared list against the directory
# for every plugin that declares commands at all.
@test "every command file on disk is declared in plugin.json" {
  while IFS= read -r manifest; do
    jq --exit-status 'has("commands")' "$manifest" >/dev/null || continue

    plugin_root="${manifest%/.claude-plugin/plugin.json}"

    declared="$(jq --raw-output '.commands[]' "$manifest" | sed 's|^[.]/commands/||' | sort)"
    on_disk="$(find "$plugin_root/commands" -maxdepth 1 -name '*.md' -type f \
      -exec basename {} \; | sort)"

    [ "$declared" = "$on_disk" ] || {
      echo "$plugin_root declares:"
      echo "$declared"
      echo "$plugin_root has on disk:"
      echo "$on_disk"
      false
    }
  done < <(find "$PROJECT_ROOT/plugins" -path '*/.claude-plugin/plugin.json' -type f -print)
}
