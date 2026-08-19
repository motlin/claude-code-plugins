#!/bin/bash

set -Eeuo pipefail

codex_manifest_contract_errors() {
    local manifest="$1"

    if ! jq empty "$manifest" 2>/dev/null; then
        echo "must be valid JSON"
        return
    fi

    jq --raw-output '
        def nes: type == "string" and test("\\S");
        [
            "id", "name", "version", "description", "skills", "apps", "mcpServers",
            "interface", "author", "homepage", "repository", "license", "keywords"
        ] as $allowed
        | [
            (keys_unsorted[] | select(. as $k | $allowed | index($k) | not) | "unknown top-level key `\(.)`"),
            (if (.name | nes) then empty else "`name` must be a non-empty string" end),
            (if (.version | nes) then empty else "`version` must be a non-empty string" end),
            (if (.version | type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z-.]+)?(\\+[0-9A-Za-z-.]+)?$")) then empty else "`version` must be strict semver" end),
            (if (.description | nes) then empty else "`description` must be a non-empty string" end),
            (if (.author | type == "object") then empty else "`author` must be an object" end),
            (if (.author.name | nes) then empty else "`author.name` must be a non-empty string" end),
            ((.author // {}) | keys_unsorted[] | select(. as $k | ["name", "email", "url"] | index($k) | not) | "unknown `author` key `\(.)`"),
            (if (.interface | type == "object") then empty else "`interface` must be an object" end),
            (["displayName", "shortDescription", "longDescription", "developerName", "category"][] as $f | if (.interface[$f] | nes) then empty else "`interface.\($f)` must be a non-empty string" end),
            (if ((.interface | has("defaultPrompt")) or (.interface | has("default_prompt"))) then empty else "`interface.defaultPrompt` or `interface.default_prompt` is required" end),
            ((.interface.capabilities) as $c | if ($c | type == "array") and ($c | all(.[]; type == "string" and test("\\S"))) then empty else "`interface.capabilities` must be an array of strings" end),
            (if (.interface | has("brandColor") | not) or (.interface.brandColor | type == "string" and test("^#[0-9A-Fa-f]{6}$")) then empty else "`interface.brandColor` must use `#RRGGBB`" end),
            (if (.skills == null) or ((.skills | type == "string") and ((.skills | sub("^\\./"; "") | sub("/$"; "")) == "skills")) then empty else "`skills` must resolve to `skills`" end)
        ]
        | .[]
    ' "$manifest"
}

codex_supported_hook_events() {
    printf '%s\n' \
        PermissionRequest \
        PostCompact \
        PostToolUse \
        PreCompact \
        PreToolUse \
        SessionStart \
        Stop \
        SubagentStart \
        SubagentStop \
        UserPromptSubmit
}

extract_literal_plugin_script_references() {
    local skill_file="$1"

    # Without this, a missing rg yields no matches, and every caller reads that
    # as "no broken references" and passes.
    if ! command -v rg >/dev/null; then
        echo "rg (ripgrep) is required but not installed" >&2
        return 1
    fi

    rg --no-filename --only-matching --pcre2 \
        '(?:<plugin-root>|\$\{?CLAUDE_PLUGIN_ROOT\}?)/scripts/[A-Za-z0-9_./-]+' \
        "$skill_file" | sort --unique
}

# Prints one `<file>: <reference>` line per script reference that does not
# resolve to a file inside the plugin, and nothing when they all resolve.
missing_plugin_script_references() {
    local plugin_root="$1"
    local source_file="$2"
    local reference

    while IFS= read -r reference; do
        [ -n "$reference" ] || continue
        if [ ! -f "$plugin_root/scripts/${reference#*/scripts/}" ]; then
            printf '%s: %s\n' "$source_file" "$reference"
        fi
    done < <(extract_literal_plugin_script_references "$source_file")
}

validate_codex_hooks() {
    local hooks_file="$1"
    local supported_events
    supported_events="$(codex_supported_hook_events)"

    if ! jq --exit-status \
        'type == "object" and keys == ["hooks"] and (.hooks | type == "object" and length > 0)' \
        "$hooks_file" >/dev/null; then
        echo "Codex hooks must have the strict {\"hooks\": {...}} root: $hooks_file"
        return 1
    fi

    local event
    while IFS= read -r event; do
        if ! grep --fixed-strings --line-regexp --quiet "$event" <<<"$supported_events"; then
            echo "Unsupported Codex hook event '$event' in $hooks_file"
            return 1
        fi
    done < <(jq --raw-output '.hooks | keys[]' "$hooks_file")
}
