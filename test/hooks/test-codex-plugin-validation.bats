#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=../lib/codex-plugin-helpers.sh
  source "$PROJECT_ROOT/test/lib/codex-plugin-helpers.sh"
}

@test "Codex manifests and marketplace entries have one-to-one parity" {
  manifest_names="$({
    for manifest in "$PROJECT_ROOT"/plugins/*/.codex-plugin/plugin.json; do
      basename "${manifest%/.codex-plugin/plugin.json}"
    done
  } | sort)"
  marketplace_names="$(jq --raw-output '.plugins[].name' \
    "$PROJECT_ROOT/.agents/plugins/marketplace.json" | sort)"

  if [ "$manifest_names" != "$marketplace_names" ]; then
    echo "Codex manifests:"
    echo "$manifest_names"
    echo "Marketplace entries:"
    echo "$marketplace_names"
    return 1
  fi
}

@test "Codex marketplace entries are unique and match their plugin sources" {
  marketplace="$PROJECT_ROOT/.agents/plugins/marketplace.json"

  duplicate_names="$(jq --raw-output \
    '[.plugins[].name] | group_by(.)[] | select(length > 1) | .[0]' "$marketplace")"
  duplicate_paths="$(jq --raw-output \
    '[.plugins[].source.path] | group_by(.)[] | select(length > 1) | .[0]' "$marketplace")"
  [ -z "$duplicate_names" ]
  [ -z "$duplicate_paths" ]

  while IFS=$'\t' read -r name source_type source_path; do
    [ "$source_type" = "local" ]
    [ "$source_path" = "./plugins/$name" ]

    plugin_root="$PROJECT_ROOT/${source_path#./}"
    [ -d "$plugin_root" ]
    [ "$(basename "$plugin_root")" = "$name" ]
    [ "$(jq --raw-output '.name' "$plugin_root/.codex-plugin/plugin.json")" = "$name" ]
  done < <(jq --raw-output \
    '.plugins[] | [.name, .source.source, .source.path] | @tsv' "$marketplace")
}

@test "current plugin-creator validator accepts every Codex plugin" {
  validator="$(codex_plugin_validator)"
  [ -f "$validator" ]

  failed=()
  for manifest in "$PROJECT_ROOT"/plugins/*/.codex-plugin/plugin.json; do
    plugin_root="${manifest%/.codex-plugin/plugin.json}"
    if ! output="$(python3 "$validator" "$plugin_root" 2>&1)"; then
      failed+=("$plugin_root: $output")
    fi
  done

  if [ "${#failed[@]}" -ne 0 ]; then
    printf 'failed Codex plugins:\n'
    printf '  %s\n' "${failed[@]}"
    return 1
  fi
}

@test "Codex-bundled skill script references resolve inside their plugins" {
  missing=()

  for manifest in "$PROJECT_ROOT"/plugins/*/.codex-plugin/plugin.json; do
    if [ "$(jq --raw-output '.skills // empty' "$manifest")" != "./skills/" ]; then
      continue
    fi

    plugin_root="${manifest%/.codex-plugin/plugin.json}"
    while IFS= read -r skill_file; do
      while IFS= read -r reference; do
        [ -n "$reference" ] || continue
        relative_path="scripts/${reference#*/scripts/}"
        if [ ! -f "$plugin_root/$relative_path" ]; then
          missing+=("$skill_file: $reference")
        fi
      done < <(extract_literal_plugin_script_references "$skill_file")
    done < <(find "$plugin_root/skills" -name SKILL.md -type f -print)
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'missing plugin script references:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "every available Codex plugin exposes usable skills or supported hooks" {
  marketplace="$PROJECT_ROOT/.agents/plugins/marketplace.json"
  unusable=()

  while IFS= read -r source_path; do
    plugin_root="$PROJECT_ROOT/${source_path#./}"
    manifest="$plugin_root/.codex-plugin/plugin.json"
    has_skills=false
    has_hooks=false

    if [ "$(jq --raw-output '.skills // empty' "$manifest")" = "./skills/" ] &&
        find "$plugin_root/skills" -name SKILL.md -type f -print -quit | grep --quiet .; then
      has_skills=true
    fi

    hooks_file="$plugin_root/hooks/hooks.json"
    if [ -f "$hooks_file" ] && validate_codex_hooks "$hooks_file"; then
      has_hooks=true
    fi

    if [ "$has_skills" = false ] && [ "$has_hooks" = false ]; then
      unusable+=("$plugin_root")
    fi
  done < <(jq --raw-output \
    '.plugins[] | select(.policy.installation == "AVAILABLE" or .policy.installation == "INSTALLED_BY_DEFAULT") | .source.path' \
    "$marketplace")

  if [ "${#unusable[@]}" -ne 0 ]; then
    printf 'available plugins without usable Codex components:\n'
    printf '  %s\n' "${unusable[@]}"
    return 1
  fi
}

@test "default hooks loaded for available Codex plugins use supported events" {
  marketplace="$PROJECT_ROOT/.agents/plugins/marketplace.json"

  while IFS= read -r source_path; do
    hooks_file="$PROJECT_ROOT/${source_path#./}/hooks/hooks.json"
    if [ -f "$hooks_file" ]; then
      validate_codex_hooks "$hooks_file"
    fi
  done < <(jq --raw-output \
    '.plugins[] | select(.policy.installation == "AVAILABLE" or .policy.installation == "INSTALLED_BY_DEFAULT") | .source.path' \
    "$marketplace")
}
