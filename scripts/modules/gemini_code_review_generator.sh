#!/bin/bash

# Gemini Code Review Generator
# Generates AI-powered code reviews using Gemini API

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GEMINI_CONFIG_DIR="$PROJECT_ROOT/.gemini"
CONFIG_FILE="$GEMINI_CONFIG_DIR/config.yaml"
STYLEGUIDE_FILE="$GEMINI_CONFIG_DIR/styleguide.md"
SETTINGS_FILE="$GEMINI_CONFIG_DIR/settings.json"
REVIEW_TEMPLATE="$(dirname "$SCRIPT_DIR")/templates/gemini_code_review_template.html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${BLUE}🔍 $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to check if file should be included in review
should_include_file() {
    local file="$1"
    
    # Skip if file doesn't exist (check from repo root)
    if [[ ! -f "$file" ]]; then
        log "File does not exist: $file"
        return 1
    fi
    
    # Include Dart files (but exclude generated files)
    if [[ "$file" == *.dart ]]; then
        # Exclude common generated files
        if [[ "$file" == *.g.dart ]] || [[ "$file" == *.freezed.dart ]] || [[ "$file" == *.mocks.dart ]]; then
            log "Excluding generated Dart file: $file"
            return 1
        fi
        # Exclude localization generated files
        if [[ "$file" == *"l10n/generated/"* ]] || [[ "$file" == *"localizations.dart" ]] || [[ "$file" == *"messages_"*.dart ]]; then
            log "Excluding localization generated file: $file"
            return 1
        fi
        log "Including Dart file: $file"
        return 0
    fi
    
    # Include YAML files
    if [[ "$file" == *.yaml ]] || [[ "$file" == *.yml ]]; then
        log "Including YAML file: $file"
        return 0
    fi
    
    # Include JSON files
    if [[ "$file" == *.json ]]; then
        log "Including JSON file: $file"
        return 0
    fi
    
    # Include Markdown files
    if [[ "$file" == *.md ]]; then
        log "Including Markdown file: $file"
        return 0
    fi
    
    # Exclude everything else
    log "Excluding file (unsupported type): $file"
    return 1
}

# Function to check Gemini availability
check_gemini_availability() {
    if ! command -v gemini &> /dev/null; then
        log_error "Gemini CLI not found. Please install it first."
        return 1
    fi
    
    if [ ! -f "$STYLEGUIDE_FILE" ]; then
        log_error "Styleguide file not found: $STYLEGUIDE_FILE"
        return 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    return 0
}

# Function to detect changes and create review content
detect_changes() {
    local package_path="$1"
    local base_branch="$2"
    local output_file="$3"
    
    log "Detecting changes in $package_path against $base_branch"
    
    # Get list of modified files
    local modified_files
    if [[ "$package_path" == "." ]]; then
        # Get all changes in the repository
        modified_files=$(git diff --name-only "$base_branch"...HEAD 2>/dev/null || \
                        git diff --name-only HEAD~1 2>/dev/null || \
                        git status --porcelain | cut -c4- || \
                        echo "")
    else
        # Get changes in specific package path
        modified_files=$(git diff --name-only "$base_branch"...HEAD -- "$package_path/" 2>/dev/null || \
                        git diff --name-only HEAD~1 -- "$package_path/" 2>/dev/null || \
                        echo "")
    fi
    
    if [[ -z "$modified_files" ]]; then
        log_warning "No changes detected in $package_path"
        return 1
    fi
    
    log "Found modified files: $modified_files"
    
    # Filter files that should be included
    local filtered_files=""
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            log "Checking file: $file"
            if should_include_file "$file"; then
                log "Including file: $file"
                filtered_files="$filtered_files$file\n"
            else
                log "Excluding file: $file"
            fi
        fi
    done <<< "$modified_files"
    
    if [[ -z "$filtered_files" ]]; then
        log_warning "No relevant files found for review"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$(dirname "$output_file")"
    
    # Write header
    echo "# Code Review for $package_path" > "$output_file"
    echo "" >> "$output_file"
    echo "## Modified Files" >> "$output_file"
    echo -e "$filtered_files" | grep -v '^$' >> "$output_file"
    echo "" >> "$output_file"
    echo "## Changes" >> "$output_file"
    echo "" >> "$output_file"
    
    # Add diff content for each file
    # Process each file individually
    while IFS= read -r file; do
        if [[ -n "$file" && -f "$file" ]]; then
            echo "### $file" >> "$output_file"
            printf '%s\n' '```diff' >> "$output_file"
            
            # Get diff for the file
            local diff_output
            diff_output=$(git diff "$base_branch"...HEAD -- "$file" 2>/dev/null) || \
            diff_output=$(git diff HEAD~1 -- "$file" 2>/dev/null) || \
            diff_output="No diff available"
            
            echo "$diff_output" >> "$output_file"
            printf '%s\n' '```' >> "$output_file"
            echo "" >> "$output_file"
        fi
    done <<< "$(echo -e "$filtered_files" | grep -v '^$')"
    
    log_success "Changes detected and saved to $output_file"
    return 0
}

# Function to convert markdown to HTML
convert_to_html() {
    local markdown_file="$1"
    local html_file="$2"
    local title="$3"
    
    # Create review template if it doesn't exist
    if [[ ! -f "$REVIEW_TEMPLATE" ]]; then
        create_review_template
    fi
    
    # Check if Python 3 is available for markdown conversion
    if command -v python3 >/dev/null 2>&1; then
        log "Converting markdown to HTML using Python"
        python3 "$SCRIPT_DIR/../utils/markdown_to_html.py" "$markdown_file" "$html_file" "$title" "$REVIEW_TEMPLATE"
    else
        log_warning "Python 3 not found, creating basic HTML"
        create_basic_html "$markdown_file" "$html_file" "$title"
    fi
    
    log_success "HTML review generated: $html_file"
}

# Function to create review template if it doesn't exist
create_review_template() {
    mkdir -p "$(dirname "$REVIEW_TEMPLATE")"
    
    cat > "$REVIEW_TEMPLATE" << 'TEMPLATE_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{TITLE}}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            color: #e0e0e0;
            background-color: #1a1a1a;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: #2d2d2d;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
        }
        h1, h2, h3, h4, h5, h6 {
            color: #ffffff;
            margin-top: 30px;
            margin-bottom: 15px;
        }
        h1 {
            border-bottom: 2px solid #4a9eff;
            padding-bottom: 10px;
        }
        h2 {
            border-bottom: 1px solid #666;
            padding-bottom: 5px;
        }
        pre {
            background: #1e1e1e;
            border: 1px solid #444;
            border-radius: 4px;
            padding: 15px;
            overflow-x: auto;
            margin: 15px 0;
        }
        code {
            background: #1e1e1e;
            border: 1px solid #444;
            border-radius: 3px;
            padding: 2px 6px;
            font-family: "Monaco", "Menlo", "Ubuntu Mono", monospace;
            color: #f8f8f2;
        }
        pre code {
            background: none;
            border: none;
            padding: 0;
        }
        blockquote {
            border-left: 4px solid #4a9eff;
            margin: 20px 0;
            padding: 10px 20px;
            background: #2a2a2a;
            border-radius: 0 4px 4px 0;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            color: #4a9eff;
            text-decoration: none;
            font-weight: 500;
        }
        .back-link:hover {
            text-decoration: underline;
        }
        .content {
            margin-top: 20px;
        }
        ul, ol {
            margin: 15px 0;
            padding-left: 30px;
        }
        li {
            margin: 8px 0;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #444;
            padding: 12px;
            text-align: left;
        }
        th {
            background: #333;
            font-weight: 600;
        }
        tr:nth-child(even) {
            background: #2a2a2a;
        }
        .diff-added {
            background-color: #1e4d2b;
            color: #a8e6a3;
        }
        .diff-removed {
            background-color: #4d1e1e;
            color: #f8a8a8;
        }
    </style>
</head>
<body>
    <div class="container">
        <a href="index.html" class="back-link">← Back to Coverage Report</a>
        <h1>{{TITLE}}</h1>
        <div class="content">
            {{CONTENT}}
        </div>
    </div>
</body>
</html>
TEMPLATE_EOF
}

# Function to create basic HTML fallback
create_basic_html() {
    local markdown_file="$1"
    local html_file="$2"
    local title="$3"
    
    # Read template content
    local template_content
    if [[ -f "$REVIEW_TEMPLATE" ]]; then
        template_content=$(cat "$REVIEW_TEMPLATE")
    else
        create_review_template
        template_content=$(cat "$REVIEW_TEMPLATE")
    fi
    
    # Read markdown content and escape special characters for sed
    local content
    content=$(cat "$markdown_file" | sed 's/[\\&\/]/\\&/g')
    
    # Create temporary file for content processing
    local temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    
    # Replace placeholders using perl for better handling
    if command -v perl &> /dev/null; then
        echo "$template_content" | \
            perl -pe "s/\{\{TITLE\}\}/$title/g" | \
            perl -pe "s/\{\{CONTENT\}\}/$(cat "$temp_file" | sed 's/[\\&\/]/\\&/g')/g" > "$html_file"
    else
        # Fallback: create simple HTML without template
        cat > "$html_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #1a1a1a; color: #e0e0e0; }
        pre { background: #2d2d2d; padding: 15px; border-radius: 5px; overflow-x: auto; }
        h1, h2, h3 { color: #ffffff; }
    </style>
</head>
<body>
    <h1>$title</h1>
    <pre>$(cat "$markdown_file")</pre>
</body>
</html>
EOF
    fi
    
    rm -f "$temp_file"
    log_success "HTML review created: $html_file"
}

# Main function
main() {
    local package_path="$1"
    local base_branch="${2:-main}"
    local output_dir="${3:-coverage}"
    
    if [[ -z "$package_path" ]]; then
        log_error "Usage: $0 <package_path> [base_branch] [output_dir]"
        exit 1
    fi
    
    # Ensure we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Create output files
    local markdown_file="$output_dir/code_review.md"
    local html_file="$output_dir/code_review.html"
    local title="Code Review - $(basename "$package_path")"
    
    # Detect changes and create markdown
    if detect_changes "$package_path" "$base_branch" "$markdown_file"; then
        # Convert to HTML
        convert_to_html "$markdown_file" "$html_file" "$title"
        log_success "Code review generated successfully!"
        log "Markdown: $markdown_file"
        log "HTML: $html_file"
    else
        log_error "Failed to generate code review"
        exit 1
    fi
}

# Function to add code review link to coverage report
add_code_review_link_to_coverage_report() {
    local output_dir="$1"
    local coverage_html="$output_dir/html/index.html"
    
    if [ -f "$coverage_html" ]; then
        # Simple sed replacement to add code review link before </body>
        sed -i.bak "s|</body>|<table width=\"100%\" border=0 cellspacing=0 cellpadding=0><tr><td class=\"ruler\"><img src=\"glass.png\" width=3 height=3></td></tr><tr><td class=\"versionInfo\" style=\"text-align: center; padding: 20px;\"><a href=\"code_review.html\" style=\"background: white; color: #333; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold; border: 1px solid #ddd;\">🔍 View Gemini Code Review</a></td></tr></table><br></body>|" "$coverage_html"
        rm "$coverage_html.bak"
        echo -e "${GREEN}✨ Code review link added to coverage report${NC}"
    else
        echo -e "${YELLOW}⚠️  Coverage HTML file not found: $coverage_html${NC}"
    fi
}

# Function to generate Gemini review
generate_gemini_review() {
    local changes_file="$1"
    local output_file="$2"
    
    log "Generating Gemini code review..."
    
    # Read styleguide
    local styleguide_content
    if [[ -f "$STYLEGUIDE_FILE" ]]; then
        styleguide_content=$(cat "$STYLEGUIDE_FILE")
    else
        log_warning "Styleguide not found, using default guidelines"
        styleguide_content="Follow Flutter/Dart best practices and coding standards."
    fi
    
    # Create prompt
    local prompt_file=$(mktemp)
    cat > "$prompt_file" << EOF
As a senior Flutter/Dart code reviewer, please review the following code changes:

Coding Guidelines:
$styleguide_content

Code Changes:
$(cat "$changes_file")

Please provide:
1. 🎯 Overall assessment
2. 🔍 Specific issues and suggestions
3. ✅ Positive aspects
4. 🚀 Recommendations for improvement
5. 🧪 Testing considerations

Format as markdown with clear sections and code examples where helpful.
EOF
    
    # Generate review with Gemini
    if command -v gemini &> /dev/null; then
        if gemini -p "$(cat "$prompt_file")" > "$output_file" 2>/dev/null; then
            log_success "Gemini review generated successfully"
            rm -f "$prompt_file"
            return 0
        else
            log_warning "Gemini failed, using fallback review"
        fi
    else
        log_warning "Gemini CLI not available"
    fi
    
    # Fallback review
    cat > "$output_file" << EOF
# 🔍 Code Review

## 📋 Summary
Code review generated for the modified files. Please review the changes manually.

## 📁 Changes Detected
$(cat "$changes_file")

## 🎯 Recommendations
- Review all modified files for potential issues
- Ensure proper testing coverage
- Follow project coding standards
- Consider performance implications

## 📝 Notes
This is a fallback review. Install Gemini CLI for AI-powered insights.
EOF
    
    rm -f "$prompt_file"
    log_success "Fallback review generated"
    return 0
}

# Main function to process code review
process_code_review() {
    local output_dir="$1"
    local package_name="$2"
    local modified_files="$3"
    local script_dir="$4"
    
    echo -e "${BLUE}Starting Gemini code review generation...${NC}"
    
    # Ensure we're in the repository root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$repo_root" ]]; then
        cd "$repo_root" || {
            log_error "Failed to change to repository root: $repo_root"
            return 1
        }
    fi
    
    # Check prerequisites
    if ! check_gemini_availability; then
        return 1
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Generate temporary files
    local changes_file=$(mktemp)
    local review_md="$output_dir/code_review.md"
    local review_html="$output_dir/html/code_review.html"
    
    # Ensure HTML directory exists
    mkdir -p "$output_dir/html"
    
    # Get git changes
    if ! detect_changes "." "main" "$changes_file"; then
        echo -e "${RED}❌ Failed to detect changes${NC}"
        rm -f "$changes_file"
        return 1
    fi
    
    # Generate review
    if ! generate_gemini_review "$changes_file" "$review_md"; then
        echo -e "${RED}❌ Failed to generate code review${NC}"
        rm -f "$changes_file"
        return 1
    fi
    
    # Convert to HTML
    create_basic_html "$review_md" "$review_html" "Gemini Code Review"
    
    # Add link to coverage report
    add_code_review_link_to_coverage_report "$output_dir"
    
    # Cleanup
    rm -f "$changes_file"
    
    echo -e "${GREEN}✅ Code review generation complete!${NC}"
    echo -e "${CYAN}📄 Markdown review: $review_md${NC}"
    echo -e "${CYAN}🌐 HTML review: $review_html${NC}"
    
    return 0
}

# Export functions for use in other scripts
export -f process_code_review
export -f detect_changes
export -f create_review_template
export -f create_basic_html

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi