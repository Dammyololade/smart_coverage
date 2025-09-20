import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:smart_coverage/src/services/performance_profiler.dart';
import 'package:smart_coverage/src/services/performance_optimizer.dart';

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
    AiService? aiService,
    DebugService? debugService,
    PerformanceProfiler? performanceProfiler,
    PerformanceOptimizer? performanceOptimizer,
  }) : _logger = logger,
       _configService = configService ?? const ConfigServiceImpl(),
       _coverageProcessor =
           coverageProcessor ??
           const CoverageProcessorImpl(
             fileDetector: FileDetectorImpl(),
             lcovParser: LcovParserImpl(),
           ),
       _reportGenerator = reportGenerator ?? const ReportGeneratorImpl(),
       _aiService = aiService,
       _debugService = debugService ?? DebugServiceImpl(logger: logger),
       _performanceProfiler = performanceProfiler ?? PerformanceProfiler(),
       _performanceOptimizer =
           performanceOptimizer ??
           PerformanceOptimizer(
             profiler: performanceProfiler ?? PerformanceProfiler(),
           ) {
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
        defaultsTo: 'coverage/smart_coverage',
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
        'test-insights',
        help: 'Enable AI-powered test insights generation.',
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
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose debugging output with detailed logging.',
        negatable: false,
      )
      ..addFlag(
        'debug',
        abbr: 'd',
        help: 'Generate debug report file with detailed analysis information.',
        negatable: false,
      )
      ..addFlag(
        'profile',
        help: 'Enable performance profiling and optimization recommendations.',
        negatable: false,
      )
      ..addMultiOption(
        'output-formats',
        help: 'Output formats to generate.',
        allowed: ['console', 'html', 'json', 'lcov'],
        defaultsTo: ['console'],
      );
  }

  @override
  String get description =>
      'Analyze coverage data for modified files with optional test insights.';

  @override
  String get name => 'analyze';

  final Logger _logger;
  final ConfigService _configService;
  final CoverageProcessor _coverageProcessor;
  final ReportGenerator _reportGenerator;
  final AiService? _aiService;
  final DebugService _debugService;
  final PerformanceProfiler _performanceProfiler;
  final PerformanceOptimizer _performanceOptimizer;

  @override
  Future<int> run() async {
    final stopwatch = Stopwatch()..start();

    // Enable debug mode if verbose flag is set
    final isVerbose = argResults!['verbose'] as bool;
    final isDebugEnabled = argResults!['debug'] as bool;
    final isProfileEnabled = argResults!['profile'] as bool;

    _debugService.setDebugMode(isVerbose);

    // Enable performance profiling if requested
    if (isProfileEnabled) {
      _performanceProfiler.enable();
      _logger.info('📊 Performance profiling enabled');
    }

    // Set logger level for verbose output
    if (isVerbose) {
      _logger.level = Level.verbose;
    }

    _logger.info('🔍 Starting coverage analysis...');

    if (isVerbose) {
      _debugService.logDebug('Verbose mode enabled');
      await _debugService.logSystemInfo();
      await _debugService.logGitInfo();
    }

    try {
      // 1. Load and validate configuration
      final configProgress = _debugService.startProgress(
        'Loading configuration...',
      );
      final config = await _performanceProfiler.profileFunction(
        'load_configuration',
        () => _loadConfiguration(),
      );
      configProgress.complete('Configuration loaded');

      if (isVerbose) {
        await _debugService.logProjectStructure(config.packagePath);
        _debugService.logDebug(
          'Configuration loaded',
          context: {
            'packagePath': config.packagePath,
            'baseBranch': config.baseBranch,
            'outputDir': config.outputDir,
            'skipTests': config.skipTests,
            'testInsights': config.testInsights,
            'codeReview': config.codeReview,
            'outputFormats': config.outputFormats,
          },
        );
      }
      final isConfigValid = await _configService.validateConfig(
        config,
        _logger,
      );

      if (!isConfigValid) {
        _logger.err(
          '\n❌ Configuration validation failed. Please fix the errors above and try again.',
        );
        return ExitCode.config.code;
      }

      if (isVerbose) {
        _debugService.logDebug('Configuration validation passed');
      }

      _logger
        ..detail('Package path: ${config.packagePath}')
        ..detail('Base branch: ${config.baseBranch}')
        ..detail('Output directory: ${config.outputDir}')
        ..detail('Skip tests: ${config.skipTests}')
        ..detail('Test insights: ${config.testInsights}')
        ..detail('Code review: ${config.codeReview}')
        ..detail('Output formats: ${config.outputFormats.join(", ")}');

      // 2. Run tests if not skipped
      final lcovFile = argResults!['lcov-file'] as String;
      if (!config.skipTests) {
        final testProgress = _debugService.startProgress('Running tests...');
        final testStopwatch = Stopwatch()..start();
        await _runTests(config.packagePath, lcovFile);
        testStopwatch.stop();
        testProgress.complete('Tests completed');

        if (isVerbose) {
          _debugService.logPerformance('Test execution', testStopwatch.elapsed);
        }
      } else if (isVerbose) {
        _debugService.logDebug(
          'Skipping test execution, using existing coverage data',
        );
      }

      // 3. Process coverage data
      final coverageProgress = _debugService.startProgress(
        'Processing coverage data...',
      );
      final coverageStopwatch = Stopwatch()..start();
      final coverageData = await _performanceProfiler.profileFunction(
        'process_coverage_data',
        () => _coverageProcessor.processCoverageWithConfig(
          lcovPath: lcovFile,
          config: config,
        ),
        metadata: {
          'lcov_file': lcovFile,
          'package_path': config.packagePath,
        },
      );
      coverageStopwatch.stop();
      coverageProgress.complete('Coverage data processed');

      if (isVerbose) {
        _debugService.logPerformance(
          'Coverage processing',
          coverageStopwatch.elapsed,
          metrics: {
            'totalFiles': coverageData.files.length,
            'linesHit': coverageData.summary.linesHit,
            'linesFound': coverageData.summary.linesFound,
            'linePercentage':
                '${coverageData.summary.linePercentage.toStringAsFixed(2)}%',
          },
        );
      }

      // 4. Generate reports
      final reportProgress = _debugService.startProgress(
        'Generating reports...',
      );
      final reportStopwatch = Stopwatch()..start();
      await _performanceProfiler.profileFunction(
        'generate_reports',
        () => _reportGenerator.generateReports(coverageData, config),
        metadata: {
          'output_formats': config.outputFormats,
          'output_dir': config.outputDir,
          'file_count': coverageData.files.length,
        },
      );
      reportStopwatch.stop();
      reportProgress.complete('Reports generated');

      if (isVerbose) {
        _debugService.logPerformance(
          'Report generation',
          reportStopwatch.elapsed,
          metrics: {
            'outputFormats': config.outputFormats.join(', '),
            'outputDir': config.outputDir,
          },
        );
      }

      // 5. Display summary (console output)
      if (config.outputFormats.contains('console')) {
        final consoleOutput = _reportGenerator.generateConsoleOutput(
          coverageData,
        );
        _logger.info(consoleOutput);
      }

      // 6. Generate test insights if enabled
      if (config.testInsights || config.codeReview) {
        await _generateAiInsights(coverageData, config);

        // Add navigation buttons to HTML report after AI files are generated
        if (config.outputFormats.contains('html')) {
          await _reportGenerator.addNavigationButtons(config.outputDir);
        }
      }

      // 7. Auto-open HTML report if generated
      await _autoOpenReport(config);

      stopwatch.stop();

      // Generate performance summary and recommendations if profiling is enabled
      if (isProfileEnabled) {
        await _generatePerformanceSummary(
          config,
          coverageData,
          stopwatch.elapsed,
        );
      }

      if (isVerbose) {
        _debugService.logPerformance('Total analysis time', stopwatch.elapsed);
      }

      // Generate debug report only if debug flag is provided
      if (isDebugEnabled) {
        try {
          final debugReportPath = await _debugService.createDebugReport(
            projectPath: config.packagePath,
            additionalInfo: {
              'analysisTime': '${stopwatch.elapsed.inMilliseconds}ms',
              'outputFormats': config.outputFormats.join(', '),
              'testInsights': config.testInsights,
              'codeReview': config.codeReview,
              'skipTests': config.skipTests,
            },
          );
          _debugService.logDebug('Debug report generated: $debugReportPath');
        } catch (e) {
          _debugService.logDebug('Failed to generate debug report: $e');
        }
      }

      _logger.success('✅ Coverage analysis completed successfully!');
      return ExitCode.success.code;
    } catch (error) {
      stopwatch.stop();

      if (isVerbose) {
        _debugService.logDebug(
          'Analysis failed after ${stopwatch.elapsed.inMilliseconds}ms',
        );
      }

      // Generate debug report for failed analysis only if debug flag is provided
      if (isDebugEnabled) {
        try {
          final debugReportPath = await _debugService.createDebugReport(
            projectPath: argResults!['package-path'] as String? ?? '.',
            additionalInfo: {
              'error': error.toString(),
              'analysisTime': '${stopwatch.elapsed.inMilliseconds}ms',
              'failurePoint': 'During analysis execution',
            },
          );
          _logger.err(
            'Debug report generated for failed analysis: $debugReportPath',
          );
        } catch (e) {
          _debugService.logDebug('Failed to generate debug report: $e');
        }
      }

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
    if (argResults!.wasParsed('test-insights')) {
      cliArgs['testInsights'] = argResults!['test-insights'];
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

  /// Generate test insights and code review
  Future<void> _generateAiInsights(
    CoverageData coverageData,
    SmartCoverageConfig config,
  ) async {
    try {
      // Create AI service if not provided
      final aiService = _aiService ?? _createAiService(config.aiConfig);

      if (aiService == null) {
        _logger.warn('⚠️  AI service not configured properly');
        return;
      }

      // Check if AI service is available
      final isAvailable = await aiService.isAvailable();
      if (!isAvailable) {
        _logger.warn('⚠️  AI service is not available');
        return;
      }

      // Generate insights if requested
      if (config.testInsights) {
        final insightsProgress = _debugService.startProgress(
          '🧠 Generating test insights...',
        );
        
        try {
          final insights = await aiService.generateInsights(coverageData);
          insightsProgress.complete('✅ Test insights generated');
          
          // Only output to console if console format is enabled
          if (config.outputFormats.contains('console')) {
            _logger.info('\n📊 Test Insights:');
            _logger.info(insights);
          }

          // Generate HTML file if HTML output is enabled
          if (config.outputFormats.contains('html')) {
            final htmlPath = path.join(config.outputDir, 'test_insights.html');
            try {
              await aiService.generateInsightsHtml(coverageData, htmlPath);
              _logger.success('📄 Test insights HTML report generated: $htmlPath');
            } catch (e) {
              _logger.warn('⚠️  Failed to generate test insights HTML: $e');
            }
          }
        } catch (e) {
          insightsProgress.fail('❌ Failed to generate test insights');
          rethrow;
        }
      }

      // Generate code review if requested
      if (config.codeReview) {
        final reviewProgress = _debugService.startProgress(
          '🔍 Generating code review...',
        );
        
        try {
          final modifiedFiles = coverageData.files.map((f) => f.path).toList();
          final codeReview = await aiService.generateCodeReview(
            coverageData,
            modifiedFiles,
          );
          reviewProgress.complete('✅ Code review generated');
          
          // Only output to console if console format is enabled
          if (config.outputFormats.contains('console')) {
            _logger.info('\n🔍 Code Review:');
            _logger.info(codeReview);
          }

          // Generate HTML file if HTML output is enabled
          if (config.outputFormats.contains('html')) {
            final htmlPath = path.join(config.outputDir, 'code_review.html');
            try {
              await aiService.generateCodeReviewHtml(
                coverageData,
                modifiedFiles,
                htmlPath,
              );
              _logger.success('📄 Code review HTML report generated: $htmlPath');
            } catch (e) {
              _logger.warn('⚠️  Failed to generate code review HTML: $e');
            }
          }
        } catch (e) {
          reviewProgress.fail('❌ Failed to generate code review');
          rethrow;
        }
      }
    } catch (error) {
      _logger.warn('⚠️  Failed to generate AI insights: $error');
    }
  }

  /// Create AI service based on configuration
  AiService? _createAiService(AiConfig? aiConfig) {
    if (aiConfig == null) return null;

    try {
      // Get verbose flag from command line arguments
      final isVerbose = argResults!['verbose'] as bool;
      
      // Create AI config with verbose flag
      final verboseAiConfig = aiConfig.copyWith(verbose: isVerbose);
      
      // For now, only support Gemini CLI
      if (aiConfig.provider.toLowerCase() == 'gemini') {
        return GeminiCliService(verboseAiConfig);
      }

      _logger.warn('⚠️  Unsupported AI provider: ${aiConfig.provider}');
      return null;
    } catch (error) {
      _logger.warn('⚠️  Failed to create AI service: $error');
      return null;
    }
  }

  /// Run tests to generate coverage data
  Future<void> _runTests(String packagePath, String lcovFile) async {
    _logger.info('🧪 Running tests to generate coverage data...');

    try {
      // Ensure coverage directory exists
      final coverageDir = Directory(path.dirname(lcovFile));
      if (!coverageDir.existsSync()) {
        await coverageDir.create(recursive: true);
      }

      // Detect if this is a Flutter project
      final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
      var isFlutterProject = false;

      if (pubspecFile.existsSync()) {
        final pubspecContent = await pubspecFile.readAsString();
        isFlutterProject =
            pubspecContent.contains('flutter:') ||
            pubspecContent.contains('flutter_test:');
      }

      // Use appropriate test command based on project type
      final testCommand = isFlutterProject ? 'flutter' : 'dart';
      final testArgs = isFlutterProject
          ? ['test', '--coverage']
          : ['test', '--coverage=coverage'];

      _logger.info(
        "Detected ${isFlutterProject ? "Flutter" : "Dart"} project, using $testCommand test",
      );

      // Run dart test with coverage
      final testResult = await Process.run(
        testCommand,
        testArgs,
        workingDirectory: packagePath,
      );

      if (testResult.exitCode != 0) {
        final stderr = testResult.stderr.toString().trim();
        final stdout = testResult.stdout.toString().trim();
        _logger
          ..err('Test stdout: $stdout')
          ..err('Test stderr: $stderr');
        throw Exception(
          'Test execution failed with exit code ${testResult.exitCode}',
        );
      }

      // Format coverage data to LCOV format
      _logger.info('📊 Formatting coverage data...');

      if (isFlutterProject) {
        // For Flutter projects, coverage is already in LCOV format
        final flutterLcovFile = File(
          path.join(packagePath, 'coverage', 'lcov.info'),
        );

        // Check if Flutter coverage file exists and copy it
        if (flutterLcovFile.existsSync()) {
          await flutterLcovFile.copy(lcovFile);
        } else {
          throw Exception(
            'Flutter coverage file not found at: ${flutterLcovFile.path}',
          );
        }
      } else {
        // For Dart projects, check if lcov.info already exists
        final dartLcovFile = File(
          path.join(packagePath, 'coverage', 'lcov.info'),
        );

        if (dartLcovFile.existsSync()) {
          // Use existing lcov.info file
          await dartLcovFile.copy(lcovFile);
        } else {
          // Use format_coverage to convert JSON to LCOV
          final formatResult = await Process.run(
            'dart',
            [
              'pub',
              'global',
              'run',
              'coverage:format_coverage',
              '--lcov',
              '--in=coverage',
              '--out=$lcovFile',
              '--packages=.dart_tool/package_config.json',
              '--report-on=lib',
            ],
            workingDirectory: packagePath,
          );

          if (formatResult.exitCode != 0) {
            final stderr = formatResult.stderr.toString().trim();
            final stdout = formatResult.stdout.toString().trim();
            _logger
              ..err('Format stdout: $stdout')
              ..err('Format stderr: $stderr');
            throw Exception(
              'Coverage formatting failed with exit code ${formatResult.exitCode}',
            );
          }
        }
      }

      // Check if LCOV file was generated
      final lcovFileObj = File(lcovFile);
      if (!lcovFileObj.existsSync()) {
        throw Exception('LCOV file was not generated at: $lcovFile');
      }

      _logger.success('✅ Tests completed and coverage data generated.');
    } catch (e) {
      _logger.err('❌ Failed to run tests: $e');
      rethrow;
    }
  }

  /// Generate performance summary and optimization recommendations
  Future<void> _generatePerformanceSummary(
    SmartCoverageConfig config,
    dynamic coverageData,
    Duration totalTime,
  ) async {
    try {
      final summary = _performanceProfiler.getSummary();

      _logger.info('\n📊 Performance Summary:');
      _logger.info('   Total analysis time: ${totalTime.inMilliseconds}ms');

      for (final entry in summary.operationBreakdown.entries) {
        final operation = entry.value;
        final avgTime = operation.averageDuration.inMilliseconds;
        _logger.info(
          '   ${entry.key}: ${operation.totalDuration.inMilliseconds}ms (avg: ${avgTime.toStringAsFixed(1)}ms, calls: ${operation.count})',
        );
      }

      // Generate optimization recommendations
      final fileCount = (coverageData?.files?.length as int?) ?? 0;
      final optimizationResult = _performanceOptimizer.getRecommendations(
        fileCount: fileCount,
        totalSizeBytes: 0, // TODO: Calculate actual size
        lastRunDuration: totalTime,
      );
      final recommendations = optimizationResult.recommendations;

      if (recommendations.isNotEmpty) {
        _logger.info('\n🚀 Optimization Recommendations:');
        for (final recommendation in recommendations) {
          _logger.info('   • $recommendation');
        }
      }

      // Export detailed performance report if verbose
      if (argResults!['verbose'] as bool) {
        await _performanceProfiler.exportToFile(
          '${config.outputDir}/performance_report.json',
        );
        final reportPath = '${config.outputDir}/performance_report.json';
        _logger.info('\n📈 Detailed performance report: $reportPath');
      }
    } catch (e) {
      _logger.warn('Failed to generate performance summary: $e');
    }
  }

  /// Auto-open HTML report if configured
  Future<void> _autoOpenReport(SmartCoverageConfig config) async {
    final htmlReportPath = path.join(config.outputDir, 'index.html');
    final htmlFile = File(htmlReportPath);

    if (htmlFile.existsSync() && config.outputFormats.contains('html')) {
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
