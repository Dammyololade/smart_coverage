#!/bin/bash

# AI Insights Generator Module
# This module handles the generation of AI-powered coverage insights using Gemini

# Function to generate AI insights with Gemini
generate_ai_insights() {
    local output_dir="$1"
    local package_name="$2"
    local modified_files="$3"
    local filtered_info="$4"
    
    echo -e "${PURPLE}🤖 Generating AI insights with Gemini...${NC}"
    
    # Create comprehensive analysis prompt for single package
    cat > "$output_dir/gemini_prompt.txt" << EOF
As a Flutter testing expert, analyze this coverage data for the '$package_name' package:

Coverage Summary:
$(lcov --summary "$filtered_info" 2>/dev/null)

Modified Files in this Package:
$modified_files

Package: $package_name
Project Type: Flutter package/app

Provide:
1. 🎯 Critical missing tests for this package (prioritized)
2. 🧪 Specific test case suggestions with Flutter/Dart code examples
3. ⚡ Performance risk assessment for modified files
4. 🏗️ Package-specific architecture recommendations
5. 📊 Quick wins for coverage improvement in this package
6. 🔍 Code quality insights based on modified files

Format as markdown with emojis and code blocks. Focus specifically on the '$package_name' package.
EOF
    
    # Generate insights with Gemini
    if command -v gemini &> /dev/null; then
        gemini -p "$(cat "$output_dir/gemini_prompt.txt")" > "$output_dir/ai_insights.md" || {
            echo -e "${YELLOW}⚠️  Gemini failed, using fallback insights${NC}"
            generate_fallback_insights "$output_dir" "$package_name" "$modified_files"
        }
    else
        echo -e "${YELLOW}⚠️  Gemini CLI not available. Install with: npm install -g @google/generative-ai${NC}"
        generate_fallback_insights "$output_dir" "$package_name" "$modified_files"
    fi
}

# Function to generate fallback insights when Gemini is not available
generate_fallback_insights() {
    local output_dir="$1"
    local package_name="$2"
    local modified_files="$3"
    
    cat > "$output_dir/ai_insights.md" << EOF
# 🤖 Coverage Analysis for $package_name

## 📊 Summary
- Package: $package_name
- Modified files: $(echo "$modified_files" | wc -l | tr -d ' ')
- Coverage report: See HTML report for detailed metrics

## 🎯 Recommendations
1. Review uncovered lines in the HTML report
2. Add unit tests for new functionality
3. Consider integration tests for complex workflows
4. Ensure edge cases are covered

## 📋 Next Steps
- Open the HTML coverage report to identify specific uncovered lines
- Prioritize testing for business-critical code paths
- Consider adding widget tests for UI components

## 📁 Modified Files
$(echo "$modified_files" | sed 's/^/- /')
EOF
}

# Function to generate HTML version of AI insights
generate_ai_insights_html() {
    local output_dir="$1"
    local script_dir="$2"
    local insights_md="$output_dir/ai_insights.md"
    local insights_html="$output_dir/html/ai_insights.html"
    # Adjust script_dir to point to the parent scripts directory
    local parent_script_dir="$(dirname "$script_dir")"
    local template_file="$parent_script_dir/templates/ai_insights_template.html"
    
    if [ -f "$insights_md" ] && [ -f "$template_file" ]; then
        # Read the template
        local template_content=$(cat "$template_file")
        
        # Convert markdown to HTML
        local html_content
        if command -v pandoc &> /dev/null; then
            # Use pandoc with syntax highlighting for Dart
            html_content=$(pandoc "$insights_md" -f markdown -t html --highlight-style=tango)
        else
            # Use our custom markdown converter
            html_content=$(python3 "$parent_script_dir/utils/markdown_to_html.py" "$insights_md")
        fi
        
        # Replace placeholder with content using a temporary file approach
        local temp_content=$(mktemp)
        echo "$html_content" > "$temp_content"
        
        # Use perl for reliable multiline replacement
        if command -v perl &> /dev/null; then
            echo "$template_content" | perl -pe "s/{{CONTENT}}/$(cat "$temp_content" | sed 's/[\\&\/]/\\&/g')/g" > "$insights_html"
        else
            # Fallback: simple string replacement without the HTML content
            echo "$template_content" | sed 's/{{CONTENT}}/<p>AI insights content could not be processed. Please check ai_insights.md for the raw content.<\/p>/' > "$insights_html"
        fi
        
        rm -f "$temp_content"
        
        echo -e "${GREEN}✨ HTML insights generated: $insights_html${NC}"
    else
        echo -e "${YELLOW}⚠️  Template or markdown file not found${NC}"
        if [ ! -f "$template_file" ]; then
            echo -e "${YELLOW}   Missing: $template_file${NC}"
        fi
        if [ ! -f "$insights_md" ]; then
            echo -e "${YELLOW}   Missing: $insights_md${NC}"
        fi
    fi
}

# Function to add AI insights link to coverage report
add_ai_link_to_coverage_report() {
    local output_dir="$1"
    local coverage_html="$output_dir/html/index.html"
    
    if [ -f "$coverage_html" ]; then
        # Create a temporary file with the AI insights link
        local temp_file=$(mktemp)
        
        # Insert AI insights link before the closing body tag
        awk '/<\/body>/ {
            print "          <table width=\"100%\" border=0 cellspacing=0 cellpadding=0>"
            print "            <tr><td class=\"ruler\"><img src=\"glass.png\" width=3 height=3 alt=\"\"></td></tr>"
            print "            <tr><td class=\"versionInfo\" style=\"text-align: center; padding: 20px;\">"
            print "              <a href=\"ai_insights.html\" style=\"background: white; color: #333; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold; border: 1px solid #ddd;\">🤖 View AI Coverage Insights</a>"
            print "            </td></tr>"
            print "          </table>"
            print "          <br>"
        }
        { print }' "$coverage_html" > "$temp_file"
        
        mv "$temp_file" "$coverage_html"
        echo -e "${GREEN}✨ AI insights link added to coverage report${NC}"
    else
        echo -e "${YELLOW}⚠️  Coverage HTML file not found: $coverage_html${NC}"
    fi
}

# Function to process AI insights (main entry point)
process_ai_insights() {
    local output_dir="$1"
    local package_name="$2"
    local modified_files="$3"
    local filtered_info="$4"
    local script_dir="$5"
    
    # Generate AI insights
    generate_ai_insights "$output_dir" "$package_name" "$modified_files" "$filtered_info"
    
    # Generate HTML version
    generate_ai_insights_html "$output_dir" "$script_dir"
    
    # Add link to coverage report
    add_ai_link_to_coverage_report "$output_dir"
    
    echo -e "${GREEN}✨ AI insights generated: $output_dir/ai_insights.md${NC}"
    echo -e "${BLUE}📖 View insights: cat $output_dir/ai_insights.md${NC}"
}