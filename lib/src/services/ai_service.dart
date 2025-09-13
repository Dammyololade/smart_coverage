import 'package:smart_coverage/src/models/coverage_data.dart';
import 'package:smart_coverage/src/models/smart_coverage_config.dart';

/// AI provider types
enum AiProviderType {
  /// API-based provider
  api,
  /// Local CLI-based provider
  local,
}

/// {@template ai_service}
/// Interface for AI-powered code analysis services
/// {@endtemplate}
abstract class AiService {
  /// Generate code review based on coverage data
  Future<String> generateCodeReview(CoverageData coverage, List<String> files);

  /// Generate insights about coverage patterns
  Future<String> generateInsights(CoverageData coverage);

  /// Check if the AI service is available
  Future<bool> isAvailable();

  /// Get the provider type
  AiProviderType get providerType;
}

/// {@template local_ai_service}
/// Interface for local CLI-based AI services
/// {@endtemplate}
abstract class LocalAiService extends AiService {
  @override
  AiProviderType get providerType => AiProviderType.local;

  /// Check if the CLI tool is installed
  Future<bool> isCliInstalled();

  /// Get the CLI tool version
  Future<String> getCliVersion();

  /// Get the CLI command name
  String get cliCommand;
}

/// {@template api_ai_service}
/// Interface for API-based AI services
/// {@endtemplate}
abstract class ApiAiService extends AiService {
  @override
  AiProviderType get providerType => AiProviderType.api;

  /// Check if a valid API key is available
  Future<bool> hasValidApiKey();

  /// Get the API endpoint URL
  String get apiEndpoint;
}

/// {@template ai_service_factory}
/// Factory for creating AI service instances
/// {@endtemplate}
class AiServiceFactory {
  /// Create an AI service based on configuration
  static Future<AiService> create(SmartCoverageConfig config) async {
    final providerType = await _determineProviderType(config);
    
    switch (config.aiConfig.provider) {
      case 'gemini':
        return providerType == AiProviderType.local
            ? GeminiCliService(config.aiConfig)
            : GeminiApiService(config.aiConfig);
      case 'gemini-cli':
        return GeminiCliService(config.aiConfig);
      default:
        throw UnsupportedError('Provider ${config.aiConfig.provider} not supported');
    }
  }
  
  static Future<AiProviderType> _determineProviderType(SmartCoverageConfig config) async {
    if (config.aiConfig.providerType == 'local') return AiProviderType.local;
    if (config.aiConfig.providerType == 'api') return AiProviderType.api;
    
    // Auto-detection logic
    final localService = _createLocalService(config);
    if (await localService.isCliInstalled()) {
      return AiProviderType.local;
    }
    
    final apiService = _createApiService(config);
    if (await apiService.hasValidApiKey()) {
      return AiProviderType.api;
    }
    
    throw StateError('No available AI provider found');
  }
  
  static LocalAiService _createLocalService(SmartCoverageConfig config) {
    switch (config.aiConfig.provider) {
      case 'gemini':
      case 'gemini-cli':
        return GeminiCliService(config.aiConfig);
      default:
        throw UnsupportedError('Local provider ${config.aiConfig.provider} not supported');
    }
  }
  
  static ApiAiService _createApiService(SmartCoverageConfig config) {
    switch (config.aiConfig.provider) {
      case 'gemini':
        return GeminiApiService(config.aiConfig);
      default:
        throw UnsupportedError('API provider ${config.aiConfig.provider} not supported');
    }
  }
}

/// {@template gemini_cli_service}
/// Gemini CLI-based AI service implementation
/// {@endtemplate}
class GeminiCliService extends LocalAiService {
  /// {@macro gemini_cli_service}
  GeminiCliService(this.config);

  /// AI configuration
  final AiConfig config;

  @override
  String get cliCommand => config.cliCommand;

  @override
  Future<bool> isCliInstalled() async {
    // TODO: Implement CLI detection
    // Check if the CLI command is available in PATH
    throw UnimplementedError('CLI detection not yet implemented');
  }

  @override
  Future<String> getCliVersion() async {
    // TODO: Implement version detection
    // Run CLI command with --version flag
    throw UnimplementedError('CLI version detection not yet implemented');
  }

  @override
  Future<String> generateCodeReview(CoverageData coverage, List<String> files) async {
    // TODO: Implement code review generation
    // Build prompt and execute CLI command
    throw UnimplementedError('Code review generation not yet implemented');
  }

  @override
  Future<String> generateInsights(CoverageData coverage) async {
    // TODO: Implement insights generation
    // Analyze coverage patterns and generate recommendations
    throw UnimplementedError('Insights generation not yet implemented');
  }

  @override
  Future<bool> isAvailable() async {
    return isCliInstalled();
  }
}

/// {@template gemini_api_service}
/// Gemini API-based AI service implementation
/// {@endtemplate}
class GeminiApiService extends ApiAiService {
  /// {@macro gemini_api_service}
  GeminiApiService(this.config);

  /// AI configuration
  final AiConfig config;

  @override
  String get apiEndpoint => config.apiEndpoint ?? 'https://generativelanguage.googleapis.com';

  @override
  Future<bool> hasValidApiKey() async {
    // TODO: Implement API key validation
    // Check if API key environment variable is set
    throw UnimplementedError('API key validation not yet implemented');
  }

  @override
  Future<String> generateCodeReview(CoverageData coverage, List<String> files) async {
    // TODO: Implement API-based code review generation
    // Make HTTP request to Gemini API
    throw UnimplementedError('API code review generation not yet implemented');
  }

  @override
  Future<String> generateInsights(CoverageData coverage) async {
    // TODO: Implement API-based insights generation
    // Make HTTP request to analyze coverage patterns
    throw UnimplementedError('API insights generation not yet implemented');
  }

  @override
  Future<bool> isAvailable() async {
    return hasValidApiKey();
  }
}