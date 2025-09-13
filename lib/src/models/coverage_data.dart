/// {@template coverage_data}
/// Represents parsed coverage data from LCOV files
/// {@endtemplate}
class CoverageData {
  /// {@macro coverage_data}
  const CoverageData({
    required this.files,
    required this.summary,
  });

  /// List of file coverage information
  final List<FileCoverage> files;

  /// Overall coverage summary
  final CoverageSummary summary;

  /// Creates a copy of this coverage data with optional modifications
  CoverageData copyWith({
    List<FileCoverage>? files,
    CoverageSummary? summary,
  }) {
    return CoverageData(
      files: files ?? this.files,
      summary: summary ?? this.summary,
    );
  }
}

/// {@template file_coverage}
/// Coverage information for a single file
/// {@endtemplate}
class FileCoverage {
  /// {@macro file_coverage}
  const FileCoverage({
    required this.path,
    required this.lines,
    required this.summary,
  });

  /// Path to the file
  final String path;

  /// Line-by-line coverage information
  final List<LineCoverage> lines;

  /// Coverage summary for this file
  final CoverageSummary summary;

  /// Creates a copy of this file coverage with optional modifications
  FileCoverage copyWith({
    String? path,
    List<LineCoverage>? lines,
    CoverageSummary? summary,
  }) {
    return FileCoverage(
      path: path ?? this.path,
      lines: lines ?? this.lines,
      summary: summary ?? this.summary,
    );
  }
}

/// {@template line_coverage}
/// Coverage information for a single line
/// {@endtemplate}
class LineCoverage {
  /// {@macro line_coverage}
  const LineCoverage({
    required this.lineNumber,
    required this.hitCount,
  });

  /// Line number (1-indexed)
  final int lineNumber;

  /// Number of times this line was executed
  final int hitCount;

  /// Whether this line is covered by tests
  bool get isCovered => hitCount > 0;
}

/// {@template coverage_summary}
/// Overall coverage statistics
/// {@endtemplate}
class CoverageSummary {
  /// {@macro coverage_summary}
  const CoverageSummary({
    required this.linesFound,
    required this.linesHit,
    required this.functionsFound,
    required this.functionsHit,
    required this.branchesFound,
    required this.branchesHit,
  });

  /// Total number of executable lines
  final int linesFound;

  /// Number of lines covered by tests
  final int linesHit;

  /// Total number of functions
  final int functionsFound;

  /// Number of functions covered by tests
  final int functionsHit;

  /// Total number of branches
  final int branchesFound;

  /// Number of branches covered by tests
  final int branchesHit;

  /// Line coverage percentage (0.0 to 100.0)
  double get linePercentage =>
      linesFound > 0 ? (linesHit / linesFound) * 100 : 0.0;

  /// Function coverage percentage (0.0 to 100.0)
  double get functionPercentage =>
      functionsFound > 0 ? (functionsHit / functionsFound) * 100 : 0.0;

  /// Branch coverage percentage (0.0 to 100.0)
  double get branchPercentage =>
      branchesFound > 0 ? (branchesHit / branchesFound) * 100 : 0.0;

  /// Creates a copy of this summary with optional modifications
  CoverageSummary copyWith({
    int? linesFound,
    int? linesHit,
    int? functionsFound,
    int? functionsHit,
    int? branchesFound,
    int? branchesHit,
  }) {
    return CoverageSummary(
      linesFound: linesFound ?? this.linesFound,
      linesHit: linesHit ?? this.linesHit,
      functionsFound: functionsFound ?? this.functionsFound,
      functionsHit: functionsHit ?? this.functionsHit,
      branchesFound: branchesFound ?? this.branchesFound,
      branchesHit: branchesHit ?? this.branchesHit,
    );
  }
}
