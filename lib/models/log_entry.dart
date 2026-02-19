/// A structured terminal log entry.
class LogEntry {
  final String id;
  final String agentId;
  final DateTime timestamp;
  final String level;
  final String message;

  const LogEntry({
    required this.id,
    required this.agentId,
    required this.timestamp,
    required this.level,
    required this.message,
  });

  /// Format timestamp as HH:mm:ss.
  String get timeString {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// A notification event.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? agentId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.agentId,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      agentId: agentId,
    );
  }
}
