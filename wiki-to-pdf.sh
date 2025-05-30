#!/usr/bin/env bash
# Convert GitHub wiki pages into a single PDF using Pandoc:
# - Always places Home.md first
# - Uses _Sidebar.md to determine page order
# - Works with a locally cloned wiki in both in CI and locally

# Better debugging output when using `bash -x <script>`
export PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:+${FUNCNAME[0]}():} '

# Safe-mode: error on unset vars, pipe failures, or programs/commands
set -Eeuo pipefail

# Read-only constants
readonly program="$0"  # For messages
# Find the local project directory separately to help Bash better reports errors
_project="$(git rev-parse --show-toplevel)"
readonly PROJECT="$_project"  # Run from within a code project
readonly PROJECT_NAME="${PROJECT##*/}"
readonly WIKI_DIR="wiki"  # Expected name for the checked-out wiki directory
readonly WIKI_FALLBACK_DIR="$PROJECT/../$PROJECT_NAME.wiki"  # Fallback path for local use
readonly SIDEBAR_FILE="$WIKI_DIR/_Sidebar.md"  # Navigation source
readonly DEFAULT_OUTPUT_WIKI_PDF_FILE="out.pdf"
# Better UNICODE support outside ASCII
# TODO: Fallback fonts for missing UNICODE glyphs
readonly PDF_FONT_MAIN="DejaVu Sans"
readonly PDF_FONT_MONO="DejaVu Sans Mono"

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
        printf "🧹 Cleaning up temporary directory/symlink: %s\n" "$WIKI_DIR"
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
            die "Wiki folder not found. Expected either:\n    - $WIKI_DIR (CI) or\n    - $WIKI_FALLBACK_DIR (local)"
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
    done < <(
        grep '\[\[' "$SIDEBAR_FILE" |
            sed 's/.*\[\[\(.*\)\]\].*/\1/' |
            grep -v 'some page title'  # Ignore the example
    )

    readonly PAGE_FILES=("${pages[@]}")
}

# Render the Markdown files into a single PDF using Pandoc
generate_pdf() {
    local pdf_wiki_file="$1"

    if [[ ${#PAGE_FILES[@]} -eq 0 ]]; then
        die "No valid Markdown files found for PDF generation."
    fi

    pandoc --from=gfm "${PAGE_FILES[@]}" \
        --output="$pdf_wiki_file" \
        --pdf-engine=xelatex \
        --variable mainfont="$PDF_FONT_MAIN" \
        --variable monofont="$PDF_FONT_MONO"
}

# Print an error and exit the script
die() {
    printf "::error::%s\n" "$*" >&2
    exit 1
}

function print_usage() {
    cat <<EOU
Usage: $program [-h|--help][-o|--output outfile]
EOU
}

function print_help() {
    print_usage
    cat <<EOF
Converts a matching GitHub repository wiki to PDF.

Options:
    -h, --help          Show this message and exit
    -o, --output=FILE   Save/overwrite PDF file (default: $DEFAULT_OUTPUT_WIKI_PDF_FILE)
EOF
}

# --- Execution begins here ---

pdf_wiki_file="$DEFAULT_OUTPUT_WIKI_PDF_FILE"
while getopts :ho:-: opt; do
    # Complex, but addresses "--foo=bar" type options
    [[ $opt == - ]] && opt=${OPTARG%%=*} OPTARG=${OPTARG#*=}
    case $opt in
    o | output)
        [[ "$OPTARG" = *.pdf ]] || die "$0: $OPTARG: Not a PDF output file"
        pdf_wiki_file="$OPTARG"
        ;;
    h | help) print_help ; exit 0 ;;
    *) print_usage >&2 ;  exit 2 ;;
    esac
done
shift $((OPTIND - 1))

# Step-by-step execution
setup
resolve_wiki_dir
validate_sidebar
order_pages
generate_pdf "$pdf_wiki_file"
printf "✅ PDF generated: %s\n" "$pdf_wiki_file"
