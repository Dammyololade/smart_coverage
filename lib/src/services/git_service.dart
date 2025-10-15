import 'dart:io';

/// {@template git_service}
/// Service for Git repository operations and detection
/// {@endtemplate}
abstract class GitService {
  /// Find the Git repository root directory starting from the given path
  Future<Directory?> findGitRepository([String? startPath]);

  /// Check if the given directory is within a Git repository
  Future<bool> isInGitRepository([String? path]);

  /// Get the Git repository root path
  Future<String?> getGitRepositoryRoot([String? startPath]);
}

/// {@template git_service_impl}
/// Implementation of Git service with proper monorepo support
/// {@endtemplate}
class GitServiceImpl implements GitService {
  /// {@macro git_service_impl}
  const GitServiceImpl();

  @override
  Future<Directory?> findGitRepository([String? startPath]) async {
    // Resolve to absolute path to handle relative paths and symlinks
    final startDir = startPath ?? Directory.current.path;
    var currentDir = Directory(startDir);

    // Resolve symlinks and get canonical path
    try {
      currentDir = Directory(await currentDir.resolveSymbolicLinks());
    } catch (e) {
      // If resolving fails, use the original path
      currentDir = Directory(startDir);
    }

    // Traverse up the directory tree looking for .git
    var attempts = 0;
    const maxAttempts = 100; // Safety limit to prevent infinite loops

    while (attempts < maxAttempts) {
      final gitDir = Directory('${currentDir.path}/.git');

      if (await gitDir.exists()) {
        return currentDir;
      }
      
      // Get parent directory
      final parent = currentDir.parent;

      // Check if we've reached the root directory
      // Compare resolved paths to handle different representations
      final currentPath = currentDir.path.replaceAll(r'\', '/');
      final parentPath = parent.path.replaceAll(r'\', '/');

      if (currentPath == parentPath || parentPath == '/' || parentPath.endsWith(':/')) {
        // We've reached the root directory without finding .git
        break;
      }
      
      currentDir = parent;
      attempts++;
    }
    
    return null;
  }

  @override
  Future<bool> isInGitRepository([String? path]) async {
    final gitRepo = await findGitRepository(path);
    return gitRepo != null;
  }

  @override
  Future<String?> getGitRepositoryRoot([String? startPath]) async {
    final gitRepo = await findGitRepository(startPath);
    return gitRepo?.path;
  }
}