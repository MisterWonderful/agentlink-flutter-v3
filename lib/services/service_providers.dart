import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_service.dart';
import 'health_service.dart';
import 'openclaw_service.dart';

final agentServiceProvider = Provider<AgentService>((ref) {
  return AgentService();
});

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

final openClawServiceProvider = Provider<OpenClawService>((ref) {
  return OpenClawService();
});
