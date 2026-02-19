import 'package:flutter/material.dart';

enum AgentType {
  openaiCompatible,
  ollama,
  anthropicCompatible,
  openClaw,
  custom,
}

class AgentConfig {
  final String id;
  final String name;
  final IconData icon;
  final AgentType type;
  final String baseUrl;
  final String? apiKey;
  final String? modelName;
  final String systemPrompt;
  final String contextInfo;
  final String deviceId;

  const AgentConfig({
    required this.id,
    required this.name,
    required this.icon,
    this.type = AgentType.openaiCompatible,
    this.baseUrl = '',
    this.apiKey,
    this.modelName,
    this.systemPrompt = '',
    this.contextInfo = '',
    this.deviceId = '',
  });

  AgentConfig copyWith({
    String? id,
    String? name,
    IconData? icon,
    AgentType? type,
    String? baseUrl,
    String? apiKey,
    String? modelName,
    String? systemPrompt,
    String? contextInfo,
    String? deviceId,
  }) {
    return AgentConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      contextInfo: contextInfo ?? this.contextInfo,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
