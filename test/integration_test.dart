import 'dart:io';

import 'package:smart_coverage/src/models/smart_coverage_config.dart';
import 'package:smart_coverage/src/services/coverage_processor.dart';
import 'package:smart_coverage/src/services/file_detector.dart';
import 'package:smart_coverage/src/services/lcov_parser.dart';
import 'package:smart_coverage/src/services/report_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Integration Tests', () {
    late Directory tempDir;
    late File tempLcovFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('smart_coverage_test');
      tempLcovFile = File('${tempDir.path}/coverage.info');

      // Create a sample LCOV file
      await tempLcovFile.writeAsString('''
TN:
SF:lib/src/example.dart
FNF:2
FNH:1
LF:10
LH:8
BRF:4
BRH:3
FN:1,main
FN:5,helper
FNDA:1,main
FNDA:0,helper
DA:1,1
DA:2,1
DA:3,1
DA:4,1
DA:5,1
DA:6,1
DA:7,0
DA:8,1
DA:9,1
DA:10,0
BRDA:3,0,0,1
BRDA:3,0,1,0
BRDA:7,0,0,2
BRDA:7,0,1,1
end_of_record
''');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('should parse LCOV file and generate console report', () async {
      // Test LCOV parsing
      const parser = LcovParserImpl();
      final coverageData = await parser.parseFile(tempLcovFile.path);

      expect(coverageData.files, hasLength(1));
      expect(coverageData.files.first.path, equals('lib/src/example.dart'));
      expect(coverageData.summary.linesFound, equals(10));
      expect(coverageData.summary.linesHit, equals(8));

      // Test report generation
      const reportGenerator = ReportGeneratorImpl();
      final config = SmartCoverageConfig(
        packagePath: tempDir.path,
        baseBranch: 'main',
        outputDir: '${tempDir.path}/output',
        skipTests: false,
        testInsights: false,
        codeReview: false,
        darkMode: false,
        outputFormats: ['console'],
        aiConfig: const AiConfig(provider: 'gemini'),
      );

      await reportGenerator.generateReports(coverageData, config);

      // Verify console output was generated (no exception thrown)
      expect(coverageData.summary.linePercentage, equals(80.0));
    });

    test('should handle file detection', () async {
      // Create a simple package structure
      final libDir = Directory('${tempDir.path}/lib');
      await libDir.create();
      await File('${libDir.path}/main.dart').writeAsString('void main() {}');

      const detector = FileDetectorImpl();
      final dartFiles = await detector.getAllDartFiles(tempDir.path);

      expect(dartFiles, isNotEmpty);
      expect(dartFiles.any((file) => file.endsWith('main.dart')), isTrue);
    });

    test('should process coverage data end-to-end', () async {
      // Create package structure
      final libDir = Directory('${tempDir.path}/lib/src');
      await libDir.create(recursive: true);
      await File('${libDir.path}/example.dart').writeAsString('void main() {}');

      // Create pubspec.yaml
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_package
version: 1.0.0
environment:
  sdk: '>=2.17.0 <4.0.0'
''');

      const processor = CoverageProcessorImpl(
        fileDetector: FileDetectorImpl(),
        lcovParser: LcovParserImpl(),
      );

      final result = await processor.processAllFilesCoverage(
        lcovPath: tempLcovFile.path,
        packagePath: tempDir.path,
      );

      expect(result.files, hasLength(1));
      expect(result.files.first.path, equals('lib/src/example.dart'));
      expect(result.summary.linesFound, equals(10));
      expect(result.summary.linesHit, equals(8));
    });
  });
}
