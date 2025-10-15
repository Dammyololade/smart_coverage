import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;

import 'performance_profiler.dart';

/// Performance optimizer for handling large codebases efficiently
class PerformanceOptimizer {
  final PerformanceProfiler _profiler;
  final int _maxConcurrency;
  final int _batchSize;
  final bool _useIsolates;

  PerformanceOptimizer({
    required PerformanceProfiler profiler,
    int? maxConcurrency,
    int? batchSize,
    bool useIsolates = true,
  }) : _profiler = profiler,
       _maxConcurrency = maxConcurrency ?? Platform.numberOfProcessors,
       _batchSize = batchSize ?? 50,
       _useIsolates = useIsolates;

  /// Process files in optimized batches
  Future<List<T>> processFilesInBatches<T>(
    List<String> filePaths,
    Future<T> Function(String filePath) processor, {
    String? operationName,
    void Function(int processed, int total)? onProgress,
  }) async {
    final operation = operationName ?? 'batch_processing';

    return await _profiler.profileFunction(
      operation,
      () async {
        final results = <T>[];
        final batches = _createBatches(filePaths, _batchSize);

        for (int i = 0; i < batches.length; i++) {
          final batch = batches[i];
          final batchResults = await _processBatch(
            batch,
            processor,
            '$operation.batch_${i + 1}',
          );

          results.addAll(batchResults);

          onProgress?.call(results.length, filePaths.length);

          // Allow garbage collection between batches
          if (i < batches.length - 1) {
            await Future<void>.delayed(Duration(milliseconds: 10));
          }
        }

        return results;
      },
      metadata: {
        'total_files': filePaths.length,
        'batch_count': (filePaths.length / _batchSize).ceil(),
        'batch_size': _batchSize,
        'use_isolates': _useIsolates,
      },
    );
  }

  /// Process a single batch of files
  Future<List<T>> _processBatch<T>(
    List<String> filePaths,
    Future<T> Function(String filePath) processor,
    String operationName,
  ) async {
    return await _profiler.profileFunction(
      operationName,
      () async {
        if (_useIsolates && filePaths.length > 10) {
          return await _processWithIsolates(filePaths, processor);
        } else {
          return await _processSequentially(filePaths, processor);
        }
      },
      metadata: {
        'files_in_batch': filePaths.length,
        'processing_method': _useIsolates ? 'isolates' : 'sequential',
      },
    );
  }

  /// Process files using isolates for CPU-intensive tasks
  Future<List<T>> _processWithIsolates<T>(
    List<String> filePaths,
    Future<T> Function(String filePath) processor,
  ) async {
    final chunks = _createBatches(
      filePaths,
      math.max(1, filePaths.length ~/ _maxConcurrency),
    );
    final futures = <Future<List<T>>>[];

    for (final chunk in chunks) {
      futures.add(_processChunkInIsolate(chunk, processor));
    }

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  /// Process a chunk of files in an isolate
  Future<List<T>> _processChunkInIsolate<T>(
    List<String> filePaths,
    Future<T> Function(String filePath) processor,
  ) async {
    // For now, we'll process sequentially within each isolate
    // In a real implementation, you'd want to serialize the processor function
    // and send it to the isolate
    return await _processSequentially(filePaths, processor);
  }

  /// Process files sequentially
  Future<List<T>> _processSequentially<T>(
    List<String> filePaths,
    Future<T> Function(String filePath) processor,
  ) async {
    final results = <T>[];

    for (final filePath in filePaths) {
      try {
        final result = await processor(filePath);
        results.add(result);
      } catch (e) {
        // Log error but continue processing other files
        print('Error processing $filePath: $e');
      }
    }

    return results;
  }

  /// Create batches from a list of items
  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];

    for (int i = 0; i < items.length; i += batchSize) {
      final end = math.min(i + batchSize, items.length);
      batches.add(items.sublist(i, end));
    }

    return batches;
  }

  /// Optimize file reading for large files
  Future<String> readFileOptimized(String filePath) async {
    return await _profiler.profileFunction(
      'file_read_optimized',
      () async {
        final file = File(filePath);
        final stat = await file.stat();

        // For large files, use streaming
        if (stat.size > 10 * 1024 * 1024) {
          // 10MB
          return await _readFileStreaming(file);
        } else {
          return await file.readAsString();
        }
      },
      metadata: {
        'file_path': filePath,
        'file_size': await File(filePath).length(),
      },
    );
  }

  /// Read large files using streaming
  Future<String> _readFileStreaming(File file) async {
    final buffer = StringBuffer();
    final stream = file.openRead();

    await for (final chunk in stream.transform(
      const SystemEncoding().decoder,
    )) {
      buffer.write(chunk);
    }

    return buffer.toString();
  }

  /// Optimize directory scanning for large projects
  Future<List<String>> scanDirectoryOptimized(
    String directoryPath, {
    List<String> extensions = const ['.dart'],
    List<String> excludePatterns = const [],
    int maxDepth = 10,
  }) async {
    return await _profiler.profileFunction(
      'directory_scan_optimized',
      () async {
        final files = <String>[];
        final directory = Directory(directoryPath);

        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            final filePath = entity.path;
            final relativePath = path.relative(filePath, from: directoryPath);

            // Check depth
            if (relativePath.split(path.separator).length > maxDepth) {
              continue;
            }

            // Check extension
            if (extensions.isNotEmpty &&
                !extensions.any((ext) => filePath.endsWith(ext))) {
              continue;
            }

            // Check exclude patterns
            if (excludePatterns.any(
              (pattern) => relativePath.contains(pattern),
            )) {
              continue;
            }

            files.add(filePath);
          }
        }

        return files;
      },
      metadata: {
        'directory_path': directoryPath,
        'extensions': extensions,
        'exclude_patterns': excludePatterns,
        'max_depth': maxDepth,
      },
    );
  }

  /// Get optimization recommendations based on project size
  OptimizationRecommendations getRecommendations({
    required int fileCount,
    required int totalSizeBytes,
    required Duration lastRunDuration,
  }) {
    final recommendations = <String>[];
    final settings = <String, dynamic>{};

    // File count recommendations
    if (fileCount > 1000) {
      recommendations.add(
        'Large project detected ($fileCount files). '
        'Consider using batch processing and isolates.',
      );
      settings['use_isolates'] = true;
      settings['batch_size'] = math.min(100, fileCount ~/ 10);
    }

    // Size recommendations
    if (totalSizeBytes > 100 * 1024 * 1024) {
      // 100MB
      recommendations.add(
        'Large codebase detected (${_formatBytes(totalSizeBytes)}). '
        'Consider streaming file reads and memory optimization.',
      );
      settings['use_streaming'] = true;
      settings['memory_limit'] = '512MB';
    }

    // Performance recommendations
    if (lastRunDuration.inMinutes > 5) {
      recommendations.add(
        'Slow analysis detected (${lastRunDuration.inMinutes}m). '
        'Consider increasing concurrency and using caching.',
      );
      settings['max_concurrency'] = Platform.numberOfProcessors * 2;
      settings['enable_caching'] = true;
    }

    // Default optimizations
    if (recommendations.isEmpty) {
      recommendations.add(
        'Project size is manageable. Current settings should work well.',
      );
    }

    return OptimizationRecommendations(
      recommendations: recommendations,
      suggestedSettings: settings,
      estimatedImprovement: _estimateImprovement(fileCount, totalSizeBytes),
    );
  }

  /// Estimate performance improvement percentage
  double _estimateImprovement(int fileCount, int totalSizeBytes) {
    double improvement = 0.0;

    if (fileCount > 500) improvement += 20.0; // Batch processing
    if (fileCount > 1000) improvement += 15.0; // Isolates
    if (totalSizeBytes > 50 * 1024 * 1024) improvement += 25.0; // Streaming

    return math.min(improvement, 70.0); // Cap at 70% improvement
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Optimization recommendations
class OptimizationRecommendations {
  final List<String> recommendations;
  final Map<String, dynamic> suggestedSettings;
  final double estimatedImprovement;

  OptimizationRecommendations({
    required this.recommendations,
    required this.suggestedSettings,
    required this.estimatedImprovement,
  });
}
