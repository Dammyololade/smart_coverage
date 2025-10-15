import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:test/test.dart';

void main() {
  group('CoverageData', () {
    test('should create coverage data with files and summary', () {
      const data = CoverageData(
        files: [],
        summary: CoverageSummary(
          linesFound: 100,
          linesHit: 80,
          functionsFound: 10,
          functionsHit: 8,
          branchesFound: 20,
          branchesHit: 15,
        ),
      );

      expect(data.files, isEmpty);
      expect(data.summary.linesFound, equals(100));
      expect(data.summary.linesHit, equals(80));
    });

    test('should copy with new files', () {
      const original = CoverageData(
        files: [],
        summary: CoverageSummary(
          linesFound: 100,
          linesHit: 80,
          functionsFound: 10,
          functionsHit: 8,
          branchesFound: 20,
          branchesHit: 15,
        ),
      );

      final file = FileCoverage(
        path: 'lib/test.dart',
        lines: const [],
        summary: const CoverageSummary(
          linesFound: 10,
          linesHit: 5,
          functionsFound: 1,
          functionsHit: 1,
          branchesFound: 2,
          branchesHit: 1,
        ),
      );

      final copied = original.copyWith(files: [file]);

      expect(copied.files.length, equals(1));
      expect(copied.summary, equals(original.summary));
    });

    test('should copy with new summary', () {
      const original = CoverageData(
        files: [],
        summary: CoverageSummary(
          linesFound: 100,
          linesHit: 80,
          functionsFound: 10,
          functionsHit: 8,
          branchesFound: 20,
          branchesHit: 15,
        ),
      );

      const newSummary = CoverageSummary(
        linesFound: 200,
        linesHit: 160,
        functionsFound: 20,
        functionsHit: 16,
        branchesFound: 40,
        branchesHit: 30,
      );

      final copied = original.copyWith(summary: newSummary);

      expect(copied.summary.linesFound, equals(200));
      expect(copied.files, equals(original.files));
    });
  });

  group('FileCoverage', () {
    test('should create file coverage', () {
      const file = FileCoverage(
        path: 'lib/example.dart',
        lines: [
          LineCoverage(lineNumber: 1, hitCount: 2),
          LineCoverage(lineNumber: 2, hitCount: 0),
        ],
        summary: CoverageSummary(
          linesFound: 2,
          linesHit: 1,
          functionsFound: 1,
          functionsHit: 1,
          branchesFound: 0,
          branchesHit: 0,
        ),
      );

      expect(file.path, equals('lib/example.dart'));
      expect(file.lines.length, equals(2));
      expect(file.summary.linesFound, equals(2));
    });

    test('should copy with new path', () {
      const original = FileCoverage(
        path: 'lib/old.dart',
        lines: [],
        summary: CoverageSummary(
          linesFound: 0,
          linesHit: 0,
          functionsFound: 0,
          functionsHit: 0,
          branchesFound: 0,
          branchesHit: 0,
        ),
      );

      final copied = original.copyWith(path: 'lib/new.dart');

      expect(copied.path, equals('lib/new.dart'));
      expect(copied.lines, equals(original.lines));
      expect(copied.summary, equals(original.summary));
    });

    test('should copy with new lines', () {
      const original = FileCoverage(
        path: 'lib/test.dart',
        lines: [],
        summary: CoverageSummary(
          linesFound: 0,
          linesHit: 0,
          functionsFound: 0,
          functionsHit: 0,
          branchesFound: 0,
          branchesHit: 0,
        ),
      );

      const newLines = [
        LineCoverage(lineNumber: 1, hitCount: 1),
        LineCoverage(lineNumber: 2, hitCount: 0),
      ];

      final copied = original.copyWith(lines: newLines);

      expect(copied.lines.length, equals(2));
      expect(copied.path, equals(original.path));
    });

    test('should copy with new summary', () {
      const original = FileCoverage(
        path: 'lib/test.dart',
        lines: [],
        summary: CoverageSummary(
          linesFound: 10,
          linesHit: 5,
          functionsFound: 1,
          functionsHit: 1,
          branchesFound: 2,
          branchesHit: 1,
        ),
      );

      const newSummary = CoverageSummary(
        linesFound: 20,
        linesHit: 10,
        functionsFound: 2,
        functionsHit: 2,
        branchesFound: 4,
        branchesHit: 2,
      );

      final copied = original.copyWith(summary: newSummary);

      expect(copied.summary.linesFound, equals(20));
      expect(copied.path, equals(original.path));
    });
  });

  group('LineCoverage', () {
    test('should create line coverage', () {
      const line = LineCoverage(lineNumber: 42, hitCount: 5);

      expect(line.lineNumber, equals(42));
      expect(line.hitCount, equals(5));
    });

    test('should report covered when hit count > 0', () {
      const line = LineCoverage(lineNumber: 1, hitCount: 1);

      expect(line.isCovered, isTrue);
    });

    test('should report not covered when hit count = 0', () {
      const line = LineCoverage(lineNumber: 1, hitCount: 0);

      expect(line.isCovered, isFalse);
    });

    test('should handle high hit counts', () {
      const line = LineCoverage(lineNumber: 1, hitCount: 999999);

      expect(line.isCovered, isTrue);
      expect(line.hitCount, equals(999999));
    });
  });

  group('CoverageSummary', () {
    test('should create coverage summary', () {
      const summary = CoverageSummary(
        linesFound: 100,
        linesHit: 80,
        functionsFound: 10,
        functionsHit: 8,
        branchesFound: 20,
        branchesHit: 15,
      );

      expect(summary.linesFound, equals(100));
      expect(summary.linesHit, equals(80));
      expect(summary.functionsFound, equals(10));
      expect(summary.functionsHit, equals(8));
      expect(summary.branchesFound, equals(20));
      expect(summary.branchesHit, equals(15));
    });

    test('should calculate line percentage', () {
      const summary = CoverageSummary(
        linesFound: 100,
        linesHit: 80,
        functionsFound: 0,
        functionsHit: 0,
        branchesFound: 0,
        branchesHit: 0,
      );

      expect(summary.linePercentage, equals(80.0));
    });

    test('should calculate function percentage', () {
      const summary = CoverageSummary(
        linesFound: 0,
        linesHit: 0,
        functionsFound: 10,
        functionsHit: 7,
        branchesFound: 0,
        branchesHit: 0,
      );

      expect(summary.functionPercentage, equals(70.0));
    });

    test('should calculate branch percentage', () {
      const summary = CoverageSummary(
        linesFound: 0,
        linesHit: 0,
        functionsFound: 0,
        functionsHit: 0,
        branchesFound: 20,
        branchesHit: 15,
      );

      expect(summary.branchPercentage, equals(75.0));
    });

    test('should return 0 percentage when no lines found', () {
      const summary = CoverageSummary(
        linesFound: 0,
        linesHit: 0,
        functionsFound: 0,
        functionsHit: 0,
        branchesFound: 0,
        branchesHit: 0,
      );

      expect(summary.linePercentage, equals(0.0));
      expect(summary.functionPercentage, equals(0.0));
      expect(summary.branchPercentage, equals(0.0));
    });

    test('should handle 100% coverage', () {
      const summary = CoverageSummary(
        linesFound: 50,
        linesHit: 50,
        functionsFound: 5,
        functionsHit: 5,
        branchesFound: 10,
        branchesHit: 10,
      );

      expect(summary.linePercentage, equals(100.0));
      expect(summary.functionPercentage, equals(100.0));
      expect(summary.branchPercentage, equals(100.0));
    });

    test('should copy with modifications', () {
      const original = CoverageSummary(
        linesFound: 100,
        linesHit: 80,
        functionsFound: 10,
        functionsHit: 8,
        branchesFound: 20,
        branchesHit: 15,
      );

      final copied = original.copyWith(
        linesFound: 200,
        linesHit: 160,
      );

      expect(copied.linesFound, equals(200));
      expect(copied.linesHit, equals(160));
      expect(copied.functionsFound, equals(original.functionsFound));
      expect(copied.functionsHit, equals(original.functionsHit));
    });

    test('should copy without changes when no parameters provided', () {
      const original = CoverageSummary(
        linesFound: 100,
        linesHit: 80,
        functionsFound: 10,
        functionsHit: 8,
        branchesFound: 20,
        branchesHit: 15,
      );

      final copied = original.copyWith();

      expect(copied.linesFound, equals(original.linesFound));
      expect(copied.linesHit, equals(original.linesHit));
      expect(copied.functionsFound, equals(original.functionsFound));
      expect(copied.functionsHit, equals(original.functionsHit));
      expect(copied.branchesFound, equals(original.branchesFound));
      expect(copied.branchesHit, equals(original.branchesHit));
    });
  });
}
