#!/bin/bash

# Package-specific filtered coverage tool
# Generates coverage reports for modified files in a single Flutter package

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required modules
source "$SCRIPT_DIR/modules/config_manager.sh"
source "$SCRIPT_DIR/modules/file_detector.sh"
source "$SCRIPT_DIR/modules/coverage_processor.sh"
source "$SCRIPT_DIR/modules/ai_insights_generator.sh"
source "$SCRIPT_DIR/modules/gemini_code_review_generator.sh"

# Initialize configuration
if ! init_configuration "$@"; then
    exit 1
fi

# Change to package directory
cd "$CONFIG_PACKAGE_PATH"

# Main workflow
echo -e "${BLUE}🔍 Detecting modified files...${NC}"
MODIFIED_FILES=$(detect_modified_files "$CONFIG_BASE_BRANCH" "$CONFIG_PACKAGE_PATH")

# Validate package structure
if ! validate_package_structure "$CONFIG_PACKAGE_PATH"; then
    exit 1
fi

# Check if we have modified files
if [ -z "$MODIFIED_FILES" ]; then
    echo -e "${YELLOW}⚠️  No modified Dart files found in lib/ directory${NC}"
    echo -e "${YELLOW}   Package: $(pwd)${NC}"
    echo -e "${YELLOW}   Comparing against branch: $CONFIG_BASE_BRANCH${NC}"
    echo -e "${BLUE}📊 Processing full coverage instead...${NC}"
    INCLUDE_PATTERNS=""
else
    echo -e "${GREEN}✅ Found modified files:${NC}"
    echo "$MODIFIED_FILES" | sed 's/^/   - /'
    echo ""
    # Create include patterns for LCOV filtering
    INCLUDE_PATTERNS=$(create_lcov_include_patterns "$MODIFIED_FILES")
fi

echo -e "${BLUE}📊 Processing coverage...${NC}"
# Determine if we're in code review only mode (no AI insights, only code review)
CODE_REVIEW_ONLY="false"
if [ "$CONFIG_CODE_REVIEW" = "true" ] && [ "$CONFIG_AI_INSIGHTS" = "false" ]; then
    CODE_REVIEW_ONLY="true"
fi

FILTERED_INFO=$(process_coverage "$MODIFIED_FILES" "$CONFIG_OUTPUT_DIR" "$CONFIG_SKIP_TESTS" "$INCLUDE_PATTERNS" "$CODE_REVIEW_ONLY")
if [ $? -ne 0 ]; then
    exit 1
fi

# Get package name for AI insights
PACKAGE_NAME=$(basename "$(pwd)")

if [ "$CONFIG_AI_INSIGHTS" = "true" ]; then
     echo -e "${BLUE}🤖 Generating AI insights...${NC}"
     process_ai_insights "$CONFIG_OUTPUT_DIR" "$PACKAGE_NAME" "$MODIFIED_FILES" "$FILTERED_INFO" "$SCRIPT_DIR"
fi

if [ "$CONFIG_CODE_REVIEW" = "true" ]; then
     echo -e "${BLUE}🔍 Generating Gemini code review...${NC}"
     process_code_review "$CONFIG_OUTPUT_DIR" "$PACKAGE_NAME" "$MODIFIED_FILES" "$SCRIPT_DIR"
fi

echo -e "${GREEN}✅ Coverage analysis complete!${NC}"
echo -e "${CYAN}📁 Output directory: $CONFIG_OUTPUT_DIR${NC}"
echo -e "${CYAN}📊 HTML report: $CONFIG_OUTPUT_DIR/html/index.html${NC}"
echo -e "${CYAN}📄 LCOV file: $CONFIG_OUTPUT_DIR/lcov.info${NC}"
if [ "$CONFIG_AI_INSIGHTS" = "true" ]; then
    echo -e "${CYAN}🤖 AI insights: $CONFIG_OUTPUT_DIR/ai_insights.md${NC}"
    echo -e "${CYAN}🌐 AI insights HTML: $CONFIG_OUTPUT_DIR/html/ai_insights.html${NC}"
fi
if [ "$CONFIG_CODE_REVIEW" = "true" ]; then
    echo -e "${CYAN}🔍 Code review: $CONFIG_OUTPUT_DIR/code_review.md${NC}"
    echo -e "${CYAN}🌐 Code review HTML: $CONFIG_OUTPUT_DIR/html/code_review.html${NC}"
fi
echo -e "${YELLOW}💡 Open the HTML report in your browser to view the results${NC}"

echo -e "${BLUE}🚀 Opening coverage report...${NC}"
# Check if the HTML file exists before trying to open it
html_file="$CONFIG_OUTPUT_DIR/html/index.html"
if [[ -f "$html_file" ]]; then
    open "$html_file"
    echo -e "${GREEN}✅ Coverage report opened successfully${NC}"
else
    echo -e "${RED}❌ Coverage HTML file not found: $html_file${NC}"
    echo -e "${YELLOW}💡 Please check if the coverage generation completed successfully${NC}"
    exit 1
fi