import 'dart:io';

import 'package:smart_coverage/src/services/performance_optimizer.dart';
import 'package:smart_coverage/src/services/performance_profiler.dart';
import 'package:test/test.dart';

void main() {
  group('PerformanceOptimizer', () {
    late PerformanceProfiler profiler;
    late PerformanceOptimizer optimizer;

    setUp(() {
      profiler = PerformanceProfiler();
      optimizer = PerformanceOptimizer(profiler: profiler);
    });

    group('getRecommendations', () {
      test('suggests batch processing for large projects', () {
        final result = optimizer.getRecommendations(
          fileCount: 1500,
          totalSizeBytes: 50 * 1024 * 1024,
          lastRunDuration: const Duration(seconds: 30),
        );

        expect(result.recommendations, isNotEmpty);
        expect(
          result.recommendations.any((r) => r.contains('Large project')),
          isTrue,
        );
      });

      test('suggests streaming for large codebases', () {
        final result = optimizer.getRecommendations(
          fileCount: 500,
          totalSizeBytes: 150 * 1024 * 1024,
          lastRunDuration: const Duration(seconds: 30),
        );

        expect(
          result.recommendations.any((r) => r.contains('Large codebase')),
          isTrue,
        );
      });

      test('suggests performance improvements for slow runs', () {
        final result = optimizer.getRecommendations(
          fileCount: 500,
          totalSizeBytes: 50 * 1024 * 1024,
          lastRunDuration: const Duration(minutes: 6),
        );

        expect(
          result.recommendations.any((r) => r.contains('Slow analysis')),
          isTrue,
        );
      });

      test('provides default recommendation for manageable projects', () {
        final result = optimizer.getRecommendations(
          fileCount: 50,
          totalSizeBytes: 5 * 1024 * 1024,
          lastRunDuration: const Duration(seconds: 10),
        );

        expect(
          result.recommendations.any((r) => r.contains('manageable')),
          isTrue,
        );
      });

      test('includes suggested settings for large projects', () {
        final result = optimizer.getRecommendations(
          fileCount: 1500,
          totalSizeBytes: 50 * 1024 * 1024,
          lastRunDuration: const Duration(seconds: 30),
        );

        expect(result.suggestedSettings, isNotEmpty);
        expect(result.suggestedSettings.containsKey('use_isolates'), isTrue);
        expect(result.suggestedSettings.containsKey('batch_size'), isTrue);
      });

      test('includes streaming settings for large codebases', () {
        final result = optimizer.getRecommendations(
          fileCount: 100,
          totalSizeBytes: 150 * 1024 * 1024,
          lastRunDuration: const Duration(seconds: 30),
        );

        expect(result.suggestedSettings.containsKey('use_streaming'), isTrue);
      });

      test('includes concurrency settings for slow runs', () {
        final result = optimizer.getRecommendations(
          fileCount: 500,
          totalSizeBytes: 50 * 1024 * 1024,
          lastRunDuration: const Duration(minutes: 6),
        );

        expect(result.suggestedSettings.containsKey('max_concurrency'), isTrue);
        expect(result.suggestedSettings.containsKey('enable_caching'), isTrue);
      });

      test('estimates performance improvement', () {
        final result = optimizer.getRecommendations(
          fileCount: 1500,
          totalSizeBytes: 150 * 1024 * 1024,
          lastRunDuration: const Duration(minutes: 6),
        );

        expect(result.estimatedImprovement, greaterThan(0));
      });

      test('caps improvement estimation at 70%', () {
        final result = optimizer.getRecommendations(
          fileCount: 5000,
          totalSizeBytes: 500 * 1024 * 1024,
          lastRunDuration: const Duration(minutes: 20),
        );

        expect(result.estimatedImprovement, lessThanOrEqualTo(70.0));
      });
    });

    group('processFilesInBatches', () {
      test('processes files in batches', () async {
        final files = List.generate(150, (i) => 'file_$i.dart');
        final processed = <String>[];

        await optimizer.processFilesInBatches(
          files,
          (filePath) async {
            processed.add(filePath);
            return filePath.length;
          },
        );

        expect(processed.length, equals(150));
        expect(processed, containsAll(files));
      });

      test('returns results in order', () async {
        final files = ['a.dart', 'b.dart', 'c.dart'];

        final results = await optimizer.processFilesInBatches(
          files,
          (filePath) async => filePath,
        );

        expect(results, equals(files));
      });

      test('calls progress callback', () async {
        final files = List.generate(10, (i) => 'file_$i.dart');
        var progressCalls = 0;

        await optimizer.processFilesInBatches(
          files,
          (filePath) async => filePath,
          onProgress: (processed, total) {
            progressCalls++;
            expect(processed, lessThanOrEqualTo(total));
            expect(total, equals(10));
          },
        );

        expect(progressCalls, greaterThan(0));
      });

      test('handles empty file list', () async {
        final results = await optimizer.processFilesInBatches(
          [],
          (filePath) async => filePath,
        );

        expect(results, isEmpty);
      });

      test('handles processor errors gracefully', () async {
        final files = ['good.dart', 'bad.dart', 'good2.dart'];

        final results = await optimizer.processFilesInBatches(
          files,
          (filePath) async {
            if (filePath == 'bad.dart') {
              throw Exception('Processing error');
            }
            return filePath;
          },
        );

        // Should continue processing other files
        expect(results.length, lessThan(3));
      });

      test('uses custom operation name', () async {
        final files = ['file.dart'];

        await optimizer.processFilesInBatches(
          files,
          (filePath) async => filePath,
          operationName: 'custom_operation',
        );

        // Should complete without errors
      });
    });

    group('readFileOptimized', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('optimizer_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('reads small file normally', () async {
        final file = File('${tempDir.path}/small.txt');
        await file.writeAsString('Hello World');

        final content = await optimizer.readFileOptimized(file.path);

        expect(content, equals('Hello World'));
      });

      test('reads large file using streaming', () async {
        final file = File('${tempDir.path}/large.txt');
        final largeContent = 'A' * (15 * 1024 * 1024); // 15MB
        await file.writeAsString(largeContent);

        final content = await optimizer.readFileOptimized(file.path);

        expect(content.length, equals(largeContent.length));
      });
    });

    group('scanDirectoryOptimized', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('optimizer_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('scans directory for Dart files', () async {
        await File(
          '${tempDir.path}/file1.dart',
        ).writeAsString('void main() {}');
        await File('${tempDir.path}/file2.dart').writeAsString('class Test {}');
        await File('${tempDir.path}/file3.txt').writeAsString('not dart');

        final files = await optimizer.scanDirectoryOptimized(tempDir.path);

        expect(files.length, equals(2));
        expect(files.every((f) => f.endsWith('.dart')), isTrue);
      });

      test('respects extension filter', () async {
        await File('${tempDir.path}/file.dart').writeAsString('dart');
        await File('${tempDir.path}/file.md').writeAsString('markdown');

        final files = await optimizer.scanDirectoryOptimized(
          tempDir.path,
          extensions: ['.md'],
        );

        expect(files.length, equals(1));
        expect(files.first.endsWith('.md'), isTrue);
      });

      test('excludes files by pattern', () async {
        await Directory('${tempDir.path}/src').create();
        await File('${tempDir.path}/src/main.dart').writeAsString('main');
        await Directory('${tempDir.path}/test').create();
        await File('${tempDir.path}/test/test.dart').writeAsString('test');

        final files = await optimizer.scanDirectoryOptimized(
          tempDir.path,
          excludePatterns: ['test'],
        );

        expect(files.length, equals(1));
      });

      test('respects max depth', () async {
        await Directory('${tempDir.path}/a/b/c').create(recursive: true);
        await File('${tempDir.path}/file.dart').writeAsString('root');
        await File('${tempDir.path}/a/file.dart').writeAsString('level1');
        await File('${tempDir.path}/a/b/file.dart').writeAsString('level2');
        await File('${tempDir.path}/a/b/c/file.dart').writeAsString('level3');

        final files = await optimizer.scanDirectoryOptimized(
          tempDir.path,
          maxDepth: 2,
        );

        expect(files.length, lessThan(4));
      });

      test('handles empty directory', () async {
        final files = await optimizer.scanDirectoryOptimized(tempDir.path);

        expect(files, isEmpty);
      });

      test('finds files recursively', () async {
        await Directory('${tempDir.path}/sub1/sub2').create(recursive: true);
        await File('${tempDir.path}/root.dart').writeAsString('root');
        await File('${tempDir.path}/sub1/nested.dart').writeAsString('nested1');
        await File('${tempDir.path}/sub1/sub2/deep.dart').writeAsString('deep');

        final files = await optimizer.scanDirectoryOptimized(tempDir.path);

        expect(files.length, equals(3));
      });
    });

    group('OptimizationRecommendations', () {
      test('has correct properties', () {
        final recommendations = OptimizationRecommendations(
          recommendations: ['test1', 'test2'],
          suggestedSettings: {'key': 'value'},
          estimatedImprovement: 25.0,
        );

        expect(recommendations.recommendations, equals(['test1', 'test2']));
        expect(recommendations.suggestedSettings, equals({'key': 'value'}));
        expect(recommendations.estimatedImprovement, equals(25.0));
      });
    });

    group('integration', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('optimizer_int_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('full optimization workflow', () async {
        // Create test files
        final files = <String>[];
        for (var i = 0; i < 100; i++) {
          final file = File('${tempDir.path}/file_$i.dart');
          await file.writeAsString('void main() {}');
          files.add(file.path);
        }

        // Get recommendations
        final recommendations = optimizer.getRecommendations(
          fileCount: files.length,
          totalSizeBytes: 100 * 1024,
          lastRunDuration: const Duration(seconds: 5),
        );

        expect(recommendations.recommendations, isNotEmpty);

        // Process files in batches
        final results = await optimizer.processFilesInBatches(
          files,
          (filePath) async {
            final content = await optimizer.readFileOptimized(filePath);
            return content.length;
          },
        );

        expect(results.length, equals(100));

        // Scan directory
        final foundFiles = await optimizer.scanDirectoryOptimized(tempDir.path);
        expect(foundFiles.length, equals(100));
      });

      test('handles mixed file sizes efficiently', () async {
        // Create small and large files
        final smallFile = File('${tempDir.path}/small.dart');
        await smallFile.writeAsString('small');

        final largeFile = File('${tempDir.path}/large.dart');
        await largeFile.writeAsString('A' * (15 * 1024 * 1024)); // 15MB

        // Read both
        final smallContent = await optimizer.readFileOptimized(smallFile.path);
        final largeContent = await optimizer.readFileOptimized(largeFile.path);

        expect(smallContent, equals('small'));
        expect(largeContent.length, equals(15 * 1024 * 1024));
      });
    });
  });
}
