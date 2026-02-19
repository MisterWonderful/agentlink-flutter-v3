import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/service_providers.dart';
import '../models/agent.dart';
import '../models/agent_config.dart';
import '../services/openclaw_service.dart';
import '../services/local_db.dart';
import 'agent_providers.dart';
import 'log_providers.dart';

class ChatState {
  final String agentId;
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? thinkingContent;
  final bool isThinking;

  const ChatState({
    required this.agentId,
    this.messages = const [],
    this.isStreaming = false,
    this.thinkingContent,
    this.isThinking = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? thinkingContent,
    bool? isThinking,
  }) {
    return ChatState(
      agentId: agentId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
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
    // Load messages for all agents when they become available
    // We listen to agentsProvider to know which agents exist
    final agents = ref.watch(agentsProvider);
    _loadMessagesForAgents(agents);
    return {};
  }

  Future<void> _loadMessagesForAgents(List<Agent> agents) async {
    final db = ref.read(localDbProvider);
    final newState = {...state};
    
    for (final agent in agents) {
      if (!newState.containsKey(agent.id) || newState[agent.id]!.messages.isEmpty) {
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
  
  // Need to generate IDs that don't collide. Database uses Strings. 
  // UUIDs are safer, but for now simple increment is okay if persisted? 
  // No, if we restart, _nextId resets. We should use UUIDs or timestamp-based IDs.
  // Converting to static utility for ID generation.
  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> sendMessage(String agentId, String content) async {
    if (content.trim().isEmpty) return;
    final cs = _getOrCreate(agentId);
    final db = ref.read(localDbProvider);

    // 1. Add User Message
    final userMsg = ChatMessage(
      id: _generateId(),
      role: MessageRole.user,
      content: content.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.complete, // User messages are complete immediately
    );
    await db.insertMessage(agentId, userMsg);

    // 2. Add Assistant Placeholder (Streaming)
    final assistantMsg = ChatMessage(
      id: _generateId(), // Separate ID
      role: MessageRole.assistant,
      content: '', 
      timestamp: DateTime.now(),
      status: MessageStatus.streaming,
    );
    await db.insertMessage(agentId, assistantMsg);

    _update(agentId, cs.copyWith(
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
        await _streamOpenClaw(agent, agentId, content);
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

  Future<void> _streamOpenClaw(Agent agent, String agentId, String content) async {
    final service = ref.read(openClawServiceProvider);
    
    if (!service.isConnected) {
       ref.read(logProvider.notifier).addEntry(agentId, 'WS', 'Connecting...');
       await service.connect(agent);
    }

    _subscriptions[agentId] = service.events.listen((event) {
      switch (event.type) {
        case OpenClawEventType.token:
          appendStreamedContent(agentId, event.data as String);
          break;
        case OpenClawEventType.done:
          completeStream(agentId);
          ref.read(logProvider.notifier).addEntry(agentId, 'WS', 'Run complete.');
          _subscriptions.remove(agentId);
          break;
        case OpenClawEventType.error:
          streamError(agentId, event.data.toString());
          ref.read(logProvider.notifier).addEntry(agentId, 'ERR', 'WS Error: ${event.data}');
          _subscriptions.remove(agentId);
          break;
        case OpenClawEventType.toolLog:
           final data = event.data as Map<String, dynamic>;
           ref.read(logProvider.notifier).addEntry(agentId, 'TOOL', '${data['name']} (${data['phase']})');
           break;
        default:
          break;
      }
    });

    ref.read(logProvider.notifier).addEntry(agentId, 'WS', '>> chat.send: "$content"');
    await service.sendChatMessage(content);
  }

  Future<void> _streamHttpAgent(
      Agent agent, String agentId, List<ChatMessage> history, ChatMessage userMsg) async {
    final service = ref.read(agentServiceProvider);
      
    ref.read(logProvider.notifier).addEntry(agentId, 'API', 'POST ${agent.chatEndpoint} - Sending...');

    final stream = service.streamChatCompletion(
      agent: agent,
      messages: [...history, userMsg], 
    );

    _subscriptions[agentId] = stream.listen(
      (token) => appendStreamedContent(agentId, token),
      onDone: () {
        completeStream(agentId);
        ref.read(logProvider.notifier).addEntry(agentId, 'API', 'POST ${agent.chatEndpoint} - 200 OK');
        _subscriptions.remove(agentId);
      },
      onError: (e) {
        streamError(agentId, e.toString());
        ref.read(logProvider.notifier).addEntry(agentId, 'ERR', 'Connection failed: $e');
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
           ref.read(logProvider.notifier).addEntry(agentId, 'WS', '>> chat.abort');
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
    if (cs.messages.isEmpty || cs.messages.last.role != MessageRole.assistant) return;

    final messages = [...cs.messages];
    var lastMsg = messages.last;
    
    // --- Tag Parsing Logic ---
    var currentContent = lastMsg.content;
    var currentThinking = cs.thinkingContent ?? '';
    var isThinking = cs.isThinking;
    
    String textToProcess = (_tagBuffers[agentId] ?? '') + token;
    _tagBuffers[agentId] = ''; 

    final partialTagMatch = RegExp(r'<[/a-z]*$').firstMatch(textToProcess);
    if (partialTagMatch != null && partialTagMatch.start < textToProcess.length && partialTagMatch.group(0) != '<think>' && partialTagMatch.group(0) != '</think>') {
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

    // Update memory
    messages[messages.length - 1] = lastMsg.copyWith(content: currentContent);
    _update(agentId, cs.copyWith(
      messages: messages, 
      thinkingContent: currentThinking.isEmpty && !isThinking ? null : currentThinking,
      isThinking: isThinking
    ));
    
    // NOTE: We do NOT persist to DB here to avoid performance hit. 
    // Only on completeStream.
  }

  void completeStream(String agentId) {
    final cs = _getOrCreate(agentId);
    if (cs.messages.isEmpty || cs.messages.last.role != MessageRole.assistant) return;

    final messages = [...cs.messages];
    final completedMsg = messages.last.copyWith(
      status: MessageStatus.complete,
      thinkingContent: cs.thinkingContent, // Ensure thinking content is saved in msg
    );
    messages[messages.length - 1] = completedMsg;
    
    _update(agentId, cs.copyWith(messages: messages, isStreaming: false));

    // Persist to DB
    final db = ref.read(localDbProvider);
    db.insertMessage(agentId, completedMsg);
  }

  void streamError(String agentId, String error) {
    final cs = _getOrCreate(agentId);
    if (cs.messages.isEmpty || cs.messages.last.role != MessageRole.assistant) return;

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

final chatMessagesProvider = Provider.family<ChatState, String>((ref, agentId) {
  final allChats = ref.watch(chatProvider);
  return allChats[agentId] ?? ChatState(agentId: agentId);
});
