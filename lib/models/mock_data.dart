import 'package:flutter/material.dart';
import 'agent.dart';
import 'agent_config.dart';
import 'chat_message.dart';

class MockData {
  MockData._();

  static const agents = [
    Agent(
      id: 'openclaw',
      config: AgentConfig(
        id: 'openclaw',
        name: 'OpenClaw',
        icon: Icons.all_inclusive,
        type: AgentType.openClaw,
        baseUrl: 'ws://localhost:18789',
        modelName: 'llama3',
        contextInfo: '128k',
        deviceId: 'mock-device-id',
      ),
      version: 'v4.2.1',
      latencyMs: 48,
      status: AgentStatus.online,
      activity: 'Idle',
    ),
    Agent(
      id: 'nanoclaw',
      config: AgentConfig(
        id: 'nanoclaw',
        name: 'Nanoclaw',
        icon: Icons.bolt,
        type: AgentType.ollama,
        baseUrl: 'http://localhost:11434',
        modelName: 'phi3',
        contextInfo: 'Edge',
      ),
      version: 'v1.0.8',
      latencyMs: 12,
      status: AgentStatus.slow,
      activity: 'Processing',
    ),
    Agent(
      id: 'deepthink',
      config: AgentConfig(
        id: 'deepthink',
        name: 'DeepThink',
        icon: Icons.psychology,
        type: AgentType.anthropicCompatible,
        baseUrl: 'https://api.anthropic.com',
        modelName: 'claude-3-opus',
        contextInfo: 'Reasoning',
      ),
      version: 'v3.5',
      latencyMs: 240,
      status: AgentStatus.standby,
      activity: 'Standby',
    ),
    Agent(
      id: 'nexus7',
      config: AgentConfig(
        id: 'nexus7',
        name: 'Nexus-7',
        icon: Icons.hub,
        type: AgentType.custom,
        baseUrl: 'ws://swarm-cluster:8080',
        contextInfo: 'Swarm',
      ),
      version: 'v2.1',
      latencyMs: 86,
      status: AgentStatus.online,
      activity: 'Active',
    ),
  ];

  static final chatMessages = [
    ChatMessage(
      id: '1',
      role: MessageRole.user,
      content:
          'Can you analyze the bottleneck in the current rendering pipeline we discussed yesterday?',
      timestamp: DateTime(2025, 1, 15, 10, 42),
    ),
    ChatMessage(
      id: '2',
      role: MessageRole.assistant,
      content:
          'I\'ve reviewed the trace logs. The main bottleneck appears to be in the texture_streaming thread.\n\nIt\'s causing a 14ms stall during high-fidelity asset loading. Here is a breakdown of the frame timing:',
      timestamp: DateTime(2025, 1, 15, 10, 42, 30),
      thinkingContent:
          'Analyzing context vector from previous session. Retrieving relevant memory nodes for "Project Alpha" timelines.',
    ),
    ChatMessage(
      id: '3',
      role: MessageRole.user,
      content: 'Okay, let\'s try parallelizing the load. Draft a refactor plan.',
      timestamp: DateTime(2025, 1, 15, 10, 45),
    ),
  ];

  static const systemMetrics = {
    'Token Flow': '2,491/s',
    'Latent Sync': '98.2%',
    'Uptime': '14d 03h',
  };

  static const deploymentLog = [
    {'time': '14:02', 'message': 'Cluster update completed'},
    {'time': '12:45', 'message': 'Re-routed through sg-1'},
  ];

  static const frameTiming = [
    {'label': 'Geometry', 'time': '2.4ms', 'percent': 0.15},
    {'label': 'Lighting', 'time': '4.1ms', 'percent': 0.25},
    {'label': 'Texture Streaming', 'time': '14.2ms', 'percent': 0.85},
  ];

  static const terminalLogs = [
    {
      'time': '20:43:12',
      'level': 'INFO',
      'message': 'Connection established with OpenClaw Core v2.4.1',
    },
    {
      'time': '20:43:12',
      'level': 'DEBG',
      'message': 'Loading config from /etc/openclaw/agents/manifest.json',
    },
    {
      'time': '20:43:13',
      'level': 'DEBG',
      'message': 'Vector database initialized. Shards: 4, Replicas: 2',
    },
    {
      'time': '20:43:15',
      'level': 'API',
      'message': 'POST /v1/embeddings - 200 OK (45ms)',
    },
    {
      'time': '20:43:16',
      'level': 'SYS',
      'message': 'Garbage collection cycle started...',
    },
    {
      'time': '20:43:16',
      'level': 'SYS',
      'message': 'Garbage collection cycle finished (12ms). Freed 24MB.',
    },
    {
      'time': '20:43:18',
      'level': 'WARN',
      'message': 'Memory usage spike detected (84%). Throttling non-essential tasks.',
    },
    {
      'time': '20:43:20',
      'level': 'API',
      'message': 'GET /v1/models/gpt-4-turbo - 200 OK',
    },
    {
      'time': '20:43:21',
      'level': 'AGNT',
      'message': 'Thinking process initiated.',
    },
    {
      'time': '20:43:22',
      'level': 'DB',
      'message':
          'Query executed: SELECT * FROM memories WHERE embedding_distance < 0.2',
    },
    {
      'time': '20:43:24',
      'level': 'ERR',
      'message':
          'Connection timeout on external plugin: weather_api. Retrying in 5s...',
    },
    {
      'time': '20:43:25',
      'level': 'INFO',
      'message': 'Retry 1/3 for weather_api initiated.',
    },
    {
      'time': '20:43:29',
      'level': 'NET',
      'message': 'Inbound packet received from 192.168.1.105 (Control Panel)',
    },
    {
      'time': '20:43:30',
      'level': 'API',
      'message': 'POST /v1/chat/completions - 200 OK (Generation time: 1.2s)',
    },
    {
      'time': '20:43:32',
      'level': 'AGNT',
      'message': 'Response generated. Token usage: 45 prompt, 120 completion.',
    },
    {
      'time': '20:43:35',
      'level': 'AUTH',
      'message': 'Token refresh successful. Expires in 3600s.',
    },
  ];
}
