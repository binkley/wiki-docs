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
readonly SIDEBAR_FILE="wiki/_Sidebar.md"  # Navigation source
readonly DEFAULT_OUTPUT_WIKI_PDF_FILE="out.pdf"

update_wiki() {
    git submodule update --remote
    printf "✅ Updated wiki locally\n"
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
    local home="wiki/Home.md"
    if [[ -f "$home" ]]; then
        pages+=("$home")
    else
        echo "::warning file=$home::Home.md not found, skipping"
    fi

    # Parse [[Page Title]] from _Sidebar.md
    while read -r title; do
        local file="${title// /-}.md"   # GitHub Wiki uses dash-separated filenames
        local path="wiki/$file"

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

    # Typist refers to images form the current directory
    local wiki_files=("${PAGE_FILES[@]//wiki\/}")
    pdf_wiki_file="$(realpath "$pdf_wiki_file")"

    # Subshell so CWD is same and cleanup does not change
    (
        cd wiki
        pandoc --from=gfm "${wiki_files[@]}" \
            --output="$pdf_wiki_file" \
            --pdf-engine=typst
    )
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
update_wiki
validate_sidebar
order_pages
generate_pdf "$pdf_wiki_file"
printf "✅ PDF generated: %s\n" "$pdf_wiki_file"
