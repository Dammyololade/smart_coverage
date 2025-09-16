import 'dart:io';
import 'dart:math' as math;

/// Performance profiler for monitoring and optimizing Smart Coverage operations
class PerformanceProfiler {
  final Map<String, _ProfileData> _profiles = {};
  final List<_PerformanceMetric> _metrics = [];
  bool _isEnabled = false;

  /// Enable performance profiling
  void enable() {
    _isEnabled = true;
    _profiles.clear();
    _metrics.clear();
  }

  /// Disable performance profiling
  void disable() {
    _isEnabled = false;
  }

  /// Start profiling an operation
  void startOperation(String operationName) {
    if (!_isEnabled) return;

    _profiles[operationName] = _ProfileData(
      name: operationName,
      startTime: DateTime.now(),
      startMemory: _getCurrentMemoryUsage(),
    );
  }

  /// End profiling an operation
  void endOperation(String operationName, {Map<String, dynamic>? metadata}) {
    if (!_isEnabled || !_profiles.containsKey(operationName)) return;

    final profile = _profiles[operationName]!;
    final endTime = DateTime.now();
    final endMemory = _getCurrentMemoryUsage();

    final metric = _PerformanceMetric(
      operationName: operationName,
      duration: endTime.difference(profile.startTime),
      memoryUsed: endMemory - profile.startMemory,
      peakMemory: endMemory,
      metadata: metadata ?? {},
    );

    _metrics.add(metric);
    _profiles.remove(operationName);
  }

  /// Profile a function execution
  Future<T> profileFunction<T>(
    String operationName,
    Future<T> Function() function, {
    Map<String, dynamic>? metadata,
  }) async {
    startOperation(operationName);
    try {
      final result = await function();
      endOperation(operationName, metadata: metadata);
      return result;
    } catch (e) {
      endOperation(
        operationName,
        metadata: {...?metadata, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get performance summary
  PerformanceSummary getSummary() {
    if (_metrics.isEmpty) {
      return PerformanceSummary(
        totalOperations: 0,
        totalDuration: Duration.zero,
        totalMemoryUsed: 0,
        peakMemoryUsage: 0,
        operationBreakdown: {},
        recommendations: [],
      );
    }

    final totalDuration = _metrics.fold<Duration>(
      Duration.zero,
      (sum, metric) => sum + metric.duration,
    );

    final totalMemory = _metrics.fold<int>(
      0,
      (sum, metric) => sum + metric.memoryUsed,
    );

    final peakMemory = _metrics.fold<int>(
      0,
      (max, metric) => math.max(max, metric.peakMemory),
    );

    final operationBreakdown = <String, OperationStats>{};
    for (final metric in _metrics) {
      final existing = operationBreakdown[metric.operationName];
      if (existing == null) {
        operationBreakdown[metric.operationName] = OperationStats(
          count: 1,
          totalDuration: metric.duration,
          averageDuration: metric.duration,
          totalMemory: metric.memoryUsed,
          averageMemory: metric.memoryUsed,
          maxDuration: metric.duration,
          maxMemory: metric.memoryUsed,
        );
      } else {
        final newCount = existing.count + 1;
        final newTotalDuration = existing.totalDuration + metric.duration;
        final newTotalMemory = existing.totalMemory + metric.memoryUsed;

        operationBreakdown[metric.operationName] = OperationStats(
          count: newCount,
          totalDuration: newTotalDuration,
          averageDuration: Duration(
            microseconds: newTotalDuration.inMicroseconds ~/ newCount,
          ),
          totalMemory: newTotalMemory,
          averageMemory: newTotalMemory ~/ newCount,
          maxDuration: Duration(
            microseconds: math.max(
              existing.maxDuration.inMicroseconds,
              metric.duration.inMicroseconds,
            ),
          ),
          maxMemory: math.max(existing.maxMemory, metric.memoryUsed),
        );
      }
    }

    return PerformanceSummary(
      totalOperations: _metrics.length,
      totalDuration: totalDuration,
      totalMemoryUsed: totalMemory,
      peakMemoryUsage: peakMemory,
      operationBreakdown: operationBreakdown,
      recommendations: _generateRecommendations(operationBreakdown, peakMemory),
    );
  }

  /// Generate performance recommendations
  List<String> _generateRecommendations(
    Map<String, OperationStats> breakdown,
    int peakMemory,
  ) {
    final recommendations = <String>[];

    // Memory usage recommendations
    if (peakMemory > 500 * 1024 * 1024) {
      // 500MB
      recommendations.add(
        'High memory usage detected (${_formatBytes(peakMemory)}). '
        'Consider processing files in smaller batches or implementing streaming.',
      );
    }

    // Slow operations recommendations
    for (final entry in breakdown.entries) {
      final stats = entry.value;
      if (stats.averageDuration.inSeconds > 10) {
        recommendations.add(
          'Operation "${entry.key}" is slow (avg: ${stats.averageDuration.inSeconds}s). '
          'Consider optimizing or adding progress indicators.',
        );
      }
    }

    // Frequent operations recommendations
    final frequentOps =
        breakdown.entries.where((e) => e.value.count > 100).toList()
          ..sort((a, b) => b.value.count.compareTo(a.value.count));

    for (final entry in frequentOps.take(3)) {
      recommendations.add(
        'Operation "${entry.key}" runs frequently (${entry.value.count} times). '
        'Consider caching results or optimizing the implementation.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Performance looks good! No specific recommendations.',
      );
    }

    return recommendations;
  }

  /// Get current memory usage (approximate)
  int _getCurrentMemoryUsage() {
    try {
      // This is a simplified approach - in production you might want
      // to use more sophisticated memory monitoring
      final info = ProcessInfo.currentRss;
      return info;
    } catch (e) {
      return 0;
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Export performance data to file
  Future<void> exportToFile(String filePath) async {
    final summary = getSummary();
    final file = File(filePath);

    final buffer = StringBuffer();
    buffer.writeln('# Smart Coverage Performance Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    buffer.writeln('## Summary');
    buffer.writeln('- Total Operations: ${summary.totalOperations}');
    buffer.writeln(
      '- Total Duration: ${summary.totalDuration.inMilliseconds}ms',
    );
    buffer.writeln(
      '- Total Memory Used: ${_formatBytes(summary.totalMemoryUsed)}',
    );
    buffer.writeln(
      '- Peak Memory Usage: ${_formatBytes(summary.peakMemoryUsage)}',
    );
    buffer.writeln();

    buffer.writeln('## Operation Breakdown');
    for (final entry in summary.operationBreakdown.entries) {
      final stats = entry.value;
      buffer.writeln('### ${entry.key}');
      buffer.writeln('- Count: ${stats.count}');
      buffer.writeln(
        '- Total Duration: ${stats.totalDuration.inMilliseconds}ms',
      );
      buffer.writeln(
        '- Average Duration: ${stats.averageDuration.inMilliseconds}ms',
      );
      buffer.writeln('- Max Duration: ${stats.maxDuration.inMilliseconds}ms');
      buffer.writeln('- Total Memory: ${_formatBytes(stats.totalMemory)}');
      buffer.writeln('- Average Memory: ${_formatBytes(stats.averageMemory)}');
      buffer.writeln('- Max Memory: ${_formatBytes(stats.maxMemory)}');
      buffer.writeln();
    }

    buffer.writeln('## Recommendations');
    for (final recommendation in summary.recommendations) {
      buffer.writeln('- $recommendation');
    }

    await file.writeAsString(buffer.toString());
  }
}

/// Internal class for tracking profile data
class _ProfileData {
  final String name;
  final DateTime startTime;
  final int startMemory;

  _ProfileData({
    required this.name,
    required this.startTime,
    required this.startMemory,
  });
}

/// Internal class for performance metrics
class _PerformanceMetric {
  final String operationName;
  final Duration duration;
  final int memoryUsed;
  final int peakMemory;
  final Map<String, dynamic> metadata;

  _PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.memoryUsed,
    required this.peakMemory,
    required this.metadata,
  });
}

/// Performance summary data
class PerformanceSummary {
  final int totalOperations;
  final Duration totalDuration;
  final int totalMemoryUsed;
  final int peakMemoryUsage;
  final Map<String, OperationStats> operationBreakdown;
  final List<String> recommendations;

  PerformanceSummary({
    required this.totalOperations,
    required this.totalDuration,
    required this.totalMemoryUsed,
    required this.peakMemoryUsage,
    required this.operationBreakdown,
    required this.recommendations,
  });
}

/// Statistics for a specific operation
class OperationStats {
  final int count;
  final Duration totalDuration;
  final Duration averageDuration;
  final int totalMemory;
  final int averageMemory;
  final Duration maxDuration;
  final int maxMemory;

  OperationStats({
    required this.count,
    required this.totalDuration,
    required this.averageDuration,
    required this.totalMemory,
    required this.averageMemory,
    required this.maxDuration,
    required this.maxMemory,
  });
}
