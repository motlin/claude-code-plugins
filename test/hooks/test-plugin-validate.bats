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
    plugin_root="${hooks_file%/hooks/*}"
    while IFS= read -r reference; do
      [ -n "$reference" ] || continue
      relative_path="scripts/${reference#*/scripts/}"
      if [ ! -f "$plugin_root/$relative_path" ]; then
        missing+=("$hooks_file: $reference")
      fi
    done < <(extract_literal_plugin_script_references "$hooks_file")
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
    while IFS= read -r reference; do
      [ -n "$reference" ] || continue
      relative_path="scripts/${reference#*/scripts/}"
      if [ ! -f "$plugin_root/$relative_path" ]; then
        missing+=("$component_file: $reference")
      fi
    done < <(extract_literal_plugin_script_references "$component_file")
  done < <(find "$PROJECT_ROOT/plugins" \( -path '*/commands/*' -o -path '*/agents/*' \) -name '*.md' -type f -print)

  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'missing command and agent script references:\n'
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
  for skill_root in "$PROJECT_ROOT"/plugins/*/skills/*/; do
    [ -d "$skill_root" ] || continue
    if [ ! -f "${skill_root}SKILL.md" ]; then
      missing+=("${skill_root#"$PROJECT_ROOT/"}")
    fi
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
