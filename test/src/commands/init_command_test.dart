import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_coverage/src/commands/init_command.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _TestCommandRunner extends CommandRunner<int> {
  _TestCommandRunner(InitCommand command)
      : super('test', 'Test runner') {
    addCommand(command);
  }
}

void main() {
  group('InitCommand', () {
    late Logger logger;
    late Directory tempDir;

    setUp(() {
      logger = _MockLogger();
      tempDir = Directory.systemTemp.createTempSync('init_command_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('has correct name and description', () {
      final command = InitCommand(logger: logger);
      expect(command.name, equals('init'));
      expect(
        command.description,
        contains('Generate a smart_coverage.yaml configuration file'),
      );
    });

    test('generates default configuration file', () async {
      final command = InitCommand(logger: logger);
      final runner = _TestCommandRunner(command);
      final configPath = '${tempDir.path}/smart_coverage.yaml';

      final result = await runner.run(['init', '--output', configPath]);

      expect(result, equals(ExitCode.success.code));
      expect(File(configPath).existsSync(), isTrue);

      final content = await File(configPath).readAsString();
      expect(content, contains('base_branch: "origin/main"'));
      expect(content, contains('output_dir: "coverage/smart_coverage"'));
      expect(content, contains('dark_mode: true'));
    });

    test('generates minimal configuration when --minimal flag is used', () async {
      final command = InitCommand(logger: logger);
      final runner = _TestCommandRunner(command);
      final configPath = '${tempDir.path}/minimal_config.yaml';

      final result = await runner.run(['init', '--minimal', '--output', configPath]);

      expect(result, equals(ExitCode.success.code));
      expect(File(configPath).existsSync(), isTrue);

      final content = await File(configPath).readAsString();
      expect(content, contains('Minimal configuration'));
      expect(content, contains('base_branch: "origin/main"'));
    });

    test('generates configuration with AI settings when --with-ai flag is used', () async {
      final command = InitCommand(logger: logger);
      final runner = _TestCommandRunner(command);
      final configPath = '${tempDir.path}/ai_config.yaml';

      final result = await runner.run(['init', '--with-ai', '--output', configPath]);

      expect(result, equals(ExitCode.success.code));
      expect(File(configPath).existsSync(), isTrue);

      final content = await File(configPath).readAsString();
      expect(content, contains('ai_config:'));
      expect(content, contains('provider: "gemini"'));
    });

    test('uses custom base branch when --base-branch is specified', () async {
      final command = InitCommand(logger: logger);
      final runner = _TestCommandRunner(command);
      final configPath = '${tempDir.path}/custom_branch.yaml';

      final result = await runner.run([
        'init',
        '--base-branch',
        'origin/develop',
        '--output',
        configPath,
      ]);

      expect(result, equals(ExitCode.success.code));
      expect(File(configPath).existsSync(), isTrue);

      final content = await File(configPath).readAsString();
      expect(content, contains('base_branch: "origin/develop"'));
    });

    test('overwrites existing file by default', () async {
      final command = InitCommand(logger: logger);
      final runner = _TestCommandRunner(command);
      final configPath = '${tempDir.path}/existing.yaml';
      await File(configPath).writeAsString('existing content');

      final result = await runner.run(['init', '--output', configPath]);

      expect(result, equals(ExitCode.success.code));
      expect(File(configPath).existsSync(), isTrue);

      final content = await File(configPath).readAsString();
      expect(content, isNot(equals('existing content')));
      expect(content, contains('Smart Coverage Configuration'));
    });
  });
}
