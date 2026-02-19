import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/log_entry.dart';
import '../models/mock_data.dart';

class LogState {
  final String agentId;
  final List<LogEntry> entries;
  final Set<String> activeFilters;
  final String searchQuery;
  final bool autoScroll;

  const LogState({
    required this.agentId,
    this.entries = const [],
    this.activeFilters = const {},
    this.searchQuery = '',
    this.autoScroll = true,
  });

  LogState copyWith({
    List<LogEntry>? entries,
    Set<String>? activeFilters,
    String? searchQuery,
    bool? autoScroll,
  }) {
    return LogState(
      agentId: agentId,
      entries: entries ?? this.entries,
      activeFilters: activeFilters ?? this.activeFilters,
      searchQuery: searchQuery ?? this.searchQuery,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }

  List<LogEntry> get filteredEntries {
    var result = entries;
    if (activeFilters.isNotEmpty) {
      result = result.where((e) => activeFilters.contains(e.level)).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((e) => e.message.toLowerCase().contains(q)).toList();
    }
    return result;
  }
}

/// Central log notifier — holds all agents' log states in a map.
final logProvider =
    NotifierProvider<LogNotifier, Map<String, LogState>>(LogNotifier.new);

class LogNotifier extends Notifier<Map<String, LogState>> {
  @override
  Map<String, LogState> build() => {};

  int _nextId = 100;

  LogState _getOrCreate(String agentId) {
    if (state.containsKey(agentId)) return state[agentId]!;

    // Seed with mock data
    final now = DateTime.now();
    final entries = MockData.terminalLogs.asMap().entries.map((entry) {
      final i = entry.key;
      final log = entry.value;
      return LogEntry(
        id: 'log_$i',
        agentId: agentId,
        timestamp: now.subtract(Duration(seconds: (MockData.terminalLogs.length - i) * 3)),
        level: log['level']!,
        message: log['message']!,
      );
    }).toList();

    final newState = LogState(agentId: agentId, entries: entries);
    state = {...state, agentId: newState};
    return newState;
  }

  void _update(String agentId, LogState logState) {
    state = {...state, agentId: logState};
  }

  void addEntry(String agentId, String level, String message) {
    final ls = _getOrCreate(agentId);
    final entry = LogEntry(
      id: 'log_${_nextId++}',
      agentId: agentId,
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );
    _update(agentId, ls.copyWith(entries: [...ls.entries, entry]));
  }

  void toggleFilter(String agentId, String level) {
    final ls = _getOrCreate(agentId);
    final filters = {...ls.activeFilters};
    if (filters.contains(level)) {
      filters.remove(level);
    } else {
      filters.add(level);
    }
    _update(agentId, ls.copyWith(activeFilters: filters));
  }

  void clearFilters(String agentId) {
    final ls = _getOrCreate(agentId);
    _update(agentId, ls.copyWith(activeFilters: {}));
  }

  void setSearchQuery(String agentId, String query) {
    final ls = _getOrCreate(agentId);
    _update(agentId, ls.copyWith(searchQuery: query));
  }

  void toggleAutoScroll(String agentId) {
    final ls = _getOrCreate(agentId);
    _update(agentId, ls.copyWith(autoScroll: !ls.autoScroll));
  }

  void clearLogs(String agentId) {
    final ls = _getOrCreate(agentId);
    _update(agentId, ls.copyWith(entries: []));
  }
}

/// Derived provider: get log state for a single agent.
final terminalLogsProvider = Provider.family<LogState, String>((ref, agentId) {
  final allLogs = ref.watch(logProvider);
  return allLogs[agentId] ?? LogState(agentId: agentId);
});
