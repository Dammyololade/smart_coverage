import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_coverage/src/commands/analyze_command.dart';
import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:smart_coverage/src/services/performance_profiler.dart';
import 'package:smart_coverage/src/services/performance_optimizer.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockConfigService extends Mock implements ConfigService {}

class _MockCoverageProcessor extends Mock implements CoverageProcessor {}

class _MockReportGenerator extends Mock implements ReportGenerator {}

class _MockDebugService extends Mock implements DebugService {}

class _MockAiService extends Mock implements AiService {}

class _MockPerformanceProfiler extends Mock implements PerformanceProfiler {}

class _MockPerformanceOptimizer extends Mock implements PerformanceOptimizer {}

class _MockProgress extends Mock implements Progress {
  @override
  void complete([String? message]) {}

  @override
  void fail([String? message]) {}
}

class _FakeLogger extends Fake implements Logger {}

class _TestCommandRunner extends CommandRunner<int> {
  _TestCommandRunner(AnalyzeCommand command)
      : super('test', 'Test runner') {
    addCommand(command);
  }
}

void main() {
  group('AnalyzeCommand', () {
    late Logger logger;
    late ConfigService configService;
    late CoverageProcessor coverageProcessor;
    late ReportGenerator reportGenerator;
    late DebugService debugService;
    late AiService aiService;
    late PerformanceProfiler performanceProfiler;
    late PerformanceOptimizer performanceOptimizer;
    late Directory tempDir;
    late SmartCoverageConfig defaultConfig;
    late CoverageData defaultCoverageData;

    setUpAll(() {
      registerFallbackValue(Level.info);
      registerFallbackValue(const Duration(seconds: 1));
      registerFallbackValue(_FakeLogger());
      registerFallbackValue(
        const SmartCoverageConfig(
          packagePath: '.',
          baseBranch: 'main',
          outputDir: 'coverage',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: true,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        ),
      );
      registerFallbackValue(
        const CoverageData(
          files: [],
          summary: CoverageSummary(
            linesFound: 0,
            linesHit: 0,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        ),
      );
    });

    setUp(() {
      logger = _MockLogger();
      configService = _MockConfigService();
      coverageProcessor = _MockCoverageProcessor();
      reportGenerator = _MockReportGenerator();
      debugService = _MockDebugService();
      aiService = _MockAiService();
      performanceProfiler = _MockPerformanceProfiler();
      performanceOptimizer = _MockPerformanceOptimizer();
      tempDir = Directory.systemTemp.createTempSync('analyze_command_test_');

      defaultConfig = SmartCoverageConfig(
        packagePath: tempDir.path,
        baseBranch: 'main',
        outputDir: '${tempDir.path}/coverage',
        skipTests: true,
        testInsights: false,
        codeReview: false,
        darkMode: true,
        outputFormats: const ['console'], // Prevent HTML generation in tests
        aiConfig: const AiConfig(provider: 'gemini'),
      );

      defaultCoverageData = const CoverageData(
        files: [],
        summary: CoverageSummary(
          linesFound: 100,
          linesHit: 80,
          functionsFound: 10,
          functionsHit: 8,
          branchesFound: 0,
          branchesHit: 0,
        ),
      );

      // Setup logger mocks
      when(() => logger.level).thenReturn(Level.info);
      when(() => logger.level = Level.verbose).thenReturn(Level.verbose);
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.detail(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.warn(any())).thenReturn(null);
      when(() => logger.success(any())).thenReturn(null);

      // Setup debug service mocks
      when(() => debugService.setDebugMode(any())).thenReturn(null);
      when(() => debugService.logDebug(any(), context: any(named: 'context')))
          .thenReturn(null);
      when(() => debugService.startProgress(any()))
          .thenReturn(_MockProgress());
      when(() => debugService.logSystemInfo()).thenAnswer((_) async {});
      when(() => debugService.logGitInfo()).thenAnswer((_) async {});
      when(() => debugService.logProjectStructure(any()))
          .thenAnswer((_) async {});
      when(() => debugService.logPerformance(
            any(),
            any(),
            metrics: any(named: 'metrics'),
          )).thenReturn(null);
      when(() => debugService.createDebugReport(
            projectPath: any(named: 'projectPath'),
            additionalInfo: any(named: 'additionalInfo'),
          )).thenAnswer((_) async => '${tempDir.path}/debug_report.json');

      // Setup performance profiler mocks
      when(() => performanceProfiler.enable()).thenReturn(null);
      when(() => performanceProfiler.profileFunction<SmartCoverageConfig>(
            any(),
            any(),
            metadata: any(named: 'metadata'),
          )).thenAnswer((invocation) async {
        final function = invocation.positionalArguments[1] as Function;
        return await function() as SmartCoverageConfig;
      });
      when(() => performanceProfiler.profileFunction<CoverageData>(
            any(),
            any(),
            metadata: any(named: 'metadata'),
          )).thenAnswer((invocation) async {
        final function = invocation.positionalArguments[1] as Function;
        return await function() as CoverageData;
      });
      when(() => performanceProfiler.profileFunction<void>(
            any(),
            any(),
            metadata: any(named: 'metadata'),
          )).thenAnswer((invocation) async {
        final function = invocation.positionalArguments[1] as Function;
        await function();
      });
      when(() => performanceProfiler.getSummary()).thenReturn(
        PerformanceSummary(
          totalOperations: 2,
          totalDuration: const Duration(milliseconds: 300),
          totalMemoryUsed: 1024 * 1024, // 1MB
          peakMemoryUsage: 2 * 1024 * 1024, // 2MB
          operationBreakdown: {
            'load_configuration': OperationStats(
              count: 1,
              totalDuration: const Duration(milliseconds: 100),
              averageDuration: const Duration(milliseconds: 100),
              totalMemory: 512 * 1024,
              averageMemory: 512 * 1024,
              maxDuration: const Duration(milliseconds: 100),
              maxMemory: 512 * 1024,
            ),
            'process_coverage_data': OperationStats(
              count: 1,
              totalDuration: const Duration(milliseconds: 200),
              averageDuration: const Duration(milliseconds: 200),
              totalMemory: 512 * 1024,
              averageMemory: 512 * 1024,
              maxDuration: const Duration(milliseconds: 200),
              maxMemory: 512 * 1024,
            ),
          },
          recommendations: [
            'Performance looks good! No specific recommendations.',
          ],
        ),
      );
      when(() => performanceProfiler.exportToFile(any()))
          .thenAnswer((_) async {});

      // Setup performance optimizer mocks
      when(() => performanceOptimizer.getRecommendations(
            fileCount: any(named: 'fileCount'),
            totalSizeBytes: any(named: 'totalSizeBytes'),
            lastRunDuration: any(named: 'lastRunDuration'),
          )).thenReturn(
        OptimizationRecommendations(
          recommendations: [
            'Consider using parallel processing for faster analysis',
            'Enable caching to reduce processing time',
          ],
          suggestedSettings: {
            'use_isolates': true,
            'batch_size': 50,
          },
          estimatedImprovement: 25.0,
        ),
      );

      // Setup report generator mocks - prevent HTML generation
      when(() => reportGenerator.generateReports(any(), any()))
          .thenAnswer((_) async {});
      when(() => reportGenerator.generateConsoleOutput(any()))
          .thenReturn('Mock Coverage Output: 80%');
      when(() => reportGenerator.addNavigationButtons(any()))
          .thenAnswer((_) async {});

      // Setup config service mocks
      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => defaultConfig);
      when(() => configService.validateConfig(any(), any()))
          .thenAnswer((_) async => true);

      // Setup coverage processor mocks
      when(() => coverageProcessor.processCoverageWithConfig(
            lcovPath: any(named: 'lcovPath'),
            config: any(named: 'config'),
          )).thenAnswer((_) async => defaultCoverageData);

      // Setup AI service mocks
      when(() => aiService.isAvailable()).thenAnswer((_) async => true);
      when(() => aiService.generateInsights(any()))
          .thenAnswer((_) async => 'Mock insights');
      when(() => aiService.generateCodeReview(any(), any()))
          .thenAnswer((_) async => 'Mock code review');
      when(() => aiService.generateInsightsHtml(any(), any()))
          .thenAnswer((_) async => "");
      when(() => aiService.generateCodeReviewHtml(any(), any(), any()))
          .thenAnswer((_) async => "");
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('has correct name and description', () {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      expect(command.name, equals('analyze'));
      expect(
        command.description,
        contains('Analyze coverage data for modified files'),
      );
    });

    test('executes full run() method - happy path', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests']);

      expect(result, equals(ExitCode.success.code));

      // Verify the actual run() method executed these calls
      verify(() => debugService.setDebugMode(false)).called(1);
      verify(() => logger.info('🔍 Starting coverage analysis...')).called(1);
      verify(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).called(1);
      verify(() => configService.validateConfig(any(), any())).called(1);
      verify(() => coverageProcessor.processCoverageWithConfig(
            lcovPath: any(named: 'lcovPath'),
            config: any(named: 'config'),
          )).called(1);
      verify(() => reportGenerator.generateReports(any(), any())).called(1);
      verify(() => reportGenerator.generateConsoleOutput(any())).called(1);
      verify(() => logger.success('✅ Coverage analysis completed successfully!')).called(1);
    });

    test('run() method handles verbose mode', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--verbose', '--skip-tests']);

      // Verify verbose-specific code paths executed
      verify(() => debugService.setDebugMode(true)).called(1);
      verify(() => logger.level = Level.verbose).called(1);
      verify(() => debugService.logDebug('Verbose mode enabled')).called(1);
      verify(() => debugService.logSystemInfo()).called(1);
      verify(() => debugService.logGitInfo()).called(1);
      verify(() => debugService.logProjectStructure(any())).called(1);
      verify(() => debugService.logDebug('Configuration loaded', context: any(named: 'context'))).called(1);
      verify(() => debugService.logDebug('Configuration validation passed')).called(1);
      verify(() => debugService.logPerformance(any(), any(), metrics: any(named: 'metrics'))).called(greaterThan(0));
    });

    test('run() method handles debug mode', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--debug', '--skip-tests']);

      // Verify debug report was created
      verify(() => debugService.createDebugReport(
            projectPath: any(named: 'projectPath'),
            additionalInfo: any(named: 'additionalInfo'),
          )).called(1);
    });

    test('run() method handles profile mode', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        performanceProfiler: performanceProfiler,
        performanceOptimizer: performanceOptimizer,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--profile', '--skip-tests']);

      // Verify profiling was enabled
      verify(() => logger.info('📊 Performance profiling enabled')).called(1);
      verify(() => performanceProfiler.enable()).called(1);
      verify(() => performanceProfiler.getSummary()).called(1);
      verify(() => performanceOptimizer.getRecommendations(
            fileCount: any(named: 'fileCount'),
            totalSizeBytes: any(named: 'totalSizeBytes'),
            lastRunDuration: any(named: 'lastRunDuration'),
          )).called(1);
    });

    test('run() method returns config error when validation fails', () async {
      when(() => configService.validateConfig(any(), any()))
          .thenAnswer((_) async => false);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests']);

      expect(result, equals(ExitCode.config.code));
      verify(() => logger.err(
        '\n❌ Configuration validation failed. Please fix the errors above and try again.',
      )).called(1);
    });

    test('run() method handles coverage processing errors', () async {
      when(() => coverageProcessor.processCoverageWithConfig(
            lcovPath: any(named: 'lcovPath'),
            config: any(named: 'config'),
          )).thenThrow(Exception('Coverage processing failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests']);

      expect(result, equals(ExitCode.software.code));
      verify(() => logger.err(any())).called(greaterThan(0));
    });

    // test('run() method generates debug report on failure when debug enabled', () async {
    //   when(() => coverageProcessor.processCoverageWithConfig(
    //         lcovPath: any(named: 'lcovPath'),
    //         config: any(named: 'config'),
    //       )).thenThrow(Exception('Processing failed'));
    //
    //   final command = AnalyzeCommand(
    //     logger: logger,
    //     configService: configService,
    //     coverageProcessor: coverageProcessor,
    //     reportGenerator: reportGenerator,
    //     debugService: debugService,
    //   );
    //
    //   final runner = _TestCommandRunner(command);
    //   await runner.run(['analyze', '--debug', '--skip-tests']);
    //
    //   // Verify debug report was created even on failure
    //   verify(() => debugService.createDebugReport(
    //         projectPath: any(named: 'projectPath'),
    //         additionalInfo: any(named: 'additionalInfo'),
    //       )).called(2); // Once on error, once at end
    // });

    test('run() method uses custom CLI arguments', () async {
      final customConfig = defaultConfig.copyWith(
        packagePath: '/custom/path',
        baseBranch: 'develop',
        outputDir: '/custom/output',
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => customConfig);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run([
        'analyze',
        '--skip-tests',
        '--package-path', '/custom/path',
        '--base-branch', 'develop',
        '--output-dir', '/custom/output',
      ]);

      // Verify CLI args were passed to loadConfig
      verify(() => configService.loadConfig(
            configFilePath: null,
            cliArgs: any(named: 'cliArgs'),
          )).called(1);
    });

    test('run() method handles test insights with AI', () async {
      final configWithAi = defaultConfig.copyWith(
        testInsights: true,
        outputFormats: ['console', 'html'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--test-insights']);

      // Verify AI service was called
      verify(() => aiService.isAvailable()).called(1);
      verify(() => aiService.generateInsights(any())).called(1);
      verify(() => aiService.generateInsightsHtml(any(), any())).called(1);
      verify(() => reportGenerator.addNavigationButtons(any())).called(1);
    });

    test('run() method handles code review with AI', () async {
      final configWithAi = defaultConfig.copyWith(
        codeReview: true,
        outputFormats: ['console', 'html'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--code-review']);

      // Verify AI service was called
      verify(() => aiService.isAvailable()).called(1);
      verify(() => aiService.generateCodeReview(any(), any())).called(1);
      verify(() => aiService.generateCodeReviewHtml(any(), any(), any())).called(1);
      verify(() => reportGenerator.addNavigationButtons(any())).called(1);
    });

    test('run() method skips AI when service is not available', () async {
      final configWithAi = defaultConfig.copyWith(testInsights: true);

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);
      when(() => aiService.isAvailable()).thenAnswer((_) async => false);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--test-insights']);

      // Verify AI was checked but not called
      verify(() => aiService.isAvailable()).called(1);
      verifyNever(() => aiService.generateInsights(any()));
      verify(() => logger.warn('⚠️  AI service is not available')).called(1);
    });

    test('run() method handles AI generation errors gracefully', () async {
      final configWithAi = defaultConfig.copyWith(testInsights: true);

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);
      when(() => aiService.generateInsights(any()))
          .thenThrow(Exception('AI generation failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests', '--test-insights']);

      // Should still complete successfully even if AI fails
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn(any())).called(greaterThan(0));
    });

    test('run() method displays console output only when format includes console', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests']);

      verify(() => reportGenerator.generateConsoleOutput(any())).called(1);
      verify(() => logger.info('Mock Coverage Output: 80%')).called(1);
    });

    test('run() method skips console output when format excludes console', () async {
      final noConsoleConfig = defaultConfig.copyWith(outputFormats: ['json']);

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => noConsoleConfig);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--output-formats', 'json']);

      verifyNever(() => reportGenerator.generateConsoleOutput(any()));
    });

    test('run() method handles multiple output formats', () async {
      final multiConfig = defaultConfig.copyWith(
        outputFormats: ['console', 'json', 'lcov'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => multiConfig);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run([
        'analyze',
        '--skip-tests',
        '--output-formats', 'console',
        '--output-formats', 'json',
        '--output-formats', 'lcov',
      ]);

      verify(() => reportGenerator.generateReports(any(), multiConfig)).called(1);
    });

    test('run() method logs detail messages for configuration', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests']);

      // Verify detail logs are called (these are in lines 190-197)
      verify(() => logger.detail('Package path: ${defaultConfig.packagePath}')).called(1);
      verify(() => logger.detail('Base branch: ${defaultConfig.baseBranch}')).called(1);
      verify(() => logger.detail('Output directory: ${defaultConfig.outputDir}')).called(1);
      verify(() => logger.detail('Skip tests: ${defaultConfig.skipTests}')).called(1);
      verify(() => logger.detail('Test insights: ${defaultConfig.testInsights}')).called(1);
      verify(() => logger.detail('Code review: ${defaultConfig.codeReview}')).called(1);
    });

    test('run() method loads config from file when --config specified', () async {
      final configPath = '${tempDir.path}/test_config.yaml';
      await File(configPath).writeAsString('packagePath: .\n');

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--config', configPath]);

      verify(() => configService.loadConfig(
            configFilePath: configPath,
            cliArgs: any(named: 'cliArgs'),
          )).called(1);
    });

    test('run() handles test insights without HTML output format', () async {
      final configWithAi = defaultConfig.copyWith(
        testInsights: true,
        outputFormats: ['console'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--test-insights']);

      verify(() => aiService.generateInsights(any())).called(1);
      verify(() => logger.info('\n📊 Test Insights:')).called(1);
      verify(() => logger.info('Mock insights')).called(1);
      verifyNever(() => aiService.generateInsightsHtml(any(), any()));
    });

    test('run() handles code review without HTML output format', () async {
      final configWithAi = defaultConfig.copyWith(
        codeReview: true,
        outputFormats: ['console'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--code-review']);

      verify(() => aiService.generateCodeReview(any(), any())).called(1);
      verify(() => logger.info('\n🔍 Code Review:')).called(1);
      verify(() => logger.info('Mock code review')).called(1);
      verifyNever(() => aiService.generateCodeReviewHtml(any(), any(), any()));
    });

    test('run() handles AI insights HTML generation errors gracefully', () async {
      final configWithAi = defaultConfig.copyWith(
        testInsights: true,
        outputFormats: ['console', 'html'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);
      when(() => aiService.generateInsightsHtml(any(), any()))
          .thenThrow(Exception('HTML generation failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests', '--test-insights']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn(any())).called(greaterThan(0));
    });

    test('run() handles code review HTML generation errors gracefully', () async {
      final configWithAi = defaultConfig.copyWith(
        codeReview: true,
        outputFormats: ['console', 'html'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);
      when(() => aiService.generateCodeReviewHtml(any(), any(), any()))
          .thenThrow(Exception('HTML generation failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests', '--code-review']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn(any())).called(greaterThan(0));
    });

    // test('run() handles AI service not configured properly', () async {
    //   final configWithAi = defaultConfig.copyWith(
    //     testInsights: true,
    //     aiConfig: null,
    //   );
    //
    //   when(() => configService.loadConfig(
    //         configFilePath: any(named: 'configFilePath'),
    //         cliArgs: any(named: 'cliArgs'),
    //       )).thenAnswer((_) async => configWithAi);
    //
    //   final command = AnalyzeCommand(
    //     logger: logger,
    //     configService: configService,
    //     coverageProcessor: coverageProcessor,
    //     reportGenerator: reportGenerator,
    //     debugService: debugService,
    //   );
    //
    //   final runner = _TestCommandRunner(command);
    //   await runner.run(['analyze', '--skip-tests', '--test-insights']);
    //
    //   verify(() => logger.warn('⚠️  AI service not configured properly')).called(1);
    // });

    test('run() handles both test insights and code review', () async {
      final configWithAi = defaultConfig.copyWith(
        testInsights: true,
        codeReview: true,
        outputFormats: ['console', 'html'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--test-insights', '--code-review']);

      verify(() => aiService.generateInsights(any())).called(1);
      verify(() => aiService.generateCodeReview(any(), any())).called(1);
      verify(() => reportGenerator.addNavigationButtons(any())).called(1);
    });

    test('run() handles profile mode with verbose output', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        performanceProfiler: performanceProfiler,
        performanceOptimizer: performanceOptimizer,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--profile', '--verbose', '--skip-tests']);

      verify(() => performanceProfiler.exportToFile(any())).called(1);
      verify(() => logger.info(any(that: contains('Detailed performance report')))).called(1);
    });

    test('run() handles performance summary generation errors', () async {
      when(() => performanceProfiler.getSummary()).thenThrow(Exception('Failed to get summary'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        performanceProfiler: performanceProfiler,
        performanceOptimizer: performanceOptimizer,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--profile', '--skip-tests']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn(any(that: contains('Failed to generate performance summary')))).called(1);
    });

    test('run() handles debug report generation failure', () async {
      when(() => debugService.createDebugReport(
            projectPath: any(named: 'projectPath'),
            additionalInfo: any(named: 'additionalInfo'),
          )).thenThrow(Exception('Debug report failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--debug', '--skip-tests']);

      expect(result, equals(ExitCode.success.code));
      verify(() => debugService.logDebug(any(that: contains('Failed to generate debug report')))).called(1);
    });

    test('run() handles debug report generation failure on error', () async {
      when(() => coverageProcessor.processCoverageWithConfig(
            lcovPath: any(named: 'lcovPath'),
            config: any(named: 'config'),
          )).thenThrow(Exception('Processing failed'));
      when(() => debugService.createDebugReport(
            projectPath: any(named: 'projectPath'),
            additionalInfo: any(named: 'additionalInfo'),
          )).thenThrow(Exception('Debug report failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--debug', '--skip-tests']);

      expect(result, equals(ExitCode.software.code));
      verify(() => debugService.logDebug(any(that: contains('Failed to generate debug report')))).called(greaterThan(0));
    });


    test('run() handles all CLI argument parsing', () async {
      final customConfig = defaultConfig.copyWith(
        packagePath: '/custom/path',
        baseBranch: 'develop',
        outputDir: '/custom/output',
        skipTests: true,
        testInsights: true,
        codeReview: true,
        darkMode: false,
        outputFormats: ['console', 'html', 'json'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => customConfig);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run([
        'analyze',
        '--package-path', '/custom/path',
        '--base-branch', 'develop',
        '--output-dir', '/custom/output',
        '--skip-tests',
        '--test-insights',
        '--code-review',
        '--no-dark-mode',
        '--output-formats', 'console',
        '--output-formats', 'html',
        '--output-formats', 'json',
      ]);

      verify(() => configService.loadConfig(
            configFilePath: null,
            cliArgs: any(named: 'cliArgs'),
          )).called(1);
    });

    test('run() handles lcov-file custom path', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run([
        'analyze',
        '--skip-tests',
        '--lcov-file', '/custom/lcov.info',
      ]);

      verify(() => coverageProcessor.processCoverageWithConfig(
            lcovPath: '/custom/lcov.info',
            config: any(named: 'config'),
          )).called(1);
    });

    test('run() handles code review generation with progress', () async {
      final configWithAi = defaultConfig.copyWith(
        codeReview: true,
        outputFormats: ['console'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--code-review']);

      verify(() => debugService.startProgress('🔍 Generating code review...')).called(1);
    });

    test('run() handles test insights generation with progress', () async {
      final configWithAi = defaultConfig.copyWith(
        testInsights: true,
        outputFormats: ['console'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--skip-tests', '--test-insights']);

      verify(() => debugService.startProgress('🧠 Generating test insights...')).called(1);
    });

    test('run() handles code review generation error with progress', () async {
      final configWithAi = defaultConfig.copyWith(
        codeReview: true,
        outputFormats: ['console'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);
      when(() => aiService.generateCodeReview(any(), any()))
          .thenThrow(Exception('Code review failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests', '--code-review']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn(any(that: contains('Failed to generate AI insights')))).called(1);
    });

    test('run() handles test insights generation error with progress', () async {
      final configWithAi = defaultConfig.copyWith(
        testInsights: true,
        outputFormats: ['console'],
      );

      when(() => configService.loadConfig(
            configFilePath: any(named: 'configFilePath'),
            cliArgs: any(named: 'cliArgs'),
          )).thenAnswer((_) async => configWithAi);
      when(() => aiService.generateInsights(any()))
          .thenThrow(Exception('Insights failed'));

      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        aiService: aiService,
      );

      final runner = _TestCommandRunner(command);
      final result = await runner.run(['analyze', '--skip-tests', '--test-insights']);

      expect(result, equals(ExitCode.success.code));
      verify(() => logger.warn(any(that: contains('Failed to generate AI insights')))).called(1);
    });

    test('run() handles performance profiling of all operations', () async {
      final command = AnalyzeCommand(
        logger: logger,
        configService: configService,
        coverageProcessor: coverageProcessor,
        reportGenerator: reportGenerator,
        debugService: debugService,
        performanceProfiler: performanceProfiler,
        performanceOptimizer: performanceOptimizer,
      );

      final runner = _TestCommandRunner(command);
      await runner.run(['analyze', '--profile', '--skip-tests']);

      verify(() => performanceProfiler.profileFunction<SmartCoverageConfig>(
            'load_configuration',
            any(),
            metadata: any(named: 'metadata'),
          )).called(1);
      verify(() => performanceProfiler.profileFunction<CoverageData>(
            'process_coverage_data',
            any(),
            metadata: any(named: 'metadata'),
          )).called(1);
      verify(() => performanceProfiler.profileFunction<void>(
            'generate_reports',
            any(),
            metadata: any(named: 'metadata'),
          )).called(1);
    });
  });
}
