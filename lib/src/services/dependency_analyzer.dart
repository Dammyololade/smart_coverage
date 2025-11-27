import 'dart:io';

import 'package:path/path.dart' as path;

/// {@template dependency_analyzer}
/// Service for analyzing Dart file dependencies and building dependency graphs
/// {@endtemplate}
abstract class DependencyAnalyzer {
  /// Build a map of file -> files that depend on it (reverse dependencies)
  Future<Map<String, Set<String>>> buildReverseDependencyGraph(
    String packagePath,
  );

  /// Get all files that depend on the given files (directly or transitively)
  Future<Set<String>> getDependentFiles(
    List<String> modifiedFiles,
    String packagePath, {
    bool transitive = true,
  });

  /// Parse imports from a Dart file
  Future<List<String>> parseImports(String filePath);
}

/// {@template dependency_analyzer_impl}
/// Implementation of dependency analyzer service
/// {@endtemplate}
class DependencyAnalyzerImpl implements DependencyAnalyzer {
  /// {@macro dependency_analyzer_impl}
  const DependencyAnalyzerImpl();

  /// Regex to match import statements
  static final _importRegex = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Regex to match export statements
  static final _exportRegex = RegExp(
    r'''^\s*export\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Regex to match part statements
  static final _partRegex = RegExp(
    r'''^\s*part\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Regex to match part of statements
  static final _partOfRegex = RegExp(
    r'''^\s*part\s+of\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  @override
  Future<Map<String, Set<String>>> buildReverseDependencyGraph(
    String packagePath,
  ) async {
    final reverseDeps = <String, Set<String>>{};
    final packageName = await _getPackageName(packagePath);

    // Get all Dart files in lib directory
    final libDir = Directory(path.join(packagePath, 'lib'));
    if (!await libDir.exists()) {
      return reverseDeps;
    }

    final dartFiles = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity.path);
      }
    }

    // Build forward dependency map first (file -> what it imports)
    final forwardDeps = <String, Set<String>>{};

    for (final filePath in dartFiles) {
      final imports = await parseImports(filePath);
      final resolvedImports = <String>{};

      for (final import in imports) {
        final resolved = _resolveImport(
          import,
          filePath,
          packagePath,
          packageName,
        );
        if (resolved != null) {
          resolvedImports.add(resolved);
        }
      }

      // Normalize path relative to package
      final relativePath = _getRelativePath(filePath, packagePath);
      forwardDeps[relativePath] = resolvedImports;
    }

    // Invert to get reverse dependencies (file -> files that depend on it)
    for (final entry in forwardDeps.entries) {
      final file = entry.key;
      final dependencies = entry.value;

      for (final dep in dependencies) {
        reverseDeps.putIfAbsent(dep, () => <String>{}).add(file);
      }
    }

    return reverseDeps;
  }

  @override
  Future<Set<String>> getDependentFiles(
    List<String> modifiedFiles,
    String packagePath, {
    bool transitive = true,
  }) async {
    final reverseDeps = await buildReverseDependencyGraph(packagePath);
    final dependents = <String>{};
    final visited = <String>{};

    // Normalize modified file paths
    final normalizedModified = modifiedFiles
        .map((f) => _normalizePath(f, packagePath))
        .where((f) => f != null)
        .cast<String>()
        .toSet();

    if (transitive) {
      // BFS to find all transitive dependents
      final queue = <String>[...normalizedModified];

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        if (visited.contains(current)) continue;
        visited.add(current);

        final fileDependents = reverseDeps[current] ?? <String>{};
        for (final dependent in fileDependents) {
          if (!visited.contains(dependent)) {
            dependents.add(dependent);
            queue.add(dependent);
          }
        }
      }
    } else {
      // Only direct dependents
      for (final file in normalizedModified) {
        final fileDependents = reverseDeps[file] ?? <String>{};
        dependents.addAll(fileDependents);
      }
    }

    return dependents;
  }

  @override
  Future<List<String>> parseImports(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final imports = <String>[];

      // Parse import statements
      for (final match in _importRegex.allMatches(content)) {
        final importPath = match.group(1);
        if (importPath != null) {
          imports.add(importPath);
        }
      }

      // Parse export statements
      for (final match in _exportRegex.allMatches(content)) {
        final exportPath = match.group(1);
        if (exportPath != null) {
          imports.add(exportPath);
        }
      }

      // Parse part statements
      for (final match in _partRegex.allMatches(content)) {
        final partPath = match.group(1);
        if (partPath != null) {
          imports.add(partPath);
        }
      }

      // Parse part of statements
      for (final match in _partOfRegex.allMatches(content)) {
        final partOfPath = match.group(1);
        if (partOfPath != null) {
          imports.add(partOfPath);
        }
      }

      return imports;
    } catch (e) {
      return [];
    }
  }

  /// Get package name from pubspec.yaml
  Future<String?> _getPackageName(String packagePath) async {
    final pubspecFile = File(path.join(packagePath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      return null;
    }

    try {
      final content = await pubspecFile.readAsString();
      final nameMatch = RegExp(r'^name:\s*(\S+)', multiLine: true)
          .firstMatch(content);
      return nameMatch?.group(1);
    } catch (e) {
      return null;
    }
  }

  /// Resolve an import path to a file path relative to the package
  String? _resolveImport(
    String importPath,
    String currentFilePath,
    String packagePath,
    String? packageName,
  ) {
    // Skip dart: imports
    if (importPath.startsWith('dart:')) {
      return null;
    }

    // Skip external package imports (not our package)
    if (importPath.startsWith('package:')) {
      final packagePart = importPath.substring(8); // Remove 'package:'
      final slashIndex = packagePart.indexOf('/');
      if (slashIndex == -1) return null;

      final importPackageName = packagePart.substring(0, slashIndex);

      // Only process imports from our own package
      if (importPackageName != packageName) {
        return null;
      }

      // Convert package import to relative path
      final relativePart = packagePart.substring(slashIndex + 1);
      return 'lib/$relativePart';
    }

    // Relative import
    if (importPath.startsWith('.')) {
      final currentDir = path.dirname(currentFilePath);
      final resolvedPath = path.normalize(path.join(currentDir, importPath));
      return _getRelativePath(resolvedPath, packagePath);
    }

    return null;
  }

  /// Get path relative to package root
  String _getRelativePath(String filePath, String packagePath) {
    final normalized = path.normalize(filePath);
    final packageNormalized = path.normalize(packagePath);

    if (normalized.startsWith(packageNormalized)) {
      var relative = normalized.substring(packageNormalized.length);
      if (relative.startsWith('/') || relative.startsWith(r'\')) {
        relative = relative.substring(1);
      }
      return relative.replaceAll(r'\', '/');
    }

    return filePath.replaceAll(r'\', '/');
  }

  /// Normalize a file path for comparison
  String? _normalizePath(String filePath, String packagePath) {
    // Remove leading ./ or /
    var normalized = filePath
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp(r'^\.?/'), '');

    // If it's an absolute path, make it relative
    final packageNormalized = packagePath.replaceAll(r'\', '/');
    if (normalized.startsWith(packageNormalized)) {
      normalized = normalized.substring(packageNormalized.length);
      if (normalized.startsWith('/')) {
        normalized = normalized.substring(1);
      }
    }

    // Ensure lib/ prefix for source files
    if (!normalized.startsWith('lib/') &&
        !normalized.startsWith('test/') &&
        !normalized.startsWith('bin/')) {
      // Try to add lib/ prefix
      if (File(path.join(packagePath, 'lib', normalized)).existsSync()) {
        normalized = 'lib/$normalized';
      }
    }

    return normalized;
  }
}

