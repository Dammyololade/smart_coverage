import 'dart:io';

import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/services/lcov_parser.dart';
import 'package:test/test.dart';

void main() {
  group('LcovParserImpl', () {
    late LcovParser parser;
    late Directory tempDir;

    setUp(() {
      parser = const LcovParserImpl();
      tempDir = Directory.systemTemp.createTempSync('lcov_parser_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('parseContent', () {
      test('should parse simple LCOV content', () async {
        const lcovContent = '''
SF:lib/example.dart
DA:1,2
DA:2,0
DA:3,1
LF:3
LH:2
end_of_record
''';

        final result = await parser.parseContent(lcovContent);

        expect(result.files.length, equals(1));
        expect(result.files.first.path, equals('lib/example.dart'));
        expect(result.files.first.lines.length, equals(3));
        expect(result.summary.linesFound, equals(3));
        expect(result.summary.linesHit, equals(2));
      });

      test('should parse multiple files', () async {
        const lcovContent = '''
SF:lib/file1.dart
DA:1,1
LF:1
LH:1
end_of_record
SF:lib/file2.dart
DA:1,0
DA:2,1
LF:2
LH:1
end_of_record
''';

        final result = await parser.parseContent(lcovContent);

        expect(result.files.length, equals(2));
        expect(result.files[0].path, equals('lib/file1.dart'));
        expect(result.files[1].path, equals('lib/file2.dart'));
        expect(result.summary.linesFound, equals(3));
        expect(result.summary.linesHit, equals(2));
      });

      test('should parse function coverage', () async {
        const lcovContent = '''
SF:lib/example.dart
FNF:5
FNH:3
LF:10
LH:7
end_of_record
''';

        final result = await parser.parseContent(lcovContent);

        expect(result.summary.functionsFound, equals(5));
        expect(result.summary.functionsHit, equals(3));
      });

      test('should parse branch coverage', () async {
        const lcovContent = '''
SF:lib/example.dart
BRF:4
BRH:2
LF:10
LH:7
end_of_record
''';

        final result = await parser.parseContent(lcovContent);

        expect(result.summary.branchesFound, equals(4));
        expect(result.summary.branchesHit, equals(2));
      });

      test('should handle empty content', () async {
        final result = await parser.parseContent('');

        expect(result.files, isEmpty);
        expect(result.summary.linesFound, equals(0));
        expect(result.summary.linesHit, equals(0));
      });

      test('should handle malformed line data gracefully', () async {
        const lcovContent = '''
SF:lib/example.dart
DA:invalid,data
DA:1,1
LF:1
LH:1
end_of_record
''';

        final result = await parser.parseContent(lcovContent);

        expect(result.files.first.lines.length, equals(1));
      });
    });

    group('parseFile', () {
      test('should parse LCOV file', () async {
        final lcovFile = File('${tempDir.path}/lcov.info');
        const content = '''
SF:lib/example.dart
DA:1,1
LF:1
LH:1
end_of_record
''';
        await lcovFile.writeAsString(content);

        final result = await parser.parseFile(lcovFile.path);

        expect(result.files.length, equals(1));
        expect(result.files.first.path, equals('lib/example.dart'));
      });

      test('should throw when file not found', () async {
        expect(
          () => parser.parseFile('/nonexistent/file.info'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle large files efficiently', () async {
        final lcovFile = File('${tempDir.path}/large_lcov.info');
        final buffer = StringBuffer();

        // Generate large LCOV content (>1MB to trigger isolate)
        for (var i = 0; i < 1000; i++) {
          buffer.writeln('SF:lib/file_$i.dart');
          for (var j = 1; j <= 100; j++) {
            buffer.writeln('DA:$j,${j % 2}');
          }
          buffer.writeln('LF:100');
          buffer.writeln('LH:50');
          buffer.writeln('end_of_record');
        }

        await lcovFile.writeAsString(buffer.toString());

        final result = await parser.parseFile(lcovFile.path);

        expect(result.files.length, equals(1000));
      });
    });

    group('filterByFiles', () {
      test('should filter files by path', () async {
        final data = CoverageData(
          files: [
            FileCoverage(
              path: 'lib/feature1.dart',
              lines: const [LineCoverage(lineNumber: 1, hitCount: 1)],
              summary: const CoverageSummary(
                linesFound: 1,
                linesHit: 1,
                functionsFound: 0,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
            FileCoverage(
              path: 'lib/feature2.dart',
              lines: const [LineCoverage(lineNumber: 1, hitCount: 0)],
              summary: const CoverageSummary(
                linesFound: 1,
                linesHit: 0,
                functionsFound: 0,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: const CoverageSummary(
            linesFound: 2,
            linesHit: 1,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final result = parser.filterByFiles(data, ['lib/feature1.dart']);

        expect(result.files.length, equals(1));
        expect(result.files.first.path, equals('lib/feature1.dart'));
        expect(result.summary.linesFound, equals(1));
        expect(result.summary.linesHit, equals(1));
      });

      test('should match files by ending path', () async {
        final data = CoverageData(
          files: [
            FileCoverage(
              path: '/absolute/path/lib/feature1.dart',
              lines: const [LineCoverage(lineNumber: 1, hitCount: 1)],
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

        final result = parser.filterByFiles(data, ['lib/feature1.dart']);

        expect(result.files.length, equals(1));
      });

      test('should return empty when no matches', () async {
        final data = CoverageData(
          files: [
            FileCoverage(
              path: 'lib/feature1.dart',
              lines: const [],
              summary: const CoverageSummary(
                linesFound: 0,
                linesHit: 0,
                functionsFound: 0,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: const CoverageSummary(
            linesFound: 0,
            linesHit: 0,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final result = parser.filterByFiles(data, ['lib/nonexistent.dart']);

        expect(result.files, isEmpty);
      });

      test('should return empty for empty filter list', () async {
        final data = CoverageData(
          files: [
            FileCoverage(
              path: 'lib/feature1.dart',
              lines: const [],
              summary: const CoverageSummary(
                linesFound: 0,
                linesHit: 0,
                functionsFound: 0,
                functionsHit: 0,
                branchesFound: 0,
                branchesHit: 0,
              ),
            ),
          ],
          summary: const CoverageSummary(
            linesFound: 0,
            linesHit: 0,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );

        final result = parser.filterByFiles(data, []);

        expect(result.files, isEmpty);
      });

      test('should handle paths with different separators', () async {
        final data = CoverageData(
          files: [
            FileCoverage(
              path: r'lib\feature1.dart',
              lines: const [LineCoverage(lineNumber: 1, hitCount: 1)],
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

        final result = parser.filterByFiles(data, ['lib/feature1.dart']);

        expect(result.files.length, equals(1));
      });
    });
  });
}
