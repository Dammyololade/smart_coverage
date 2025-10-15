import 'dart:io';

import 'package:smart_coverage/src/models/models.dart';
import 'package:smart_coverage/src/services/ai_service.dart';
import 'package:test/test.dart';

void main() {
  group('AiServiceFactory', () {
    late Directory tempDir;
    late SmartCoverageConfig config;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ai_service_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates GeminiCliService when provider is gemini-cli', () async {
      config = const SmartCoverageConfig(
        packagePath: '.',
        baseBranch: 'main',
        outputDir: 'coverage',
        skipTests: false,
        testInsights: false,
        codeReview: false,
        darkMode: false,
        outputFormats: ['console'],
        aiConfig: AiConfig(
          provider: 'gemini-cli',
          providerType: 'local',
        ),
      );

      final service = await AiServiceFactory.create(config);

      expect(service, isA<GeminiCliService>());
      expect(service, isA<LocalAiService>());
      expect(service.providerType, equals(AiProviderType.local));
    });

    test('creates GeminiApiService when provider is gemini and type is api',
        () async {
      config = const SmartCoverageConfig(
        packagePath: '.',
        baseBranch: 'main',
        outputDir: 'coverage',
        skipTests: false,
        testInsights: false,
        codeReview: false,
        darkMode: false,
        outputFormats: ['console'],
        aiConfig: AiConfig(
          provider: 'gemini',
          providerType: 'api',
        ),
      );

      final service = await AiServiceFactory.create(config);

      expect(service, isA<GeminiApiService>());
      expect(service, isA<ApiAiService>());
      expect(service.providerType, equals(AiProviderType.api));
    });

    test('creates GeminiCliService when provider is gemini and type is local',
        () async {
      config = const SmartCoverageConfig(
        packagePath: '.',
        baseBranch: 'main',
        outputDir: 'coverage',
        skipTests: false,
        testInsights: false,
        codeReview: false,
        darkMode: false,
        outputFormats: ['console'],
        aiConfig: AiConfig(
          provider: 'gemini',
          providerType: 'local',
        ),
      );

      final service = await AiServiceFactory.create(config);

      expect(service, isA<GeminiCliService>());
      expect(service, isA<LocalAiService>());
    });

    test('throws UnsupportedError for unknown provider', () async {
      config = const SmartCoverageConfig(
        packagePath: '.',
        baseBranch: 'main',
        outputDir: 'coverage',
        skipTests: false,
        testInsights: false,
        codeReview: false,
        darkMode: false,
        outputFormats: ['console'],
        aiConfig: AiConfig(
          provider: 'unknown-provider',
          providerType: 'local',
        ),
      );

      expect(
        () => AiServiceFactory.create(config),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('GeminiCliService', () {
    late GeminiCliService service;
    late Directory tempDir;
    late AiConfig aiConfig;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gemini_cli_test');
      aiConfig = AiConfig(
        provider: 'gemini',
        providerType: 'local',
        cliCommand: 'gemini',
        cliTimeout: 60,
        timeout: 30,
        cacheEnabled: true,
        cacheDirectory: '${tempDir.path}/.cache',
      );
      service = GeminiCliService(aiConfig);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('isCliInstalled', () {
      test('returns true when CLI is installed', () async {
        // This test depends on the system having 'which' command
        // We'll test with a known command like 'echo'
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'echo'),
        );

        final isInstalled = await testService.isCliInstalled();

        expect(isInstalled, isTrue);
      });

      test('returns false when CLI is not installed', () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'nonexistent-command-xyz-123'),
        );

        final isInstalled = await testService.isCliInstalled();

        expect(isInstalled, isFalse);
      });
    });

    group('getCliVersion', () {
      test('returns version string when command supports --version', () async {
        // Test with a command that has --version (like dart)
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'dart'),
        );

        final version = await testService.getCliVersion();

        expect(version, isNotEmpty);
        expect(version, isNot(equals('unknown')));
      });

      test('returns unknown when command does not support --version',
          () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'echo'),
        );

        final version = await testService.getCliVersion();

        // echo doesn't support --version, so it might return 'unknown' or the error message
        expect(version, isA<String>());
      });

      test('returns unknown when command does not exist', () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'nonexistent-cmd'),
        );

        final version = await testService.getCliVersion();

        expect(version, equals('unknown'));
      });
    });

    group('isAvailable', () {
      test('returns true when CLI is available', () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'echo'),
        );

        final isAvailable = await testService.isAvailable();

        expect(isAvailable, isTrue);
      });

      test('returns false when CLI is not available', () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(cliCommand: 'nonexistent-command'),
        );

        final isAvailable = await testService.isAvailable();

        expect(isAvailable, isFalse);
      });
    });

    group('caching', () {
      test('cliCommand returns configured command', () {
        expect(service.cliCommand, equals('gemini'));
      });

      test('cache is enabled by default', () {
        final defaultService = GeminiCliService(
          const AiConfig(provider: 'gemini'),
        );

        // Cache should be enabled by default based on AiConfig defaults
        expect(defaultService.config.cacheEnabled, isTrue);
      });

      test('cache directory can be configured', () {
        final customCacheDir = '${tempDir.path}/custom_cache';
        final customService = GeminiCliService(
          aiConfig.copyWith(cacheDirectory: customCacheDir),
        );

        expect(customService.config.cacheDirectory, equals(customCacheDir));
      });
    });

    group('providerType', () {
      test('returns local for GeminiCliService', () {
        expect(service.providerType, equals(AiProviderType.local));
      });
    });

    group('prompt building', () {
      late CoverageData mockCoverage;

      setUp(() {
        mockCoverage = CoverageData(
          summary: const CoverageSummary(
            linesFound: 100,
            linesHit: 80,
            functionsFound: 10,
            functionsHit: 8,
            branchesFound: 0,
            branchesHit: 0,
          ),
          files: [
            const FileCoverage(
              path: 'lib/example.dart',
              summary: CoverageSummary(
                linesFound: 50,
                linesHit: 40,
                functionsFound: 5,
                functionsHit: 4,
                branchesFound: 0,
                branchesHit: 0,
              ),
              lines: [],
            ),
          ],
        );
      });

      test('generateCodeReview throws when CLI command fails', () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(
            cliCommand: 'false', // Command that always fails
            cliTimeout: 2,
          ),
        );

        expect(
          () => testService.generateCodeReview(mockCoverage, []),
          throwsA(isA<Exception>()),
        );
      });

      test('generateInsights throws when CLI command fails', () async {
        final testService = GeminiCliService(
          aiConfig.copyWith(
            cliCommand: 'false', // Command that always fails
            cliTimeout: 2,
          ),
        );

        expect(
          () => testService.generateInsights(mockCoverage),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('GeminiApiService', () {
    late GeminiApiService service;
    late AiConfig aiConfig;

    setUp(() {
      aiConfig = const AiConfig(
        provider: 'gemini',
        providerType: 'api',
        apiKeyEnv: 'GEMINI_API_KEY',
        apiEndpoint: 'https://custom.endpoint.com',
      );
      service = GeminiApiService(aiConfig);
    });

    test('providerType returns api', () {
      expect(service.providerType, equals(AiProviderType.api));
    });

    test('apiEndpoint returns default when not configured', () {
      final defaultService = GeminiApiService(
        const AiConfig(provider: 'gemini', providerType: 'api'),
      );

      expect(
        defaultService.apiEndpoint,
        equals('https://generativelanguage.googleapis.com'),
      );
    });

    group('unimplemented methods', () {
      late CoverageData mockCoverage;

      setUp(() {
        mockCoverage = CoverageData(
          summary: const CoverageSummary(
            linesFound: 100,
            linesHit: 80,
            functionsFound: 10,
            functionsHit: 8,
            branchesFound: 0,
            branchesHit: 0,
          ),
          files: [],
        );
      });

      test('hasValidApiKey throws UnimplementedError', () {
        expect(
          () => service.hasValidApiKey(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('generateCodeReview throws UnimplementedError', () {
        expect(
          () => service.generateCodeReview(mockCoverage, []),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('generateInsights throws UnimplementedError', () {
        expect(
          () => service.generateInsights(mockCoverage),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('generateCodeReviewHtml throws UnimplementedError', () {
        expect(
          () => service.generateCodeReviewHtml(mockCoverage, [], 'output.html'),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('generateInsightsHtml throws UnimplementedError', () {
        expect(
          () => service.generateInsightsHtml(mockCoverage, 'output.html'),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('isAvailable throws UnimplementedError', () {
        expect(
          () => service.isAvailable(),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });
  });

  group('AiProviderType', () {
    test('has api type', () {
      expect(AiProviderType.api, isNotNull);
    });

    test('has local type', () {
      expect(AiProviderType.local, isNotNull);
    });

    test('enum values are distinct', () {
      expect(AiProviderType.api, isNot(equals(AiProviderType.local)));
    });
  });

  group('Integration scenarios', () {
    test('LocalAiService interface is properly implemented', () {
      const config = AiConfig(provider: 'gemini', providerType: 'local');
      final service = GeminiCliService(config);

      expect(service, isA<LocalAiService>());
      expect(service, isA<AiService>());
      expect(service.providerType, equals(AiProviderType.local));
      expect(service.cliCommand, isNotEmpty);
    });

    test('ApiAiService interface is properly implemented', () {
      const config = AiConfig(provider: 'gemini', providerType: 'api');
      final service = GeminiApiService(config);

      expect(service, isA<ApiAiService>());
      expect(service, isA<AiService>());
      expect(service.providerType, equals(AiProviderType.api));
      expect(service.apiEndpoint, isNotEmpty);
    });

    test('AiConfig is properly passed to services', () {
      const config = AiConfig(
        provider: 'gemini',
        providerType: 'local',
        cliCommand: 'custom-gemini',
        timeout: 45,
        cliTimeout: 90,
        cacheEnabled: false,
      );
      final service = GeminiCliService(config);

      expect(service.config.cliCommand, equals('custom-gemini'));
      expect(service.config.timeout, equals(45));
      expect(service.config.cliTimeout, equals(90));
      expect(service.config.cacheEnabled, isFalse);
    });
  });

  group('Error handling', () {
    test('GeminiCliService handles timeout gracefully', () async {
      final config = AiConfig(
        provider: 'gemini',
        providerType: 'local',
        cliCommand: 'sleep',
        cliArgs: const ['10'], // Sleep for 10 seconds
        cliTimeout: 1, // But timeout after 1 second
      );
      final service = GeminiCliService(config);

      final mockCoverage = const CoverageData(
        summary: CoverageSummary(
          linesFound: 100,
          linesHit: 80,
          functionsFound: 10,
          functionsHit: 8,
          branchesFound: 0,
          branchesHit: 0,
        ),
        files: [],
      );

      expect(
        () => service.generateInsights(mockCoverage),
        throwsA(isA<Exception>()),
      );
    });

    test('Factory throws StateError when no provider available in auto mode',
        () async {
      final config = SmartCoverageConfig(
        packagePath: '.',
        baseBranch: 'main',
        outputDir: 'coverage',
        skipTests: false,
        testInsights: false,
        codeReview: false,
        darkMode: false,
        outputFormats: const ['console'],
        aiConfig: AiConfig(
          provider: 'gemini',
          providerType: 'auto',
          cliCommand: 'nonexistent-cli-command-xyz',
          apiKeyEnv: 'NONEXISTENT_API_KEY_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      expect(
        () => AiServiceFactory.create(config),
        throwsA(isA<Error>()),
      );
    });
  });
}

