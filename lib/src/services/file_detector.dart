import 'dart:io';

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

    // Check if we're in a Git repository
    final gitDir = Directory('$workingDir/.git');
    if (!await gitDir.exists()) {
      // Fallback: return all Dart files in the package
      return getAllDartFiles(workingDir);
    }

    try {
      // Get modified files using git diff
      final result = await Process.run(
        'git',
        ['diff', '--name-only', baseBranch, 'HEAD'],
        workingDirectory: workingDir,
      );

      if (result.exitCode != 0) {
        // Fallback: compare with working directory changes
        final fallbackResult = await Process.run(
          'git',
          ['diff', '--name-only', 'HEAD'],
          workingDirectory: workingDir,
        );

        if (fallbackResult.exitCode != 0) {
          // Final fallback: return all Dart files
          return await getAllDartFiles(workingDir);
        }

        return _filterDartFiles(
          fallbackResult.stdout.toString().trim().split('\n'),
        );
      }

      final modifiedFiles = result.stdout
          .toString()
          .trim()
          .split('\n')
          .where((file) => file.isNotEmpty)
          .toList();

      // If no committed changes found, check for uncommitted changes
      if (modifiedFiles.isEmpty) {
        final fallbackResult = await Process.run(
          'git',
          ['diff', '--name-only', 'HEAD'],
          workingDirectory: workingDir,
        );

        if (fallbackResult.exitCode == 0) {
          final uncommittedFiles = fallbackResult.stdout
              .toString()
              .trim()
              .split('\n')
              .where((file) => file.isNotEmpty)
              .toList();
          return _filterDartFiles(uncommittedFiles);
        }
      }

      return _filterDartFiles(modifiedFiles);
    } catch (e) {
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
