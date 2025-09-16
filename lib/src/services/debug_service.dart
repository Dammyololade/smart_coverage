import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// {@template debug_service}
/// Service for enhanced debugging and logging capabilities
/// {@endtemplate}
abstract class DebugService {
  /// Start a progress indicator with a message
  Progress startProgress(String message);

  /// Log detailed debug information
  void logDebug(String message, {Map<String, dynamic>? context});

  /// Log performance metrics
  void logPerformance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metrics,
  });

  /// Log system information
  Future<void> logSystemInfo();

  /// Log git information
  Future<void> logGitInfo();

  /// Log project structure
  Future<void> logProjectStructure(String projectPath);

  /// Create a debug report
  Future<String> createDebugReport({
    required String projectPath,
    Map<String, dynamic>? additionalInfo,
  });

  /// Enable/disable debug mode
  void setDebugMode(bool enabled);

  /// Check if debug mode is enabled
  bool get isDebugEnabled;
}

/// {@template debug_service_impl}
/// Implementation of debug service
/// {@endtemplate}
class DebugServiceImpl implements DebugService {
  /// {@macro debug_service_impl}
  DebugServiceImpl({
    required Logger logger,
  }) : _logger = logger;

  final Logger _logger;
  bool _debugEnabled = false;

  @override
  Progress startProgress(String message) {
    return _logger.progress(message);
  }

  @override
  void logDebug(String message, {Map<String, dynamic>? context}) {
    if (!_debugEnabled) return;

    _logger.detail('🔍 DEBUG: $message');
    if (context != null && context.isNotEmpty) {
      for (final entry in context.entries) {
        _logger.detail('   ${entry.key}: ${entry.value}');
      }
    }
  }

  @override
  void logPerformance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metrics,
  }) {
    if (!_debugEnabled) return;

    _logger.detail(
      '⏱️  PERFORMANCE: $operation took ${duration.inMilliseconds}ms',
    );
    if (metrics != null && metrics.isNotEmpty) {
      for (final entry in metrics.entries) {
        _logger.detail('   ${entry.key}: ${entry.value}');
      }
    }
  }

  @override
  Future<void> logSystemInfo() async {
    if (!_debugEnabled) return;

    _logger.detail('💻 SYSTEM INFO:');
    _logger.detail('   Platform: ${Platform.operatingSystem}');
    _logger.detail('   Version: ${Platform.operatingSystemVersion}');
    _logger.detail('   Dart version: ${Platform.version}');
    _logger.detail('   Working directory: ${Directory.current.path}');

    // Check Dart/Flutter installation
    try {
      final dartResult = await Process.run('dart', ['--version']);
      if (dartResult.exitCode == 0) {
        _logger.detail('   Dart CLI: Available');
      }
    } catch (e) {
      _logger.detail('   Dart CLI: Not available ($e)');
    }

    try {
      final flutterResult = await Process.run('flutter', ['--version']);
      if (flutterResult.exitCode == 0) {
        _logger.detail('   Flutter CLI: Available');
      }
    } catch (e) {
      _logger.detail('   Flutter CLI: Not available');
    }
  }

  @override
  Future<void> logGitInfo() async {
    if (!_debugEnabled) return;

    _logger.detail('🌿 GIT INFO:');

    try {
      // Current branch
      final branchResult = await Process.run('git', [
        'branch',
        '--show-current',
      ]);
      if (branchResult.exitCode == 0) {
        _logger.detail(
          '   Current branch: ${branchResult.stdout.toString().trim()}',
        );
      }

      // Remote URL
      final remoteResult = await Process.run('git', [
        'remote',
        'get-url',
        'origin',
      ]);
      if (remoteResult.exitCode == 0) {
        _logger.detail(
          '   Remote origin: ${remoteResult.stdout.toString().trim()}',
        );
      }

      // Last commit
      final commitResult = await Process.run('git', ['log', '-1', '--oneline']);
      if (commitResult.exitCode == 0) {
        _logger.detail(
          '   Last commit: ${commitResult.stdout.toString().trim()}',
        );
      }

      // Working tree status
      final statusResult = await Process.run('git', ['status', '--porcelain']);
      if (statusResult.exitCode == 0) {
        final changes = statusResult.stdout.toString().trim();
        if (changes.isEmpty) {
          _logger.detail('   Working tree: Clean');
        } else {
          _logger.detail(
            '   Working tree: ${changes.split('\n').length} changes',
          );
        }
      }
    } catch (e) {
      _logger.detail('   Git: Not available or not a git repository');
    }
  }

  @override
  Future<void> logProjectStructure(String projectPath) async {
    if (!_debugEnabled) return;

    _logger.detail('📁 PROJECT STRUCTURE:');

    final projectDir = Directory(projectPath);
    if (!projectDir.existsSync()) {
      _logger.detail('   Project directory does not exist: $projectPath');
      return;
    }

    // Key files and directories
    final keyPaths = [
      'pubspec.yaml',
      'lib/',
      'test/',
      'coverage/',
      'coverage/lcov.info',
      'smart_coverage.yaml',
      '.git/',
    ];

    for (final keyPath in keyPaths) {
      final fullPath = path.join(projectPath, keyPath);
      final exists =
          FileSystemEntity.typeSync(fullPath) != FileSystemEntityType.notFound;
      final icon = exists ? '✅' : '❌';
      _logger.detail('   $icon $keyPath');
    }

    // Count files in key directories
    try {
      final libDir = Directory(path.join(projectPath, 'lib'));
      if (libDir.existsSync()) {
        final dartFiles = libDir
            .listSync(recursive: true)
            .where((e) => e.path.endsWith('.dart'))
            .length;
        _logger.detail('   📊 Dart files in lib/: $dartFiles');
      }

      final testDir = Directory(path.join(projectPath, 'test'));
      if (testDir.existsSync()) {
        final testFiles = testDir
            .listSync(recursive: true)
            .where((e) => e.path.endsWith('.dart'))
            .length;
        _logger.detail('   📊 Test files: $testFiles');
      }
    } catch (e) {
      _logger.detail('   Error analyzing project structure: $e');
    }
  }

  @override
  Future<String> createDebugReport({
    required String projectPath,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final reportPath = path.join(
      projectPath,
      'smart_coverage_debug_$timestamp.txt',
    );

    final buffer = StringBuffer();
    buffer.writeln('Smart Coverage Debug Report');
    buffer.writeln('Generated: $timestamp');
    buffer.writeln('=' * 50);
    buffer.writeln();

    // System information
    buffer.writeln('SYSTEM INFORMATION:');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Version: ${Platform.operatingSystemVersion}');
    buffer.writeln('Dart version: ${Platform.version}');
    buffer.writeln('Working directory: ${Directory.current.path}');
    buffer.writeln();

    // Git information
    buffer.writeln('GIT INFORMATION:');
    try {
      final branchResult = await Process.run('git', [
        'branch',
        '--show-current',
      ]);
      if (branchResult.exitCode == 0) {
        buffer.writeln(
          'Current branch: ${branchResult.stdout.toString().trim()}',
        );
      }

      final statusResult = await Process.run('git', ['status', '--porcelain']);
      if (statusResult.exitCode == 0) {
        final changes = statusResult.stdout.toString().trim();
        buffer.writeln(
          'Working tree changes: ${changes.isEmpty ? 'None' : changes.split('\n').length}',
        );
      }
    } catch (e) {
      buffer.writeln('Git not available: $e');
    }
    buffer.writeln();

    // Project structure
    buffer.writeln('PROJECT STRUCTURE:');
    final keyPaths = [
      'pubspec.yaml',
      'lib/',
      'test/',
      'coverage/',
      'smart_coverage.yaml',
    ];
    for (final keyPath in keyPaths) {
      final fullPath = path.join(projectPath, keyPath);
      final exists =
          FileSystemEntity.typeSync(fullPath) != FileSystemEntityType.notFound;
      buffer.writeln('$keyPath: ${exists ? 'EXISTS' : 'MISSING'}');
    }
    buffer.writeln();

    // Additional information
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      buffer.writeln('ADDITIONAL INFORMATION:');
      for (final entry in additionalInfo.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }

    // Write to file
    final reportFile = File(reportPath);
    await reportFile.writeAsString(buffer.toString());

    return reportPath;
  }

  @override
  void setDebugMode(bool enabled) {
    _debugEnabled = enabled;
    if (enabled) {
      _logger.detail('🐛 Debug mode enabled');
    }
  }

  @override
  bool get isDebugEnabled => _debugEnabled;
}
