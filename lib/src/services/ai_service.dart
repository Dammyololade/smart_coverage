import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';

/// AI provider types
enum AiProviderType {
  /// API-based provider
  api,

  /// Local CLI-based provider
  local,
}

/// {@template ai_service}
/// Interface for AI-powered code analysis services
/// {@endtemplate}
abstract class AiService {
  /// Generate code review based on coverage data
  Future<String> generateCodeReview(CoverageData coverage, List<String> files);

  /// Generate insights about coverage patterns
  Future<String> generateInsights(CoverageData coverage);

  /// Generate HTML file for code review
  Future<String> generateCodeReviewHtml(
    CoverageData coverage,
    List<String> files,
    String outputPath,
  );

  /// Generate HTML file for insights
  Future<String> generateInsightsHtml(
    CoverageData coverage,
    String outputPath,
  );

  /// Check if the AI service is available
  Future<bool> isAvailable();

  /// Get the provider type
  AiProviderType get providerType;
}

/// {@template local_ai_service}
/// Interface for local CLI-based AI services
/// {@endtemplate}
abstract class LocalAiService extends AiService {
  @override
  AiProviderType get providerType => AiProviderType.local;

  /// Check if the CLI tool is installed
  Future<bool> isCliInstalled();

  /// Get the CLI tool version
  Future<String> getCliVersion();

  /// Get the CLI command name
  String get cliCommand;
}

/// {@template api_ai_service}
/// Interface for API-based AI services
/// {@endtemplate}
abstract class ApiAiService extends AiService {
  @override
  AiProviderType get providerType => AiProviderType.api;

  /// Check if a valid API key is available
  Future<bool> hasValidApiKey();

  /// Get the API endpoint URL
  String get apiEndpoint;
}

/// {@template ai_service_factory}
/// Factory for creating AI service instances
/// {@endtemplate}
class AiServiceFactory {
  /// Create an AI service based on configuration
  static Future<AiService> create(SmartCoverageConfig config) async {
    final providerType = await _determineProviderType(config);

    switch (config.aiConfig.provider) {
      case 'gemini':
        return providerType == AiProviderType.local
            ? GeminiCliService(config.aiConfig)
            : GeminiApiService(config.aiConfig);
      case 'gemini-cli':
        return GeminiCliService(config.aiConfig);
      default:
        throw UnsupportedError(
          'Provider ${config.aiConfig.provider} not supported',
        );
    }
  }

  static Future<AiProviderType> _determineProviderType(
    SmartCoverageConfig config,
  ) async {
    if (config.aiConfig.providerType == 'local') return AiProviderType.local;
    if (config.aiConfig.providerType == 'api') return AiProviderType.api;

    // Auto-detection logic
    final localService = _createLocalService(config);
    if (await localService.isCliInstalled()) {
      return AiProviderType.local;
    }

    final apiService = _createApiService(config);
    if (await apiService.hasValidApiKey()) {
      return AiProviderType.api;
    }

    throw StateError('No available AI provider found');
  }

  static LocalAiService _createLocalService(SmartCoverageConfig config) {
    switch (config.aiConfig.provider) {
      case 'gemini':
      case 'gemini-cli':
        return GeminiCliService(config.aiConfig);
      default:
        throw UnsupportedError(
          'Local provider ${config.aiConfig.provider} not supported',
        );
    }
  }

  static ApiAiService _createApiService(SmartCoverageConfig config) {
    switch (config.aiConfig.provider) {
      case 'gemini':
        return GeminiApiService(config.aiConfig);
      default:
        throw UnsupportedError(
          'API provider ${config.aiConfig.provider} not supported',
        );
    }
  }
}

/// {@template gemini_cli_service}
/// Gemini CLI-based AI service implementation
/// {@endtemplate}
class GeminiCliService extends LocalAiService {
  /// {@macro gemini_cli_service}
  GeminiCliService(this.config);

  /// AI configuration
  final AiConfig config;

  /// Whether caching is enabled
  bool get _isCacheEnabled => config.cacheEnabled;

  /// Cache directory for storing AI responses
  String get _cacheDir => config.cacheDirectory;

  @override
  String get cliCommand => config.cliCommand;

  @override
  Future<bool> isCliInstalled() async {
    try {
      final result = await Process.run('which', [cliCommand]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getCliVersion() async {
    try {
      final result = await Process.run(cliCommand, ['--version']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Future<String> generateCodeReview(
    CoverageData coverage,
    List<String> files,
  ) async {
    final prompt = _buildCodeReviewPrompt(coverage, files);
    return _executeGeminiCommand(prompt);
  }

  @override
  Future<String> generateInsights(CoverageData coverage) async {
    final prompt = _buildInsightsPrompt(coverage);
    return _executeGeminiCommand(prompt);
  }

  @override
  Future<String> generateCodeReviewHtml(
    CoverageData coverage,
    List<String> files,
    String outputPath,
  ) async {
    // Generate the code review content
    final content = await generateCodeReview(coverage, files);

    // Load and process the template
    final htmlContent = await _generateHtmlFromTemplate(
      'gemini_code_review_template.html',
      'Smart Coverage - AI Code Review',
      content,
      outputPath,
    );

    return htmlContent;
  }

  @override
  Future<String> generateInsightsHtml(
    CoverageData coverage,
    String outputPath,
  ) async {
    // Generate the insights content
    final content = await generateInsights(coverage);

    // Load and process the template
    final htmlContent = await _generateHtmlFromTemplate(
      'test_insights_template.html',
      'Smart Coverage - Test Insights',
      content,
      outputPath,
    );

    return htmlContent;
  }

  /// Generate HTML file from template
  Future<String> _generateHtmlFromTemplate(
    String templatePath,
    String title,
    String content,
    String outputPath,
  ) async {
    try {
      // Get absolute path to template file
      final templatesDir = _findTemplatesDirectory();
      final absoluteTemplatePath = '$templatesDir/$templatePath';
      final templateFile = File(absoluteTemplatePath);
      if (!await templateFile.exists()) {
        throw Exception('Template file not found: $absoluteTemplatePath');
      }

      String template = await templateFile.readAsString();

      // Convert markdown-style content to HTML
      final htmlContent = _convertMarkdownToHtml(content);

      // Generate navigation links
      final navLinks = _generateNavigationLinks(outputPath);

      // Replace placeholders
      template = template.replaceAll('{{TITLE}}', title);
      template = template.replaceAll('{{CONTENT}}', htmlContent);

      // Update navigation links in template
      template = _updateNavigationLinks(template, navLinks);

      // Write the HTML file
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(template);

      return outputPath;
    } catch (e) {
      throw Exception('Failed to generate HTML file: $e');
    }
  }

  /// Find the templates directory relative to the current package
  String _findTemplatesDirectory() {
    // First, try to find the smart_coverage package directory
    // by looking for the directory containing this dart file
    final currentFile = Platform.script.toFilePath();
    var packageDir = Directory(currentFile).parent;

    // Navigate up to find the package root (containing pubspec.yaml)
    while (packageDir.path != packageDir.parent.path) {
      final pubspecFile = File('${packageDir.path}/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        final pubspecContent = pubspecFile.readAsStringSync();
        if (pubspecContent.contains('name: smart_coverage')) {
          final templatesDir = Directory('${packageDir.path}/templates');
          if (templatesDir.existsSync()) {
            return templatesDir.path;
          }
        }
      }
      packageDir = packageDir.parent;
    }

    // Fallback: try to find templates directory from current working directory
    var current = Directory.current;

    // Look for templates directory in current or parent directories
    while (current.path != current.parent.path) {
      final templatesDir = Directory('${current.path}/templates');
      if (templatesDir.existsSync()) {
        return templatesDir.path;
      }
      current = current.parent;
    }

    // Fallback to relative path
    return 'templates';
  }

  /// Generate navigation links based on available files
  String _generateNavigationLinks(String currentFilePath) {
    final outputDir = File(currentFilePath).parent.path;
    final links = <String>[];

    // Always include link to main coverage report
    links.add('<a href="index.html">📊 Coverage Report</a>');

    // Check for test insights file
    final testInsightsFile = File('$outputDir/test_insights.html');
    if (testInsightsFile.existsSync() &&
        !currentFilePath.endsWith('test_insights.html')) {
      links.add('<a href="test_insights.html">📊 Test Insights</a>');
    }

    // Check for code review file
    final codeReviewFile = File('$outputDir/code_review.html');
    if (codeReviewFile.existsSync() &&
        !currentFilePath.endsWith('code_review.html')) {
      links.add('<a href="code_review.html">🔍 Code Review</a>');
    }

    return links.join(' • ');
  }

  /// Update navigation links in template
  String _updateNavigationLinks(String template, String navLinks) {
    // Replace the static navigation links with dynamic ones
    template = template.replaceAll(
      '<a href="index.html">← Back to Coverage Report</a>',
      navLinks,
    );

    // Also update any other navigation sections
    template = template.replaceAll(
      RegExp(r'<a href="[^"]*">← Back to Coverage Report</a>'),
      navLinks,
    );

    return template;
  }

  /// Convert markdown to HTML using the markdown package
  String _convertMarkdownToHtml(String markdown) {
    // Use GitHub Flavored Markdown extension set for better compatibility
    // This includes support for tables, strikethrough, autolinks, and more
    return md.markdownToHtml(
      markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      blockSyntaxes: [
        const md.FencedCodeBlockSyntax(),
        const md.HeaderWithIdSyntax(),
        const md.SetextHeaderWithIdSyntax(),
        const md.TableSyntax(),
      ],
      inlineSyntaxes: [
        md.InlineHtmlSyntax(),
        md.StrikethroughSyntax(),
        md.AutolinkExtensionSyntax(),
        md.EmojiSyntax(),
      ],
    );
  }

  @override
  Future<bool> isAvailable() async {
    return isCliInstalled();
  }

  /// Generate a cache key for the given prompt
  String _generateCacheKey(String prompt) {
    final bytes = utf8.encode(prompt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get cache file path for the given cache key
  String _getCacheFilePath(String cacheKey) {
    return '$_cacheDir/gemini_$cacheKey.json';
  }

  /// Load cached response if available
  Future<String?> _loadCachedResponse(String prompt) async {
    if (!_isCacheEnabled) return null;

    try {
      final cacheKey = _generateCacheKey(prompt);
      final cacheFile = File(_getCacheFilePath(cacheKey));

      if (await cacheFile.exists()) {
        final cacheContent = await cacheFile.readAsString();
        final cacheData = jsonDecode(cacheContent) as Map<String, dynamic>;

        // Check if cache is still valid (optional: add expiration logic here)
        return cacheData['response'] as String?;
      }
    } catch (e) {
      // If cache loading fails, continue with normal execution
      if (config.verbose) {
        print('Warning: Failed to load cached response: $e');
      }
    }

    return null;
  }

  /// Save response to cache
  Future<void> _saveCachedResponse(String prompt, String response) async {
    if (!_isCacheEnabled) return;

    try {
      final cacheKey = _generateCacheKey(prompt);
      final cacheFile = File(_getCacheFilePath(cacheKey));

      // Ensure cache directory exists
      await cacheFile.parent.create(recursive: true);

      final cacheData = {
        'prompt_hash': cacheKey,
        'response': response,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await cacheFile.writeAsString(jsonEncode(cacheData));
    } catch (e) {
      // If cache saving fails, continue with normal execution
      if (config.verbose) {
        print('Warning: Failed to save cached response: $e');
      }
    }
  }

  /// Execute Gemini CLI command with the given prompt
  Future<String> _executeGeminiCommand(String prompt) async {
    // Try to load cached response first
    final cachedResponse = await _loadCachedResponse(prompt);
    if (cachedResponse != null) {
      if (config.verbose) {
        print('Using cached Gemini response');
      }
      return cachedResponse;
    }

    try {
      if (config.verbose) {
        print('Executing Gemini CLI command...');
      }
      final process = await Process.start(
        cliCommand,
        config.cliArgs,
        runInShell: true,
      );

      // Send prompt to stdin
      process.stdin.writeln(prompt);
      await process.stdin.close();

      // Wait for completion with timeout
      final result = await process.exitCode.timeout(
        Duration(seconds: config.cliTimeout),
      );

      if (result == 0) {
        final output = await process.stdout
            .transform(utf8.decoder)
            .join()
            .timeout(Duration(seconds: config.cliTimeout));

        final response = output.trim();

        // Save response to cache
        await _saveCachedResponse(prompt, response);

        return response;
      } else {
        final error = await process.stderr
            .transform(utf8.decoder)
            .join()
            .timeout(Duration(seconds: config.cliTimeout));
        throw Exception('Gemini CLI failed: $error');
      }
    } catch (e) {
      throw Exception('Failed to execute Gemini CLI: $e');
    }
  }

  /// Build prompt for code review generation
  String _buildCodeReviewPrompt(CoverageData coverage, List<String> files) {
    final buffer = StringBuffer();

    // Enhanced prompt for standardized, actionable feedback
    buffer.writeln(
      'You are an expert code reviewer. Analyze the provided codebase and generate a comprehensive, actionable code review report.',
    );
    buffer.writeln();

    buffer.writeln('## Project Context');
    buffer.writeln('- **Total Lines of Code:** ${coverage.summary.linesFound}');
    buffer.writeln('- **Files Analyzed:** ${coverage.files.length}');
    buffer.writeln(
      '- **Coverage:** ${coverage.summary.linePercentage.toStringAsFixed(1)}%',
    );
    buffer.writeln();

    if (files.isNotEmpty) {
      buffer.writeln('## Files Under Review');
      for (final file in files) {
        buffer.writeln('- `$file`');
      }
      buffer.writeln();
    }

    buffer.writeln('## Review Guidelines');
    buffer.writeln(
      'Please structure your analysis using the following format with HTML-compatible sections:',
    );
    buffer.writeln();

    buffer.writeln('### 🔍 **Code Quality Assessment**');
    buffer.writeln('- **Readability:** Rate and provide specific improvements');
    buffer.writeln(
      '- **Maintainability:** Identify complex areas needing simplification',
    );
    buffer.writeln('- **Structure:** Evaluate organization and modularity');
    buffer.writeln();

    buffer.writeln('### 🏗️ **Architecture & Design Patterns**');
    buffer.writeln(
      '- **Design Patterns:** Identify used patterns and suggest improvements',
    );
    buffer.writeln('- **SOLID Principles:** Evaluate adherence and violations');
    buffer.writeln(
      '- **Separation of Concerns:** Assess component responsibilities',
    );
    buffer.writeln();

    buffer.writeln('### ⚡ **Performance Considerations**');
    buffer.writeln(
      '- **Optimization Opportunities:** Specific code sections to improve',
    );
    buffer.writeln('- **Resource Usage:** Memory and CPU efficiency concerns');
    buffer.writeln(
      '- **Algorithmic Complexity:** Big O analysis where relevant',
    );
    buffer.writeln();

    buffer.writeln('### 🔒 **Security Analysis**');
    buffer.writeln('- **Vulnerabilities:** Identify potential security issues');
    buffer.writeln('- **Input Validation:** Check for proper sanitization');
    buffer.writeln('- **Error Handling:** Evaluate exception management');
    buffer.writeln();

    buffer.writeln('### 📋 **Best Practices & Standards**');
    buffer.writeln(
      '- **Coding Standards:** Dart/Flutter conventions adherence',
    );
    buffer.writeln(
      '- **Naming Conventions:** Variable, function, and class names',
    );
    buffer.writeln('- **Code Comments:** Documentation quality and coverage');
    buffer.writeln();

    buffer.writeln('### 🔧 **Refactoring Opportunities**');
    buffer.writeln('- **Technical Debt:** Prioritized list of improvements');
    buffer.writeln(
      '- **Code Duplication:** Identify and suggest consolidation',
    );
    buffer.writeln('- **Dead Code:** Unused variables, functions, or imports');
    buffer.writeln();

    buffer.writeln('## Output Format Requirements');
    buffer.writeln(
      '1. **Use HTML-compatible markdown** for proper rendering in the styled template',
    );
    buffer.writeln(
      '2. **Include code snippets** with proper syntax highlighting using ```dart blocks',
    );
    buffer.writeln(
      '3. **Use proper indentation** (2 spaces for Dart) to mirror code editor appearance',
    );
    buffer.writeln(
      '4. **Provide specific line references** when possible (e.g., "Line 45 in user_service.dart")',
    );
    buffer.writeln(
      '5. **Use severity levels**: 🔴 Critical, 🟡 Warning, 🔵 Suggestion, ✅ Good Practice',
    );
    buffer.writeln(
      '6. **Include actionable recommendations** with before/after code examples',
    );
    buffer.writeln('7. **Prioritize issues** by impact and effort required');
    buffer.writeln(
      '8. **Use enhanced code formatting** with proper syntax highlighting colors',
    );
    buffer.writeln();

    buffer.writeln('## Code Example Format');
    buffer.writeln(
      'When showing code improvements, use this enhanced structure for better visual presentation:',
    );
    buffer.writeln();
    buffer.writeln('<div class="code-comparison">');
    buffer.writeln('<div class="code-before">');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln('// Current implementation with proper indentation');
    buffer.writeln('// Use 2-space indentation for Dart code');
    buffer.writeln('// Include meaningful variable names and comments');
    buffer.writeln('class ExampleClass {');
    buffer.writeln('  void problematicMethod() {');
    buffer.writeln('    // Show the actual problematic code here');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('</div>');
    buffer.writeln('<div class="code-after">');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln('// Improved implementation with proper indentation');
    buffer.writeln('// Use 2-space indentation for Dart code');
    buffer.writeln('// Include meaningful variable names and comments');
    buffer.writeln('class ExampleClass {');
    buffer.writeln('  void improvedMethod() {');
    buffer.writeln('    // Show the improved code here');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('</div>');
    buffer.writeln('</div>');
    buffer.writeln();
    buffer.writeln(
      '**💡 Benefits:** Explain why this change improves the code quality, performance, or maintainability',
    );
    buffer.writeln();

    buffer.writeln('## Code Formatting Best Practices');
    buffer.writeln(
      '- **Indentation:** Use exactly 2 spaces for each level of nesting',
    );
    buffer.writeln(
      '- **Line Length:** Keep lines under 80 characters when possible',
    );
    buffer.writeln(
      '- **Naming:** Use camelCase for variables/methods, PascalCase for classes',
    );
    buffer.writeln(
      '- **Comments:** Include meaningful comments explaining complex logic',
    );
    buffer.writeln('- **Imports:** Group and organize imports properly');
    buffer.writeln(
      '- **Spacing:** Use consistent spacing around operators and after commas',
    );
    buffer.writeln();

    buffer.writeln(
      'Focus on implementation details and avoid test-related analysis. Provide concrete, actionable feedback that developers can immediately implement with properly formatted, editor-like code examples.',
    );

    return buffer.toString();
  }

  /// Build prompt for insights generation
  String _buildInsightsPrompt(CoverageData coverage) {
    final buffer = StringBuffer();

    // Enhanced prompt for comprehensive test insights
    buffer.writeln(
      'You are a testing expert and coverage analyst. Analyze the provided coverage data and generate actionable insights for improving test coverage and quality.',
    );
    buffer.writeln();

    buffer.writeln('## Coverage Overview');
    buffer.writeln('- **Total Lines:** ${coverage.summary.linesFound}');
    buffer.writeln('- **Covered Lines:** ${coverage.summary.linesHit}');
    buffer.writeln(
      '- **Uncovered Lines:** ${coverage.summary.linesFound - coverage.summary.linesHit}',
    );
    buffer.writeln(
      '- **Coverage Percentage:** ${coverage.summary.linePercentage.toStringAsFixed(2)}%',
    );
    buffer.writeln();

    if (coverage.files.isNotEmpty) {
      buffer.writeln('## File-by-File Coverage Analysis');

      // Sort files by coverage percentage for better insights
      final sortedFiles = coverage.files.toList()
        ..sort(
          (a, b) =>
              a.summary.linePercentage.compareTo(b.summary.linePercentage),
        );

      buffer.writeln('### 📊 **Coverage Distribution**');
      for (final file in sortedFiles) {
        final percentage = file.summary.linePercentage.toStringAsFixed(1);
        final coverageStatus = file.summary.linePercentage >= 80
            ? '✅'
            : file.summary.linePercentage >= 60
            ? '🟡'
            : '🔴';
        buffer.writeln(
          '- $coverageStatus `${file.path}`: **$percentage%** (${file.summary.linesHit}/${file.summary.linesFound})',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('## Analysis Framework');
    buffer.writeln(
      'Please provide a comprehensive analysis using the following structured format with enhanced visual presentation:',
    );
    buffer.writeln();

    buffer.writeln('### 🎯 **Coverage Assessment**');
    buffer.writeln(
      '- **Overall Health:** Rate the current coverage state (Excellent/Good/Fair/Poor)',
    );
    buffer.writeln(
      '- **Coverage Trends:** Identify patterns in well-covered vs poorly-covered files',
    );
    buffer.writeln(
      '- **Critical Gaps:** Highlight files with <50% coverage that need immediate attention',
    );
    buffer.writeln(
      '- **Coverage Distribution:** Analyze if coverage is evenly distributed or concentrated',
    );
    buffer.writeln();

    buffer.writeln('### 📈 **Pattern Analysis**');
    buffer.writeln(
      '- **High Coverage Files:** What makes these files well-tested?',
    );
    buffer.writeln(
      '- **Low Coverage Files:** Common characteristics of under-tested files',
    );
    buffer.writeln(
      '- **File Type Patterns:** Coverage differences between services, models, utilities, etc.',
    );
    buffer.writeln(
      '- **Complexity Correlation:** Relationship between file complexity and coverage',
    );
    buffer.writeln();

    buffer.writeln('### 🎯 **Priority Recommendations**');
    buffer.writeln('Provide actionable recommendations in priority order:');
    buffer.writeln();
    buffer.writeln('#### 🔴 **High Priority (Immediate Action)**');
    buffer.writeln('- Files with <30% coverage requiring urgent attention');
    buffer.writeln('- Critical business logic that lacks proper testing');
    buffer.writeln('- Security-sensitive code with insufficient coverage');
    buffer.writeln();
    buffer.writeln('#### 🟡 **Medium Priority (Next Sprint)**');
    buffer.writeln('- Files with 30-60% coverage that need improvement');
    buffer.writeln('- Edge cases and error handling scenarios');
    buffer.writeln('- Integration points between components');
    buffer.writeln();
    buffer.writeln('#### 🔵 **Low Priority (Future Improvement)**');
    buffer.writeln('- Files with 60-80% coverage for optimization');
    buffer.writeln('- Performance testing and stress scenarios');
    buffer.writeln('- Documentation and example improvements');
    buffer.writeln();

    buffer.writeln('### 🧪 **Testing Strategy Recommendations**');
    buffer.writeln(
      '- **Unit Tests:** Specific areas needing more unit test coverage',
    );
    buffer.writeln(
      '- **Integration Tests:** Components requiring integration testing',
    );
    buffer.writeln(
      '- **Edge Cases:** Uncommon scenarios that should be tested',
    );
    buffer.writeln('- **Error Handling:** Exception paths that need coverage');
    buffer.writeln(
      '- **Mocking Strategy:** Dependencies that should be mocked for better testing',
    );
    buffer.writeln();

    buffer.writeln('### 📋 **Actionable Next Steps**');
    buffer.writeln('Provide specific, implementable actions:');
    buffer.writeln();
    buffer.writeln('1. **Immediate Actions (This Week)**');
    buffer.writeln('   - List 3-5 specific files to focus on first');
    buffer.writeln('   - Suggested test cases for each priority file');
    buffer.writeln();
    buffer.writeln('2. **Short-term Goals (Next 2 Weeks)**');
    buffer.writeln('   - Target coverage percentage for the project');
    buffer.writeln('   - Specific testing patterns to implement');
    buffer.writeln();
    buffer.writeln('3. **Long-term Strategy (Next Month)**');
    buffer.writeln('   - Overall testing architecture improvements');
    buffer.writeln('   - Continuous integration testing enhancements');
    buffer.writeln();

    buffer.writeln('### 🎖️ **Quality Metrics & Goals**');
    buffer.writeln(
      '- **Current Quality Score:** Based on coverage distribution and patterns',
    );
    buffer.writeln(
      '- **Recommended Target:** Realistic coverage goals for this project',
    );
    buffer.writeln(
      '- **Success Metrics:** How to measure testing improvement progress',
    );
    buffer.writeln(
      '- **Maintenance Strategy:** Keeping coverage high as code evolves',
    );
    buffer.writeln();

    buffer.writeln('## Output Format Requirements');
    buffer.writeln(
      '1. **Use HTML-compatible markdown** with proper headings and enhanced formatting',
    );
    buffer.writeln(
      '2. **Include specific file references** with backticks for code files',
    );
    buffer.writeln(
      '3. **Use visual indicators**: ✅ Good, 🟡 Needs Attention, 🔴 Critical',
    );
    buffer.writeln(
      '4. **Provide concrete examples** of test cases to write with proper Dart formatting',
    );
    buffer.writeln('5. **Include coverage targets** with realistic timelines');
    buffer.writeln(
      '6. **Focus on actionable insights** rather than general observations',
    );
    buffer.writeln(
      '7. **Use enhanced code formatting** when showing test examples:',
    );
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln(
      '// Example test structure with proper indentation (2 spaces)',
    );
    buffer.writeln('void main() {');
    buffer.writeln('  group(\'ClassName Tests\', () {');
    buffer.writeln('    test(\'should handle normal case\', () {');
    buffer.writeln('      // Arrange');
    buffer.writeln('      final instance = ClassName();');
    buffer.writeln('      ');
    buffer.writeln('      // Act');
    buffer.writeln('      final result = instance.method();');
    buffer.writeln('      ');
    buffer.writeln('      // Assert');
    buffer.writeln('      expect(result, expectedValue);');
    buffer.writeln('    });');
    buffer.writeln('  });');
    buffer.writeln('}');
    buffer.writeln('```');
    buffer.writeln();

    buffer.writeln(
      'Generate insights that help developers understand not just what to test, but how to prioritize their testing efforts for maximum impact on code quality and reliability. Use the enhanced styling and formatting to create visually appealing, editor-like code examples.',
    );

    return buffer.toString();
  }
}

/// {@template gemini_api_service}
/// Gemini API-based AI service implementation
/// {@endtemplate}
class GeminiApiService extends ApiAiService {
  /// {@macro gemini_api_service}
  GeminiApiService(this.config);

  /// AI configuration
  final AiConfig config;

  @override
  String get apiEndpoint =>
      config.apiEndpoint ?? 'https://generativelanguage.googleapis.com';

  @override
  Future<bool> hasValidApiKey() async {
    throw UnimplementedError('API key validation not yet implemented');
  }

  @override
  Future<String> generateCodeReview(
    CoverageData coverage,
    List<String> files,
  ) async {
    throw UnimplementedError('API code review generation not yet implemented');
  }

  @override
  Future<String> generateInsights(CoverageData coverage) async {
    throw UnimplementedError('API insights generation not yet implemented');
  }

  @override
  Future<String> generateCodeReviewHtml(
    CoverageData coverage,
    List<String> files,
    String outputPath,
  ) async {
    throw UnimplementedError('API service HTML generation not implemented');
  }

  @override
  Future<String> generateInsightsHtml(
    CoverageData coverage,
    String outputPath,
  ) async {
    throw UnimplementedError('API service HTML generation not implemented');
  }

  @override
  Future<bool> isAvailable() async {
    return hasValidApiKey();
  }
}
