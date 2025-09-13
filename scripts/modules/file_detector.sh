#!/bin/bash

# File Modification Detection Module
# This module handles the detection of modified Dart files in a package

# Function to detect modified Dart files in the current package
detect_modified_files() {
    local base_branch="$1"
    local package_path="$2"
    
    echo -e "${BLUE}📋 Identifying modified files in current package...${NC}" >&2
    
    local modified_files=""
    local package_rel_path=$(git rev-parse --show-prefix)
    
    # Get modified files in lib/ directory of current package
    # First try committed changes relative to base branch
    modified_files=$(git diff --name-only "$base_branch"...HEAD -- lib/ | grep '\.dart$' | sed "s|^${package_rel_path}||" || true)
    
    if [ -z "$modified_files" ]; then
        # Try from git root with current package path for committed changes
        # Strip the package path prefix to get relative paths from package root
        modified_files=$(git diff --name-only "$base_branch"...HEAD | grep "^${package_rel_path}lib/.*\.dart$" | sed "s|^${package_rel_path}||" || true)
    fi
    
    # If no committed changes, check for uncommitted changes (staged + unstaged)
    if [ -z "$modified_files" ]; then
        echo -e "${YELLOW}No committed changes found. Checking for uncommitted changes...${NC}" >&2
        # Get both staged and unstaged changes, strip package path prefix
        modified_files=$(git status --porcelain | grep "^.M.*${package_rel_path}lib/.*\.dart$" | sed "s|^.M *${package_rel_path}||" || true)
        if [ -n "$modified_files" ]; then
            echo -e "${BLUE}Found uncommitted changes in lib/ directory${NC}" >&2
        fi
    fi
    
    # Output the modified files
    if [ -n "$modified_files" ]; then
        echo "$modified_files"
    else
        echo "" # Ensure we return empty string if no files found
    fi
}

# Function to validate and display modified files
validate_modified_files() {
    local modified_files="$1"
    local base_branch="$2"
    
    if [ -z "$modified_files" ]; then
        echo -e "${YELLOW}⚠️  No modified Dart files found in lib/ directory${NC}"
        echo -e "${YELLOW}   Package: $(pwd)${NC}"
        echo -e "${YELLOW}   Comparing against branch: $base_branch${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Found modified files:${NC}"
    echo "$modified_files" | sed 's/^/   - /'
    echo ""
    return 0
}

# Function to get the count of modified files
get_modified_files_count() {
    local modified_files="$1"
    echo "$modified_files" | wc -l | tr -d ' '
}

# Function to check if package is a melos workspace
is_melos_workspace() {
    if [ -f "pubspec.yaml" ] && grep -q "melos" pubspec.yaml 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to validate package structure
validate_package_structure() {
    local package_path="$1"
    
    if is_melos_workspace; then
        echo -e "${YELLOW}⚠️  Running from melos workspace root. Use the main filtered_coverage.sh script instead.${NC}"
        return 1
    fi
    
    if [ ! -f "pubspec.yaml" ]; then
        echo -e "${RED}❌ No pubspec.yaml found. Make sure you're in a Flutter package directory.${NC}"
        return 1
    fi
    
    return 0
}

# Function to create include patterns for lcov
create_lcov_include_patterns() {
    local modified_files="$1"
    local include_patterns=""
    
    # Process each file on a separate line
    echo "$modified_files" | while IFS= read -r file; do
        if [ -n "$file" ]; then
            # Add patterns to match the file
            include_patterns="$include_patterns --include '*/$file' --include '$file'"
        fi
    done | tr '\n' ' '
    
    # Alternative approach using array to handle newlines properly
    local patterns=""
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            patterns="$patterns --include '*/$file' --include '$file'"
        fi
    done <<< "$modified_files"
    
    echo "$patterns"
}

# Main function to detect and validate modified files
detect_and_validate_files() {
    local base_branch="$1"
    local package_path="$2"
    
    # Validate package structure first
    if ! validate_package_structure "$package_path"; then
        return 1
    fi
    
    # Detect modified files
    local modified_files=$(detect_modified_files "$base_branch" "$package_path")
    
    # Validate and display results
    if ! validate_modified_files "$modified_files" "$base_branch"; then
        return 1
    fi
    
    # Return the modified files
    echo "$modified_files"
    return 0
}

# Main execution when script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "detect_modified_files")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 detect_modified_files <base_branch> [package_path]" >&2
                exit 1
            fi
            detect_modified_files "$2" "${3:-.}"
            ;;
        "detect_and_validate_files")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 detect_and_validate_files <base_branch> [package_path]" >&2
                exit 1
            fi
            detect_and_validate_files "$2" "${3:-.}"
            ;;
        *)
            echo "Usage: $0 {detect_modified_files|detect_and_validate_files} <base_branch> [package_path]" >&2
            exit 1
            ;;
    esac
fi