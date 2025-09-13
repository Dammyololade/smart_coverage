import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/file_detector.dart';
import 'package:smart_coverage/src/services/lcov_parser.dart';

/// {@template coverage_processor}
/// Main service that coordinates coverage analysis workflow
/// {@endtemplate}
abstract class CoverageProcessor {
  /// Process coverage for modified files
  Future<CoverageData> processModifiedFilesCoverage({
    required String lcovPath,
    required String baseBranch,
    String? packagePath,
  });

  /// Process coverage for all files
  Future<CoverageData> processAllFilesCoverage({
    required String lcovPath,
    String? packagePath,
  });

  /// Process coverage with custom configuration
  Future<CoverageData> processCoverageWithConfig({
    required String lcovPath,
    required SmartCoverageConfig config,
  });
}

/// {@template coverage_processor_impl}
/// Implementation of coverage processor service
/// {@endtemplate}
class CoverageProcessorImpl implements CoverageProcessor {
  /// {@macro coverage_processor_impl}
  const CoverageProcessorImpl({
    required this.fileDetector,
    required this.lcovParser,
  });

  /// File detector service for Git integration
  final FileDetector fileDetector;

  /// LCOV parser service for coverage data parsing
  final LcovParser lcovParser;

  @override
  Future<CoverageData> processModifiedFilesCoverage({
    required String lcovPath,
    required String baseBranch,
    String? packagePath,
  }) async {
    final workingDir = packagePath ?? '.';

    // Validate package structure
    final isValidPackage = await fileDetector.validatePackageStructure(workingDir);
    if (!isValidPackage) {
      throw ArgumentError('Invalid Dart package structure at: $workingDir');
    }

    // Detect modified files
    final modifiedFiles = await fileDetector.detectModifiedFiles(
      baseBranch,
      packagePath: packagePath,
    );

    if (modifiedFiles.isEmpty) {
      // Return empty coverage data if no modified files
      return const CoverageData(
        files: [],
        summary: CoverageSummary(
          linesFound: 0,
          linesHit: 0,
          functionsFound: 0,
          functionsHit: 0,
          branchesFound: 0,
          branchesHit: 0,
        ),
      );
    }

    // Generate include patterns for modified files
    final includePatterns = fileDetector.generateIncludePatterns(modifiedFiles);

    // Parse LCOV data and filter by modified files
    final allCoverageData = await lcovParser.parseFile(lcovPath);
    final coverageData = lcovParser.filterByFiles(allCoverageData, modifiedFiles);

    return coverageData;
  }

  @override
  Future<CoverageData> processAllFilesCoverage({
    required String lcovPath,
    String? packagePath,
  }) async {
    final workingDir = packagePath ?? '.';

    // Validate package structure
    final isValidPackage = await fileDetector.validatePackageStructure(workingDir);
    if (!isValidPackage) {
      throw ArgumentError('Invalid Dart package structure at: $workingDir');
    }

    // Parse all LCOV data without filtering
    final coverageData = await lcovParser.parseFile(lcovPath);

    return coverageData;
  }

  @override
  Future<CoverageData> processCoverageWithConfig({
    required String lcovPath,
    required SmartCoverageConfig config,
  }) async {
    // Validate package structure
    final isValidPackage = await fileDetector.validatePackageStructure(config.packagePath);
    if (!isValidPackage) {
      throw ArgumentError('Invalid Dart package structure at: ${config.packagePath}');
    }

    // Determine processing mode based on configuration
    if (config.baseBranch == null) {
      // No base branch specified, process all files
      return processAllFilesCoverage(
        lcovPath: lcovPath,
        packagePath: config.packagePath,
      );
    }
    
    try {
      // Try to process modified files only
      final modifiedCoverage = await processModifiedFilesCoverage(
        lcovPath: lcovPath,
        baseBranch: config.baseBranch!,
        packagePath: config.packagePath,
      );
      
      // If no modified files found, fall back to processing all files
      if (modifiedCoverage.files.isEmpty) {
        return processAllFilesCoverage(
          lcovPath: lcovPath,
          packagePath: config.packagePath,
        );
      }
      
      return modifiedCoverage;
    } catch (e) {
      // If Git is not available or fails, fall back to processing all files
      if (e.toString().contains('Not a Git repository') || e.toString().contains('Git command failed')) {
        return processAllFilesCoverage(
          lcovPath: lcovPath,
          packagePath: config.packagePath,
        );
      }
      rethrow;
    }
    }

  /// Get coverage statistics for a specific file
  Future<FileCoverage?> getFileCoverage({
    required String lcovPath,
    required String filePath,
  }) async {
    final allCoverageData = await lcovParser.parseFile(lcovPath);
    final coverageData = lcovParser.filterByFiles(allCoverageData, [filePath]);

    return coverageData.files.isNotEmpty ? coverageData.files.first : null;
  }

  /// Calculate coverage delta between two LCOV files
  Future<CoverageData> calculateCoverageDelta({
    required String baseLcovPath,
    required String currentLcovPath,
    String? packagePath,
  }) async {
    final baseCoverage = await processAllFilesCoverage(
      lcovPath: baseLcovPath,
      packagePath: packagePath,
    );

    final currentCoverage = await processAllFilesCoverage(
      lcovPath: currentLcovPath,
      packagePath: packagePath,
    );

    // Calculate delta (simplified implementation)
    final deltaFiles = <FileCoverage>[];
    final baseFileMap = {for (final file in baseCoverage.files) file.path: file};

    for (final currentFile in currentCoverage.files) {
      final baseFile = baseFileMap[currentFile.path];
      if (baseFile != null) {
        // Calculate line coverage delta
        final deltaLines = <LineCoverage>[];
        final baseLineMap = {for (final line in baseFile.lines) line.lineNumber: line};

        for (final currentLine in currentFile.lines) {
          final baseLine = baseLineMap[currentLine.lineNumber];
          if (baseLine != null) {
            final deltaHitCount = currentLine.hitCount - baseLine.hitCount;
            if (deltaHitCount != 0) {
              deltaLines.add(LineCoverage(
                lineNumber: currentLine.lineNumber,
                hitCount: deltaHitCount,
              ));
            }
          } else {
            // New line in current coverage
            deltaLines.add(currentLine);
          }
        }

        if (deltaLines.isNotEmpty) {
          deltaFiles.add(FileCoverage(
            path: currentFile.path,
            lines: deltaLines,
            summary: _calculateFileSummary(deltaLines),
          ));
        }
      } else {
        // New file in current coverage
        deltaFiles.add(currentFile);
      }
    }

    return CoverageData(
      files: deltaFiles,
      summary: _calculateOverallSummary(deltaFiles),
    );
  }

  /// Calculate summary for a single file
  CoverageSummary _calculateFileSummary(List<LineCoverage> lines) {
    final linesFound = lines.length;
    final linesHit = lines.where((line) => line.isCovered).length;

    return CoverageSummary(
      linesFound: linesFound,
      linesHit: linesHit,
      functionsFound: 0, // Not available in line-level data
      functionsHit: 0,
      branchesFound: 0,
      branchesHit: 0,
    );
  }

  /// Calculate overall summary from multiple files
  CoverageSummary _calculateOverallSummary(List<FileCoverage> files) {
    var totalLinesFound = 0;
    var totalLinesHit = 0;
    var totalFunctionsFound = 0;
    var totalFunctionsHit = 0;
    var totalBranchesFound = 0;
    var totalBranchesHit = 0;

    for (final file in files) {
      totalLinesFound += file.summary.linesFound;
      totalLinesHit += file.summary.linesHit;
      totalFunctionsFound += file.summary.functionsFound;
      totalFunctionsHit += file.summary.functionsHit;
      totalBranchesFound += file.summary.branchesFound;
      totalBranchesHit += file.summary.branchesHit;
    }

    return CoverageSummary(
      linesFound: totalLinesFound,
      linesHit: totalLinesHit,
      functionsFound: totalFunctionsFound,
      functionsHit: totalFunctionsHit,
      branchesFound: totalBranchesFound,
      branchesHit: totalBranchesHit,
    );
  }
}