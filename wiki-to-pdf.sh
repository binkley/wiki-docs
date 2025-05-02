#!/bin/bash
set -euo pipefail

# Constants
WIKI_DIR="wiki"
WIKI_FALLBACK_DIR="../wiki-docs.wiki"
SIDEBAR_FILE="$WIKI_DIR/_Sidebar.md"
OUTPUT_FILE="wiki-docs.pdf"

cleanup_symlink=false

# Cleanup handler
cleanup() {
  if [[ "$cleanup_symlink" == true && -L "$WIKI_DIR" ]]; then
    echo "🧹 Cleaning up temporary symlink: $WIKI_DIR"
    rm -f "$WIKI_DIR"
  fi
}
trap cleanup EXIT

# Resolve wiki source
if [[ ! -d "$WIKI_DIR" ]]; then
  if [[ -d "$WIKI_FALLBACK_DIR" ]]; then
    echo "💡 Linking $WIKI_FALLBACK_DIR → $WIKI_DIR"
    ln -s "$WIKI_FALLBACK_DIR" "$WIKI_DIR"
    cleanup_symlink=true
  else
    echo "::error::Wiki folder not found. Expected either:"
    echo " - $WIKI_DIR (used in CI), or"
    echo " - $WIKI_FALLBACK_DIR (used in local dev)"
    exit 1
  fi
fi

# Validate sidebar
if [[ ! -f "$SIDEBAR_FILE" ]]; then
  echo "::error::Missing $SIDEBAR_FILE"
  exit 1
fi

# Collect valid .md files
valid_files=()

while read -r title; do
  file="${title// /-}.md"
  path="$WIKI_DIR/$file"
  if [[ -f "$path" ]]; then
    valid_files+=("$path")
  else
    echo "::warning file=$path::File not found, skipping"
  fi
done < <(grep '\[\[' "$SIDEBAR_FILE" | sed 's/.*\[\[\(.*\)\]\].*/\1/')

if [[ ${#valid_files[@]} -eq 0 ]]; then
  echo "::error::No valid Markdown files found for PDF generation."
  exit 1
fi

# Generate PDF
pandoc "${valid_files[@]}" -o "$OUTPUT_FILE" --pdf-engine=xelatex
echo "
