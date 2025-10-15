import 'dart:io';

import 'package:smart_coverage/src/services/performance_profiler.dart';
import 'package:test/test.dart';

void main() {
  group('PerformanceProfiler', () {
    late PerformanceProfiler profiler;

    setUp(() {
      profiler = PerformanceProfiler();
    });

    group('enable and disable', () {
      test('starts disabled by default', () {
        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(0));
      });

      test('enable clears previous data', () async {
        profiler.enable();
        await profiler.profileFunction('test', () async {});

        profiler.enable(); // Enable again

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(0));
      });

      test('disable stops profiling', () {
        profiler.enable();
        profiler.startOperation('test');
        profiler.disable();
        profiler.endOperation('test');

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(0));
      });
    });

    group('startOperation and endOperation', () {
      test('does not profile when disabled', () {
        profiler.startOperation('test');
        profiler.endOperation('test');

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(0));
      });

      test('profiles operation when enabled', () {
        profiler.enable();
        profiler.startOperation('test');
        profiler.endOperation('test');

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(1));
      });

      test('ignores endOperation without startOperation', () {
        profiler.enable();
        profiler.endOperation('test');

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(0));
      });

      test('records operation with metadata', () {
        profiler.enable();
        profiler.startOperation('test');
        profiler.endOperation('test', metadata: {'key': 'value'});

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(1));
      });
    });

    group('profileFunction', () {
      test('executes and profiles function', () async {
        profiler.enable();
        var executed = false;

        await profiler.profileFunction('test', () async {
          executed = true;
        });

        expect(executed, isTrue);
        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(1));
      });

      test('returns function result', () async {
        profiler.enable();

        final result = await profiler.profileFunction('test', () async {
          return 42;
        });

        expect(result, equals(42));
      });

      test('profiles even when function throws', () async {
        profiler.enable();

        try {
          await profiler.profileFunction('test', () async {
            throw Exception('Test error');
          });
        } catch (e) {
          // Expected
        }

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(1));
      });

      test('rethrows function exceptions', () async {
        profiler.enable();

        expect(
          () => profiler.profileFunction('test', () async {
            throw Exception('Test error');
          }),
          throwsException,
        );
      });

      test('records metadata', () async {
        profiler.enable();

        await profiler.profileFunction(
          'test',
          () async {},
          metadata: {'key': 'value'},
        );

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(1));
      });
    });

    group('getSummary', () {
      test('returns empty summary when no operations', () {
        profiler.enable();

        final summary = profiler.getSummary();

        expect(summary.totalOperations, equals(0));
        expect(summary.totalDuration, equals(Duration.zero));
        expect(summary.totalMemoryUsed, equals(0));
        expect(summary.peakMemoryUsage, equals(0));
        expect(summary.operationBreakdown, isEmpty);
      });

      test('calculates total duration correctly', () async {
        profiler.enable();

        await profiler.profileFunction('op1', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await profiler.profileFunction('op2', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(2));
        expect(summary.totalDuration.inMilliseconds, greaterThan(15));
      });

      test('aggregates same operations', () async {
        profiler.enable();

        await profiler.profileFunction('test', () async {});
        await profiler.profileFunction('test', () async {});
        await profiler.profileFunction('test', () async {});

        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(3));
        expect(summary.operationBreakdown.containsKey('test'), isTrue);
        expect(summary.operationBreakdown['test']!.count, equals(3));
      });

      test('calculates average duration', () async {
        profiler.enable();

        await profiler.profileFunction('test', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await profiler.profileFunction('test', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });

        final summary = profiler.getSummary();
        final stats = summary.operationBreakdown['test']!;
        expect(stats.averageDuration.inMilliseconds, greaterThan(5));
      });

      test('tracks max duration', () async {
        profiler.enable();

        await profiler.profileFunction('test', () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        });
        await profiler.profileFunction('test', () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });

        final summary = profiler.getSummary();
        final stats = summary.operationBreakdown['test']!;
        expect(stats.maxDuration.inMilliseconds, greaterThan(15));
      });

      test('includes recommendations', () async {
        profiler.enable();

        await profiler.profileFunction('test', () async {});

        final summary = profiler.getSummary();
        expect(summary.recommendations, isNotEmpty);
      });
    });

    group('exportToFile', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('profiler_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('exports summary to file', () async {
        profiler.enable();
        await profiler.profileFunction('test', () async {});

        final filePath = '${tempDir.path}/report.txt';
        await profiler.exportToFile(filePath);

        final file = File(filePath);
        expect(file.existsSync(), isTrue);
      });

      test('file contains performance report header', () async {
        profiler.enable();
        await profiler.profileFunction('test', () async {});

        final filePath = '${tempDir.path}/report.txt';
        await profiler.exportToFile(filePath);

        final content = await File(filePath).readAsString();
        expect(content, contains('Smart Coverage Performance Report'));
        expect(content, contains('Generated:'));
      });

      test('file contains summary section', () async {
        profiler.enable();
        await profiler.profileFunction('test', () async {});

        final filePath = '${tempDir.path}/report.txt';
        await profiler.exportToFile(filePath);

        final content = await File(filePath).readAsString();
        expect(content, contains('## Summary'));
        expect(content, contains('Total Operations:'));
        expect(content, contains('Total Duration:'));
      });

      test('file contains operation breakdown', () async {
        profiler.enable();
        await profiler.profileFunction('test_op', () async {});

        final filePath = '${tempDir.path}/report.txt';
        await profiler.exportToFile(filePath);

        final content = await File(filePath).readAsString();
        expect(content, contains('## Operation Breakdown'));
        expect(content, contains('### test_op'));
      });

      test('file contains recommendations', () async {
        profiler.enable();
        await profiler.profileFunction('test', () async {});

        final filePath = '${tempDir.path}/report.txt';
        await profiler.exportToFile(filePath);

        final content = await File(filePath).readAsString();
        expect(content, contains('## Recommendations'));
      });
    });

    group('PerformanceSummary', () {
      test('has correct properties', () {
        final summary = PerformanceSummary(
          totalOperations: 5,
          totalDuration: const Duration(seconds: 10),
          totalMemoryUsed: 1024,
          peakMemoryUsage: 2048,
          operationBreakdown: {},
          recommendations: ['test'],
        );

        expect(summary.totalOperations, equals(5));
        expect(summary.totalDuration, equals(const Duration(seconds: 10)));
        expect(summary.totalMemoryUsed, equals(1024));
        expect(summary.peakMemoryUsage, equals(2048));
        expect(summary.recommendations, equals(['test']));
      });
    });

    group('OperationStats', () {
      test('has correct properties', () {
        final stats = OperationStats(
          count: 3,
          totalDuration: const Duration(seconds: 30),
          averageDuration: const Duration(seconds: 10),
          totalMemory: 3072,
          averageMemory: 1024,
          maxDuration: const Duration(seconds: 15),
          maxMemory: 2048,
        );

        expect(stats.count, equals(3));
        expect(stats.totalDuration, equals(const Duration(seconds: 30)));
        expect(stats.averageDuration, equals(const Duration(seconds: 10)));
        expect(stats.totalMemory, equals(3072));
        expect(stats.averageMemory, equals(1024));
        expect(stats.maxDuration, equals(const Duration(seconds: 15)));
        expect(stats.maxMemory, equals(2048));
      });
    });

    group('integration', () {
      test('profiles multiple operations correctly', () async {
        profiler.enable();

        await profiler.profileFunction('load_data', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await profiler.profileFunction('process_data', () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await profiler.profileFunction('load_data', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });

        final summary = profiler.getSummary();

        expect(summary.totalOperations, equals(3));
        expect(summary.operationBreakdown.length, equals(2));
        expect(summary.operationBreakdown['load_data']!.count, equals(2));
        expect(summary.operationBreakdown['process_data']!.count, equals(1));
      });

      test('full workflow with export', () async {
        profiler.enable();

        // Profile various operations
        await profiler.profileFunction('op1', () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }, metadata: {'type': 'fast'});

        await profiler.profileFunction('op2', () async {
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }, metadata: {'type': 'slow'});

        // Get summary
        final summary = profiler.getSummary();
        expect(summary.totalOperations, equals(2));

        // Export to file
        final tempDir = Directory.systemTemp.createTempSync();
        final filePath = '${tempDir.path}/report.txt';
        await profiler.exportToFile(filePath);

        expect(File(filePath).existsSync(), isTrue);

        // Cleanup
        tempDir.deleteSync(recursive: true);
      });
    });
  });
}
