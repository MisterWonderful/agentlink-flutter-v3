import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/agent.dart';
import '../models/agent_config.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthResult {
  final bool isHealthy;
  final String message;
  final int latencyMs;
  final AgentStatus status;

  HealthResult({required this.isHealthy, required this.message, required this.latencyMs, required this.status});
}

class HealthService {
  final http.Client _client;

  HealthService({http.Client? client}) : _client = client ?? http.Client();

  Future<HealthResult> checkHealth(String baseUrl, AgentType type, {String? apiKey}) async {
    final startTime = DateTime.now();
    try {
      final success = await _ping(baseUrl, type, apiKey);
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      
      if (success) {
        return HealthResult(
          isHealthy: true,
          message: 'Connected (${latency}ms)',
          latencyMs: latency,
          status: latency > 1000 ? AgentStatus.slow : AgentStatus.online,
        );
      } else {
        return HealthResult(
          isHealthy: false,
          message: 'Connection failed',
          latencyMs: 0,
          status: AgentStatus.offline,
        );
      }
    } catch (e) {
      return HealthResult(
        isHealthy: false,
        message: 'Error: ${e.toString()}',
        latencyMs: 0,
        status: AgentStatus.offline,
      );
    }
  }

  Future<bool> _ping(String baseUrl, AgentType type, String? apiKey) async {
    try {
      Uri url;
      switch (type) {
        case AgentType.openaiCompatible:
          url = Uri.parse('$baseUrl/v1/models');
          break;
        case AgentType.ollama:
           // Ollama has a specific version endpoint or tags
          url = Uri.parse('$baseUrl/api/tags'); 
          break;
        case AgentType.anthropicCompatible:
          // Anthropic requires auth even for models list usually
          url = Uri.parse('$baseUrl/v1/models'); // Placeholder, might need different endpoint
          break;
        case AgentType.openClaw:
          // Assuming http health endpoint exists
          url = Uri.parse('${baseUrl.replaceFirst('ws', 'http')}/health');
          break;
        case AgentType.custom:
          url = Uri.parse('$baseUrl/health');
          break;
      }

      final response = await _client.get(
        url,
        headers: apiKey != null && apiKey.isNotEmpty
          ? {'Authorization': 'Bearer $apiKey'} 
          : {},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
