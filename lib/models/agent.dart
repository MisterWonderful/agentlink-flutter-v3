import 'package:flutter/material.dart';
import 'agent_config.dart';

enum AgentStatus { online, slow, standby, offline }

class Agent {
  final String id;
  final AgentConfig config;
  final String version;
  final int latencyMs;
  final AgentStatus status;
  final String activity;

  // Delegates to config for convenience
  String get name => config.name;
  IconData get icon => config.icon;
  AgentType get agentType => config.type;
  String get baseUrl => config.baseUrl;
  String? get apiKey => config.apiKey;
  String? get modelName => config.modelName;
  String get contextInfo => config.contextInfo;

  const Agent({
    required this.id,
    required this.config,
    required this.version,
    required this.latencyMs,
    required this.status,
    required this.activity,
  });

  Agent copyWith({
    String? id,
    AgentConfig? config,
    String? version,
    int? latencyMs,
    AgentStatus? status,
    String? activity,
  }) {
    return Agent(
      id: id ?? this.id,
      config: config ?? this.config,
      version: version ?? this.version,
      latencyMs: latencyMs ?? this.latencyMs,
      status: status ?? this.status,
      activity: activity ?? this.activity,
    );
  }

  /// Default chat endpoint based on agent type.
  String get chatEndpoint {
    switch (config.type) {
      case AgentType.openaiCompatible:
        return '${config.baseUrl}/v1/chat/completions';
      case AgentType.ollama:
        return '${config.baseUrl}/api/chat';
      case AgentType.anthropicCompatible:
        return '${config.baseUrl}/v1/messages';
      case AgentType.openClaw:
        // OpenClaw uses WebSocket, so HTTP endpoint might be different or unused
        // But for compatibility with existing string getter:
        return config.baseUrl.replaceFirst('ws', 'http'); 
      case AgentType.custom:
        return config.baseUrl;
    }
  }
}
