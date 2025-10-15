import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_coverage/src/services/debug_service.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

void main() {
  group('DebugServiceImpl', () {
    late Logger logger;
    late DebugServiceImpl debugService;
    late Directory tempDir;

    setUp(() {
      logger = _MockLogger();
      debugService = DebugServiceImpl(logger: logger);
      tempDir = Directory.systemTemp.createTempSync('debug_service_test_');

      // Setup logger mocks
      when(() => logger.progress(any())).thenReturn(_MockProgress());
      when(() => logger.detail(any())).thenReturn(null);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('setDebugMode', () {
      test('enables debug mode', () {
        expect(debugService.isDebugEnabled, isFalse);

        debugService.setDebugMode(true);

        expect(debugService.isDebugEnabled, isTrue);
        verify(() => logger.detail('🐛 Debug mode enabled')).called(1);
      });

      test('disables debug mode', () {
        debugService.setDebugMode(true);
        expect(debugService.isDebugEnabled, isTrue);

        debugService.setDebugMode(false);

        expect(debugService.isDebugEnabled, isFalse);
      });
    });

    group('startProgress', () {
      test('starts progress with message', () {
        final progress = debugService.startProgress('Testing...');

        expect(progress, isA<Progress>());
        verify(() => logger.progress('Testing...')).called(1);
      });
    });

    group('logDebug', () {
      test('does not log when debug mode is disabled', () {
        debugService.setDebugMode(false);

        debugService.logDebug('Test message');

        verifyNever(() => logger.detail(any()));
      });

      test('logs message when debug mode is enabled', () {
        debugService.setDebugMode(true);
        clearInteractions(logger); // Clear the setDebugMode log

        debugService.logDebug('Test message');

        verify(() => logger.detail('🔍 DEBUG: Test message')).called(1);
      });

      test('logs message with context when debug mode is enabled', () {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        debugService.logDebug('Test message', context: {
          'key1': 'value1',
          'key2': 42,
        });

        verify(() => logger.detail('🔍 DEBUG: Test message')).called(1);
        verify(() => logger.detail('   key1: value1')).called(1);
        verify(() => logger.detail('   key2: 42')).called(1);
      });

      test('logs message without context when context is empty', () {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        debugService.logDebug('Test message', context: {});

        verify(() => logger.detail('🔍 DEBUG: Test message')).called(1);
        verifyNever(() => logger.detail(any(that: contains('   '))));
      });
    });

    group('logPerformance', () {
      test('does not log when debug mode is disabled', () {
        debugService.setDebugMode(false);

        debugService.logPerformance('test_operation', const Duration(milliseconds: 100));

        verifyNever(() => logger.detail(any()));
      });

      test('logs performance when debug mode is enabled', () {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        debugService.logPerformance('test_operation', const Duration(milliseconds: 100));

        verify(() => logger.detail('⏱️  PERFORMANCE: test_operation took 100ms')).called(1);
      });

      test('logs performance with metrics when debug mode is enabled', () {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        debugService.logPerformance(
          'test_operation',
          const Duration(milliseconds: 150),
          metrics: {
            'files': 10,
            'lines': 1000,
          },
        );

        verify(() => logger.detail('⏱️  PERFORMANCE: test_operation took 150ms')).called(1);
        verify(() => logger.detail('   files: 10')).called(1);
        verify(() => logger.detail('   lines: 1000')).called(1);
      });

      test('logs performance without metrics when metrics are empty', () {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        debugService.logPerformance(
          'test_operation',
          const Duration(milliseconds: 200),
          metrics: {},
        );

        verify(() => logger.detail('⏱️  PERFORMANCE: test_operation took 200ms')).called(1);
        verifyNever(() => logger.detail(any(that: contains('   '))));
      });
    });

    group('logSystemInfo', () {
      test('does not log when debug mode is disabled', () async {
        debugService.setDebugMode(false);

        await debugService.logSystemInfo();

        verifyNever(() => logger.detail(any()));
      });

      test('logs system information when debug mode is enabled', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logSystemInfo();

        verify(() => logger.detail('💻 SYSTEM INFO:')).called(1);
        verify(() => logger.detail(any(that: contains('Platform:')))).called(1);
        verify(() => logger.detail(any(that: contains('Version:')))).called(1);
        verify(() => logger.detail(any(that: contains('Dart version:')))).called(1);
        verify(() => logger.detail(any(that: contains('Working directory:')))).called(1);
      });

      test('checks Dart CLI availability', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logSystemInfo();

        verify(() => logger.detail(any(that: contains('Dart CLI:')))).called(1);
      });

      test('checks Flutter CLI availability', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logSystemInfo();

        verify(() => logger.detail(any(that: contains('Flutter CLI:')))).called(1);
      });
    });

    group('logGitInfo', () {
      test('does not log when debug mode is disabled', () async {
        debugService.setDebugMode(false);

        await debugService.logGitInfo();

        verifyNever(() => logger.detail(any()));
      });

      test('logs git information when debug mode is enabled', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logGitInfo();

        verify(() => logger.detail('🌿 GIT INFO:')).called(1);
      });

      test('handles git not available gracefully', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logGitInfo();

        // Should log something about git info
        verify(() => logger.detail(any())).called(greaterThan(0));
      });
    });

    group('logProjectStructure', () {
      test('does not log when debug mode is disabled', () async {
        debugService.setDebugMode(false);

        await debugService.logProjectStructure(tempDir.path);

        verifyNever(() => logger.detail(any()));
      });

      test('logs project structure when debug mode is enabled', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logProjectStructure(tempDir.path);

        verify(() => logger.detail('📁 PROJECT STRUCTURE:')).called(1);
      });

      test('logs error when project directory does not exist', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logProjectStructure('${tempDir.path}/nonexistent');

        verify(() => logger.detail('📁 PROJECT STRUCTURE:')).called(1);
        verify(() => logger.detail(any(that: contains('does not exist')))).called(1);
      });

      test('checks for key project files and directories', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        // Create some key files
        await File('${tempDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${tempDir.path}/lib').create();
        await Directory('${tempDir.path}/test').create();

        await debugService.logProjectStructure(tempDir.path);

        verify(() => logger.detail(any(that: contains('pubspec.yaml')))).called(1);
        verify(() => logger.detail(any(that: contains('lib/')))).called(greaterThan(0));
        verify(() => logger.detail(any(that: contains('test/')))).called(1);
      });

      test('counts test files in test directory', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        // Create test directory with some test files
        final testDir = Directory('${tempDir.path}/test');
        await testDir.create();
        await File('${tempDir.path}/test/test1_test.dart').writeAsString('void main() {}');
        await File('${tempDir.path}/test/test2_test.dart').writeAsString('void main() {}');

        await debugService.logProjectStructure(tempDir.path);

        verify(() => logger.detail(any(that: contains('Test files:')))).called(1);
      });

      test('handles errors when analyzing project structure', () async {
        debugService.setDebugMode(true);
        clearInteractions(logger);

        await debugService.logProjectStructure(tempDir.path);

        // Should not throw, should log structure info
        verify(() => logger.detail('📁 PROJECT STRUCTURE:')).called(1);
      });
    });

    group('createDebugReport', () {
      test('creates debug report file', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        expect(reportPath, contains('smart_coverage_debug_'));
        expect(File(reportPath).existsSync(), isTrue);
      });

      test('includes system information in report', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        final content = await File(reportPath).readAsString();

        expect(content, contains('Smart Coverage Debug Report'));
        expect(content, contains('SYSTEM INFORMATION:'));
        expect(content, contains('Platform:'));
        expect(content, contains('Dart version:'));
      });

      test('includes git information in report', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        final content = await File(reportPath).readAsString();

        expect(content, contains('GIT INFORMATION:'));
      });

      test('includes project structure in report', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        final content = await File(reportPath).readAsString();

        expect(content, contains('PROJECT STRUCTURE:'));
        expect(content, contains('pubspec.yaml:'));
        expect(content, contains('lib/:'));
        expect(content, contains('test/:'));
      });

      test('includes additional information when provided', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
          additionalInfo: {
            'testKey': 'testValue',
            'errorCode': 42,
          },
        );

        final content = await File(reportPath).readAsString();

        expect(content, contains('ADDITIONAL INFORMATION:'));
        expect(content, contains('testKey: testValue'));
        expect(content, contains('errorCode: 42'));
      });

      test('handles missing additional information', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
          additionalInfo: {},
        );

        final content = await File(reportPath).readAsString();

        expect(content, isNot(contains('ADDITIONAL INFORMATION:')));
      });

      test('handles null additional information', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        final content = await File(reportPath).readAsString();

        expect(content, isNot(contains('ADDITIONAL INFORMATION:')));
      });

      test('creates report with timestamp in filename', () async {
        final reportPath1 = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        // Wait a bit to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 10));

        final reportPath2 = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        expect(reportPath1, isNot(equals(reportPath2)));
      });

      test('report contains timestamp in content', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        final content = await File(reportPath).readAsString();

        expect(content, contains('Generated:'));
      });

      test('handles git errors gracefully in report', () async {
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
        );

        final content = await File(reportPath).readAsString();

        // Should still create report even if git is not available
        expect(content, contains('GIT INFORMATION:'));
      });
    });

    group('isDebugEnabled', () {
      test('returns false by default', () {
        final service = DebugServiceImpl(logger: logger);
        expect(service.isDebugEnabled, isFalse);
      });

      test('returns true after enabling debug mode', () {
        debugService.setDebugMode(true);
        expect(debugService.isDebugEnabled, isTrue);
      });

      test('returns false after disabling debug mode', () {
        debugService.setDebugMode(true);
        debugService.setDebugMode(false);
        expect(debugService.isDebugEnabled, isFalse);
      });
    });

    group('integration tests', () {
      test('full debug workflow with all features', () async {
        // Enable debug mode
        debugService.setDebugMode(true);
        clearInteractions(logger);

        // Start progress
        final progress = debugService.startProgress('Testing...');
        expect(progress, isA<Progress>());

        // Log debug message
        debugService.logDebug('Debug message', context: {'key': 'value'});

        // Log performance
        debugService.logPerformance(
          'operation',
          const Duration(milliseconds: 100),
          metrics: {'count': 5},
        );

        // Log system info
        await debugService.logSystemInfo();

        // Log git info
        await debugService.logGitInfo();

        // Create project structure
        await File('${tempDir.path}/pubspec.yaml').writeAsString('name: test');
        await Directory('${tempDir.path}/lib').create();

        // Log project structure
        await debugService.logProjectStructure(tempDir.path);

        // Create debug report
        final reportPath = await debugService.createDebugReport(
          projectPath: tempDir.path,
          additionalInfo: {'testRun': 'integration'},
        );

        // Verify report was created
        expect(File(reportPath).existsSync(), isTrue);

        // Verify all logging occurred
        verify(() => logger.progress('Testing...')).called(1);
        verify(() => logger.detail(any(that: contains('DEBUG:')))).called(greaterThan(0));
        verify(() => logger.detail(any(that: contains('PERFORMANCE:')))).called(greaterThan(0));
        verify(() => logger.detail(any(that: contains('SYSTEM INFO:')))).called(greaterThan(0));
        verify(() => logger.detail(any(that: contains('GIT INFO:')))).called(greaterThan(0));
        verify(() => logger.detail(any(that: contains('PROJECT STRUCTURE:')))).called(greaterThan(0));
      });

      test('operations are silent when debug mode is disabled', () async {
        debugService.setDebugMode(false);

        // Try all operations
        debugService.logDebug('Message');
        debugService.logPerformance('op', const Duration(milliseconds: 100));
        await debugService.logSystemInfo();
        await debugService.logGitInfo();
        await debugService.logProjectStructure(tempDir.path);

        // Nothing should be logged
        verifyNever(() => logger.detail(any()));
      });
    });
  });
}

