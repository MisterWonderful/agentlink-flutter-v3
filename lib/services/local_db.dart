import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/agent.dart';
import '../models/agent_config.dart';
import '../models/chat_message.dart';
import '../models/log_entry.dart';
import 'package:flutter/material.dart';

final localDbProvider = Provider<LocalDb>((ref) {
  // We assume init is called in main or lazily. 
  // For simplicity, we'll return a singleton instance that initializes itself on first use.
  return LocalDb.instance;
});

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'agentlink.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Agents Table
        await db.execute('''
          CREATE TABLE agents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon_code INTEGER NOT NULL,
            type TEXT NOT NULL,
            base_url TEXT NOT NULL,
            api_key TEXT,
            model_name TEXT,
            system_prompt TEXT,
            context_info TEXT,
            device_id TEXT,
            version TEXT,
            latency_ms INTEGER,
            status TEXT,
            activity TEXT
          )
        ''');

        // Messages Table
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            agent_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            thinking_content TEXT,
            timestamp_ms INTEGER NOT NULL,
            token_count INTEGER,
            latency_ms INTEGER,
            FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE CASCADE
          )
        ''');

        // Logs Table
        await db.execute('''
          CREATE TABLE logs (
            id TEXT PRIMARY KEY,
            agent_id TEXT NOT NULL,
            level TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp_ms INTEGER NOT NULL,
            FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ── Agents ─────────────────────────────────────────────────────────

  Future<List<Agent>> getAllAgents() async {
    final db = await database;
    final maps = await db.query('agents');
    return maps.map((row) => _agentFromRow(row)).toList();
  }

  Future<void> insertAgent(Agent agent) async {
    final db = await database;
    await db.insert(
      'agents', 
      _agentToRow(agent),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAgent(Agent agent) async {
     final db = await database;
     await db.update(
       'agents',
       _agentToRow(agent),
       where: 'id = ?',
       whereArgs: [agent.id],
     );
  }

  Future<void> deleteAgent(String id) async {
    final db = await database;
    await db.delete('agents', where: 'id = ?', whereArgs: [id]);
  }

  // ── Messages ───────────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessages(String agentId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'agent_id = ?',
      whereArgs: [agentId],
      orderBy: 'timestamp_ms ASC',
    );
    return maps.map((row) => _messageFromRow(row)).toList();
  }

  Future<void> insertMessage(String agentId, ChatMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      _messageToRow(agentId, message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMessages(String agentId) async {
    final db = await database;
    await db.delete('messages', where: 'agent_id = ?', whereArgs: [agentId]);
  }

  // ── Logs ───────────────────────────────────────────────────────────

  Future<List<LogEntry>> getLogs(String agentId) async {
    final db = await database;
    final maps = await db.query(
      'logs',
      where: 'agent_id = ?',
      whereArgs: [agentId],
      orderBy: 'timestamp_ms ASC', // Logs usually appended
    );
    return maps.map((row) => _logFromRow(row)).toList();
  }

  Future<void> insertLog(LogEntry log) async {
    final db = await database;
    await db.insert(
      'logs',
      _logToRow(log),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<void> clearLogs(String agentId) async {
    final db = await database;
    await db.delete('logs', where: 'agent_id = ?', whereArgs: [agentId]);
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Agent _agentFromRow(Map<String, dynamic> row) {
    final config = AgentConfig(
      id: row['id'] as String,
      name: row['name'] as String,
      icon: IconData(row['icon_code'] as int, fontFamily: 'MaterialIcons'),
      type: AgentType.values.firstWhere((e) => e.toString() == row['type']),
      baseUrl: row['base_url'] as String,
      apiKey: row['api_key'] as String?,
      modelName: row['model_name'] as String?,
      systemPrompt: row['system_prompt'] as String? ?? '',
      contextInfo: row['context_info'] as String? ?? '',
      deviceId: row['device_id'] as String? ?? '',
    );
    
    return Agent(
      id: row['id'] as String,
      config: config,
      version: row['version'] as String? ?? '1.0.0',
      latencyMs: row['latency_ms'] as int? ?? 0,
      status: AgentStatus.values.firstWhere(
        (e) => e.name == row['status'], 
        orElse: () => AgentStatus.offline
      ),
      activity: row['activity'] as String? ?? 'Idle',
    );
  }

  Map<String, dynamic> _agentToRow(Agent agent) {
    return {
      'id': agent.id,
      'name': agent.config.name,
      'icon_code': agent.config.icon.codePoint,
      'type': agent.config.type.toString(),
      'base_url': agent.config.baseUrl,
      'api_key': agent.config.apiKey,
      'model_name': agent.config.modelName,
      'system_prompt': agent.config.systemPrompt,
      'context_info': agent.config.contextInfo,
      'device_id': agent.config.deviceId,
      'version': agent.version,
      'latency_ms': agent.latencyMs,
      'status': agent.status.name,
      'activity': agent.activity,
    };
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row) {
    return ChatMessage(
        id: row['id'] as String,
        role: (row['role'] as String) == 'user' ? MessageRole.user : MessageRole.assistant,
        content: row['content'] as String,
        thinkingContent: row['thinking_content'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp_ms'] as int),
        tokenCount: row['token_count'] as int?,
        latencyMs: row['latency_ms'] as int?,
    );
  }

  Map<String, dynamic> _messageToRow(String agentId, ChatMessage message) {
    return {
      'id': message.id,
      'agent_id': agentId,
      'role': message.role == MessageRole.user ? 'user' : 'assistant',
      'content': message.content,
      'thinking_content': message.thinkingContent,
      'timestamp_ms': message.timestamp.millisecondsSinceEpoch,
      'token_count': message.tokenCount,
      'latency_ms': message.latencyMs,
    };
  }

  LogEntry _logFromRow(Map<String, dynamic> row) {
    return LogEntry(
      id: row['id'] as String,
      agentId: row['agent_id'] as String,
      level: row['level'] as String,
      message: row['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp_ms'] as int),
    );
  }

  Map<String, dynamic> _logToRow(LogEntry log) {
    return {
      'id': log.id,
      'agent_id': log.agentId,
      'level': log.level,
      'message': log.message,
      'timestamp_ms': log.timestamp.millisecondsSinceEpoch,
    };
  }
}
