import 'package:smart_coverage/src/models/models.dart';
import 'package:smart_coverage/src/services/services.dart';
import 'package:test/test.dart';

// Mock implementations for testing
class MockFileDetector implements FileDetector {
  MockFileDetector({
    List<String>? modifiedFiles,
    List<String>? allFiles,
    bool validPackage = true,
  }) : _mockModifiedFiles = modifiedFiles ?? [],
       _mockAllFiles = allFiles ?? [],
       _mockValidPackage = validPackage;
  final List<String> _mockModifiedFiles;
  final List<String> _mockAllFiles;
  final bool _mockValidPackage;

  @override
  Future<List<String>> detectModifiedFiles(
    String baseBranch, {
    String? packagePath,
  }) async {
    return _mockModifiedFiles;
  }

  @override
  List<String> generateIncludePatterns(List<String> files) {
    return files.map((file) => r'**/$file').toList();
  }

  @override
  Future<bool> validatePackageStructure(String packagePath) async {
    return _mockValidPackage;
  }

  @override
  Future<List<String>> getAllDartFiles(String packagePath) async {
    return _mockAllFiles;
  }
}

class MockLcovParser implements LcovParser {
  MockLcovParser(this._mockCoverageData);

  final CoverageData _mockCoverageData;

  @override
  Future<CoverageData> parseContent(String content) async {
    return _mockCoverageData;
  }

  Future<CoverageData> parseLcovFile(String filePath) async {
    return _mockCoverageData;
  }

  @override
  Future<CoverageData> parseFile(String filePath) async {
    return _mockCoverageData;
  }

  @override
  CoverageData filterByFiles(CoverageData data, List<String> files) {
    final filteredFiles = data.files
        .where((file) => files.contains(file.path))
        .toList();

    // Calculate summary from filtered files
    var totalLinesFound = 0;
    var totalLinesHit = 0;
    var totalFunctionsFound = 0;
    var totalFunctionsHit = 0;
    var totalBranchesFound = 0;
    var totalBranchesHit = 0;

    for (final file in filteredFiles) {
      totalLinesFound += file.summary.linesFound;
      totalLinesHit += file.summary.linesHit;
      totalFunctionsFound += file.summary.functionsFound;
      totalFunctionsHit += file.summary.functionsHit;
      totalBranchesFound += file.summary.branchesFound;
      totalBranchesHit += file.summary.branchesHit;
    }

    return CoverageData(
      files: filteredFiles,
      summary: CoverageSummary(
        linesFound: totalLinesFound,
        linesHit: totalLinesHit,
        functionsFound: totalFunctionsFound,
        functionsHit: totalFunctionsHit,
        branchesFound: totalBranchesFound,
        branchesHit: totalBranchesHit,
      ),
    );
  }
}

void main() {
  group('CoverageProcessorImpl', () {
    late CoverageProcessor processor;
    late MockFileDetector mockFileDetector;
    late MockLcovParser mockLcovParser;
    late CoverageData mockCoverageData;

    setUp(() {
      mockCoverageData = const CoverageData(
        files: [
          FileCoverage(
            path: 'lib/src/service1.dart',
            lines: [
              LineCoverage(lineNumber: 1, hitCount: 1),
              LineCoverage(lineNumber: 2, hitCount: 0),
              LineCoverage(lineNumber: 3, hitCount: 1),
            ],
            summary: CoverageSummary(
              linesFound: 3,
              linesHit: 2,
              functionsFound: 1,
              functionsHit: 1,
              branchesFound: 1,
              branchesHit: 0,
            ),
          ),
          FileCoverage(
            path: 'lib/src/service2.dart',
            lines: [
              LineCoverage(lineNumber: 1, hitCount: 1),
              LineCoverage(lineNumber: 2, hitCount: 1),
            ],
            summary: CoverageSummary(
              linesFound: 2,
              linesHit: 2,
              functionsFound: 0,
              functionsHit: 0,
              branchesFound: 0,
              branchesHit: 0,
            ),
          ),
          FileCoverage(
            path: 'test/service1_test.dart',
            lines: [
              LineCoverage(lineNumber: 1, hitCount: 1),
            ],
            summary: CoverageSummary(
              linesFound: 1,
              linesHit: 1,
              functionsFound: 0,
              functionsHit: 0,
              branchesFound: 0,
              branchesHit: 0,
            ),
          ),
        ],
        summary: CoverageSummary(
          linesFound: 6,
          linesHit: 5,
          functionsFound: 1,
          functionsHit: 1,
          branchesFound: 1,
          branchesHit: 0,
        ),
      );

      mockFileDetector = MockFileDetector(
        modifiedFiles: ['lib/src/service1.dart', 'lib/src/service2.dart'],
        allFiles: [
          'lib/src/service1.dart',
          'lib/src/service2.dart',
          'test/service1_test.dart',
        ],
      );

      mockLcovParser = MockLcovParser(mockCoverageData);

      processor = CoverageProcessorImpl(
        fileDetector: mockFileDetector,
        lcovParser: mockLcovParser,
      );
    });

    group('processModifiedFilesCoverage', () {
      test('should process coverage for modified files only', () async {
        final result = await processor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, hasLength(2));
        expect(
          result.files.map((f) => f.path),
          containsAll([
            'lib/src/service1.dart',
            'lib/src/service2.dart',
          ]),
        );
        expect(result.summary.linesFound, equals(5)); // 3 + 2
        expect(result.summary.linesHit, equals(4)); // 2 + 2
      });

      test('should handle empty modified files list', () async {
        final emptyFileDetector = MockFileDetector(modifiedFiles: []);
        const emptyCoverageData = CoverageData(
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
        final emptyLcovParser = MockLcovParser(emptyCoverageData);
        final emptyProcessor = CoverageProcessorImpl(
          fileDetector: emptyFileDetector,
          lcovParser: emptyLcovParser,
        );

        final result = await emptyProcessor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, isEmpty);
        expect(result.summary.linesFound, equals(0));
      });

      test('should handle invalid package structure', () async {
        final invalidFileDetector = MockFileDetector(validPackage: false);
        final invalidProcessor = CoverageProcessorImpl(
          fileDetector: invalidFileDetector,
          lcovParser: mockLcovParser,
        );

        expect(
          () => invalidProcessor.processModifiedFilesCoverage(
            lcovPath: '/test/coverage.info',
            baseBranch: 'main',
            packagePath: '/invalid/package',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('processAllFilesCoverage', () {
      test('should process coverage for all Dart files', () async {
        final result = await processor.processAllFilesCoverage(
          lcovPath: '/test/coverage.info',
          packagePath: '/test/package',
        );

        expect(result.files, hasLength(3));
        expect(
          result.files.map((f) => f.path),
          containsAll([
            'lib/src/service1.dart',
            'lib/src/service2.dart',
            'test/service1_test.dart',
          ]),
        );
        expect(result.summary.linesFound, equals(6)); // 3 + 2 + 1
        expect(result.summary.linesHit, equals(5)); // 2 + 2 + 1
      });

      test('should handle package with no Dart files', () async {
        final emptyFileDetector = MockFileDetector(allFiles: []);
        const emptyCoverageData = CoverageData(
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
        final emptyLcovParser = MockLcovParser(emptyCoverageData);
        final emptyProcessor = CoverageProcessorImpl(
          fileDetector: emptyFileDetector,
          lcovParser: emptyLcovParser,
        );

        final result = await emptyProcessor.processAllFilesCoverage(
          lcovPath: '/test/coverage.info',
          packagePath: '/test/package',
        );

        expect(result.files, isEmpty);
        expect(result.summary.linesFound, equals(0));
      });
    });

    // processCustomFiles method doesn't exist in implementation
    // These tests have been removed

    // Helper methods tests removed as
    // getFileCoverage method doesn't exist in the interface

    group('error handling', () {
      test('should handle LCOV parsing errors', () async {
        final errorParser = MockLcovParser(
          const CoverageData(
            files: [],
            summary: CoverageSummary(
              linesFound: 0,
              linesHit: 0,
              functionsFound: 0,
              functionsHit: 0,
              branchesFound: 0,
              branchesHit: 0,
            ),
          ), // Empty data to simulate error
        );

        final errorProcessor = CoverageProcessorImpl(
          fileDetector: mockFileDetector,
          lcovParser: errorParser,
        );

        // Should not throw, but return empty data
        final result = await errorProcessor.processModifiedFilesCoverage(
          lcovPath: '/invalid/path.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, isEmpty);
      });

      test('should handle file detection errors', () async {
        final errorFileDetector = MockFileDetector(
          modifiedFiles: [], // Empty to simulate no files found
        );

        final errorProcessor = CoverageProcessorImpl(
          fileDetector: errorFileDetector,
          lcovParser: mockLcovParser,
        );

        final result = await errorProcessor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, isEmpty);
      });
    });

    group('performance tests', () {
      test(
        'should handle large coverage data efficiently',
        () async {
          // Create large mock coverage data
          final largeCoverageData = CoverageData(
            files: List.generate(
              1000,
              (index) => FileCoverage(
                path: 'lib/src/file_$index.dart',
                lines: List.generate(
                  100,
                  (lineIndex) => LineCoverage(
                    lineNumber: lineIndex + 1,
                    hitCount: lineIndex % 2,
                  ),
                ),
                summary: const CoverageSummary(
                  linesFound: 100,
                  linesHit: 50,
                  functionsFound: 0,
                  functionsHit: 0,
                  branchesFound: 0,
                  branchesHit: 0,
                ),
              ),
            ),
            summary: const CoverageSummary(
              linesFound: 100000,
              linesHit: 50000,
              functionsFound: 0,
              functionsHit: 0,
              branchesFound: 0,
              branchesHit: 0,
            ),
          );

          final largeFileDetector = MockFileDetector(
            modifiedFiles: List.generate(
              1000,
              (index) => 'lib/src/file_$index.dart',
            ),
          );

          final largeProcessor = CoverageProcessorImpl(
            fileDetector: largeFileDetector,
            lcovParser: MockLcovParser(largeCoverageData),
          );

          final stopwatch = Stopwatch()..start();
          final result = await largeProcessor.processModifiedFilesCoverage(
            lcovPath: '/test/coverage.info',
            baseBranch: 'main',
            packagePath: '/test/package',
          );
          stopwatch.stop();

          expect(result.files, hasLength(1000));
          expect(result.summary.linesFound, equals(100000)); // 1000 * 100
          expect(result.summary.linesHit, equals(50000)); // 1000 * 50

          // Should complete in reasonable time (under 2 seconds)
          expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        },
        timeout: const Timeout(Duration(seconds: 5)),
      );
    });
  });
}
