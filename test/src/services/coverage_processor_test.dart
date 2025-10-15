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

      test('should handle invalid package structure', () async {
        final invalidFileDetector = MockFileDetector(validPackage: false);
        final invalidProcessor = CoverageProcessorImpl(
          fileDetector: invalidFileDetector,
          lcovParser: mockLcovParser,
        );

        expect(
          () => invalidProcessor.processAllFilesCoverage(
            lcovPath: '/test/coverage.info',
            packagePath: '/invalid/package',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('processCoverageWithConfig', () {
      test('should process coverage with valid config', () async {
        const config = SmartCoverageConfig(
          packagePath: '/test/package',
          baseBranch: 'main',
          outputDir: '/test/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final result = await processor.processCoverageWithConfig(
          lcovPath: '/test/coverage.info',
          config: config,
        );

        expect(result.files, hasLength(2));
        expect(result.summary.linesFound, equals(5));
      });

      test('should fall back to all files when no modified files', () async {
        final noModsFileDetector = MockFileDetector(
          modifiedFiles: [],
          allFiles: [
            'lib/src/service1.dart',
            'lib/src/service2.dart',
            'test/service1_test.dart',
          ],
        );

        final noModsProcessor = CoverageProcessorImpl(
          fileDetector: noModsFileDetector,
          lcovParser: mockLcovParser,
        );

        const config = SmartCoverageConfig(
          packagePath: '/test/package',
          baseBranch: 'main',
          outputDir: '/test/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final result = await noModsProcessor.processCoverageWithConfig(
          lcovPath: '/test/coverage.info',
          config: config,
        );

        // Should fall back to all files
        expect(result.files, hasLength(3));
        expect(result.summary.linesFound, equals(6));
      });

      test('should fall back to all files when Git is not available', () async {
        // Create a file detector that throws Git error
        final gitErrorDetector = _GitErrorFileDetector();
        final gitErrorProcessor = CoverageProcessorImpl(
          fileDetector: gitErrorDetector,
          lcovParser: mockLcovParser,
        );

        const config = SmartCoverageConfig(
          packagePath: '/test/package',
          baseBranch: 'main',
          outputDir: '/test/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        final result = await gitErrorProcessor.processCoverageWithConfig(
          lcovPath: '/test/coverage.info',
          config: config,
        );

        // Should fall back to all files
        expect(result.files, hasLength(3));
      });

      test('should handle invalid package in config', () async {
        final invalidFileDetector = MockFileDetector(validPackage: false);
        final invalidProcessor = CoverageProcessorImpl(
          fileDetector: invalidFileDetector,
          lcovParser: mockLcovParser,
        );

        const config = SmartCoverageConfig(
          packagePath: '/invalid/package',
          baseBranch: 'main',
          outputDir: '/test/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        expect(
          () => invalidProcessor.processCoverageWithConfig(
            lcovPath: '/test/coverage.info',
            config: config,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should rethrow non-Git errors', () async {
        final errorDetector = _GeneralErrorFileDetector();
        final errorProcessor = CoverageProcessorImpl(
          fileDetector: errorDetector,
          lcovParser: mockLcovParser,
        );

        const config = SmartCoverageConfig(
          packagePath: '/test/package',
          baseBranch: 'main',
          outputDir: '/test/output',
          skipTests: false,
          testInsights: false,
          codeReview: false,
          darkMode: false,
          outputFormats: ['console'],
          aiConfig: AiConfig(provider: 'gemini'),
        );

        expect(
          () => errorProcessor.processCoverageWithConfig(
            lcovPath: '/test/coverage.info',
            config: config,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getFileCoverage', () {
      test('should return coverage for specific file', () async {
        final implProcessor = processor as CoverageProcessorImpl;
        final result = await implProcessor.getFileCoverage(
          lcovPath: '/test/coverage.info',
          filePath: 'lib/src/service1.dart',
        );

        expect(result, isNotNull);
        expect(result!.path, equals('lib/src/service1.dart'));
        expect(result.summary.linesFound, equals(3));
        expect(result.summary.linesHit, equals(2));
      });

      test('should return null for non-existent file', () async {
        final implProcessor = processor as CoverageProcessorImpl;
        final result = await implProcessor.getFileCoverage(
          lcovPath: '/test/coverage.info',
          filePath: 'lib/src/nonexistent.dart',
        );

        expect(result, isNull);
      });

      test('should handle multiple files with same filter', () async {
        final implProcessor = processor as CoverageProcessorImpl;
        final result = await implProcessor.getFileCoverage(
          lcovPath: '/test/coverage.info',
          filePath: 'lib/src/service2.dart',
        );

        expect(result, isNotNull);
        expect(result!.path, equals('lib/src/service2.dart'));
        expect(result.summary.linesFound, equals(2));
        expect(result.summary.linesHit, equals(2));
      });
    });

    group('calculateCoverageDelta', () {
      test('should calculate delta between two coverage files', () async {
        // Base coverage: line 1 not hit, line 2 not hit, line 3 hit
        final baseCoverageData = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/service1.dart',
              lines: [
                LineCoverage(lineNumber: 1, hitCount: 0),
                LineCoverage(lineNumber: 2, hitCount: 0),
                LineCoverage(lineNumber: 3, hitCount: 1),
              ],
              summary: CoverageSummary(
                linesFound: 3,
                linesHit: 1,
                functionsFound: 1,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: CoverageSummary(
            linesFound: 3,
            linesHit: 1,
            functionsFound: 1,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        // Current coverage: line 1 now hit (delta +1), line 2 still not hit (delta 0), line 3 still hit (delta 0)
        final currentCoverageData = const CoverageData(
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
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: CoverageSummary(
            linesFound: 3,
            linesHit: 2,
            functionsFound: 1,
            functionsHit: 1,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        // Create two different parsers for base and current
        // We need to mock the parseFile method to return different data
        final testFileDetector = MockFileDetector(
          allFiles: ['lib/src/service1.dart'],
        );

        // Create a special parser that returns base first, then current
        final deltaParser = _DeltaLcovParser(
          baseCoverageData,
          currentCoverageData,
        );

        final deltaProcessor = CoverageProcessorImpl(
          fileDetector: testFileDetector,
          lcovParser: deltaParser,
        );

        final result = await deltaProcessor.calculateCoverageDelta(
          baseLcovPath: '/test/base.info',
          currentLcovPath: '/test/current.info',
          packagePath: '/test/package',
        );

        // Should only include line 1 which has a delta of +1
        expect(result.files, hasLength(1));
        expect(result.files.first.path, equals('lib/src/service1.dart'));
        expect(result.files.first.lines, hasLength(1));
        expect(result.files.first.lines.first.lineNumber, equals(1));
        expect(
          result.files.first.lines.first.hitCount,
          equals(1),
        ); // Delta is +1
      });

      test('should detect new files in current coverage', () async {
        final baseCoverageData = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/service1.dart',
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
            linesFound: 1,
            linesHit: 1,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final currentCoverageData = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/service1.dart',
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
          ],
          summary: CoverageSummary(
            linesFound: 3,
            linesHit: 3,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final testFileDetector = MockFileDetector(
          allFiles: ['lib/src/service1.dart', 'lib/src/service2.dart'],
        );

        final deltaParser = _DeltaLcovParser(
          baseCoverageData,
          currentCoverageData,
        );

        final deltaProcessor = CoverageProcessorImpl(
          fileDetector: testFileDetector,
          lcovParser: deltaParser,
        );

        final result = await deltaProcessor.calculateCoverageDelta(
          baseLcovPath: '/test/base.info',
          currentLcovPath: '/test/current.info',
          packagePath: '/test/package',
        );

        // Should include the new file service2.dart (entire file is new)
        expect(result.files, hasLength(1));
        final newFile = result.files.firstWhere(
          (f) => f.path == 'lib/src/service2.dart',
          orElse: () => result.files.first,
        );
        expect(newFile.path, equals('lib/src/service2.dart'));
        expect(newFile.lines.length, equals(2));
      });

      test('should handle no changes between coverages', () async {
        final sameCoverageData = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/service1.dart',
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
            linesFound: 1,
            linesHit: 1,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final testFileDetector = MockFileDetector(
          allFiles: ['lib/src/service1.dart'],
        );

        // Both base and current have same coverage
        final deltaParser = _DeltaLcovParser(
          sameCoverageData,
          sameCoverageData,
        );

        final deltaProcessor = CoverageProcessorImpl(
          fileDetector: testFileDetector,
          lcovParser: deltaParser,
        );

        final result = await deltaProcessor.calculateCoverageDelta(
          baseLcovPath: '/test/base.info',
          currentLcovPath: '/test/current.info',
          packagePath: '/test/package',
        );

        // When there are no deltas, files list should be empty
        expect(result.files, isEmpty);
        expect(result.summary.linesFound, equals(0));
      });

      test('should handle new lines in existing files', () async {
        final baseCoverageData = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/service1.dart',
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
            linesFound: 1,
            linesHit: 1,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final currentCoverageData = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/service1.dart',
              lines: [
                LineCoverage(lineNumber: 1, hitCount: 1),
                LineCoverage(lineNumber: 2, hitCount: 1),
                LineCoverage(lineNumber: 3, hitCount: 0),
              ],
              summary: CoverageSummary(
                linesFound: 3,
                linesHit: 2,
                functionsFound: 0,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: CoverageSummary(
            linesFound: 3,
            linesHit: 2,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final testFileDetector = MockFileDetector(
          allFiles: ['lib/src/service1.dart'],
        );

        final deltaParser = _DeltaLcovParser(
          baseCoverageData,
          currentCoverageData,
        );

        final deltaProcessor = CoverageProcessorImpl(
          fileDetector: testFileDetector,
          lcovParser: deltaParser,
        );

        final result = await deltaProcessor.calculateCoverageDelta(
          baseLcovPath: '/test/base.info',
          currentLcovPath: '/test/current.info',
          packagePath: '/test/package',
        );

        expect(result.files, isNotEmpty);
        final file = result.files.first;
        // Should include new lines (2 and 3) that weren't in base
        expect(file.lines.length, equals(2));
        // Line 2 should be covered (hitCount 1)
        expect(
          file.lines.any((l) => l.lineNumber == 2 && l.hitCount == 1),
          isTrue,
        );
        // Line 3 should be uncovered (hitCount 0)
        expect(
          file.lines.any((l) => l.lineNumber == 3 && l.hitCount == 0),
          isTrue,
        );
      });
    });

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

    group('edge cases', () {
      test('should handle coverage data with only test files', () async {
        final testOnlyCoverage = const CoverageData(
          files: [
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
            linesFound: 1,
            linesHit: 1,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final testProcessor = CoverageProcessorImpl(
          fileDetector: MockFileDetector(
            modifiedFiles: ['test/service1_test.dart'],
          ),
          lcovParser: MockLcovParser(testOnlyCoverage),
        );

        final result = await testProcessor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, hasLength(1));
        expect(result.files.first.path, equals('test/service1_test.dart'));
      });

      test('should handle files with zero coverage', () async {
        final zeroCoverage = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/uncovered.dart',
              lines: [
                LineCoverage(lineNumber: 1, hitCount: 0),
                LineCoverage(lineNumber: 2, hitCount: 0),
                LineCoverage(lineNumber: 3, hitCount: 0),
              ],
              summary: CoverageSummary(
                linesFound: 3,
                linesHit: 0,
                functionsFound: 1,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: CoverageSummary(
            linesFound: 3,
            linesHit: 0,
            functionsFound: 1,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final zeroProcessor = CoverageProcessorImpl(
          fileDetector: MockFileDetector(
            modifiedFiles: ['lib/src/uncovered.dart'],
          ),
          lcovParser: MockLcovParser(zeroCoverage),
        );

        final result = await zeroProcessor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, hasLength(1));
        expect(result.summary.linesHit, equals(0));
        expect(result.summary.linePercentage, equals(0.0));
      });

      test('should handle files with 100% coverage', () async {
        final fullCoverage = const CoverageData(
          files: [
            FileCoverage(
              path: 'lib/src/full_coverage.dart',
              lines: [
                LineCoverage(lineNumber: 1, hitCount: 5),
                LineCoverage(lineNumber: 2, hitCount: 3),
                LineCoverage(lineNumber: 3, hitCount: 10),
              ],
              summary: CoverageSummary(
                linesFound: 3,
                linesHit: 3,
                functionsFound: 1,
                functionsHit: 1,
                branchesFound: 2,
                branchesHit: 2,
              ),
            ),
          ],
          summary: CoverageSummary(
            linesFound: 3,
            linesHit: 3,
            functionsFound: 1,
            functionsHit: 1,
            branchesFound: 2,
            branchesHit: 2,
          ),
        );

        final fullProcessor = CoverageProcessorImpl(
          fileDetector: MockFileDetector(
            modifiedFiles: ['lib/src/full_coverage.dart'],
          ),
          lcovParser: MockLcovParser(fullCoverage),
        );

        final result = await fullProcessor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, hasLength(1));
        expect(result.summary.linePercentage, equals(100.0));
        expect(result.summary.functionPercentage, equals(100.0));
        expect(result.summary.branchPercentage, equals(100.0));
      });

      test('should handle very long file paths', () async {
        final longPath = 'lib/src/${'very_' * 50}long_path.dart';
        final longPathCoverage = CoverageData(
          files: [
            FileCoverage(
              path: longPath,
              lines: const [
                LineCoverage(lineNumber: 1, hitCount: 1),
              ],
              summary: const CoverageSummary(
                linesFound: 1,
                linesHit: 1,
                functionsFound: 0,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: const CoverageSummary(
            linesFound: 1,
            linesHit: 1,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final longPathProcessor = CoverageProcessorImpl(
          fileDetector: MockFileDetector(modifiedFiles: [longPath]),
          lcovParser: MockLcovParser(longPathCoverage),
        );

        final result = await longPathProcessor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: '/test/package',
        );

        expect(result.files, hasLength(1));
        expect(result.files.first.path, equals(longPath));
      });

      test('should use current directory when packagePath is null', () async {
        final result = await processor.processModifiedFilesCoverage(
          lcovPath: '/test/coverage.info',
          baseBranch: 'main',
          packagePath: null,
        );

        // Should still work with null packagePath
        expect(result, isA<CoverageData>());
      });
    });
  });
}

// Helper classes for Git error simulation
class _GitErrorFileDetector implements FileDetector {
  @override
  Future<List<String>> detectModifiedFiles(
    String baseBranch, {
    String? packagePath,
  }) async {
    throw Exception('Not a Git repository');
  }

  @override
  List<String> generateIncludePatterns(List<String> files) {
    return files.map((file) => r'**/$file').toList();
  }

  @override
  Future<bool> validatePackageStructure(String packagePath) async {
    return true;
  }

  @override
  Future<List<String>> getAllDartFiles(String packagePath) async {
    return [
      'lib/src/service1.dart',
      'lib/src/service2.dart',
      'test/service1_test.dart',
    ];
  }
}

class _GeneralErrorFileDetector implements FileDetector {
  @override
  Future<List<String>> detectModifiedFiles(
    String baseBranch, {
    String? packagePath,
  }) async {
    throw Exception('Some other error');
  }

  @override
  List<String> generateIncludePatterns(List<String> files) {
    return files.map((file) => r'**/$file').toList();
  }

  @override
  Future<bool> validatePackageStructure(String packagePath) async {
    return true;
  }

  @override
  Future<List<String>> getAllDartFiles(String packagePath) async {
    return [];
  }
}

// Special parser for delta calculation tests
class _DeltaLcovParser implements LcovParser {
  _DeltaLcovParser(this._baseData, this._currentData);

  final CoverageData _baseData;
  final CoverageData _currentData;

  @override
  Future<CoverageData> parseContent(String content) async {
    return _currentData;
  }

  @override
  Future<CoverageData> parseFile(String filePath) async {
    // Simulate different data for base vs current
    if (filePath.contains('base')) {
      return _baseData;
    } else {
      return _currentData;
    }
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
