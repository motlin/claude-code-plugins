#!/usr/bin/env bash
# Refresh offline Claude Code documentation from code.claude.com

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$SCRIPT_DIR/../docs"
BASE_URL="https://code.claude.com/docs/en"

echo "Downloading docs map..."
curl -s "$BASE_URL/claude_code_docs_map.md" -o "$DOCS_DIR/claude_code_docs_map.md"

echo "Downloading linked documentation files..."
grep -oE '\(https://code\.claude\.com/docs/en/[^)]+\.md\)' "$DOCS_DIR/claude_code_docs_map.md" | \
  sed 's/(https:\/\/code\.claude\.com\/docs\/en\///' | sed 's/)//' | \
  while read -r filename; do
    echo "  Downloading $filename..."
    curl -s "$BASE_URL/$filename" -o "$DOCS_DIR/$filename"
  done

echo "Converting absolute links to relative links..."
sed -i '' 's|(https://code.claude.com/docs/en/|(./|g' "$DOCS_DIR/claude_code_docs_map.md"

echo "Cleaning up invalid files..."
for file in "$DOCS_DIR"/*.md; do
  if [ -f "$file" ] && grep -q '^null$' "$file"; then
    echo "  Removing invalid file: $(basename "$file")"
    rm "$file"
  fi
done

echo ""
echo "Documentation refresh complete!"
echo "Files in $DOCS_DIR:"
ls -la "$DOCS_DIR"/*.md | wc -l | xargs echo "  Total markdown files:"
