import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// {@template completion_setup_command}
/// `smart_coverage completion-setup` command for setting up shell completions
/// {@endtemplate}
class CompletionSetupCommand extends Command<int> {
  /// {@macro completion_setup_command}
  CompletionSetupCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Force setup even if completions appear to be configured.',
        negatable: false,
      )
      ..addFlag(
        'check',
        help: 'Only check if completions are properly configured.',
        negatable: false,
      );
  }

  @override
  String get description =>
      'Set up shell tab-completion for smart_coverage commands.';

  @override
  String get name => 'completion-setup';

  final Logger _logger;

  @override
  Future<int> run() async {
    final checkOnly = argResults!['check'] as bool;
    final force = argResults!['force'] as bool;

    _logger.info('🔧 Smart Coverage Shell Completion Setup\n');

    // Detect shell
    final shell = _detectShell();
    _logger.info('Detected shell: ${lightCyan.wrap(shell)}');

    if (shell == 'unknown') {
      _logger.warn(
        '⚠️  Could not detect your shell. '
        'Manual setup may be required.',
      );
      _printManualInstructions();
      return ExitCode.software.code;
    }

    // Check current completion status
    final status = await _checkCompletionStatus(shell);

    if (checkOnly) {
      _printStatus(status);
      return status.isFullyConfigured
          ? ExitCode.success.code
          : ExitCode.software.code;
    }

    if (status.isFullyConfigured && !force) {
      _logger.success('✅ Shell completions are already configured!\n');
      _logger.info('Try it out:');
      _logger.info('  1. Open a new terminal');
      _logger.info('  2. Type: smart_coverage <TAB>');
      return ExitCode.success.code;
    }

    // Perform setup
    return await _performSetup(shell, status);
  }

  String _detectShell() {
    final shellEnv = Platform.environment['SHELL'] ?? '';

    if (shellEnv.contains('zsh')) return 'zsh';
    if (shellEnv.contains('bash')) return 'bash';
    if (shellEnv.contains('fish')) return 'fish';

    return 'unknown';
  }

  Future<_CompletionStatus> _checkCompletionStatus(String shell) async {
    final status = _CompletionStatus();

    switch (shell) {
      case 'zsh':
        status.configFile = _getZshConfigFile();
        status.hasCompletionInit = await _hasZshCompinit(status.configFile);
        status.hasCompletionScript = await _hasCompletionScript(shell);
        break;
      case 'bash':
        status.configFile = _getBashConfigFile();
        status.hasCompletionInit = true; // Bash doesn't need special init
        status.hasCompletionScript = await _hasCompletionScript(shell);
        break;
      case 'fish':
        status.configFile = '~/.config/fish/config.fish';
        status.hasCompletionInit = true; // Fish handles this automatically
        status.hasCompletionScript = await _hasCompletionScript(shell);
        break;
    }

    return status;
  }

  String _getZshConfigFile() {
    final home = Platform.environment['HOME'] ?? '';
    final zshrc = File('$home/.zshrc');
    if (zshrc.existsSync()) return '$home/.zshrc';

    final zprofile = File('$home/.zprofile');
    if (zprofile.existsSync()) return '$home/.zprofile';

    return '$home/.zshrc';
  }

  String _getBashConfigFile() {
    final home = Platform.environment['HOME'] ?? '';
    final bashrc = File('$home/.bashrc');
    if (bashrc.existsSync()) return '$home/.bashrc';

    final bashProfile = File('$home/.bash_profile');
    if (bashProfile.existsSync()) return '$home/.bash_profile';

    return '$home/.bashrc';
  }

  Future<bool> _hasZshCompinit(String configFile) async {
    try {
      final file = File(configFile);
      if (!await file.exists()) return false;

      final content = await file.readAsString();

      // Check for compinit in various forms
      final hasCompinit = content.contains('compinit') ||
          content.contains('oh-my-zsh') ||
          content.contains('prezto') ||
          content.contains('zinit') ||
          content.contains('antigen') ||
          content.contains('zplug');

      return hasCompinit;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasCompletionScript(String shell) async {
    final home = Platform.environment['HOME'] ?? '';
    final completionDir = Directory('$home/.dart-cli-completion');

    if (!await completionDir.exists()) return false;

    final scriptFile = File('$home/.dart-cli-completion/smart_coverage.$shell');
    return scriptFile.existsSync();
  }

  void _printStatus(_CompletionStatus status) {
    _logger.info('\n📋 Completion Status:\n');

    _logger.info(
      '  Config file: ${status.configFile}',
    );

    final initStatus = status.hasCompletionInit
        ? '${green.wrap("✓")} Configured'
        : '${red.wrap("✗")} Missing';
    _logger.info('  Completion system: $initStatus');

    final scriptStatus = status.hasCompletionScript
        ? '${green.wrap("✓")} Installed'
        : '${red.wrap("✗")} Not installed';
    _logger.info('  Completion script: $scriptStatus');

    _logger.info('');

    if (status.isFullyConfigured) {
      _logger.success('✅ Everything is configured correctly!');
    } else {
      _logger.warn('⚠️  Setup required. Run: smart_coverage completion-setup');
    }
  }

  Future<int> _performSetup(String shell, _CompletionStatus status) async {
    var needsRestart = false;

    // Step 1: Add compinit for zsh if missing
    if (shell == 'zsh' && !status.hasCompletionInit) {
      _logger.info('\n📝 Step 1: Setting up zsh completion system...');

      final added = await _addZshCompinit(status.configFile);
      if (added) {
        _logger.success('  ✓ Added compinit to ${status.configFile}');
        needsRestart = true;
      } else {
        _logger.err('  ✗ Failed to add compinit');
        _printManualCompinit();
        return ExitCode.software.code;
      }
    } else {
      _logger.info('\n📝 Step 1: Completion system ${green.wrap("✓")}');
    }

    // Step 2: Install completion scripts
    if (!status.hasCompletionScript) {
      _logger.info('\n📝 Step 2: Installing completion scripts...');

      final installed = await _installCompletionScripts();
      if (installed) {
        _logger.success('  ✓ Completion scripts installed');
        needsRestart = true;
      } else {
        _logger.warn(
          '  ⚠️  Could not auto-install. '
          'Run: smart_coverage install-completion-files',
        );
      }
    } else {
      _logger.info('\n📝 Step 2: Completion scripts ${green.wrap("✓")}');
    }

    // Final instructions
    _logger.info('');
    _logger.success('✅ Shell completion setup complete!\n');

    if (needsRestart) {
      _logger.info('${yellow.wrap("⚡ Action required:")}');
      _logger.info('   Restart your terminal or run:\n');
      _logger.info('   ${lightCyan.wrap("source ${status.configFile}")}\n');
    }

    _logger.info('Then try it out:');
    _logger.info('   ${lightCyan.wrap("smart_coverage <TAB>")}');
    _logger.info('   ${lightCyan.wrap("smart_coverage analyze --<TAB>")}');

    return ExitCode.success.code;
  }

  Future<bool> _addZshCompinit(String configFile) async {
    try {
      final file = File(configFile);
      var content = '';

      if (await file.exists()) {
        content = await file.readAsString();
      }

      // Add compinit at the beginning
      const compinit = '''
# Zsh Completion System (added by smart_coverage)
autoload -Uz compinit
compinit

''';

      final newContent = compinit + content;
      await file.writeAsString(newContent);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _installCompletionScripts() async {
    try {
      final result = await Process.run(
        'smart_coverage',
        ['install-completion-files'],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  void _printManualCompinit() {
    _logger.info('\n📋 Manual setup required:');
    _logger.info('   Add these lines to the TOP of your ~/.zshrc:\n');
    _logger.info('   ${lightCyan.wrap("autoload -Uz compinit")}');
    _logger.info('   ${lightCyan.wrap("compinit")}\n');
  }

  void _printManualInstructions() {
    _logger.info('\n📋 Manual setup instructions:\n');
    _logger.info('For ${lightCyan.wrap("zsh")}:');
    _logger.info('  1. Add to ~/.zshrc:');
    _logger.info('     autoload -Uz compinit');
    _logger.info('     compinit');
    _logger.info('  2. Run: smart_coverage install-completion-files');
    _logger.info('  3. Restart your terminal\n');

    _logger.info('For ${lightCyan.wrap("bash")}:');
    _logger.info('  1. Run: smart_coverage install-completion-files');
    _logger.info('  2. Restart your terminal\n');

    _logger.info('For ${lightCyan.wrap("fish")}:');
    _logger.info('  1. Run: smart_coverage install-completion-files');
    _logger.info('  2. Restart your terminal\n');
  }
}

class _CompletionStatus {
  String configFile = '';
  bool hasCompletionInit = false;
  bool hasCompletionScript = false;

  bool get isFullyConfigured => hasCompletionInit && hasCompletionScript;
}

