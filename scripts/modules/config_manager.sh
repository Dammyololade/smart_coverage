#!/bin/bash

# Configuration Management Module
# This module handles script configuration and settings

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Default configuration values
DEFAULT_BASE_BRANCH="main"
DEFAULT_OUTPUT_DIR="coverage/filtered"
DEFAULT_SKIP_TESTS="false"
DEFAULT_AI_INSIGHTS="false"
DEFAULT_DARK_MODE="false"
DEFAULT_CODE_REVIEW="false"

# Function to display usage information
show_usage() {
    cat << EOF
${BLUE}📊 Package Filtered Coverage Tool${NC}

${YELLOW}Usage:${NC}
  $0 [package_path] [base_branch] [options]

${YELLOW}Arguments:${NC}
  package_path    Path to Flutter package (default: current directory)
  base_branch     Git branch to compare against (default: main)

${YELLOW}Options:${NC}
  --ai            Generate AI-powered coverage insights
  --code-review   Generate Gemini code review for changes
  --skip-tests    Skip test execution, use existing coverage data
  --dark-mode     Generate coverage report with dark theme
  --output DIR    Custom output directory (default: coverage/filtered)
  --help, -h      Show this help message

${YELLOW}Examples:${NC}
  $0                           # Analyze current package vs main branch
  $0 . develop                 # Compare against develop branch
  $0 --ai                      # Include AI insights
  $0 --code-review             # Include Gemini code review
  $0 --ai --code-review        # Include both AI insights and code review
  $0 --skip-tests --ai         # Skip tests, generate AI insights
  $0 --output my_coverage      # Custom output directory

${YELLOW}Requirements:${NC}
  - Flutter SDK
  - lcov (for coverage processing)
  - genhtml (for HTML reports)
  - git (for file change detection)
  - Optional: pandoc (for enhanced markdown conversion)
  - Optional: gemini CLI (for AI insights)

${YELLOW}Output:${NC}
  - HTML coverage report: [output_dir]/html/index.html
  - LCOV data file: [output_dir]/filtered_coverage.info
  - AI insights (if enabled): [output_dir]/ai_insights.md
  - AI insights HTML: [output_dir]/html/ai_insights.html
  - Code review (if enabled): [output_dir]/code_review.md
  - Code review HTML: [output_dir]/html/code_review.html
EOF
}

# Function to parse command line arguments
parse_arguments() {
    local package_path="."
    local base_branch="$DEFAULT_BASE_BRANCH"
    local output_dir="$DEFAULT_OUTPUT_DIR"
    local skip_tests="$DEFAULT_SKIP_TESTS"
    local ai_insights="$DEFAULT_AI_INSIGHTS"
    local dark_mode="$DEFAULT_DARK_MODE"
    local code_review="$DEFAULT_CODE_REVIEW"
    local positional_count=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --ai)
                ai_insights="true"
                shift
                ;;
            --code-review)
                code_review="true"
                shift
                ;;
            --skip-tests)
                skip_tests="true"
                shift
                ;;
            --dark-mode)
                dark_mode="true"
                shift
                ;;
            --output)
                if [[ -n $2 && $2 != --* ]]; then
                    output_dir="$2"
                    shift 2
                else
                    echo -e "${RED}❌ --output requires a directory argument${NC}"
                    exit 1
                fi
                ;;
            --*)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                case $positional_count in
                    0)
                        package_path="$1"
                        positional_count=$((positional_count + 1))
                        ;;
                    1)
                        base_branch="$1"
                        positional_count=$((positional_count + 1))
                        ;;
                    *)
                        echo -e "${RED}❌ Too many positional arguments${NC}"
                        show_usage
                        exit 1
                        ;;
                esac
                shift
                ;;
        esac
    done
    
    # Construct output directory with package path
    if [[ "$output_dir" == "$DEFAULT_OUTPUT_DIR" ]]; then
        # Use default path with package path prefix
        if [[ "$package_path" == "." ]]; then
            output_dir="$DEFAULT_OUTPUT_DIR"
        else
            output_dir="$package_path/$DEFAULT_OUTPUT_DIR"
        fi
    elif [[ "$output_dir" != /* ]]; then
        # Relative path - prefix with package path
        if [[ "$package_path" == "." ]]; then
            output_dir="$output_dir"
        else
            output_dir="$package_path/$output_dir"
        fi
    fi
    # Absolute paths are used as-is
    
    # Export configuration
    export CONFIG_PACKAGE_PATH="$package_path"
    export CONFIG_BASE_BRANCH="$base_branch"
    export CONFIG_OUTPUT_DIR="$output_dir"
    export CONFIG_SKIP_TESTS="$skip_tests"
    export CONFIG_AI_INSIGHTS="$ai_insights"
    export CONFIG_DARK_MODE="$dark_mode"
    export CONFIG_CODE_REVIEW="$code_review"
}

# Function to validate configuration
validate_configuration() {
    # Validate package path
    if [[ ! -d "$CONFIG_PACKAGE_PATH" ]]; then
        echo -e "${RED}❌ Package path does not exist: $CONFIG_PACKAGE_PATH${NC}"
        return 1
    fi
    
    # Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        return 1
    fi
    
    # Validate base branch exists
    if ! git show-ref --verify --quiet "refs/heads/$CONFIG_BASE_BRANCH" && 
       ! git show-ref --verify --quiet "refs/remotes/origin/$CONFIG_BASE_BRANCH"; then
        echo -e "${YELLOW}⚠️  Branch '$CONFIG_BASE_BRANCH' not found locally or remotely${NC}"
        echo -e "${YELLOW}   Proceeding anyway - git diff will handle missing refs${NC}"
    fi
    
    return 0
}

# Function to display current configuration
show_configuration() {
    echo -e "${CYAN}🔧 Configuration:${NC}"
    echo "   Package Path: $CONFIG_PACKAGE_PATH"
    echo "   Base Branch: $CONFIG_BASE_BRANCH"
    echo "   Output Directory: $CONFIG_OUTPUT_DIR"
    echo "   Skip Tests: $CONFIG_SKIP_TESTS"
    echo "   AI Insights: $CONFIG_AI_INSIGHTS"
    echo "   Code Review: $CONFIG_CODE_REVIEW"
    echo ""
}

# Function to check required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check required tools
    if ! command -v flutter &> /dev/null; then
        missing_deps+=("flutter")
    fi
    
    if ! command -v lcov &> /dev/null; then
        missing_deps+=("lcov")
    fi
    
    if ! command -v genhtml &> /dev/null; then
        missing_deps+=("genhtml")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${RED}   - $dep${NC}"
        done
        return 1
    fi
    
    # Check optional tools
    local optional_missing=()
    
    if ! command -v pandoc &> /dev/null; then
        optional_missing+=("pandoc (for enhanced markdown conversion)")
    fi
    
    if [[ "$CONFIG_AI_INSIGHTS" == "true" ]] && ! command -v gemini &> /dev/null; then
        optional_missing+=("gemini CLI (for AI insights)")
    fi
    
    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Optional dependencies not found:${NC}"
        for dep in "${optional_missing[@]}"; do
            echo -e "${YELLOW}   - $dep${NC}"
        done
        echo ""
    fi
    
    return 0
}

# Function to get script directory
get_script_directory() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(dirname "$script_dir")"
}

# Function to initialize configuration
init_configuration() {
    local args=("$@")
    
    # Parse arguments
    parse_arguments "${args[@]}"
    
    # Validate configuration
    if ! validate_configuration; then
        return 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Show configuration
    show_configuration
    
    return 0
}