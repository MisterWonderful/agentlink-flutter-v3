import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent.dart';

import '../services/service_providers.dart';
import '../services/local_db.dart';
// import '../services/health_service.dart'; // Already in service_providers
// Let's check service_providers.dart content later if needed.
// But ambiguous import error said: defined in health_service.dart AND service_providers.dart.
// So I should remove health_service.dart import if service_providers has it.


/// Holds the current list of agents.
final agentsProvider =
    NotifierProvider<AgentListNotifier, List<Agent>>(AgentListNotifier.new);

class AgentListNotifier extends Notifier<List<Agent>> {
  Timer? _timer;

  @override
  List<Agent> build() {
    // Start periodic health checks
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => checkAllHealth());
    ref.onDispose(() => _timer?.cancel());
    
    // Load initial data
    _loadAgents();
    
    return [];
  }

  Future<void> _loadAgents() async {
    final db = ref.read(localDbProvider);
    final agents = await db.getAllAgents();
    state = agents;
    // Trigger health check for all loaded agents
    checkAllHealth();
  }

  Future<void> addAgent(Agent agent) async {
    final db = ref.read(localDbProvider);
    await db.insertAgent(agent);
    state = [...state, agent];
    checkAgentHealth(agent.id);
  }

  Future<void> removeAgent(String id) async {
    final db = ref.read(localDbProvider);
    await db.deleteAgent(id);
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> updateAgentConfig(Agent agent) async {
     final db = ref.read(localDbProvider);
     await db.updateAgent(agent);
     state = [
      for (final a in state)
        if (a.id == agent.id) agent else a,
    ];
  }

  /// Update status (transient, but we persist it for now to keep state simple, 
  /// though ideally we'd separate runtime state from config persistence).
  void updateStatus(String id, AgentStatus status, {int? latencyMs, String? activity}) {
    state = [
      for (final a in state)
        if (a.id == id)
          a.copyWith(
            status: status,
            latencyMs: latencyMs ?? a.latencyMs,
            activity: activity ?? a.activity,
          )
        else
          a,
    ];
    // We do NOT persist transient status updates to DB to avoid IO spam
  }

  Future<void> checkAgentHealth(String id) async {
    final currentAgent = state.firstWhere((a) => a.id == id, orElse: () => throw Exception('Agent not found'));
    updateStatus(id, currentAgent.status, activity: 'Pinging...');

    final service = ref.read(healthServiceProvider);
    final result = await service.checkHealth(
        currentAgent.baseUrl, 
        currentAgent.agentType, 
        apiKey: currentAgent.apiKey
    );
    
    updateStatus(
      id, 
      result.status, 
      latencyMs: result.latencyMs,
      activity: result.status == AgentStatus.offline 
          ? result.message 
          : 'Idle' 
    );
  }

  Future<void> checkAllHealth() async {
    for (final agent in state) {
      await checkAgentHealth(agent.id);
    }
  }

  void reorder(int oldIndex, int newIndex) {
    // Reorder logic not fully persisted yet (would need 'order' field in DB)
    final agents = [...state];
    final agent = agents.removeAt(oldIndex);
    agents.insert(newIndex, agent);
    state = agents;
  }
}

/// Currently selected agent ID.
final activeAgentIdProvider =
    NotifierProvider<ActiveAgentIdNotifier, String?>(ActiveAgentIdNotifier.new);

class ActiveAgentIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

/// Derived: get the currently selected agent object.
final activeAgentProvider = Provider<Agent?>((ref) {
  final id = ref.watch(activeAgentIdProvider);
  if (id == null) return null;
  final agents = ref.watch(agentsProvider);
  return agents.where((a) => a.id == id).firstOrNull;
});

/// System metrics (derived from agent data).
final systemMetricsProvider = Provider<Map<String, String>>((ref) {
  final agents = ref.watch(agentsProvider);
  final onlineCount = agents.where((a) => a.status == AgentStatus.online).length;
  final avgLatency = agents.isEmpty
      ? 0
      : (agents.map((a) => a.latencyMs).reduce((a, b) => a + b) / agents.length).round();

  return {
    'Token Flow': '${(avgLatency * 52).toStringAsFixed(0)}/s',
    'Latent Sync': '${agents.isEmpty ? 0 : (onlineCount / agents.length * 100).toStringAsFixed(1)}%',
    'Uptime': '${agents.length} agents',
  };
});
