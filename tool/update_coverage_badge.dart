import 'dart:io';

/// Script to update the coverage badge automatically
Future<void> main(List<String> args) async {
  print('🧪 Running tests with coverage...');

  // Run tests with coverage
  var result = await Process.run(
    'dart',
    ['test', '--coverage=coverage'],
  );

  if (result.exitCode != 0) {
    print('❌ Tests failed!');
    print(result.stderr);
    exit(1);
  }

  print('📊 Formatting coverage data...');

  // Activate coverage package
  await Process.run('dart', ['pub', 'global', 'activate', 'coverage']);

  // Format coverage
  result = await Process.run(
    'dart',
    [
      'pub',
      'global',
      'run',
      'coverage:format_coverage',
      '--lcov',
      '--in=coverage',
      '--out=coverage/lcov.info',
      '--report-on=lib',
    ],
  );

  if (result.exitCode != 0) {
    print('❌ Failed to format coverage!');
    print(result.stderr);
    exit(1);
  }

  print('📈 Calculating coverage percentage...');

  // Read LCOV file and calculate coverage
  final lcovFile = File('coverage/lcov.info');
  if (!await lcovFile.exists()) {
    print('❌ LCOV file not found!');
    exit(1);
  }

  final lcovContent = await lcovFile.readAsString();
  final lines = lcovContent.split('\n');

  var linesFound = 0;
  var linesHit = 0;

  for (final line in lines) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }

  final coverage = linesFound > 0
      ? ((linesHit / linesFound) * 100).toStringAsFixed(1)
      : '0.0';

  print('Coverage: $coverage%');

  // Determine badge color
  final coverageValue = double.parse(coverage);
  String color;

  if (coverageValue >= 90) {
    color = '#44cc11'; // bright green
  } else if (coverageValue >= 80) {
    color = '#97ca00'; // green
  } else if (coverageValue >= 70) {
    color = '#dfb317'; // yellow
  } else if (coverageValue >= 60) {
    color = '#fe7d37'; // orange
  } else {
    color = '#e05d44'; // red
  }

  print('🎨 Generating coverage badge with color $color...');

  // Generate SVG badge
  final badgeContent = '''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="102" height="20">
    <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1" />
        <stop offset="1" stop-opacity=".1" />
    </linearGradient>
    <clipPath id="a">
        <rect width="102" height="20" rx="3" fill="#fff" />
    </clipPath>
    <g clip-path="url(#a)">
        <path fill="#555" d="M0 0h59v20H0z" />
        <path fill="$color" d="M59 0h43v20H59z" />
        <path fill="url(#b)" d="M0 0h102v20H0z" />
    </g>
    <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110">
        <text x="305" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="490">coverage</text>
        <text x="305" y="140" transform="scale(.1)" textLength="490">coverage</text>
        <text x="795" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="290">$coverage%</text>
        <text x="795" y="140" transform="scale(.1)" textLength="290">$coverage%</text>
    </g>
</svg>''';

  // Write badge file
  final badgeFile = File('coverage_badge.svg');
  await badgeFile.writeAsString(badgeContent);

  print('✅ Coverage badge updated to $coverage%');
  print('');
  print('Badge color legend:');
  print('  🟢 Green (≥90%): Excellent coverage');
  print('  🟢 Light Green (≥80%): Good coverage');
  print('  🟡 Yellow (≥70%): Acceptable coverage');
  print('  🟠 Orange (≥60%): Needs improvement');
  print('  🔴 Red (<60%): Poor coverage');
}

