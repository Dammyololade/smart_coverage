import 'dart:io';

import 'package:smart_coverage/src/services/git_service.dart';

/// {@template file_detector}
/// Service for detecting modified files in a Git repository
/// {@endtemplate}
abstract class FileDetector {
  /// Detect modified files compared to base branch
  Future<List<String>> detectModifiedFiles(
    String baseBranch, {
    String? packagePath,
  });

  /// Generate LCOV include patterns for modified files
  List<String> generateIncludePatterns(List<String> modifiedFiles);

  /// Validate package structure
  Future<bool> validatePackageStructure(String packagePath);

  /// Get all Dart files in the package
  Future<List<String>> getAllDartFiles(String packagePath);
}

/// {@template file_detector_impl}
/// Implementation of file detector service with Git integration
/// {@endtemplate}
class FileDetectorImpl implements FileDetector {
  /// {@macro file_detector_impl}
  const FileDetectorImpl();

  @override
  Future<List<String>> detectModifiedFiles(
    String baseBranch, {
    String? packagePath,
  }) async {
    final workingDir = packagePath ?? Directory.current.path;

    // Check if we're in a Git repository (supports monorepos)
    final gitService = GitServiceImpl();
    final gitRoot = await gitService.getGitRepositoryRoot(workingDir);

    if (gitRoot == null) {
      // Not in a Git repository - fallback: return all Dart files in the package
      print('ℹ️  Not in a Git repository (searched from: $workingDir).');
      print('ℹ️  Analyzing all Dart files in the package.');
      return getAllDartFiles(workingDir);
    }

    print('📂 Git repository found at: $gitRoot');
    print('📍 Current package: ${_getRelativePackagePath(workingDir, gitRoot)}');

    try {
      // Get modified files using git diff from the repository root
      final result = await Process.run(
        'git',
        ['diff', '--name-only', baseBranch, 'HEAD'],
        workingDirectory: gitRoot,
      );

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        print('⚠️  Git diff failed: $stderr');
        print('ℹ️  Falling back to uncommitted changes...');

        // Fallback: compare with working directory changes
        final fallbackResult = await Process.run(
          'git',
          ['diff', '--name-only', 'HEAD'],
          workingDirectory: gitRoot,
        );

        if (fallbackResult.exitCode != 0) {
          print('ℹ️  No uncommitted changes found. Analyzing all Dart files in the package.');
          // Final fallback: return all Dart files
          return await getAllDartFiles(workingDir);
        }

        final uncommittedFiles = fallbackResult.stdout
            .toString()
            .trim()
            .split('\n')
            .where((file) => file.isNotEmpty)
            .toList();

        print('🔍 Found ${uncommittedFiles.length} uncommitted file(s) in repository');

        final filteredFiles = _filterAndAdjustPaths(uncommittedFiles, workingDir, gitRoot);

        if (filteredFiles.isEmpty) {
          print('ℹ️  No modified Dart files found in this package. Analyzing all Dart files.');
          return await getAllDartFiles(workingDir);
        }

        print('📝 Analyzing ${filteredFiles.length} modified file(s) from uncommitted changes');
        return filteredFiles;
      }

      final modifiedFiles = result.stdout
          .toString()
          .trim()
          .split('\n')
          .where((file) => file.isNotEmpty)
          .toList();

      print('🔍 Found ${modifiedFiles.length} modified file(s) compared to $baseBranch');

      // If no committed changes found, check for uncommitted changes
      if (modifiedFiles.isEmpty) {
        print('ℹ️  No committed changes found. Checking uncommitted changes...');

        final fallbackResult = await Process.run(
          'git',
          ['diff', '--name-only', 'HEAD'],
          workingDirectory: gitRoot,
        );

        if (fallbackResult.exitCode == 0) {
          final uncommittedFiles = fallbackResult.stdout
              .toString()
              .trim()
              .split('\n')
              .where((file) => file.isNotEmpty)
              .toList();

          final filteredFiles = _filterAndAdjustPaths(uncommittedFiles, workingDir, gitRoot);

          if (filteredFiles.isEmpty) {
            print('ℹ️  No modified Dart files found in this package. Analyzing all Dart files.');
            return await getAllDartFiles(workingDir);
          }

          print('📝 Analyzing ${filteredFiles.length} modified file(s) from uncommitted changes');
          return filteredFiles;
        }

        print('ℹ️  No changes detected. Analyzing all Dart files in the package.');
        return await getAllDartFiles(workingDir);
      }

      // Filter and adjust paths for monorepo support
      final filteredFiles = _filterAndAdjustPaths(modifiedFiles, workingDir, gitRoot);

      if (filteredFiles.isEmpty) {
        final pkgPath = _getRelativePackagePath(workingDir, gitRoot);
        print('ℹ️  No modified Dart files found in this package${pkgPath.isNotEmpty ? " ($pkgPath)" : ""}.');
        print('ℹ️  Analyzing all Dart files in the package.');
        return await getAllDartFiles(workingDir);
      }

      print('📝 Analyzing ${filteredFiles.length} modified file(s) compared to $baseBranch');
      return filteredFiles;
    } catch (e) {
      print('⚠️  Git operation failed: $e');
      print('ℹ️  Analyzing all Dart files in the package.');
      // Final fallback: return all Dart files when git operations fail
      return getAllDartFiles(workingDir);
    }
  }

  @override
  List<String> generateIncludePatterns(List<String> modifiedFiles) {
    final patterns = <String>[];

    for (final file in modifiedFiles) {
      if (file.endsWith('.dart')) {
        // Convert file path to LCOV pattern
        // For both absolute and relative paths, use ** pattern to match any directory depth
        if (file.startsWith('/')) {
          // For absolute paths, extract from 'lib' onwards if it contains 'lib'
          final libIndex = file.indexOf('/lib/');
          if (libIndex != -1) {
            final pathFromLib = file.substring(
              libIndex + 1,
            ); // +1 to skip the leading slash
            patterns.add('**/$pathFromLib');
          } else {
            // If no 'lib' directory, just use the filename
            final fileName = file.split('/').last;
            patterns.add('**/$fileName');
          }
        } else {
          // For relative paths, extract from 'lib' onwards if it contains 'lib'
          final libIndex = file.indexOf('lib/');
          if (libIndex != -1) {
            final pathFromLib = file.substring(libIndex);
            patterns.add('**/$pathFromLib');
          } else {
            // If no 'lib' directory, use the full relative path
            patterns.add('**/$file');
          }
        }
      }
    }

    return patterns;
  }

  @override
  Future<bool> validatePackageStructure(String packagePath) async {
    final packageDir = Directory(packagePath);
    if (!await packageDir.exists()) {
      return false;
    }

    // Check for pubspec.yaml
    final pubspecFile = File('$packagePath/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      return false;
    }

    // Check for lib directory
    final libDir = Directory('$packagePath/lib');
    if (!await libDir.exists()) {
      return false;
    }

    // Validate pubspec.yaml content
    try {
      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('name:')) {
        return false;
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  @override
  Future<List<String>> getAllDartFiles(String packagePath) async {
    final packageDir = Directory(packagePath);
    if (!await packageDir.exists()) {
      return [];
    }

    final dartFiles = <String>[];
    await for (final entity in packageDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Convert to relative path from package root
        final relativePath = entity.path.substring(packagePath.length + 1);
        dartFiles.add(relativePath);
      }
    }

    return _filterDartFiles(dartFiles);
  }

  /// Filter files to only include Dart files in the current package and adjust paths
  List<String> _filterAndAdjustPaths(
    List<String> files,
    String workingDir,
    String gitRoot,
  ) {
    // Get the relative path from git root to working directory
    final relativePath = _getRelativePackagePath(workingDir, gitRoot);

    return files
        .where((file) => file.isNotEmpty && file.endsWith('.dart'))
        // Only include files from the current package (or if we're at git root, include all)
        .where((file) {
          if (relativePath.isEmpty) return true; // At git root
          return file.startsWith('$relativePath/') || file.startsWith(relativePath);
        })
        // Remove the package path prefix to make paths relative to package
        .map((file) {
          if (relativePath.isEmpty) return file;
          if (file.startsWith('$relativePath/')) {
            return file.substring(relativePath.length + 1);
          }
          return file;
        })
        .where((file) => file.isNotEmpty)
        .toList()
        .where(
          (file) => !file.startsWith('.dart_tool/'),
        ) // Exclude generated files
        .where((file) => !file.startsWith('build/')) // Exclude build directory
        .where(
          (file) => !file.contains('/generated/'),
        ) // Exclude generated files
        .where((file) => !file.endsWith('.g.dart')) // Exclude generated files
        .where(
          (file) => !file.endsWith('.freezed.dart'),
        ) // Exclude generated files
        .toList();
  }

  /// Get the relative path from git root to working directory
  String _getRelativePackagePath(String workingDir, String gitRoot) {
    // Normalize paths
    final normalizedWorking = workingDir.replaceAll(r'\', '/');
    final normalizedGit = gitRoot.replaceAll(r'\', '/');

    if (normalizedWorking == normalizedGit) return '';

    // Get relative path
    if (normalizedWorking.startsWith(normalizedGit)) {
      final relative = normalizedWorking.substring(normalizedGit.length);
      // Remove leading slash
      return relative.startsWith('/') ? relative.substring(1) : relative;
    }

    return '';
  }

  /// Filter files to include only Dart files
  List<String> _filterDartFiles(List<String> files) {
    return files
        .where((file) => file.isNotEmpty && file.endsWith('.dart'))
        .where(
          (file) => !file.startsWith('.dart_tool/'),
        ) // Exclude generated files
        .where((file) => !file.startsWith('build/')) // Exclude build directory
        .where(
          (file) => !file.contains('/generated/'),
        ) // Exclude generated files
        .where((file) => !file.endsWith('.g.dart')) // Exclude generated files
        .where(
          (file) => !file.endsWith('.freezed.dart'),
        ) // Exclude generated files
        .toList();
  }
}
