#!/bin/bash

# Coverage Processing Module
# This module handles LCOV coverage data processing and filtering

# Function to run tests and generate coverage
run_tests_with_coverage() {
    local skip_tests="$1"
    local code_review_only="$2"
    
    if [ "$skip_tests" = "true" ]; then
        echo -e "${YELLOW}⏭️  Skipping test execution (--skip-tests flag)${NC}"
        if [ "$code_review_only" = "true" ]; then
            echo -e "${BLUE}📝 Code review mode: Coverage data not required${NC}"
            return 0
        fi
        if [ ! -f "coverage/lcov.info" ]; then
            echo -e "${RED}❌ No existing coverage data found. Run tests first or remove --skip-tests flag.${NC}"
            return 1
        fi
        return 0
    fi
    
    echo -e "${BLUE}🧪 Running tests with coverage...${NC}"
    flutter test --coverage || {
        echo -e "${RED}❌ Tests failed${NC}"
        return 1
    }
    
    if [ ! -f "coverage/lcov.info" ]; then
        echo -e "${RED}❌ Coverage file not generated${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Tests completed successfully${NC}"
    return 0
}

# Function to filter coverage data for modified files
filter_coverage_data() {
    local modified_files="$1"
    local output_dir="$2"
    local include_patterns="$3"
    local code_review_only="$4"
    
    # Create filtered coverage info
    local filtered_info="$output_dir/filtered_coverage.info"
    
    # If in code review only mode and no coverage exists, create empty file
    if [ "$code_review_only" = "true" ] && [ ! -f "coverage/lcov.info" ]; then
        echo -e "${BLUE}📝 Code review mode: Skipping coverage filtering${NC}" >&2
        touch "$filtered_info"
        echo "$filtered_info"
        return 0
    fi
    
    echo -e "${BLUE}🔍 Filtering coverage for modified files...${NC}" >&2
    
    if [ -n "$include_patterns" ]; then
        # Use include patterns to filter from existing coverage
        eval "lcov --extract coverage/lcov.info $include_patterns --output-file '$filtered_info' --ignore-errors unused >&2" || {
            echo -e "${RED}❌ Coverage filtering failed${NC}" >&2
            return 1
        }
    else
        # No specific patterns, use all coverage
        cp "coverage/lcov.info" "$filtered_info"
    fi
    
    # Verify filtered coverage has data
    if [ ! -s "$filtered_info" ]; then
        echo -e "${YELLOW}⚠️  No coverage data for modified files. Using full coverage.${NC}" >&2
        cp "coverage/lcov.info" "$filtered_info"
    fi
    
    echo "$filtered_info"
    return 0
}

# Function to generate HTML coverage report
generate_html_report() {
    local filtered_info="$1"
    local output_dir="$2"
    local code_review_only="$3"
    
    # Create HTML directory
    mkdir -p "$output_dir/html"
    
    # If no coverage data or empty coverage file, create minimal HTML structure
    if [ "$code_review_only" = "true" ] || [ ! -s "$filtered_info" ] || [ ! -f "$filtered_info" ]; then
        echo -e "${BLUE}📝 Creating minimal HTML structure (no coverage data)${NC}" >&2
        
        # Create a basic index.html for code review
        cat > "$output_dir/html/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Code Review Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #0d1117; color: #e6edf3; }
        .header { text-align: center; margin-bottom: 30px; }
        .section { margin: 20px 0; padding: 15px; background-color: #161b22; border-radius: 6px; }
        .button { background-color: #238636; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 10px; }
        .button:hover { background-color: #2ea043; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Code Review Report</h1>
        <p>Generated for code review analysis</p>
    </div>
    <div class="section">
        <h2>Available Reports</h2>
        <p>This report was generated without coverage data.</p>
    </div>
</body>
</html>
EOF
        echo -e "${GREEN}✅ Minimal HTML structure created: $output_dir/html/index.html${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📊 Generating HTML coverage report...${NC}" >&2
    echo "Debug: filtered_info='$filtered_info'" >&2
    
    # Generate HTML report
    local genhtml_args=("$filtered_info" --output-directory "$output_dir/html" \
        --title "Coverage Report" \
        --show-details \
        --legend \
        --css-file "$(dirname "$SCRIPT_DIR")/templates/custom_dark_theme.css" \
        --ignore-errors deprecated)
    
    # Note: Custom dark theme will be applied post-generation if enabled
    
    # Change to package directory for genhtml to find source files
    local current_dir="$(pwd)"
    cd "$PACKAGE_PATH" || {
        echo -e "${RED}❌ Failed to change to package directory: $PACKAGE_PATH${NC}"
        return 1
    }
    
    # Calculate relative paths manually for macOS compatibility
    local relative_filtered_info="$(python3 -c "import os; print(os.path.relpath('$filtered_info', '$PACKAGE_PATH'))")"
    local relative_output_dir="$(python3 -c "import os; print(os.path.relpath('$output_dir', '$PACKAGE_PATH'))")"
    
    local genhtml_args_relative=("$relative_filtered_info" --output-directory "$relative_output_dir/html" \
        --title "Coverage Report" \
        --show-details \
        --legend \
        --css-file "$(dirname "$SCRIPT_DIR")/templates/custom_dark_theme.css" \
        --ignore-errors deprecated)
    
    genhtml "${genhtml_args_relative[@]}" || {
        cd "$current_dir"
        echo -e "${RED}❌ HTML report generation failed${NC}"
        return 1
    }
    
    # Return to original directory
    cd "$current_dir"
    
    # Apply custom dark theme if enabled (but not using built-in dark mode)
    if [[ "$CONFIG_DARK_MODE" == "true" ]]; then
        apply_custom_dark_theme "$output_dir/html"
    fi
    
    echo -e "${GREEN}✅ HTML report generated: $output_dir/html/index.html${NC}"
    return 0
}

# Function to apply custom dark theme to generated HTML reports
apply_custom_dark_theme() {
    local html_dir="$1"
    
    echo -e "${PURPLE}🌙 Applying custom dark theme...${NC}" >&2
    
    # Generate custom dark theme CSS programmatically
    local dark_css="
/* Custom Dark Theme for LCOV Coverage Reports */
body {
    background-color: #0d1117 !important;
    color: #e6edf3 !important;
}

a:link, a:visited {
    color: #58a6ff !important;
}

a:hover {
    color: #79c0ff !important;
}

.title {
    color: #f0f6fc !important;
}

.headerItem {
    background-color: #21262d !important;
    color: #e6edf3 !important;
}

.headerValue {
    background-color: #161b22 !important;
    color: #e6edf3 !important;
}

.headerCovTableHead {
    background-color: #21262d !important;
    color: #e6edf3 !important;
}

.headerCovTableEntry {
    background-color: #161b22 !important;
    color: #e6edf3 !important;
}

.headerCovTableEntryHi {
    background-color: #238636 !important;
    color: #ffffff !important;
}

.headerCovTableEntryMed {
    background-color: #d29922 !important;
    color: #ffffff !important;
}

.headerCovTableEntryLo {
    background-color: #da3633 !important;
    color: #ffffff !important;
}

.coverPerHi {
    background-color: #238636 !important;
    color: #ffffff !important;
}

.coverPerMed {
    background-color: #d29922 !important;
    color: #ffffff !important;
}

.coverPerLo {
    background-color: #da3633 !important;
    color: #ffffff !important;
}

.coverNumHi {
    background-color: #2d5016 !important;
    color: #e6edf3 !important;
}

.coverNumMed {
    background-color: #4d3800 !important;
    color: #e6edf3 !important;
}

.coverNumLo {
    background-color: #4c1a1a !important;
    color: #e6edf3 !important;
}

table {
    border-color: #30363d !important;
}

td, th {
    border-color: #30363d !important;
}

.ruler {
    background-color: #21262d !important;
}

.versionInfo {
    background-color: #161b22 !important;
    color: #7d8590 !important;
}

.tableHead {
    background-color: #21262d !important;
    color: #e6edf3 !important;
}

.coverFile {
    background-color: #0d1117 !important;
    color: #e6edf3 !important;
}

.coverFile:hover {
    background-color: #161b22 !important;
}

.coverBar {
    background-color: #21262d !important;
}

.coverBarOutline {
    border-color: #30363d !important;
}

/* Fix AI insights button visibility and accessibility */
.ai-insights-button, .ai-button, [class*="ai"], [class*="insight"], 
button[class*="ai"], input[class*="ai"], a[class*="ai"] {
    background-color: #238636 !important;
    color: #ffffff !important;
    border: 2px solid #2ea043 !important;
    padding: 8px 16px !important;
    border-radius: 6px !important;
    font-weight: 600 !important;
    text-decoration: none !important;
    display: inline-block !important;
    cursor: pointer !important;
    transition: all 0.2s ease !important;
}

.ai-insights-button:hover, .ai-button:hover, 
button[class*="ai"]:hover, input[class*="ai"]:hover, a[class*="ai"]:hover {
    background-color: #2ea043 !important;
    border-color: #46954a !important;
    transform: translateY(-1px) !important;
    box-shadow: 0 4px 8px rgba(35, 134, 54, 0.3) !important;
}

/* Ensure AI button is always visible */
[style*="display: none"] {
    display: block !important;
}

/* Fix any hidden AI elements */
.hidden, .invisible {
    visibility: visible !important;
    opacity: 1 !important;
}

/* Fix file name and code section readability */
.coverFile, .coverFilename {
    background-color: transparent !important;
    color: #e6edf3 !important;
}

.coverFile:hover {
    background-color: #161b22 !important;
}

/* Remove blue backgrounds from directory listings */
.coverDir, .directory, .dir {
    background-color: transparent !important;
    color: #e6edf3 !important;
}

.coverDir:hover, .directory:hover, .dir:hover {
    background-color: #161b22 !important;
}

/* Fix covered code sections with very thin light blue */
.lineCov, .lineNoCov, .linePart {
    background-color: transparent !important;
}

/* Covered lines - very thin light blue background */
.lineCov {
    background-color: rgba(135, 206, 235, 0.08) !important;
    color: #e6edf3 !important;
    border-left: 2px solid rgba(135, 206, 235, 0.3) !important;
}

/* Uncovered lines - subtle red background */
.lineNoCov {
    background-color: #4c1a1a !important;
    color: #e6edf3 !important;
}

/* Partially covered lines - subtle yellow background */
.linePart {
    background-color: #4d3800 !important;
    color: #e6edf3 !important;
}

/* Remove any problematic overlays */
.coverageHighlight, .coveredCode, .highlighted {
    background-color: transparent !important;
    color: inherit !important;
}

/* Fix specific coverage highlighting elements with very light blue */
span[style*="background-color"] {
    background-color: rgba(135, 206, 235, 0.05) !important;
}

/* Ensure code text is always readable */
.sourceCode, .source-line, .code-line {
    color: #e6edf3 !important;
    background-color: transparent !important;
}

/* Fix source code display */
pre, code {
    background-color: #161b22 !important;
    color: #e6edf3 !important;
}

/* Fix line numbers */
.lineNum {
    background-color: #21262d !important;
    color: #7d8590 !important;
    border-right: 1px solid #30363d !important;
}

/* Fix coverage percentage bars */
.coverPer {
    color: #ffffff !important;
}

/* Fix table rows */
tr:nth-child(even) {
    background-color: #161b22 !important;
}

tr:nth-child(odd) {
    background-color: #0d1117 !important;
}

/* Fix links in tables */
td a, th a {
    color: #58a6ff !important;
    text-decoration: none;
}

td a:hover, th a:hover {
    color: #79c0ff !important;
    text-decoration: underline;
}

/* Override td.coverDirectory blue background with more specific selectors */
table td.coverDirectory,
td.coverDirectory,
.coverDirectory {
    background-color: transparent !important;
    color: #e6edf3 !important;
}

table td.coverDirectory:hover,
td.coverDirectory:hover,
.coverDirectory:hover {
    background-color: #161b22 !important;
}

/* Additional overrides for any blue backgrounds in directory listings */
td.coverDirectory[style],
td.coverDirectory {
    background-color: transparent !important;
}

/* Override specific blue background color */
td {
    background-color: transparent !important;
}
"
    
    # Create a temporary CSS file
    local css_file="$(mktemp)"
    echo "$dark_css" > "$css_file"
    
    # Apply dark theme to all HTML files in the directory
    find "$html_dir" -name "*.html" -type f | while read -r html_file; do
        # Check if file has a </head> tag to inject CSS
        if grep -q "</head>" "$html_file"; then
            # Create a temporary file with dark theme CSS injected
            local temp_file="$(mktemp)"
            
            # Insert dark theme CSS before </head> using perl for multiline support
            perl -pe "s|</head>|<style type=\"text/css\">\n$(cat "$css_file")\n</style>\n</head>|" "$html_file" > "$temp_file"
            
            # Replace original file with modified version
            mv "$temp_file" "$html_file"
            
            echo -e "${GREEN}  ✅ Applied dark theme to: $(basename "$html_file")${NC}" >&2
        fi
    done
    
    # Clean up temporary CSS file
    rm -f "$css_file"
    
    echo -e "${PURPLE}🌙 Custom dark theme applied successfully${NC}" >&2
}

# Function to display coverage summary
display_coverage_summary() {
    local filtered_info="$1"
    local modified_files="$2"
    
    echo -e "${PURPLE}📈 Coverage Summary:${NC}"
    echo "=================="
    
    # Display LCOV summary
    lcov --summary "$filtered_info" 2>/dev/null | grep -E "(lines|functions|branches)" || {
        echo -e "${YELLOW}⚠️  Could not generate coverage summary${NC}"
    }
    
    echo ""
    echo -e "${BLUE}📁 Analyzed files:${NC}"
    echo "$modified_files" | sed 's/^/   - /'
    echo ""
}

# Function to create coverage output directory
create_output_directory() {
    local output_dir="$1"
    
    # Create output directory structure
    mkdir -p "$output_dir/html" || {
        echo -e "${RED}❌ Failed to create output directory: $output_dir${NC}"
        return 1
    }
    
    echo "$output_dir"
    return 0
}

# Function to copy LCOV file to output directory
copy_lcov_file() {
    local filtered_info="$1"
    local output_dir="$2"
    
    # Copy filtered LCOV file to output directory
    cp "$filtered_info" "$output_dir/" || {
        echo -e "${YELLOW}⚠️  Could not copy LCOV file to output directory${NC}"
    }
}

# Main function to process coverage data
process_coverage() {
    local modified_files="$1"
    local output_dir="$2"
    local skip_tests="$3"
    local include_patterns="$4"
    local code_review_only="$5"
    
    # Run tests with coverage (unless skipped or in code review mode)
    if ! run_tests_with_coverage "$skip_tests" "$code_review_only"; then
        return 1
    fi
    
    # Create output directory
    if ! create_output_directory "$output_dir"; then
        return 1
    fi
    
    # Filter coverage data
    local filtered_info
    if ! filtered_info=$(filter_coverage_data "$modified_files" "$output_dir" "$include_patterns" "$code_review_only"); then
        return 1
    fi
    
    # Generate HTML report
    if ! generate_html_report "$filtered_info" "$output_dir" "$code_review_only"; then
        return 1
    fi
    
    # Copy LCOV file to output (only if we have coverage data)
    if [ -s "$filtered_info" ]; then
        copy_lcov_file "$filtered_info" "$output_dir"
        # Display summary
        display_coverage_summary "$filtered_info" "$modified_files"
    else
        echo -e "${BLUE}📝 Code review mode: No coverage data to summarize${NC}"
    fi
    
    echo "$filtered_info"
    return 0
}