#!/bin/bash
# Enhanced filtered coverage with Gemini AI insights

set -e

# Configuration
BASE_BRANCH=${1:-"main"}
OUTPUT_DIR=${2:-"coverage/filtered"}
TEMP_DIR="/tmp/filtered_coverage_$$"
GEMINI_CONFIG=".gemini/config.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 AI-Enhanced Filtered Coverage Report Generator${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e "Base branch: ${YELLOW}$BASE_BRANCH${NC}"
echo -e "Output directory: ${YELLOW}$OUTPUT_DIR${NC}"
echo ""

# ... existing coverage generation code ...

# Step 6: Generate AI Insights with Gemini
echo -e "${PURPLE}🤖 Step 6: Generating AI insights with Gemini...${NC}"

generate_gemini_insights() {
    local coverage_file="$1"
    local modified_files="$2"
    
    # Prepare coverage summary
    local coverage_summary=$(lcov --summary "$coverage_file" 2>/dev/null || echo "No coverage data")
    local file_count=$(echo "$modified_files" | wc -l)
    
    # Create analysis prompt
    cat > "$TEMP_DIR/analysis_prompt.txt" << EOF
Analyze this Flutter test coverage data and provide actionable insights:

## Project Context
- Flutter monorepo with multiple apps and packages
- Modified files count: $file_count
- Base branch: $BASE_BRANCH

## Coverage Summary
$coverage_summary

## Modified Files
$modified_files

## Git Context
$(git diff --stat "$BASE_BRANCH"...HEAD | head -10)

## Analysis Request
Provide specific, actionable recommendations in the following format:

### 🎯 Priority Test Areas
- List critical files that need immediate test coverage
- Explain why each is important

### 🧪 Suggested Test Cases
- Provide specific test case names for Flutter/Dart
- Include widget tests, unit tests, and integration tests

### ⚡ Performance Risks
- Identify uncovered code that could impact performance
- Suggest monitoring strategies

### 🏗️ Architecture Insights
- Comment on Flutter patterns detected
- Suggest improvements for testability

### 📊 Quick Wins
- Easy tests to implement for immediate coverage boost
- Estimated time to implement each

Focus on Flutter-specific patterns like widgets, state management, and platform channels.
EOF

    # Call Gemini CLI
    if command -v gemini &> /dev/null; then
        echo -e "${BLUE}   Analyzing with Gemini AI...${NC}"
        gemini -f "$TEMP_DIR/analysis_prompt.txt" > "$OUTPUT_DIR/ai_insights.md" 2>/dev/null || {
            echo -e "${YELLOW}   ⚠️  Gemini analysis failed, generating fallback insights${NC}"
            generate_fallback_insights "$coverage_file" "$modified_files" > "$OUTPUT_DIR/ai_insights.md"
        }
    else
        echo -e "${YELLOW}   ⚠️  Gemini CLI not found, generating rule-based insights${NC}"
        generate_fallback_insights "$coverage_file" "$modified_files" > "$OUTPUT_DIR/ai_insights.md"
    fi
    
    # Generate HTML version of insights
    generate_insights_html "$OUTPUT_DIR/ai_insights.md" "$OUTPUT_DIR/ai_insights.html"
}

# Fallback insights function
generate_fallback_insights() {
    local coverage_file="$1"
    local modified_files="$2"
    
    cat << EOF
# 🤖 Flutter Coverage Analysis

## 🎯 Priority Test Areas

Based on the modified files, here are the critical areas needing test coverage:

EOF

    # Analyze file types
    echo "$modified_files" | while read -r file; do
        if [[ "$file" == *"_bloc.dart" || "$file" == *"_cubit.dart" ]]; then
            echo "- **$file**: State management logic - Test state transitions and side effects"
        elif [[ "$file" == *"_widget.dart" || "$file" == */widgets/* ]]; then
            echo "- **$file**: UI component - Add widget tests for rendering and interactions"
        elif [[ "$file" == *"_service.dart" || "$file" == */services/* ]]; then
            echo "- **$file**: Business logic - Test all public methods and error scenarios"
        elif [[ "$file" == *"_repository.dart" || "$file" == */repositories/* ]]; then
            echo "- **$file**: Data layer - Test CRUD operations and error handling"
        else
            echo "- **$file**: General Dart file - Add unit tests for public methods"
        fi
    done
    
    cat << EOF

## 🧪 Suggested Test Cases

### Widget Tests
\`\`\`dart
testWidgets('should render correctly', (tester) async {
  await tester.pumpWidget(MyWidget());
  expect(find.byType(MyWidget), findsOneWidget);
});
\`\`\`

### BLoC Tests
\`\`\`dart
blocTest<MyBloc, MyState>(
  'emits success when data loads',
  build: () => MyBloc(),
  act: (bloc) => bloc.add(LoadData()),
  expect: () => [Loading(), Success()],
);
\`\`\`

### Unit Tests
\`\`\`dart
test('should return valid result', () {
  final result = myService.processData(testData);
  expect(result, isA<ValidResult>());
});
\`\`\`

## 📊 Quick Wins

1. **Add basic widget tests** (15 min each)
2. **Test error scenarios** (10 min each)
3. **Add golden tests for UI** (20 min each)
4. **Test state management flows** (30 min each)

EOF
}

# Generate HTML insights
generate_insights_html() {
    local markdown_file="$1"
    local html_file="$2"
    
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🤖 AI Coverage Insights</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 40px; line-height: 1.6; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .insight-section { margin: 20px 0; padding: 20px; border-left: 4px solid #007acc; background: #f8f9fa; border-radius: 4px; }
        .priority-high { border-left-color: #dc3545; }
        .priority-medium { border-left-color: #ffc107; }
        .priority-low { border-left-color: #28a745; }
        code { background: #e9ecef; padding: 2px 6px; border-radius: 3px; font-family: 'SF Mono', Monaco, monospace; }
        pre { background: #2d3748; color: #e2e8f0; padding: 15px; border-radius: 6px; overflow-x: auto; }
        .quick-win { background: #d4edda; border: 1px solid #c3e6cb; padding: 10px; margin: 5px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🤖 AI-Powered Coverage Insights</h1>
        <p>Generated on $(date) for branch: $BASE_BRANCH</p>
    </div>
    
    <div id="content">
        <!-- Markdown content will be inserted here -->
    </div>
    
    <script>
        // Simple markdown-to-HTML converter for basic formatting
        fetch('ai_insights.md')
            .then(response => response.text())
            .then(markdown => {
                const html = markdown
                    .replace(/^# (.*$)/gm, '<h1>$1</h1>')
                    .replace(/^## (.*$)/gm, '<h2>$1</h2>')
                    .replace(/^### (.*$)/gm, '<h3>$1</h3>')
                    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                    .replace(/\*(.*?)\*/g, '<em>$1</em>')
                    .replace(/`(.*?)`/g, '<code>$1</code>')
                    .replace(/^- (.*$)/gm, '<li>$1</li>')
                    .replace(/(\n<li>.*<\/li>\n)/gs, '<ul>$1</ul>')
                    .replace(/\n/g, '<br>');
                document.getElementById('content').innerHTML = html;
            });
    </script>
</body>
</html>
EOF
}

# Call the main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # ... existing coverage generation steps 1-5 ...
    
    # Generate AI insights
    generate_gemini_insights "$TEMP_DIR/filtered.info" "$MODIFIED_FILES"
    
    echo ""
    echo -e "${GREEN}🎉 AI-Enhanced coverage report generated!${NC}"
    echo -e "${GREEN}📁 Coverage report: $OUTPUT_DIR/index.html${NC}"
    echo -e "${PURPLE}🤖 AI insights: $OUTPUT_DIR/ai_insights.html${NC}"
    echo ""
fi