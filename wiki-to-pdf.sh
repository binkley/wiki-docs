#!/usr/bin/env bash
# Convert GitHub wiki pages into a single PDF using Pandoc
# - Always places Home.md first
# - Uses _Sidebar.md to determine page order
# - Works both in CI and locally with a manually cloned wiki

set -Eeuo pipefail  # Safe-mode: error on unset vars, pipe failures, or command errors

# Read-only constants
readonly WIKI_DIR="wiki"                             # Expected name for the checked-out wiki directory
readonly WIKI_FALLBACK_DIR="../wiki-docs.wiki"       # Fallback path for local use
readonly SIDEBAR_FILE="$WIKI_DIR/_Sidebar.md"        # Navigation source
readonly OUTPUT_FILE="wiki-docs.pdf"                 # Final output PDF file

cleanup_symlink=false  # Whether we created a temporary symlink

# Ensure any symlinks are cleaned up, even on failure or Ctrl+C
trap cleanup EXIT

# Placeholder for future setup logic
setup() {
  :  # No-op
}

# Remove temp symlink if we created one
cleanup() {
  if [[ "$cleanup_symlink" == true && -L "$WIKI_DIR" ]]; then
    printf "🧹 Cleaning up temporary symlink: %s\n" "$WIKI_DIR"
    rm -f "$WIKI_DIR"
  fi
}

# Choose the wiki source directory
# CI: expects ./wiki to exist from git clone
# Local: uses ../wiki-docs.wiki and symlinks it to ./wiki
resolve_wiki_dir() {
  if [[ ! -d "$WIKI_DIR" ]]; then
    if [[ -d "$WIKI_FALLBACK_DIR" ]]; then
      printf "💡 Linking %s → %s\n" "$WIKI_FALLBACK_DIR" "$WIKI_DIR"
      ln -s "$WIKI_FALLBACK_DIR" "$WIKI_DIR"
      cleanup_symlink=true
    else
      die "Wiki folder not found. Expected either:\n  - $WIKI_DIR (CI) or\n  - $WIKI_FALLBACK_DIR (local)"
    fi
  fi
}

# Ensure the sidebar exists
validate_sidebar() {
  if [[ ! -f "$SIDEBAR_FILE" ]]; then
    die "Missing sidebar file: $SIDEBAR_FILE"
  fi
}

# Determine page order for PDF
# - Always include Home.md first
# - Then use _Sidebar.md to determine order
# - Skips missing files and avoids duplicate Home.md
order_pages() {
  local pages=()

  # Prefer Home.md first
  local home="$WIKI_DIR/Home.md"
  if [[ -f "$home" ]]; then
    pages+=("$home")
  else
    echo "::warning file=$home::Home.md not found, skipping"
  fi

  # Parse [[Page Title]] from _Sidebar.md
  while read -r title; do
    local file="${title// /-}.md"   # GitHub Wiki uses dash-separated filenames
    local path="$WIKI_DIR/$file"

    [[ "$file" == "Home.md" ]] && continue  # Avoid duplication

    if [[ -f "$path" ]]; then
      pages+=("$path")
    else
      echo "::warning file=$path::File not found, skipping"
    fi
  done < <(grep '\[\[' "$SIDEBAR_FILE" | sed 's/.*\[\[\(.*\)\]\].*/\1/')

  readonly PAGE_FILES=("${pages[@]}")
}

# Render the Markdown files into a single PDF using Pandoc
generate_pdf() {
  if [[ ${#PAGE_FILES[@]} -eq 0 ]]; then
    die "No valid Markdown files found for PDF generation."
  fi

  pandoc "${PAGE_FILES[@]}" -o "$OUTPUT_FILE" --pdf-engine=xelatex
}

# Print an error and exit the script
die() {
  printf "::error::%s\n" "$*" >&2
  exit 1
}

# Usage message for --help
usage() {
  cat <<EOF
Usage: $(basename "$0")

Converts a GitHub wiki (cloned to ./wiki or ../wiki-docs.wiki) into a single PDF using pandoc.

Options:
  --help        Show this help message
EOF
  exit
}

# --- Execution begins here ---

# Handle --help manually (before processing args)
if [[ "${1:-}" == "--help" ]]; then usage; fi

# Step-by-step execution
setup
resolve_wiki_dir
validate_sidebar
order_pages
generate_pdf
printf "✅ PDF generated: %s\n" "$OUTPUT_FILE"
