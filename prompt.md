# SMART COVERAGE CLI

## Project Overview
Develop a Dart CLI package called `smart_coverage` that converts our existing bash-based coverage analysis solution into a modern, maintainable, and extensible tool.

## Essential Context Files to Copy

Before starting development, copy these critical files to understand the current implementation:

### Core Scripts
- `/scripts/package_filtered_coverage.sh` - Main coverage workflow orchestrator
- `/scripts/modules/file_detector.sh` - Git diff analysis and file filtering logic
- `/scripts/modules/config_manager.sh` - Configuration management utilities

### Templates & Assets
- `/scripts/templates/` - Complete folder containing:
  - `ai_insights_template.html` - AI analysis report template
  - `code_review_template.md` - Code review output format
  - Any other template files for output formatting

### Utilities
- `/scripts/utils/markdown_to_html.py` - Markdown processing utility
- Any other utility scripts in the utils folder

### Configuration Examples
- `.gemini/config.yaml` - AI service configuration
- `.gemini/styleguide.md` - Code review style guidelines

## Success Metrics & Performance Targets

### Performance Requirements
- **LCOV parsing**: Process 10MB+ files in <2 seconds
- **File filtering**: Handle 1000+ files in <500ms
- **Memory efficiency**: <100MB peak usage for typical projects
- **Startup time**: CLI ready in <200ms

### Quality Targets
- **Test coverage**: >90% for core functionality
- **Error handling**: Graceful failures with actionable messages
- **Documentation**: Complete API docs + usage examples
- **Cross-platform**: Support macOS, Linux, Windows

## Key Learnings from Current Implementation

### What Works Well
1. **Modular architecture** - Separate concerns (file detection, coverage parsing, AI integration)
2. **Flexible AI integration** - Support multiple providers (Gemini, fallback options)
3. **Rich output formats** - HTML reports, markdown summaries, console output
4. **Git integration** - Smart diff analysis for targeted coverage
5. **Template-based reporting** - Customizable output formats

### Pain Points to Address
1. **Shell script limitations** - Error handling, maintainability, testing
2. **Dependency management** - External tool requirements (jq, curl, etc.)
3. **Performance bottlenecks** - Sequential processing, large file handling
4. **Configuration complexity** - Multiple config files, environment variables

## Core Features to Implement

### 1. LCOV Processing Engine
```dart
abstract class LcovParser {
  Future<CoverageData> parse(String lcovContent);
  Future<CoverageData> parseFile(String filePath);
}
```

### 2. File Comparison & Filtering
```dart
abstract class FileDetector {
  Future<List<String>> detectModifiedFiles(String baseBranch);
  Future<List<String>> generateIncludePatterns(List<String> files);
}
```

### 3. AI Service Integration
```dart
abstract class AiService {
  Future<String> generateCodeReview(CoverageData coverage, List<String> files);
  Future<String> generateInsights(CoverageData coverage);
}
```

### 4. Report Generation
```dart
abstract class ReportGenerator {
  Future<void> generateHtmlReport(CoverageData data, String outputPath);
  Future<void> generateMarkdownSummary(CoverageData data, String outputPath);
}
```

## Implementation Phases

### Phase 1: Core Infrastructure
- Project setup with proper Dart package structure
- CLI argument parsing and command structure
- LCOV parsing engine with performance optimization
- File system utilities and Git integration

### Phase 2: Feature Parity
- File detection and filtering logic
- Basic coverage analysis and reporting
- Template-based output generation
- Configuration management system

### Phase 3: AI Integration
- AI service abstraction layer
- Gemini API integration
- Fallback mechanisms and error handling
- Code review generation

### Phase 4: Enhancement & Polish
- Performance optimization and parallel processing
- Comprehensive testing suite
- Documentation and examples
- Cross-platform validation

## Technical Requirements

### Dependencies
- `args` - CLI argument parsing
- `path` - Cross-platform file handling
- `yaml` - Configuration management
- `test` - Testing framework
- `coverage` - Coverage analysis tools

### Architecture Principles
- **Dependency injection** - Testable, modular components
- **Interface segregation** - Small, focused abstractions
- **Error boundaries** - Graceful failure handling
- **Configuration-driven** - Flexible, environment-aware behavior

## CLI Interface Design

```bash
# Basic usage
smart_coverage analyze <package_path> [options]

# Advanced usage
smart_coverage analyze apps/heartbeat_app \
  --base-branch=main \
  --ai-provider=gemini \
  --output-format=html,markdown \
  --include-patterns=lib/**/*.dart

## Success Criteria

### Functional
- [ ] Parse LCOV files accurately and efficiently
- [ ] Detect modified files using Git diff analysis
- [ ] Generate filtered coverage reports
- [ ] Integrate with AI services for code review
- [ ] Produce HTML and markdown outputs
- [ ] Handle errors gracefully with helpful messages

### Non-Functional
- [ ] Meet all performance targets
- [ ] Achieve >90% test coverage
- [ ] Support all major platforms
- [ ] Maintain backward compatibility with current workflow
- [ ] Provide comprehensive documentation

## Getting Started

1. **Read essential files** listed above to understand current implementation
2. **Analyze the bash scripts** to extract core logic and workflows
3. **Set up Dart package structure** with proper organization
4. **Implement core abstractions** before diving into specific features
5. **Start with LCOV parsing** as the foundation for all other features
6. **Test incrementally** with real coverage data from the mobile-apps project