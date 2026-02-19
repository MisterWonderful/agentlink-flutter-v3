import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
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
    if (type == AgentType.openClaw) {
      return _pingOpenClaw(baseUrl);
    }

    try {
      Uri url;
      switch (type) {
        case AgentType.openaiCompatible:
          url = Uri.parse('$baseUrl/v1/models');
          break;
        case AgentType.ollama:
          url = Uri.parse('$baseUrl/api/tags');
          break;
        case AgentType.anthropicCompatible:
          url = Uri.parse('$baseUrl/v1/models');
          break;
        case AgentType.custom:
          url = Uri.parse('$baseUrl/health');
          break;
        default:
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

  Future<bool> _pingOpenClaw(String baseUrl) async {
    WebSocketChannel? channel;
    StreamSubscription? subscription;
    try {
      final wsUrl = Uri.parse(baseUrl);
      channel = WebSocketChannel.connect(wsUrl);

      final completer = Completer<bool>();
      subscription = channel.stream.listen(
        (message) {
          if (message is String) {
            try {
              final data = jsonDecode(message) as Map<String, dynamic>;
              if (data['type'] == 'event' && data['event'] == 'connect.challenge') {
                if (!completer.isCompleted) completer.complete(true);
              }
            } catch (_) {}
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (e) {
      return false;
    } finally {
      await subscription?.cancel();
      channel?.sink.close();
    }
  }
}
