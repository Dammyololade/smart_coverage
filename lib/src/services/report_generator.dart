import 'dart:convert';
import 'dart:io';

import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';

/// {@template report_generator}
/// Interface for generating coverage reports
/// {@endtemplate}
abstract class ReportGenerator {
  /// Generate HTML coverage report
  Future<void> generateHtmlReport(
    CoverageData data,
    String outputPath, {
    bool darkMode = true,
  });

  /// Generate JSON coverage report
  Future<void> generateJsonReport(CoverageData data, String outputPath);

  /// Generate filtered LCOV report
  Future<void> generateLcovReport(CoverageData data, String outputPath);

  /// Generate console output
  String generateConsoleOutput(CoverageData data);

  /// Generate all reports based on configuration
  Future<void> generateReports(CoverageData data, SmartCoverageConfig config);

  /// Add navigation buttons to HTML report
  Future<void> addNavigationButtons(String outputDir);
}

/// {@template report_generator_impl}
/// Default implementation of report generator
/// {@endtemplate}
class ReportGeneratorImpl implements ReportGenerator {
  /// {@macro report_generator_impl}
  const ReportGeneratorImpl();

  @override
  Future<void> generateHtmlReport(
    CoverageData data,
    String outputPath, {
    bool darkMode = true,
  }) async {
    // Use standard LCOV genhtml command with custom dark theme
    await _generateLcovHtmlReport(data, outputPath, darkMode);
  }

  @override
  Future<void> generateJsonReport(CoverageData data, String outputPath) async {
    final jsonData = {
      'timestamp': DateTime.now().toIso8601String(),
      'summary': {
        'totalFiles': data.files.length,
        'totalLines': data.summary.linesFound,
        'coveredLines': data.summary.linesHit,
        'linePercentage': data.summary.linePercentage,
        'totalFunctions': data.summary.functionsFound,
        'coveredFunctions': data.summary.functionsHit,
        'functionPercentage': data.summary.functionPercentage,
        'totalBranches': data.summary.branchesFound,
        'coveredBranches': data.summary.branchesHit,
        'branchPercentage': data.summary.branchPercentage,
      },
      'files': data.files
          .map(
            (file) => {
              'sourceFile': file.path,
              'functions':
                  <
                    Map<String, dynamic>
                  >[], // Empty for now as we don't have individual function data
              'branches':
                  <
                    Map<String, dynamic>
                  >[], // Empty for now as we don't have individual branch data
              'lines': file.lines
                  .map(
                    (line) => {
                      'lineNumber': line.lineNumber,
                      'hitCount': line.hitCount,
                      'isCovered': line.isCovered,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonData),
    );
  }

  @override
  Future<void> generateLcovReport(CoverageData data, String outputPath) async {
    final buffer = StringBuffer();

    for (final file in data.files) {
      buffer
        ..writeln('TN:')
        ..writeln('SF:${file.path}');

      // Function coverage (if available)
      if (file.summary.functionsFound > 0) {
        buffer
          ..writeln('FNF:${file.summary.functionsFound}')
          ..writeln('FNH:${file.summary.functionsHit}');
      }

      // Line coverage
      for (final line in file.lines) {
        buffer.writeln('DA:${line.lineNumber},${line.hitCount}');
      }

      buffer
        ..writeln('LF:${file.summary.linesFound}')
        ..writeln('LH:${file.summary.linesHit}')
        // Branch coverage
        ..writeln('BRF:${file.summary.branchesFound}')
        ..writeln('BRH:${file.summary.branchesHit}')
        ..writeln('end_of_record');
    }

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
  }

  @override
  String generateConsoleOutput(CoverageData data) {
    final buffer = StringBuffer();
    final summary = data.summary;

    buffer
      ..writeln('\n📈 Coverage Summary:')
      ..writeln('  Files analyzed: ${data.files.length}')
      ..writeln('  Lines found: ${summary.linesFound}')
      ..writeln('  Lines hit: ${summary.linesHit}')
      ..writeln(
        '  Line coverage: ${summary.linePercentage.toStringAsFixed(1)}%',
      );

    if (summary.functionsFound > 0) {
      buffer.writeln(
        '  Function coverage: ${summary.functionPercentage.toStringAsFixed(1)}%',
      );
    }

    if (summary.branchesFound > 0) {
      buffer.writeln(
        '  Branch coverage: ${summary.branchPercentage.toStringAsFixed(1)}%',
      );
    }

    // Display file-level coverage
    if (data.files.isNotEmpty) {
      buffer.writeln('\n📁 File Coverage:');
      for (final file in data.files.take(10)) {
        // Show top 10 files
        final percentage = file.summary.linePercentage;
        final icon = percentage >= 80
            ? '✅'
            : percentage >= 60
            ? '⚠️'
            : '❌';
        buffer.writeln(
          '  $icon ${file.path}: ${percentage.toStringAsFixed(1)}%',
        );
      }

      if (data.files.length > 10) {
        buffer.writeln('  ... and ${data.files.length - 10} more files');
      }
    }

    return buffer.toString();
  }

  @override
  Future<void> generateReports(
    CoverageData data,
    SmartCoverageConfig config,
  ) async {
    final outputDir = Directory(config.outputDir);
    await outputDir.create(recursive: true);

    for (final format in config.outputFormats) {
      switch (format) {
        case 'html':
          // Generate HTML using standard LCOV genhtml with dark theme
          await _generateLcovHtmlReport(
            data,
            config.outputDir,
            config.darkMode,
          );
        case 'json':
          final jsonPath = '${config.outputDir}/coverage_report.json';
          await generateJsonReport(data, jsonPath);
        case 'lcov':
          final lcovPath = '${config.outputDir}/coverage_report.lcov';
          await generateLcovReport(data, lcovPath);
        case 'console':
          // Console output is handled separately
          break;
      }
    }
  }

  /// Generate HTML report using standard LCOV genhtml command
  Future<void> _generateLcovHtmlReport(
    CoverageData data,
    String outputDir,
    bool darkMode,
  ) async {
    // Prepare output directory
    final outputDirectory = Directory(outputDir);
    await outputDirectory.create(recursive: true);

    // Handle empty coverage data
    if (data.files.isEmpty) {
      const htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>Coverage Report</title>
</head>
<body>
  <h1>Coverage Report</h1>
  <p>No coverage data available</p>
</body>
</html>''';

      final indexFile = File('$outputDir/index.html');
      await indexFile.writeAsString(htmlContent);
      return;
    }

    // First, generate a temporary LCOV file
    final tempDir = Directory.systemTemp.createTempSync('smart_coverage_');
    final tempLcovPath = '${tempDir.path}/temp_coverage.lcov';

    try {
      // Generate LCOV data
      await generateLcovReport(data, tempLcovPath);

      // Get the path to the custom dark theme CSS
      final templatesDir = _findTemplatesDirectory();
      final cssPath = '$templatesDir/custom_dark_theme.css';

      // Build genhtml command
      final args = [
        tempLcovPath,
        '--output-directory',
        outputDir,
        '--title',
        'Smart Coverage Report',
        '--show-details',
        '--legend',
      ];

      // Add custom CSS if dark mode is enabled and CSS file exists
      if (darkMode && File(cssPath).existsSync()) {
        args.addAll(['--css-file', cssPath]);
      }

      args
        ..add('--ignore-errors')
        ..add('deprecated')
        ..add('--ignore-errors')
        ..add('range')
        ..add('--ignore-errors')
        ..add('empty');

      // Execute genhtml command
      final result = await Process.run('genhtml', args);
      if (result.exitCode != 0) {
        throw Exception('genhtml failed: ${result.stderr}');
      }
    } finally {
      // Clean up temporary directory
      await tempDir.delete(recursive: true);
    }
  }

  @override
  Future<void> addNavigationButtons(String outputDir) async {
    await _addNavigationButtons(outputDir);
  }

  /// Add navigation buttons to the main index.html file
  Future<void> _addNavigationButtons(String outputDir) async {
    final indexFile = File('$outputDir/index.html');
    if (!await indexFile.exists()) return;

    final content = await indexFile.readAsString();

    // Check if AI-generated files exist
    final testInsightsExists = await File(
      '$outputDir/test_insights.html',
    ).exists();
    final codeReviewExists = await File('$outputDir/code_review.html').exists();

    // Only proceed if at least one insights file exists
    if (!testInsightsExists && !codeReviewExists) return;

    // Create navigation buttons HTML with center alignment
    final navigationButtons = StringBuffer();
    navigationButtons.writeln(
      '    <div style="margin: 20px auto; padding: 15px; background: var(--bg-secondary, #21262d); border-radius: 8px; border-left: 4px solid var(--accent-color, #58a6ff); max-width: 800px; text-align: center; border: 1px solid var(--border-color, #30363d);">',
    );
    navigationButtons.writeln(
      '      <h3 style="margin: 0 0 15px 0; color: var(--text-primary, #e6edf3);">🤖 AI-Generated Reports</h3>',
    );
    navigationButtons.writeln(
      '      <div style="display: flex; gap: 15px; flex-wrap: wrap; justify-content: center;">',
    );

    if (testInsightsExists) {
      navigationButtons.writeln(
        '<a href="test_insights.html" style="display: inline-block; padding: 12px 20px; background: var(--success-color, #238636); color: var(--button-text, #ffffff); text-decoration: none; border-radius: 6px; font-weight: bold; transition: all 0.3s; border: 1px solid var(--success-border, #2ea043);">📊 Test Insights</a>',
      );
    }

    if (codeReviewExists) {
      navigationButtons.writeln(
        '        <a href="code_review.html" style="display: inline-block; padding: 12px 20px; background: var(--info-color, #0969da); color: var(--button-text, #ffffff); text-decoration: none; border-radius: 6px; font-weight: bold; transition: all 0.3s; border: 1px solid var(--info-border, #0550ae);">🔍 Code Review</a>',
      );
    }

    navigationButtons.writeln('      </div>');
    navigationButtons.writeln('    </div>');

    // Find the insertion point (after the main coverage table)
    final headerEndPattern = RegExp(r'</table>\s*</center>\s*<br>');
    final match = headerEndPattern.firstMatch(content);

    if (match != null) {
      final insertionPoint = match.end;
      final modifiedContent =
          content.substring(0, insertionPoint) +
          '\n' +
          navigationButtons.toString() +
          content.substring(insertionPoint);

      await indexFile.writeAsString(modifiedContent);
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
}
