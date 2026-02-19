import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/agent.dart';
import 'device_identity_service.dart';

class OpenClawService {
  final _uuid = const Uuid();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Stream controller for client-facing events (tokens, tool calls, etc)
  final _eventController = StreamController<OpenClawEvent>.broadcast();
  Stream<OpenClawEvent> get events => _eventController.stream;

  // Track pending requests by ID to resolve futures
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};

  // Device identity for handshake signing
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

  // Session state
  String _sessionKey = 'main';
  bool _isConnected = false;
  Timer? _keepAliveTimer;

  // Fix 5: Auto-reconnect state
  Agent? _lastAgent;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectAttempts = 8;
  static const _maxReconnectDelay = Duration(seconds: 30);

  // Fix 10: Tick-based health
  DateTime? _lastTickAt;

  // Fix 12: Verbose level
  int _verboseLevel = 1;

  bool get isConnected => _isConnected;
  String get sessionKey => _sessionKey;
  DateTime? get lastTickAt => _lastTickAt;
  bool get isStale =>
      _lastTickAt != null &&
      DateTime.now().difference(_lastTickAt!) > const Duration(seconds: 60);

  Future<void> connect(Agent agent) async {
    if (_isConnected) return;

    // Cancel stale connection before opening a new one
    _subscription?.cancel();
    _channel?.sink.close();

    try {
      await _deviceIdentity.load();
      final wsUrl = Uri.parse(agent.config.baseUrl);
      _channel = WebSocketChannel.connect(wsUrl);
      _sessionKey = agent.config.sessionKey ?? 'main';
      _lastAgent = agent;
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message, agent),
        onDone: _onDisconnected,
        onError: (e) {
          _eventController
              .add(OpenClawEvent(type: OpenClawEventType.error, data: e));
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
    _scheduleReconnect();
  }

  // Fix 5: Exponential backoff reconnect
  void _scheduleReconnect() {
    if (_lastAgent == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, _maxReconnectDelay.inSeconds),
    );
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_lastAgent == null || _isConnected) return;
      try {
        await connect(_lastAgent!);
      } catch (_) {
        // connect failed, _onDisconnected will schedule next attempt
      }
    });
  }

  Future<void> disconnect() async {
    _lastAgent = null; // Prevent auto-reconnect on explicit disconnect
    _reconnectTimer?.cancel();
    _isConnected = false;
    _keepAliveTimer?.cancel();
    _channel?.sink.close();
    _subscription?.cancel();
    _eventController.add(OpenClawEvent(type: OpenClawEventType.disconnected));
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
        final payload = (data['payload'] as Map<String, dynamic>?) ?? {};

        // hello-ok: check outside _pendingRequests since connect is fire-and-forget
        if (data['ok'] == true && payload['type'] == 'hello-ok') {
          _isConnected = true;
          _reconnectAttempts = 0;
          _eventController.add(OpenClawEvent(type: OpenClawEventType.connected));
          _loadHistoryAfterConnect();
        }

        // Resolve other pending requests
        if (_pendingRequests.containsKey(id)) {
          if (data['ok'] == true) {
            _pendingRequests[id]!.complete(payload);
          } else {
            _pendingRequests[id]!.completeError(data['error'] ?? 'Unknown error');
          }
          _pendingRequests.remove(id);
        }
      } else if (type == 'event') {
        _handleEvent(data);
      }
    } catch (e) {
      // silently ignore parse errors
    }
  }

  // Ed25519 device signing - matches server buildDeviceAuthPayload v2
  Future<void> _sendHandshake(Map<String, dynamic> challenge, Agent agent) async {
    final requestId = _uuid.v4();
    String clientId;
    if (Platform.isIOS) { clientId = 'openclaw-ios'; }
    else if (Platform.isAndroid) { clientId = 'openclaw-android'; }
    else if (Platform.isMacOS) { clientId = 'openclaw-macos'; }
    else { clientId = 'webchat'; }
    const role = 'operator';
    const scopes = ['operator.read', 'operator.write'];
    final token = agent.config.apiKey ?? '';
    final nonce = challenge['nonce'] as String? ?? '';
    final signedAt = DateTime.now().millisecondsSinceEpoch;
    final deviceId = _deviceIdentity.deviceId;
    final publicKey = _deviceIdentity.publicKeyBase64Url;
    final payload = DeviceIdentityService.buildPayload(
      deviceId: deviceId, clientId: clientId, clientMode: 'ui',
      role: role, scopes: scopes, signedAtMs: signedAt, token: token, nonce: nonce,
    );
    final signature = await _deviceIdentity.signPayload(payload);
    final handshake = {
      "type": "req", "id": requestId, "method": "connect",
      "params": {
        "minProtocol": 3, "maxProtocol": 3,
        "client": {"id": clientId, "version": "0.1.0", "platform": "flutter", "mode": "ui"},
        "caps": ["tool-events"], "role": role, "scopes": scopes,
        "auth": {"token": token},
        "device": {"id": deviceId, "publicKey": publicKey, "signature": signature, "signedAt": signedAt, "nonce": nonce},
      }
    };
    _sendRequest(requestId, handshake);
  }

  void _sendRequest(String id, Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<Map<String, dynamic>> send(
      String method, Map<String, dynamic> params) {
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

  // Fix 8+12: Attachments and verbose level in sendChatMessage
  Future<void> sendChatMessage(
    String content, {
    String thinking = 'low',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final params = <String, dynamic>{
      "sessionKey": _sessionKey,
      "message": content,
      "thinking": thinking,
      "verbose": _verboseLevel,
      "idempotencyKey": _uuid.v4(),
    };
    if (attachments != null && attachments.isNotEmpty) {
      params["attachments"] = attachments;
    }
    await send('chat.send', params);
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

  // Fix 4: Load history after connect
  Future<void> _loadHistoryAfterConnect() async {
    try {
      final messages = await loadHistory();
      _eventController.add(
        OpenClawEvent(type: OpenClawEventType.historyLoaded, data: messages),
      );
    } catch (_) {
      // Non-fatal: history load failure shouldn't break the connection
    }
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
        // Fix 10: Track tick timestamps
        _lastTickAt = DateTime.now();
        break;
      case 'exec.approval.requested':
        // Fix 7: Emit approval request
        _eventController.add(OpenClawEvent(
          type: OpenClawEventType.approvalRequested,
          data: payload,
        ));
        break;
    }
  }

  // Fix 3: Handle thinking content as separate block type
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
              data: part['text'],
            ));
          } else if (part['type'] == 'thinking') {
            _eventController.add(OpenClawEvent(
              type: OpenClawEventType.thinkingToken,
              data: part['thinking'],
            ));
          }
        }
      }
    } else if (state == 'final') {
      _eventController.add(OpenClawEvent(type: OpenClawEventType.done));
    } else if (state == 'error') {
      _eventController.add(OpenClawEvent(
        type: OpenClawEventType.error,
        data: payload['error'] ?? 'Unknown chat error',
      ));
    }
  }

  void _handleAgentEvent(Map<String, dynamic> payload) {
    final stream = payload['stream'];
    final data = payload['data'];

    if (stream == 'tool') {
      _eventController.add(OpenClawEvent(
        type: OpenClawEventType.toolLog,
        data: data, // {name, phase, input, result...}
      ));
    }
  }

  // Fix 7: Resolve exec approval
  Future<void> resolveApproval(String execId, bool approved) async {
    await send('exec.approval.resolve', {
      "approvalId": execId,
      "decision": approved ? "allow-once" : "deny",
    });
  }

  // Fix 9: Session switching
  Future<List<dynamic>> listSessions() async {
    final res = await send('session.list', {});
    return res['sessions'] ?? [];
  }

  Future<void> switchSession(String key) async {
    _sessionKey = key;
    await _loadHistoryAfterConnect();
  }

  // Fix 11: chat.inject for system notes
  Future<void> injectSystemNote(String note) async {
    await send('chat.inject', {
      "sessionKey": _sessionKey,
      "role": "system",
      "content": note,
    });
  }

  // Fix 12: Verbose level setter
  void setVerboseLevel(int level) {
    _verboseLevel = level;
  }
}

enum OpenClawEventType {
  connected,
  disconnected,
  token,
  thinkingToken, // Fix 3
  done,
  error,
  toolLog,
  historyLoaded, // Fix 4
  approvalRequested, // Fix 7
}

class OpenClawEvent {
  final OpenClawEventType type;
  final dynamic data;
  OpenClawEvent({required this.type, this.data});
}
