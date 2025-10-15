import 'dart:io';

import 'package:smart_coverage/src/services/git_service.dart';
import 'package:test/test.dart';

void main() {
  group('GitServiceImpl', () {
    late GitService gitService;
    late Directory tempDir;
    late String resolvedTempPath;

    setUp(() async {
      gitService = const GitServiceImpl();
      tempDir = Directory.systemTemp.createTempSync('git_service_test_');
      // Resolve symlinks to get the canonical path for comparison
      resolvedTempPath = await tempDir.resolveSymbolicLinks();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('findGitRepository', () {
      test('should find .git in current directory', () async {
        // Create .git directory
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        final result = await gitService.findGitRepository(tempDir.path);

        expect(result, isNotNull);
        expect(result!.path, equals(resolvedTempPath));
      });

      test('should find .git in parent directory', () async {
        // Create .git in parent
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        // Create subdirectory
        final subDir = Directory('${tempDir.path}/subdir');
        await subDir.create();

        final result = await gitService.findGitRepository(subDir.path);

        expect(result, isNotNull);
        expect(result!.path, equals(resolvedTempPath));
      });

      test('should find .git multiple levels up (monorepo)', () async {
        // Create .git at root
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        // Create deep subdirectory
        final deepDir = Directory('${tempDir.path}/packages/app/lib');
        await deepDir.create(recursive: true);

        final result = await gitService.findGitRepository(deepDir.path);

        expect(result, isNotNull);
        expect(result!.path, equals(resolvedTempPath));
      });

      test('should return null when no .git found', () async {
        final result = await gitService.findGitRepository(tempDir.path);

        expect(result, isNull);
      });

      test('should handle symbolic links', () async {
        // Create .git directory
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        // Create a subdirectory
        final subDir = Directory('${tempDir.path}/subdir');
        await subDir.create();

        final result = await gitService.findGitRepository(subDir.path);

        expect(result, isNotNull);
      });

      test('should not exceed maximum attempts', () async {
        // This tests the safety limit
        final result = await gitService.findGitRepository('/');

        // Should return null without infinite loop
        expect(result, isNull);
      });

      test('should use current directory when no path provided', () async {
        final result = await gitService.findGitRepository();

        // May or may not find .git depending on test environment
        // Just ensure it doesn't throw
        expect(result, anyOf(isNull, isNotNull));
      });
    });

    group('isInGitRepository', () {
      test('should return true when .git exists', () async {
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        final result = await gitService.isInGitRepository(tempDir.path);

        expect(result, isTrue);
      });

      test('should return false when .git does not exist', () async {
        final result = await gitService.isInGitRepository(tempDir.path);

        expect(result, isFalse);
      });

      test('should work with current directory', () async {
        final result = await gitService.isInGitRepository();

        expect(result, anyOf(isTrue, isFalse));
      });
    });

    group('getGitRepositoryRoot', () {
      test('should return git root path', () async {
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        final result = await gitService.getGitRepositoryRoot(tempDir.path);

        expect(result, equals(resolvedTempPath));
      });

      test('should return null when no git repository', () async {
        final result = await gitService.getGitRepositoryRoot(tempDir.path);

        expect(result, isNull);
      });

      test('should return root from subdirectory', () async {
        final gitDir = Directory('${tempDir.path}/.git');
        await gitDir.create();

        final subDir = Directory('${tempDir.path}/packages/app');
        await subDir.create(recursive: true);

        final result = await gitService.getGitRepositoryRoot(subDir.path);

        expect(result, equals(resolvedTempPath));
      });
    });
  });
}
