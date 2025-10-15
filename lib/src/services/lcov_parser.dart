import 'dart:io';
import 'dart:isolate';
import 'package:smart_coverage/src/models/coverage_data.dart';

/// {@template lcov_parser}
/// Service for parsing LCOV coverage data
/// {@endtemplate}
abstract class LcovParser {
  /// Parse LCOV content from string
  Future<CoverageData> parseContent(String content);

  /// Parse LCOV file
  Future<CoverageData> parseFile(String filePath);

  /// Filter coverage data by file paths
  CoverageData filterByFiles(CoverageData data, List<String> filePaths);
}

/// {@template lcov_parser_impl}
/// Implementation of LCOV parser service with optimized parsing for large files
/// {@endtemplate}
class LcovParserImpl implements LcovParser {
  /// {@macro lcov_parser_impl}
  const LcovParserImpl();

  @override
  Future<CoverageData> parseContent(String content) async {
    // For large content (>1MB), use isolate for parsing
    if (content.length > 1024 * 1024) {
      return _parseInIsolate(content);
    }
    return _parseContentSync(content);
  }

  @override
  Future<CoverageData> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('LCOV file not found: $filePath');
    }

    final stat = await file.stat();
    // For large files (>1MB), use streaming and isolate
    if (stat.size > 1024 * 1024) {
      final content = await file.readAsString();
      return _parseInIsolate(content);
    }

    final content = await file.readAsString();
    return _parseContentSync(content);
  }

  @override
  CoverageData filterByFiles(CoverageData data, List<String> filePaths) {
    if (filePaths.isEmpty) {
      print('⚠️  No files to filter - returning empty coverage data');
      return CoverageData(
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

    print('🔍 Filtering coverage data:');
    print('   Total files in LCOV: ${data.files.length}');
    print('   Modified files to match: ${filePaths.length}');

    final fileSet = filePaths.toSet();
    final filteredFiles = data.files.where((file) {
      // Normalize the file path from LCOV (remove leading ./ or /)
      final normalizedLcovPath = file.path
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp(r'^\.?/'), '');

      // Check if any of the modified file paths match
      final matches = fileSet.any((modifiedPath) {
        final normalizedModified = modifiedPath
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp(r'^\.?/'), '');

        // Try exact match first
        if (normalizedLcovPath == normalizedModified) return true;

        // Try if LCOV path ends with modified path
        if (normalizedLcovPath.endsWith(normalizedModified)) return true;

        // Try if modified path ends with LCOV path
        if (normalizedModified.endsWith(normalizedLcovPath)) return true;

        // Try if they share the same filename
        final lcovFilename = normalizedLcovPath.split('/').last;
        final modifiedFilename = normalizedModified.split('/').last;
        if (lcovFilename == modifiedFilename &&
            normalizedLcovPath.contains(normalizedModified.replaceFirst('lib/', ''))) {
          return true;
        }

        return false;
      });

      return matches;
    }).toList();

    print('   Matched files: ${filteredFiles.length}');
    if (filteredFiles.isEmpty && filePaths.isNotEmpty) {
      print('⚠️  No matches found! Sample paths:');
      print('   Modified file example: ${filePaths.first}');
      print('   LCOV file example: ${data.files.isNotEmpty ? data.files.first.path : "none"}');
    }

    return CoverageData(
      files: filteredFiles,
      summary: _calculateSummary(filteredFiles),
    );
  }

  /// Parse content in isolate for better performance with large files
  Future<CoverageData> _parseInIsolate(String content) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_parseInIsolateEntry, {
      'content': content,
      'sendPort': receivePort.sendPort,
    });

    final result = await receivePort.first as Map<String, dynamic>;
    receivePort.close();

    if (result['error'] != null) {
      throw Exception('LCOV parsing failed: ${result['error']}');
    }

    return _deserializeCoverageData(result['data'] as Map<String, dynamic>);
  }

  /// Isolate entry point for parsing
  static void _parseInIsolateEntry(Map<String, dynamic> params) {
    try {
      final content = params['content'] as String;
      final sendPort = params['sendPort'] as SendPort;

      const parser = LcovParserImpl();
      final result = parser._parseContentSync(content);

      sendPort.send({
        'data': _serializeCoverageData(result),
        'error': null,
      });
    } catch (e) {
      final sendPort = params['sendPort'] as SendPort;
      sendPort.send({
        'data': null,
        'error': e.toString(),
      });
    }
  }

  /// Synchronous content parsing optimized for performance
  CoverageData _parseContentSync(String content) {
    final files = <FileCoverage>[];
    final lines = content.split('\n');

    FileCoverage? currentFile;
    final linesCoverage = <LineCoverage>[];

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        // Save previous file if exists
        if (currentFile != null) {
          files.add(currentFile.copyWith(lines: List.from(linesCoverage)));
          linesCoverage.clear();
        }

        // Start new file
        final filePath = line.substring(3);
        currentFile = FileCoverage(
          path: filePath,
          lines: [],
          summary: const CoverageSummary(
            linesFound: 0,
            linesHit: 0,
            functionsFound: 0,
            functionsHit: 0,
            branchesFound: 0,
            branchesHit: 0,
          ),
        );
      } else if (line.startsWith('DA:')) {
        // Line coverage data
        final parts = line.substring(3).split(',');
        if (parts.length >= 2) {
          final lineNumber = int.tryParse(parts[0]);
          final hitCount = int.tryParse(parts[1]);

          if (lineNumber != null && hitCount != null) {
            linesCoverage.add(
              LineCoverage(
                lineNumber: lineNumber,
                hitCount: hitCount,
              ),
            );
          }
        }
      } else if (line.startsWith('LF:')) {
        // Lines found
        final count = int.tryParse(line.substring(3)) ?? 0;
        if (currentFile != null) {
          currentFile = currentFile.copyWith(
            summary: currentFile.summary.copyWith(linesFound: count),
          );
        }
      } else if (line.startsWith('LH:')) {
        // Lines hit
        final count = int.tryParse(line.substring(3)) ?? 0;
        if (currentFile != null) {
          currentFile = currentFile.copyWith(
            summary: currentFile.summary.copyWith(linesHit: count),
          );
        }
      } else if (line.startsWith('FNF:')) {
        // Functions found
        final count = int.tryParse(line.substring(4)) ?? 0;
        if (currentFile != null) {
          currentFile = currentFile.copyWith(
            summary: currentFile.summary.copyWith(functionsFound: count),
          );
        }
      } else if (line.startsWith('FNH:')) {
        // Functions hit
        final count = int.tryParse(line.substring(4)) ?? 0;
        if (currentFile != null) {
          currentFile = currentFile.copyWith(
            summary: currentFile.summary.copyWith(functionsHit: count),
          );
        }
      } else if (line.startsWith('BRF:')) {
        // Branches found
        final count = int.tryParse(line.substring(4)) ?? 0;
        if (currentFile != null) {
          currentFile = currentFile.copyWith(
            summary: currentFile.summary.copyWith(branchesFound: count),
          );
        }
      } else if (line.startsWith('BRH:')) {
        // Branches hit
        final count = int.tryParse(line.substring(4)) ?? 0;
        if (currentFile != null) {
          currentFile = currentFile.copyWith(
            summary: currentFile.summary.copyWith(branchesHit: count),
          );
        }
      }
    }

    // Add last file
    if (currentFile != null) {
      files.add(currentFile.copyWith(lines: List.from(linesCoverage)));
    }

    return CoverageData(
      files: files,
      summary: _calculateSummary(files),
    );
  }

  /// Calculate overall coverage summary
  CoverageSummary _calculateSummary(List<FileCoverage> files) {
    var linesFound = 0;
    var linesHit = 0;
    var functionsFound = 0;
    var functionsHit = 0;
    var branchesFound = 0;
    var branchesHit = 0;

    for (final file in files) {
      linesFound += file.summary.linesFound;
      linesHit += file.summary.linesHit;
      functionsFound += file.summary.functionsFound;
      functionsHit += file.summary.functionsHit;
      branchesFound += file.summary.branchesFound;
      branchesHit += file.summary.branchesHit;
    }

    return CoverageSummary(
      linesFound: linesFound,
      linesHit: linesHit,
      functionsFound: functionsFound,
      functionsHit: functionsHit,
      branchesFound: branchesFound,
      branchesHit: branchesHit,
    );
  }

  /// Serialize coverage data for isolate communication
  static Map<String, dynamic> _serializeCoverageData(CoverageData data) {
    return {
      'files': data.files
          .map(
            (f) => {
              'path': f.path,
              'lines': f.lines
                  .map(
                    (l) => {
                      'lineNumber': l.lineNumber,
                      'hitCount': l.hitCount,
                    },
                  )
                  .toList(),
              'summary': {
                'linesFound': f.summary.linesFound,
                'linesHit': f.summary.linesHit,
                'functionsFound': f.summary.functionsFound,
                'functionsHit': f.summary.functionsHit,
                'branchesFound': f.summary.branchesFound,
                'branchesHit': f.summary.branchesHit,
              },
            },
          )
          .toList(),
      'summary': {
        'linesFound': data.summary.linesFound,
        'linesHit': data.summary.linesHit,
        'functionsFound': data.summary.functionsFound,
        'functionsHit': data.summary.functionsHit,
        'branchesFound': data.summary.branchesFound,
        'branchesHit': data.summary.branchesHit,
      },
    };
  }

  /// Deserialize coverage data from isolate communication
  CoverageData _deserializeCoverageData(Map<String, dynamic> data) {
    final files = (data['files'] as List).map((f) {
      final fileData = f as Map<String, dynamic>;
      final lines = (fileData['lines'] as List).map((l) {
        final lineData = l as Map<String, dynamic>;
        return LineCoverage(
          lineNumber: lineData['lineNumber'] as int,
          hitCount: lineData['hitCount'] as int,
        );
      }).toList();

      final summaryData = fileData['summary'] as Map<String, dynamic>;
      final summary = CoverageSummary(
        linesFound: summaryData['linesFound'] as int,
        linesHit: summaryData['linesHit'] as int,
        functionsFound: summaryData['functionsFound'] as int,
        functionsHit: summaryData['functionsHit'] as int,
        branchesFound: summaryData['branchesFound'] as int,
        branchesHit: summaryData['branchesHit'] as int,
      );

      return FileCoverage(
        path: fileData['path'] as String,
        lines: lines,
        summary: summary,
      );
    }).toList();

    final summaryData = data['summary'] as Map<String, dynamic>;
    final summary = CoverageSummary(
      linesFound: summaryData['linesFound'] as int,
      linesHit: summaryData['linesHit'] as int,
      functionsFound: summaryData['functionsFound'] as int,
      functionsHit: summaryData['functionsHit'] as int,
      branchesFound: summaryData['branchesFound'] as int,
      branchesHit: summaryData['branchesHit'] as int,
    );

    return CoverageData(
      files: files,
      summary: summary,
    );
  }
}
