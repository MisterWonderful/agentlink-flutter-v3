import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/agent.dart';

class OpenClawService {
  final _uuid = const Uuid();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  // Stream controller for client-facing events (tokens, tool calls, etc)
  final _eventController = StreamController<OpenClawEvent>.broadcast();
  Stream<OpenClawEvent> get events => _eventController.stream;

  // Track pending requests by ID to resolve futures
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  
  // Session state
  final String _sessionKey = 'main';
  String? _deviceId;
  bool _isConnected = false;
  Timer? _keepAliveTimer;

  bool get isConnected => _isConnected;

  Future<void> connect(Agent agent) async {
    if (_isConnected) return;

    try {
      final wsUrl = Uri.parse(agent.config.baseUrl);
      _channel = WebSocketChannel.connect(wsUrl);
      _deviceId = agent.config.deviceId;

      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message, agent),
        onDone: _onDisconnected,
        onError: (e) {
          _eventController.add(OpenClawEvent(type: OpenClawEventType.error, data: e));
          _onDisconnected();
        },
      );
    } catch (e) {
      throw Exception('Failed to connect to OpenClaw: $e');
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _keepAliveTimer?.cancel();
    _channel?.sink.close();
    _subscription?.cancel();
    _eventController.add(OpenClawEvent(type: OpenClawEventType.disconnected));
  }

  Future<void> disconnect() async {
    _onDisconnected();
  }

  void _handleMessage(dynamic message, Agent agent) {
    if (message is! String) return;
    
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'event' && data['event'] == 'connect.challenge') {
        _sendHandshake(data['payload'], agent);
      } else if (type == 'res') {
        final id = data['id'];
        if (_pendingRequests.containsKey(id)) {
          if (data['ok'] == true) {
            _pendingRequests[id]!.complete(data['payload'] ?? {});
            
            // If this was the handshake response (hello-ok)
            if (data['payload']?['type'] == 'hello-ok') {
               _isConnected = true;
               _eventController.add(OpenClawEvent(type: OpenClawEventType.connected));
            }
          } else {
            _pendingRequests[id]!.completeError(data['error'] ?? 'Unknown error');
          }
          _pendingRequests.remove(id);
        }
      } else if (type == 'event') {
        _handleEvent(data);
      }
    } catch (e) {
      // print('Error parsing OpenClaw message: $e');
    }
  }

  void _sendHandshake(Map<String, dynamic> challenge, Agent agent) {
    final requestId = _uuid.v4();
    final handshake = {
      "type": "req",
      "id": requestId,
      "method": "connect",
      "params": {
        "minProtocol": 3,
        "maxProtocol": 3,
        "client": {
          "id": "agentlink-mobile",
          "version": "0.1.0",
          "platform": "flutter",
          "mode": "operator"
        },
        "role": "operator",
        "scopes": ["operator.read", "operator.write"],
        "auth": {"token": agent.config.apiKey ?? "dev-token"}, 
        // In local dev with allowInsecureAuth: true, we can skip complex signature
        // But we should pass the challenge nonce back if required, or just basic params.
        // The notes say: "Note: For local/dev, you can simplify auth with gateway.controlUi.allowInsecureAuth: true to skip device identity signing"
        "device": {
          "id": _deviceId ?? "dev-device",
          // We omit signature for now as per "local/dev" instruction
        }
      }
    };
    
    _sendRequest(requestId, handshake);
  }

  void _sendRequest(String id, Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<Map<String, dynamic>> send(String method, Map<String, dynamic> params) {
    final id = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    _channel?.sink.add(jsonEncode({
      "type": "req",
      "id": id,
      "method": method,
      "params": params,
    }));

    return completer.future;
  }

  Future<void> sendChatMessage(String content, {String thinking = 'low'}) async {
    await send('chat.send', {
      "sessionKey": _sessionKey,
      "message": content,
      "thinking": thinking,
      "idempotencyKey": _uuid.v4(),
    });
  }

  Future<void> abortRun() async {
    await send('chat.abort', {
      "sessionKey": _sessionKey,
    });
  }

  Future<List<dynamic>> loadHistory({int limit = 50}) async {
    final res = await send('chat.history', {
      "sessionKey": _sessionKey,
      "limit": limit,
    });
    return res['messages'] ?? [];
  }

  void _handleEvent(Map<String, dynamic> data) {
    final eventName = data['event'];
    final payload = data['payload'];

    switch (eventName) {
      case 'chat':
        _handleChatEvent(payload);
        break;
      case 'agent':
        _handleAgentEvent(payload);
        break;
      case 'tick':
        // Keepalive, just ignore or log debug
        break;
    }
  }

  void _handleChatEvent(Map<String, dynamic> payload) {
    final state = payload['state'];
    if (state == 'delta') {
      final msg = payload['message'];
      final content = msg['content']; // Array of parts
      if (content is List) {
        for (final part in content) {
          if (part['type'] == 'text') {
            _eventController.add(OpenClawEvent(
               type: OpenClawEventType.token, 
               data: part['text']
            ));
          }
        }
      }
    } else if (state == 'final') {
      _eventController.add(OpenClawEvent(type: OpenClawEventType.done));
    }
  }

  void _handleAgentEvent(Map<String, dynamic> payload) {
    final stream = payload['stream'];
    final data = payload['data'];

    if (stream == 'lifecycle') {
      // phase: start, end
      // could map to 'Thinking...' state
    } else if (stream == 'tool') {
      // name, phase(start/end), input, result
      // We can expose this as a special event to show tool usage in UI
      _eventController.add(OpenClawEvent(
        type: OpenClawEventType.toolLog,
        data: data, // {name, phase, input...}
      ));
    }
  }
}

enum OpenClawEventType {
  connected,
  disconnected,
  token,
  done,
  error,
  toolLog,
}

class OpenClawEvent {
  final OpenClawEventType type;
  final dynamic data;
  OpenClawEvent({required this.type, this.data});
}
