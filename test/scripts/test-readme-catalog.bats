#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  README="$PROJECT_ROOT/README.md"
  MARKETPLACE="$PROJECT_ROOT/.claude-plugin/marketplace.json"
}

# Catalog rows name the plugin either as a link, `| [name](...`, or as code,
# `| `name``, for a plugin that ships no directory to link to.
catalog_plugin_names() {
  # shellcheck disable=SC2016
  sed -n -E 's/^\| (\[([a-z0-9-]+)\]|`([a-z0-9-]+)`).*/\2\3/p' "$README" | sort
}

# A marketplace plugin with no catalog row is invisible to anyone reading the
# README, and a catalog row naming no marketplace plugin advertises one that
# cannot be installed.
@test "README catalog rows and marketplace plugins have one-to-one parity" {
  catalog_names="$(catalog_plugin_names)"
  marketplace_names="$(jq --raw-output '.plugins[].name' "$MARKETPLACE" | sort)"

  if [ "$catalog_names" != "$marketplace_names" ]; then
    echo "README catalog rows:"
    echo "$catalog_names"
    echo "Marketplace plugins:"
    echo "$marketplace_names"
    return 1
  fi
}
