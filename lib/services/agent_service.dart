import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agent.dart';
import '../models/agent_config.dart';
import '../models/chat_message.dart';

class AgentService {
  final http.Client _client;

  AgentService({http.Client? client}) : _client = client ?? http.Client();

  /// Stream a chat completion from the agent.
  /// Returns a stream of token strings.
  Stream<String> streamChatCompletion({
    required Agent agent,
    required List<ChatMessage> messages,
  }) async* {
    final config = agent.config;
    final history = messages
        .where((m) => m.role != MessageRole.system) // Filter system if needed, or pass it
        .map((m) => {
              'role': m.role.name,
              'content': m.content,
            })
        .toList();

    // Add system prompt if present
    if (config.systemPrompt.isNotEmpty) {
      history.insert(0, {'role': 'system', 'content': config.systemPrompt});
    }

    try {
      switch (config.type) {
        case AgentType.openaiCompatible:
        case AgentType.ollama:
          yield* _streamOpenAI(agent, history);
          break;
        case AgentType.anthropicCompatible:
          yield* _streamAnthropic(agent, history);
          break;
        case AgentType.openClaw:
          throw UnimplementedError('OpenClaw uses WebSocket via OpenClawService');
        case AgentType.custom:
          throw UnimplementedError('Custom agents not yet supported via HTTP service');
      }
    } catch (e) {
      // In a real app, we might yield a specific error token or rethrow
      // For now, let the UI handle the stream error
      throw Exception('Failed to stream from ${agent.name}: $e');
    }
  }

  Stream<String> _streamOpenAI(Agent agent, List<Map<String, String>> messages) async* {
    final url = Uri.parse(agent.chatEndpoint);
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    if (agent.apiKey != null && agent.apiKey!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${agent.apiKey}';
    }

    final body = {
      'model': agent.modelName ?? 'default',
      'messages': messages,
      'stream': true,
    };
    request.body = jsonEncode(body);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('API Error ${response.statusCode}: $errorBody');
    }

    final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6);
        if (data == '[DONE]') break;
        
        try {
          final json = jsonDecode(data);
          final content = json['choices']?[0]?['delta']?['content'];
          if (content != null && content is String) {
            yield content;
          }
        } catch (e) {
          // Ignore parse errors for partial chunks
        }
      }
    }
  }

  Stream<String> _streamAnthropic(Agent agent, List<Map<String, String>> messages) async* {
    final url = Uri.parse(agent.chatEndpoint); // e.g. https://api.anthropic.com/v1/messages
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['x-api-key'] = agent.apiKey ?? '';
    request.headers['anthropic-version'] = '2023-06-01'; // Required header

    // Anthropic specific body
    final body = {
      'model': agent.modelName ?? 'claude-3-opus-20240229',
      'messages': messages.where((m) => m['role'] != 'system').toList(),
      'system': agent.config.systemPrompt, // Anthropic uses top-level system field
      'stream': true,
      'max_tokens': 4096,
    };
    request.body = jsonEncode(body);

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Anthropic API Error ${response.statusCode}: $errorBody');
    }

    final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
         // Anthropic SSE structure is event-driven, but data lines contain the JSON
         // event types: message_start, content_block_delta, etc.
         final data = line.substring(6);
         try {
           final json = jsonDecode(data);
           final type = json['type'];
           if (type == 'content_block_delta') {
             final delta = json['delta'];
             if (delta != null && delta['type'] == 'text_delta') {
               yield delta['text'];
             }
           }
         } catch (e) {
           // Ignore
         }
      }
    }
  }
}
