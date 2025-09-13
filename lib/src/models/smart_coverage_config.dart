/// {@template smart_coverage_config}
/// Configuration for the smart coverage CLI tool
/// {@endtemplate}
class SmartCoverageConfig {
  /// {@macro smart_coverage_config}
  const SmartCoverageConfig({
    required this.packagePath,
    required this.baseBranch,
    required this.outputDir,
    required this.skipTests,
    required this.testInsights,
    required this.codeReview,
    required this.darkMode,
    required this.outputFormats,
    required this.aiConfig,
  });

  /// Path to the Flutter/Dart package
  final String packagePath;

  /// Base branch to compare against
  final String baseBranch;

  /// Output directory for reports
  final String outputDir;

  /// Whether to skip running tests
  final bool skipTests;

  /// Whether to generate test insights
  final bool testInsights;

  /// Whether to generate code review
  final bool codeReview;

  /// Whether to use dark mode for reports
  final bool darkMode;

  /// Output formats to generate
  final List<String> outputFormats;

  /// AI service configuration
  final AiConfig aiConfig;

  /// Creates a copy of this config with optional modifications
  SmartCoverageConfig copyWith({
    String? packagePath,
    String? baseBranch,
    String? outputDir,
    bool? skipTests,
    bool? testInsights,
    bool? codeReview,
    bool? darkMode,
    List<String>? outputFormats,
    AiConfig? aiConfig,
  }) {
    return SmartCoverageConfig(
      packagePath: packagePath ?? this.packagePath,
      baseBranch: baseBranch ?? this.baseBranch,
      outputDir: outputDir ?? this.outputDir,
      skipTests: skipTests ?? this.skipTests,
      testInsights: testInsights ?? this.testInsights,
      codeReview: codeReview ?? this.codeReview,
      darkMode: darkMode ?? this.darkMode,
      outputFormats: outputFormats ?? this.outputFormats,
      aiConfig: aiConfig ?? this.aiConfig,
    );
  }
}

/// {@template ai_config}
/// Configuration for AI services
/// {@endtemplate}
class AiConfig {
  /// {@macro ai_config}
  const AiConfig({
    required this.provider,
    this.providerType = 'auto',
    this.apiKeyEnv,
    this.model,
    this.apiEndpoint,
    this.timeout = 30,
    this.cliCommand = 'gemini',
    this.cliArgs = const [],
    this.cliTimeout = 60,
    this.fallbackEnabled = true,
    this.fallbackOrder = const ['local', 'api'],
  });

  /// AI provider name (e.g., 'gemini', 'openai')
  final String provider;

  /// Provider type: 'api', 'local', or 'auto'
  final String providerType;

  /// Environment variable name for API key
  final String? apiKeyEnv;

  /// AI model to use
  final String? model;

  /// API endpoint URL
  final String? apiEndpoint;

  /// API timeout in seconds
  final int timeout;

  /// CLI command name for local AI tools
  final String cliCommand;

  /// Additional CLI arguments
  final List<String> cliArgs;

  /// CLI timeout in seconds
  final int cliTimeout;

  /// Whether fallback is enabled
  final bool fallbackEnabled;

  /// Fallback order preference
  final List<String> fallbackOrder;

  /// Creates a copy of this config with optional modifications
  AiConfig copyWith({
    String? provider,
    String? providerType,
    String? apiKeyEnv,
    String? model,
    String? apiEndpoint,
    int? timeout,
    String? cliCommand,
    List<String>? cliArgs,
    int? cliTimeout,
    bool? fallbackEnabled,
    List<String>? fallbackOrder,
  }) {
    return AiConfig(
      provider: provider ?? this.provider,
      providerType: providerType ?? this.providerType,
      apiKeyEnv: apiKeyEnv ?? this.apiKeyEnv,
      model: model ?? this.model,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      timeout: timeout ?? this.timeout,
      cliCommand: cliCommand ?? this.cliCommand,
      cliArgs: cliArgs ?? this.cliArgs,
      cliTimeout: cliTimeout ?? this.cliTimeout,
      fallbackEnabled: fallbackEnabled ?? this.fallbackEnabled,
      fallbackOrder: fallbackOrder ?? this.fallbackOrder,
    );
  }
}
