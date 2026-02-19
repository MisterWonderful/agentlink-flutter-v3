class ToolEvent {
  final String toolName;
  final String phase; // 'start' | 'end'
  final Map<String, dynamic>? input;
  final dynamic result;
  final DateTime timestamp;

  const ToolEvent({
    required this.toolName,
    required this.phase,
    this.input,
    this.result,
    required this.timestamp,
  });
}

class ApprovalRequest {
  final String execId;
  final String command;
  final String? reason;

  const ApprovalRequest({
    required this.execId,
    required this.command,
    this.reason,
  });
}
