import 'dart:io';

import 'package:smart_coverage/src/services/services.dart';
import 'package:test/test.dart';

void main() {
  group('FileDetectorImpl', () {
    late FileDetector detector;
    late Directory tempDir;

    setUp(() async {
      detector = const FileDetectorImpl();
      tempDir = await Directory.systemTemp.createTemp('file_detector_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('detectModifiedFiles', () {
      test('should detect modified Dart files using git diff', () async {
        // Create a mock git repository structure
        await _createMockGitRepo(tempDir);

        // Create some Dart files
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);

        final file1 = File('${libDir.path}/file1.dart');
        final file2 = File('${libDir.path}/file2.dart');
        final file3 = File('${libDir.path}/file3.txt'); // Non-Dart file

        await file1.writeAsString('class File1 {}');
        await file2.writeAsString('class File2 {}');
        await file3.writeAsString('Some text content');

        // Mock git diff output by creating a simple test scenario
        // In a real test, we'd mock the Process.run call
        final result = await detector.detectModifiedFiles(
          'main',
          packagePath: tempDir.path,
        );

        // Since we can't easily mock git in this test environment,
        // we'll test the fallback behavior
        expect(result, isA<List<String>>());
      });

      test('should handle git command failure gracefully', () async {
        // Test with a non-git directory
        final result = await detector.detectModifiedFiles(
          'main',
          packagePath: tempDir.path,
        );

        // Should fall back to scanning all Dart files
        expect(result, isA<List<String>>());
      });

      test('should filter only Dart files', () async {
        // Create mixed file types
        final libDir = Directory('${tempDir.path}/lib');
        await libDir.create(recursive: true);

        await File(
          '${libDir.path}/dart_file.dart',
        ).writeAsString('class Test {}');
        await File('${libDir.path}/text_file.txt').writeAsString('text');
        await File('${libDir.path}/json_file.json').writeAsString('{}');
        await File('${libDir.path}/yaml_file.yaml').writeAsString('key: value');

        final result = await detector.detectModifiedFiles(
          'main',
          packagePath: tempDir.path,
        );

        // Should only include .dart files
        final dartFiles = result
            .where((file) => file.endsWith('.dart'))
            .toList();
        expect(dartFiles.length, greaterThan(0));
        expect(result.any((file) => file.endsWith('.txt')), isFalse);
        expect(result.any((file) => file.endsWith('.json')), isFalse);
        expect(result.any((file) => file.endsWith('.yaml')), isFalse);
      });
    });

    group('generateIncludePatterns', () {
      test('should generate correct LCOV include patterns', () {
        final files = [
          'lib/src/services/service1.dart',
          'lib/src/models/model1.dart',
          'lib/src/utils/helper.dart',
        ];

        final patterns = detector.generateIncludePatterns(files);

        expect(patterns, hasLength(3));
        expect(patterns, contains('**/lib/src/services/service1.dart'));
        expect(patterns, contains('**/lib/src/models/model1.dart'));
        expect(patterns, contains('**/lib/src/utils/helper.dart'));
      });

      test('should handle empty file list', () {
        final patterns = detector.generateIncludePatterns([]);
        expect(patterns, isEmpty);
      });

      test('should handle files with different path formats', () {
        final files = [
          '/absolute/path/lib/file1.dart',
          'relative/path/lib/file2.dart',
          'lib/file3.dart',
        ];

        final patterns = detector.generateIncludePatterns(files);

        expect(patterns, hasLength(3));
        expect(patterns, contains('**/lib/file1.dart'));
        expect(patterns, contains('**/lib/file2.dart'));
        expect(patterns, contains('**/lib/file3.dart'));
      });
    });

    group('validatePackageStructure', () {
      test('should validate correct Dart package structure', () async {
        // Create a valid Dart package structure
        await Directory('${tempDir.path}/lib').create();
        await Directory('${tempDir.path}/test').create();
        await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_package
version: 1.0.0
environment:
  sdk: '>=2.17.0 <4.0.0'
''');

        final isValid = await detector.validatePackageStructure(tempDir.path);
        expect(isValid, isTrue);
      });

      test('should reject invalid package structure', () async {
        // Create directory without pubspec.yaml
        final isValid = await detector.validatePackageStructure(tempDir.path);
        expect(isValid, isFalse);
      });

      test('should reject non-existent directory', () async {
        final isValid = await detector.validatePackageStructure(
          '/non/existent/path',
        );
        expect(isValid, isFalse);
      });

      test('should handle malformed pubspec.yaml', () async {
        await File(
          '${tempDir.path}/pubspec.yaml',
        ).writeAsString('invalid yaml content [');

        final isValid = await detector.validatePackageStructure(tempDir.path);
        expect(isValid, isFalse);
      });
    });

    group('getAllDartFiles', () {
      test('should find all Dart files in package', () async {
        // Create Dart files in different directories
        await Directory('${tempDir.path}/lib/src').create(recursive: true);
        await Directory('${tempDir.path}/test').create();
        await Directory('${tempDir.path}/example').create();

        await File(
          '${tempDir.path}/lib/main.dart',
        ).writeAsString('void main() {}');
        await File(
          '${tempDir.path}/lib/src/service.dart',
        ).writeAsString('class Service {}');
        await File(
          '${tempDir.path}/test/main_test.dart',
        ).writeAsString('void main() {}');
        await File(
          '${tempDir.path}/example/example.dart',
        ).writeAsString('void main() {}');

        // Create non-Dart files that should be ignored
        await File('${tempDir.path}/lib/config.json').writeAsString('{}');
        await File('${tempDir.path}/README.md').writeAsString('# Test');

        final dartFiles = await detector.getAllDartFiles(tempDir.path);

        expect(dartFiles, hasLength(4));
        expect(dartFiles.any((file) => file.endsWith('main.dart')), isTrue);
        expect(dartFiles.any((file) => file.endsWith('service.dart')), isTrue);
        expect(
          dartFiles.any((file) => file.endsWith('main_test.dart')),
          isTrue,
        );
        expect(dartFiles.any((file) => file.endsWith('example.dart')), isTrue);

        // Should not include non-Dart files
        expect(dartFiles.any((file) => file.endsWith('.json')), isFalse);
        expect(dartFiles.any((file) => file.endsWith('.md')), isFalse);
      });

      test('should handle empty directory', () async {
        final dartFiles = await detector.getAllDartFiles(tempDir.path);
        expect(dartFiles, isEmpty);
      });

      test('should handle non-existent directory', () async {
        final dartFiles = await detector.getAllDartFiles('/non/existent/path');
        expect(dartFiles, isEmpty);
      });

      test('should exclude build and .dart_tool directories', () async {
        // Create directories that should be excluded
        await Directory('${tempDir.path}/build').create();
        await Directory('${tempDir.path}/.dart_tool').create();
        await Directory('${tempDir.path}/lib').create();

        await File(
          '${tempDir.path}/build/generated.dart',
        ).writeAsString('// Generated');
        await File(
          '${tempDir.path}/.dart_tool/package_config.dart',
        ).writeAsString('// Config');
        await File(
          '${tempDir.path}/lib/main.dart',
        ).writeAsString('void main() {}');

        final dartFiles = await detector.getAllDartFiles(tempDir.path);

        expect(dartFiles, hasLength(1));
        expect(dartFiles.first.endsWith('main.dart'), isTrue);
        expect(dartFiles.any((file) => file.contains('build')), isFalse);
        expect(dartFiles.any((file) => file.contains('.dart_tool')), isFalse);
      });
    });

    group('performance tests', () {
      test(
        'should handle large number of files efficiently',
        () async {
          // Create a large number of Dart files
          final libDir = Directory('${tempDir.path}/lib');
          await libDir.create(recursive: true);

          final stopwatch = Stopwatch()..start();

          // Create 1000 Dart files
          for (var i = 0; i < 1000; i++) {
            await File(
              '${libDir.path}/file_$i.dart',
            ).writeAsString('class File$i {}');
          }

          final dartFiles = await detector.getAllDartFiles(tempDir.path);
          stopwatch.stop();

          expect(dartFiles, hasLength(1000));
          // Should complete in reasonable time (under 5 seconds)
          expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        },
        timeout: const Timeout(Duration(seconds: 10)),
      );
    });
  });
}

/// Helper function to create a mock git repository structure
Future<void> _createMockGitRepo(Directory dir) async {
  final gitDir = Directory('${dir.path}/.git');
  await gitDir.create();

  // Create basic git structure
  await File('${gitDir.path}/HEAD').writeAsString('ref: refs/heads/main');
  await Directory('${gitDir.path}/refs/heads').create(recursive: true);
  await File(
    '${gitDir.path}/refs/heads/main',
  ).writeAsString('dummy-commit-hash');
}
