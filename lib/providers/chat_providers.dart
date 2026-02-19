import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/tool_event.dart';
import '../services/service_providers.dart';
import '../models/agent.dart';
import '../models/agent_config.dart';
import '../services/openclaw_service.dart';
import '../services/local_db.dart';
import 'agent_providers.dart';
import 'log_providers.dart';
import 'settings_providers.dart';

class ChatState {
  final String agentId;
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? thinkingContent;
  final bool isThinking;
  final List<ToolEvent> activeTools;
  final ApprovalRequest? approvalRequest;

  const ChatState({
    required this.agentId,
    this.messages = const [],
    this.isStreaming = false,
    this.thinkingContent,
    this.isThinking = false,
    this.activeTools = const [],
    this.approvalRequest,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? thinkingContent,
    bool? isThinking,
    List<ToolEvent>? activeTools,
    ApprovalRequest? approvalRequest,
    bool clearApproval = false,
  }) {
    return ChatState(
      agentId: agentId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
      activeTools: activeTools ?? this.activeTools,
      approvalRequest:
          clearApproval ? null : (approvalRequest ?? this.approvalRequest),
    );
  }
}

/// Central chat notifier — holds all agents' conversations in a map.
final chatProvider =
    NotifierProvider<ChatNotifier, Map<String, ChatState>>(ChatNotifier.new);

class ChatNotifier extends Notifier<Map<String, ChatState>> {
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, String> _tagBuffers = {};

  @override
  Map<String, ChatState> build() {
    final agents = ref.watch(agentsProvider);
    _loadMessagesForAgents(agents);
    return {};
  }

  Future<void> _loadMessagesForAgents(List<Agent> agents) async {
    final db = ref.read(localDbProvider);
    final newState = {...state};

    for (final agent in agents) {
      if (!newState.containsKey(agent.id) ||
          newState[agent.id]!.messages.isEmpty) {
        final messages = await db.getMessages(agent.id);
        newState[agent.id] = ChatState(
          agentId: agent.id,
          messages: messages,
        );
      }
    }
    state = newState;
  }

  ChatState _getOrCreate(String agentId) {
    return state[agentId] ?? ChatState(agentId: agentId);
  }

  void _update(String agentId, ChatState chatState) {
    state = {...state, agentId: chatState};
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> sendMessage(String agentId, String content,
      {List<Map<String, dynamic>>? attachments}) async {
    if (content.trim().isEmpty) return;
    final cs = _getOrCreate(agentId);
    final db = ref.read(localDbProvider);

    // 1. Add User Message
    final userMsg = ChatMessage(
      id: _generateId(),
      role: MessageRole.user,
      content: content.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.complete,
    );
    await db.insertMessage(agentId, userMsg);

    // 2. Add Assistant Placeholder (Streaming)
    final assistantMsg = ChatMessage(
      id: _generateId(),
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      status: MessageStatus.streaming,
    );
    await db.insertMessage(agentId, assistantMsg);

    _update(
        agentId,
        cs.copyWith(
          messages: [...cs.messages, userMsg, assistantMsg],
          isStreaming: true,
          thinkingContent: null,
        ));

    // 3. Start Streaming
    try {
      final agents = ref.read(agentsProvider);
      final agent = agents.firstWhere(
        (a) => a.id == agentId,
        orElse: () => throw Exception('Agent $agentId not found'),
      );

      await _subscriptions[agentId]?.cancel();

      if (agent.config.type == AgentType.openClaw) {
        await _streamOpenClaw(agent, agentId, content,
            attachments: attachments);
      } else {
        await _streamHttpAgent(agent, agentId, cs.messages, userMsg);
      }
    } catch (e) {
      streamError(agentId, e.toString());
      ref.read(logProvider.notifier).addEntry(
            agentId,
            'ERR',
            'Initialization failed: $e',
          );
    }
  }

  Future<void> _streamOpenClaw(Agent agent, String agentId, String content,
      {List<Map<String, dynamic>>? attachments}) async {
    final service = ref.read(openClawServiceProvider);

    if (!service.isConnected) {
      ref.read(logProvider.notifier).addEntry(agentId, 'WS', 'Connecting...');
      await service.connect(agent);
    }

    // Fix 12: Apply verbose level before sending
    try {
      final verboseLevel = ref.read(verboseLevelProvider);
      service.setVerboseLevel(verboseLevel);
    } catch (_) {
      // verboseLevelProvider may not be initialized yet
    }

    _subscriptions[agentId] = service.events.listen((event) {
      switch (event.type) {
        case OpenClawEventType.token:
          appendStreamedContent(agentId, event.data as String);
          break;
        // Fix 3: Thinking tokens bypass tag parser
        case OpenClawEventType.thinkingToken:
          _appendThinkingContent(agentId, event.data as String);
          break;
        case OpenClawEventType.done:
          completeStream(agentId);
          ref
              .read(logProvider.notifier)
              .addEntry(agentId, 'WS', 'Run complete.');
          _subscriptions.remove(agentId);
          break;
        case OpenClawEventType.error:
          streamError(agentId, event.data.toString());
          ref
              .read(logProvider.notifier)
              .addEntry(agentId, 'ERR', 'WS Error: ${event.data}');
          _subscriptions.remove(agentId);
          break;
        case OpenClawEventType.toolLog:
          final data = event.data as Map<String, dynamic>;
          ref
              .read(logProvider.notifier)
              .addEntry(agentId, 'TOOL', '${data['name']} (${data['phase']})');
          // Fix 6: Update tool card state
          _updateToolCard(agentId, data);
          break;
        // Fix 4: History loaded
        case OpenClawEventType.historyLoaded:
          _populateFromHistory(agentId, event.data as List);
          break;
        // Fix 7: Approval requested
        case OpenClawEventType.approvalRequested:
          final payload = event.data as Map<String, dynamic>;
          final cs = _getOrCreate(agentId);
          _update(
              agentId,
              cs.copyWith(
                approvalRequest: ApprovalRequest(
                  execId: payload['execId'] ?? '',
                  command: payload['command'] ?? '',
                  reason: payload['reason'],
                ),
              ));
          break;
        default:
          break;
      }
    });

    final thinking = agent.config.thinkingLevel ?? 'low';
    ref
        .read(logProvider.notifier)
        .addEntry(agentId, 'WS', '>> chat.send: "$content"');
    await service.sendChatMessage(content, thinking: thinking, attachments: attachments);
  }

  // Fix 3: Directly append thinking content without tag parsing
  void _appendThinkingContent(String agentId, String token) {
    if (token.isEmpty) return;
    final cs = _getOrCreate(agentId);
    final currentThinking = cs.thinkingContent ?? '';
    _update(
        agentId,
        cs.copyWith(
          thinkingContent: currentThinking + token,
          isThinking: true,
        ));
  }

  // Fix 4: Populate chat from OpenClaw history
  void _populateFromHistory(String agentId, List<dynamic> rawMessages) {
    final cs = _getOrCreate(agentId);
    // Only populate if local messages are empty
    if (cs.messages.isNotEmpty) return;

    final messages = <ChatMessage>[];
    for (final raw in rawMessages) {
      if (raw is! Map<String, dynamic>) continue;
      final role = raw['role'] == 'user' ? MessageRole.user : MessageRole.assistant;
      String textContent = '';
      String? thinkingContent;

      final content = raw['content'];
      if (content is List) {
        for (final part in content) {
          if (part is Map<String, dynamic>) {
            if (part['type'] == 'text') {
              textContent += part['text'] ?? '';
            } else if (part['type'] == 'thinking') {
              thinkingContent = (thinkingContent ?? '') + (part['thinking'] ?? '');
            }
          }
        }
      } else if (content is String) {
        textContent = content;
      }

      messages.add(ChatMessage(
        id: _generateId(),
        role: role,
        content: textContent,
        timestamp: DateTime.tryParse(raw['timestamp'] ?? '') ?? DateTime.now(),
        thinkingContent: thinkingContent,
        status: MessageStatus.complete,
      ));
    }

    if (messages.isNotEmpty) {
      _update(agentId, cs.copyWith(messages: messages));
    }
  }

  // Fix 6: Update tool card state
  void _updateToolCard(String agentId, Map<String, dynamic> data) {
    final cs = _getOrCreate(agentId);
    final toolName = data['name'] as String? ?? 'unknown';
    final phase = data['phase'] as String? ?? 'start';

    final tools = [...cs.activeTools];
    if (phase == 'end') {
      // Replace the start entry with an end entry
      tools.removeWhere((t) => t.toolName == toolName && t.phase == 'start');
      tools.add(ToolEvent(
        toolName: toolName,
        phase: 'end',
        input: data['input'] as Map<String, dynamic>?,
        result: data['result'],
        timestamp: DateTime.now(),
      ));
    } else {
      tools.add(ToolEvent(
        toolName: toolName,
        phase: phase,
        input: data['input'] as Map<String, dynamic>?,
        timestamp: DateTime.now(),
      ));
    }
    _update(agentId, cs.copyWith(activeTools: tools));
  }

  // Fix 7: Resolve approval
  Future<void> resolveApproval(String agentId, bool approved) async {
    final cs = _getOrCreate(agentId);
    final request = cs.approvalRequest;
    if (request == null) return;

    final service = ref.read(openClawServiceProvider);
    await service.resolveApproval(request.execId, approved);
    _update(agentId, cs.copyWith(clearApproval: true));
  }

  // Fix 9: Session switching
  Future<void> switchSession(String agentId, String sessionKey) async {
    final service = ref.read(openClawServiceProvider);
    _update(agentId, ChatState(agentId: agentId));
    await service.switchSession(sessionKey);
  }

  Future<void> _streamHttpAgent(Agent agent, String agentId,
      List<ChatMessage> history, ChatMessage userMsg) async {
    final service = ref.read(agentServiceProvider);

    ref
        .read(logProvider.notifier)
        .addEntry(agentId, 'API', 'POST ${agent.chatEndpoint} - Sending...');

    final stream = service.streamChatCompletion(
      agent: agent,
      messages: [...history, userMsg],
    );

    _subscriptions[agentId] = stream.listen(
      (token) => appendStreamedContent(agentId, token),
      onDone: () {
        completeStream(agentId);
        ref
            .read(logProvider.notifier)
            .addEntry(agentId, 'API', 'POST ${agent.chatEndpoint} - 200 OK');
        _subscriptions.remove(agentId);
      },
      onError: (e) {
        streamError(agentId, e.toString());
        ref
            .read(logProvider.notifier)
            .addEntry(agentId, 'ERR', 'Connection failed: $e');
        _subscriptions.remove(agentId);
      },
    );
  }

  Future<void> stopGenerating(String agentId) async {
    await _subscriptions[agentId]?.cancel();
    _subscriptions.remove(agentId);

    try {
      final agents = ref.read(agentsProvider);
      final agent = agents.firstWhere((a) => a.id == agentId);
      if (agent.config.type == AgentType.openClaw) {
        final service = ref.read(openClawServiceProvider);
        if (service.isConnected) {
          ref
              .read(logProvider.notifier)
              .addEntry(agentId, 'WS', '>> chat.abort');
          await service.abortRun();
        }
      }
    } catch (e) {
      // Ignore
    }

    completeStream(agentId);
  }

  void appendStreamedContent(String agentId, String token) {
    if (token.isEmpty) return;
    final cs = _getOrCreate(agentId);
    if (cs.messages.isEmpty ||
        cs.messages.last.role != MessageRole.assistant) {
      return;
    }

    final messages = [...cs.messages];
    var lastMsg = messages.last;

    // --- Tag Parsing Logic (for HTTP SSE agents) ---
    var currentContent = lastMsg.content;
    var currentThinking = cs.thinkingContent ?? '';
    var isThinking = cs.isThinking;

    String textToProcess = (_tagBuffers[agentId] ?? '') + token;
    _tagBuffers[agentId] = '';

    final partialTagMatch = RegExp(r'<[/a-z]*$').firstMatch(textToProcess);
    if (partialTagMatch != null &&
        partialTagMatch.start < textToProcess.length &&
        partialTagMatch.group(0) != '<think>' &&
        partialTagMatch.group(0) != '</think>') {
      final cutoff = partialTagMatch.start;
      _tagBuffers[agentId] = textToProcess.substring(cutoff);
      textToProcess = textToProcess.substring(0, cutoff);
    }

    if (textToProcess.isEmpty) return;

    int index = 0;
    while (index < textToProcess.length) {
      if (isThinking) {
        final closeIdx = textToProcess.indexOf('</think>', index);
        if (closeIdx != -1) {
          currentThinking += textToProcess.substring(index, closeIdx);
          isThinking = false;
          index = closeIdx + 8;
        } else {
          currentThinking += textToProcess.substring(index);
          index = textToProcess.length;
        }
      } else {
        final openIdx = textToProcess.indexOf('<think>', index);
        if (openIdx != -1) {
          currentContent += textToProcess.substring(index, openIdx);
          isThinking = true;
          index = openIdx + 7;
        } else {
          currentContent += textToProcess.substring(index);
          index = textToProcess.length;
        }
      }
    }

    messages[messages.length - 1] = lastMsg.copyWith(content: currentContent);
    _update(
        agentId,
        cs.copyWith(
            messages: messages,
            thinkingContent:
                currentThinking.isEmpty && !isThinking ? null : currentThinking,
            isThinking: isThinking));
  }

  void completeStream(String agentId) {
    final cs = _getOrCreate(agentId);
    if (cs.messages.isEmpty ||
        cs.messages.last.role != MessageRole.assistant) {
      return;
    }

    final messages = [...cs.messages];
    final completedMsg = messages.last.copyWith(
      status: MessageStatus.complete,
      thinkingContent: cs.thinkingContent,
    );
    messages[messages.length - 1] = completedMsg;

    _update(
        agentId,
        cs.copyWith(
          messages: messages,
          isStreaming: false,
          activeTools: const [],
          clearApproval: true,
        ));

    // Persist to DB
    final db = ref.read(localDbProvider);
    db.insertMessage(agentId, completedMsg);
  }

  void streamError(String agentId, String error) {
    final cs = _getOrCreate(agentId);
    if (cs.messages.isEmpty ||
        cs.messages.last.role != MessageRole.assistant) {
      return;
    }

    final messages = [...cs.messages];
    final errorMsg = messages.last.copyWith(
      status: MessageStatus.error,
      errorMessage: error,
      thinkingContent: cs.thinkingContent,
    );
    messages[messages.length - 1] = errorMsg;

    _update(agentId, cs.copyWith(messages: messages, isStreaming: false));

    // Persist to DB
    final db = ref.read(localDbProvider);
    db.insertMessage(agentId, errorMsg);
  }

  Future<void> clearMessages(String agentId) async {
    _update(agentId, ChatState(agentId: agentId));
    final db = ref.read(localDbProvider);
    await db.deleteMessages(agentId);
  }
}

final chatMessagesProvider =
    Provider.family<ChatState, String>((ref, agentId) {
  final allChats = ref.watch(chatProvider);
  return allChats[agentId] ?? ChatState(agentId: agentId);
});
