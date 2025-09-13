import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/services.dart';

/// {@template analyze_command}
/// `smart_coverage analyze` command for analyzing coverage data
/// {@endtemplate}
class AnalyzeCommand extends Command<int> {
  /// {@macro analyze_command}
  AnalyzeCommand({
    required Logger logger,
    ConfigService? configService,
    CoverageProcessor? coverageProcessor,
    ReportGenerator? reportGenerator,
  }) : _logger = logger,
       _configService = configService ?? const ConfigServiceImpl(),
       _coverageProcessor = coverageProcessor ?? const CoverageProcessorImpl(
         fileDetector: FileDetectorImpl(),
         lcovParser: LcovParserImpl(),
       ),
       _reportGenerator = reportGenerator ?? const ReportGeneratorImpl() {
    argParser
      ..addOption(
        'package-path',
        abbr: 'p',
        help: 'Path to the Flutter/Dart package to analyze.',
        defaultsTo: '.',
      )
      ..addOption(
        'base-branch',
        abbr: 'b',
        help: 'Base branch to compare against for detecting modified files.',
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help: 'Output directory for generated reports.',
        defaultsTo: 'coverage_reports',
      )
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to configuration file.',
      )
      ..addOption(
        'lcov-file',
        abbr: 'l',
        help: 'Path to LCOV coverage file.',
        defaultsTo: 'coverage/lcov.info',
      )
      ..addFlag(
        'skip-tests',
        help: 'Skip running tests and use existing coverage data.',
        negatable: false,
      )
      ..addFlag(
        'ai',
        help: 'Enable AI-powered insights generation.',
        negatable: false,
      )
      ..addFlag(
        'code-review',
        help: 'Generate AI-powered code review.',
        negatable: false,
      )
      ..addFlag(
        'dark-mode',
        help: 'Use dark theme for HTML reports.',
        defaultsTo: true,
      )
      ..addMultiOption(
        'output-formats',
        help: 'Output formats to generate.',
        allowed: ['console', 'html', 'json', 'lcov'],
        defaultsTo: ['console'],
      );
  }

  @override
  String get description => 'Analyze coverage data for modified files with optional AI insights.';

  @override
  String get name => 'analyze';

  final Logger _logger;
  final ConfigService _configService;
  final CoverageProcessor _coverageProcessor;
  final ReportGenerator _reportGenerator;

  @override
  Future<int> run() async {
    _logger.info('🔍 Starting coverage analysis...');

    try {
      // 1. Load and validate configuration
      final config = await _loadConfiguration();
      final validationErrors = await _configService.validateConfig(config);
      
      if (validationErrors.isNotEmpty) {
        _logger.err('❌ Configuration validation failed:');
        for (final error in validationErrors) {
          _logger.err('  • $error');
        }
        return ExitCode.config.code;
      }

      _logger.detail('Package path: ${config.packagePath}');
      _logger.detail('Base branch: ${config.baseBranch ?? "all files"}');
      _logger.detail('Output directory: ${config.outputDir}');
      _logger.detail('Skip tests: ${config.skipTests}');
      _logger.detail('AI insights: ${config.aiInsights}');
      _logger.detail('Code review: ${config.codeReview}');
      _logger.detail('Output formats: ${config.outputFormats.join(", ")}');

      // 2. Run tests if not skipped
      final lcovFile = argResults!['lcov-file'] as String;
      if (!config.skipTests) {
        await _runTests(config.packagePath, lcovFile);
      }

      // 3. Process coverage data
      final coverageData = await _coverageProcessor.processCoverageWithConfig(
        lcovPath: lcovFile,
        config: config,
      );

      // 4. Generate reports
      await _reportGenerator.generateReports(coverageData, config);

      // 5. Display summary (console output)
      if (config.outputFormats.contains('console')) {
        final consoleOutput = _reportGenerator.generateConsoleOutput(coverageData);
        _logger.info(consoleOutput);
      }

      // 6. Auto-open HTML report if generated
      await _autoOpenReport(config);

      _logger.success('✅ Coverage analysis completed successfully!');
      return ExitCode.success.code;
    } catch (error) {
      _logger.err('❌ Coverage analysis failed: $error');
      return ExitCode.software.code;
    }
  }

  /// Load configuration from multiple sources
  Future<SmartCoverageConfig> _loadConfiguration() async {
    final cliArgs = <String, dynamic>{};
    
    // Extract CLI arguments
    if (argResults!.wasParsed('package-path')) {
      cliArgs['packagePath'] = argResults!['package-path'];
    }
    if (argResults!.wasParsed('base-branch')) {
      cliArgs['baseBranch'] = argResults!['base-branch'];
    }
    if (argResults!.wasParsed('output-dir')) {
      cliArgs['outputDir'] = argResults!['output-dir'];
    }
    if (argResults!.wasParsed('skip-tests')) {
      cliArgs['skipTests'] = argResults!['skip-tests'];
    }
    if (argResults!.wasParsed('ai')) {
      cliArgs['aiInsights'] = argResults!['ai'];
    }
    if (argResults!.wasParsed('code-review')) {
      cliArgs['codeReview'] = argResults!['code-review'];
    }
    if (argResults!.wasParsed('dark-mode')) {
      cliArgs['darkMode'] = argResults!['dark-mode'];
    }
    if (argResults!.wasParsed('output-formats')) {
      cliArgs['outputFormats'] = argResults!['output-formats'];
    }

    return _configService.loadConfig(
      cliArgs: cliArgs,
      configFilePath: argResults!['config'] as String?,
    );
  }

  /// Run tests to generate coverage data
  Future<void> _runTests(String packagePath, String lcovFile) async {
    _logger.info('🧪 Running tests to generate coverage data...');
    
    try {
      // Ensure coverage directory exists
      final coverageDir = Directory(path.dirname(lcovFile));
      if (!await coverageDir.exists()) {
        await coverageDir.create(recursive: true);
      }
      
      // Detect if this is a Flutter project
      final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
      var isFlutterProject = false;
      
      if (await pubspecFile.exists()) {
        final pubspecContent = await pubspecFile.readAsString();
        isFlutterProject = pubspecContent.contains('flutter:') || 
                          pubspecContent.contains('flutter_test:');
      }
      
      // Use appropriate test command based on project type
      final testCommand = isFlutterProject ? 'flutter' : 'dart';
      final testArgs = isFlutterProject 
          ? ['test', '--coverage']
          : ['test', '--coverage=coverage'];
      
      _logger.info('Detected ${isFlutterProject ? "Flutter" : "Dart"} project, using $testCommand test');
      
      // Run dart test with coverage
      final testResult = await Process.run(
      testCommand,
      testArgs,
      workingDirectory: packagePath,
    );
      
      if (testResult.exitCode != 0) {
        final stderr = testResult.stderr.toString().trim();
        final stdout = testResult.stdout.toString().trim();
        _logger.err('Test stdout: $stdout');
        _logger.err('Test stderr: $stderr');
        throw Exception('Test execution failed with exit code ${testResult.exitCode}');
      }
      
      // Format coverage data to LCOV format
      _logger.info('📊 Formatting coverage data...');
      
      if (isFlutterProject) {
        // For Flutter projects, coverage is already in LCOV format
        final flutterLcovFile = File(path.join(packagePath, 'coverage', 'lcov.info'));
        final targetLcovFile = File(lcovFile);
        
        if (await flutterLcovFile.exists()) {
          await flutterLcovFile.copy(lcovFile);
        } else {
          throw Exception('Flutter coverage file not found at: ${flutterLcovFile.path}');
        }
      } else {
        // For Dart projects, check if lcov.info already exists
        final dartLcovFile = File(path.join(packagePath, 'coverage', 'lcov.info'));
        
        if (await dartLcovFile.exists()) {
          // Use existing lcov.info file
          final targetLcovFile = File(lcovFile);
          await dartLcovFile.copy(lcovFile);
        } else {
          // Use format_coverage to convert JSON to LCOV
          final formatResult = await Process.run(
            'dart',
            [
              'pub', 'global', 'run', 'coverage:format_coverage',
              '--lcov',
              '--in=coverage',
              '--out=$lcovFile',
              '--packages=.dart_tool/package_config.json',
              '--report-on=lib'
            ],
            workingDirectory: packagePath,
          );
          
          if (formatResult.exitCode != 0) {
            final stderr = formatResult.stderr.toString().trim();
            final stdout = formatResult.stdout.toString().trim();
            _logger.err('Format stdout: $stdout');
            _logger.err('Format stderr: $stderr');
            throw Exception('Coverage formatting failed with exit code ${formatResult.exitCode}');
          }
        }
      }
      
      // Check if LCOV file was generated
      final lcovFileObj = File(lcovFile);
      if (!await lcovFileObj.exists()) {
        throw Exception('LCOV file was not generated at: $lcovFile');
      }
      
      _logger.success('✅ Tests completed and coverage data generated.');
    } catch (e) {
      _logger.err('❌ Failed to run tests: $e');
      rethrow;
    }
  }

  /// Auto-open HTML report if generated
  Future<void> _autoOpenReport(SmartCoverageConfig config) async {
    final htmlReportPath = path.join(config.outputDir, 'index.html');
    final htmlFile = File(htmlReportPath);
    
    if (await htmlFile.exists() && config.outputFormats.contains('html')) {
      try {
        String command;
        if (Platform.isMacOS) {
          command = 'open';
        } else if (Platform.isWindows) {
          command = 'start';
        } else if (Platform.isLinux) {
          command = 'xdg-open';
        } else {
          _logger.info('📄 HTML report generated at: $htmlReportPath');
          return;
        }
        
        final result = await Process.run(command, [htmlReportPath]);
        if (result.exitCode == 0) {
          _logger.info('🌐 Opening HTML report in default browser...');
        } else {
          _logger.info('📄 HTML report generated at: $htmlReportPath');
        }
      } catch (e) {
        _logger.info('📄 HTML report generated at: $htmlReportPath');
      }
    }
  }

}