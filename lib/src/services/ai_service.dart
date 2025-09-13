import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      'ai_insights_template.html',
      'Smart Coverage - AI Insights',
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

    // Check for AI insights file
    final aiInsightsFile = File('$outputDir/ai_insights.html');
    if (aiInsightsFile.existsSync() &&
        !currentFilePath.endsWith('ai_insights.html')) {
      links.add('<a href="ai_insights.html">🤖 AI Insights</a>');
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

  /// Convert basic markdown to HTML
  String _convertMarkdownToHtml(String markdown) {
    String html = markdown;

    // Convert headers
    html = html.replaceAllMapped(
      RegExp(r'^### (.+)$', multiLine: true),
      (match) => '<h3>${match.group(1)}</h3>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^## (.+)$', multiLine: true),
      (match) => '<h2>${match.group(1)}</h2>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^# (.+)$', multiLine: true),
      (match) => '<h1>${match.group(1)}</h1>',
    );

    // Convert code blocks
    html = html.replaceAllMapped(
      RegExp(r'```(\w+)?\n([\s\S]*?)\n```'),
      (match) {
        final language = match.group(1) ?? '';
        final code = match.group(2) ?? '';
        return '<pre><code class="language-$language">$code</code></pre>';
      },
    );

    // Convert inline code
    html = html.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => '<code>${match.group(1)}</code>',
    );

    // Convert bold text
    html = html.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );

    // Convert bullet points
    html = html.replaceAllMapped(
      RegExp(r'^- (.+)$', multiLine: true),
      (match) => '<li>${match.group(1)}</li>',
    );

    // Wrap consecutive list items in ul tags
    html = html.replaceAllMapped(
      RegExp(r'(<li>.*</li>\s*)+', multiLine: true),
      (match) => '<ul>${match.group(0)}</ul>',
    );

    // Convert line breaks to paragraphs
    final lines = html.split('\n');
    final paragraphs = <String>[];
    String currentParagraph = '';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (currentParagraph.isNotEmpty) {
          paragraphs.add('<p>$currentParagraph</p>');
          currentParagraph = '';
        }
      } else if (!trimmed.startsWith('<')) {
        if (currentParagraph.isNotEmpty) currentParagraph += ' ';
        currentParagraph += trimmed;
      } else {
        if (currentParagraph.isNotEmpty) {
          paragraphs.add('<p>$currentParagraph</p>');
          currentParagraph = '';
        }
        paragraphs.add(trimmed);
      }
    }

    if (currentParagraph.isNotEmpty) {
      paragraphs.add('<p>$currentParagraph</p>');
    }

    return paragraphs.join('\n');
  }

  @override
  Future<bool> isAvailable() async {
    return isCliInstalled();
  }

  /// Execute Gemini CLI command with the given prompt
  Future<String> _executeGeminiCommand(String prompt) async {
    try {
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
        return output.trim();
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
    buffer.writeln(
      'Please provide a comprehensive code review focusing on implementation details and code quality:',
    );
    buffer.writeln();
    buffer.writeln('Project Overview:');
    buffer.writeln('- Total Lines of Code: ${coverage.summary.linesFound}');
    buffer.writeln('- Files Analyzed: ${coverage.files.length}');
    buffer.writeln();

    if (files.isNotEmpty) {
      buffer.writeln('Files to Review:');
      for (final file in files) {
        buffer.writeln('- $file');
      }
      buffer.writeln();
    }

    buffer.writeln('Please analyze the codebase implementation and provide:');
    buffer.writeln(
      '1. Code quality assessment (readability, maintainability, structure)',
    );
    buffer.writeln('2. Architecture and design patterns evaluation');
    buffer.writeln('3. Performance considerations and potential optimizations');
    buffer.writeln('4. Security vulnerabilities or concerns');
    buffer.writeln('5. Best practices adherence and coding standards');
    buffer.writeln('6. Refactoring opportunities and technical debt');
    buffer.writeln('7. Documentation and code comments quality');
    buffer.writeln();
    buffer.writeln(
      'Focus on implementation details, avoid test-related analysis as that is covered separately.',
    );

    return buffer.toString();
  }

  /// Build prompt for insights generation
  String _buildInsightsPrompt(CoverageData coverage) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Please analyze the following code coverage data and provide insights:',
    );
    buffer.writeln();
    buffer.writeln('Coverage Statistics:');
    buffer.writeln('- Total Lines: ${coverage.summary.linesFound}');
    buffer.writeln('- Covered Lines: ${coverage.summary.linesHit}');
    buffer.writeln(
      '- Uncovered Lines: ${coverage.summary.linesFound - coverage.summary.linesHit}',
    );
    buffer.writeln(
      '- Coverage Percentage: ${coverage.summary.linePercentage.toStringAsFixed(2)}%',
    );
    buffer.writeln();

    if (coverage.files.isNotEmpty) {
      buffer.writeln('File Coverage Details:');
      for (final file in coverage.files) {
        buffer.writeln(
          '- ${file.path}: ${file.summary.linePercentage.toStringAsFixed(1)}% (${file.summary.linesHit}/${file.summary.linesFound})',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('Please provide:');
    buffer.writeln('1. Key insights about the current coverage state');
    buffer.writeln('2. Patterns or trends you notice');
    buffer.writeln('3. Actionable recommendations for improvement');
    buffer.writeln('4. Priority areas for testing focus');

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
