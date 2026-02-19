import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent.dart';
import '../../providers/agent_providers.dart';
import '../../widgets/status_badge.dart';

/// Matches Stitch "Pro Agent Directory" screen.
/// Now reads from Riverpod agentsProvider instead of MockData.
class AgentDirectoryScreen extends ConsumerWidget {
  const AgentDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final metrics = ref.watch(systemMetricsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TERMINAL // V2.4',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 3.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agents',
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  // Add button → navigates to add agent flow
                  GestureDetector(
                    onTap: () {
                      context.push('/agents/new');
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF27272A),
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.add, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── System Metrics Bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF18181B), width: 1),
                  ),
                ),
                child: Row(
                  children: metrics.entries.map((entry) {
                    final isSuccess = entry.value.contains('%');
                    return Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 2.0,
                              color: const Color(0xFF52525B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.value,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: isSuccess
                                  ? AppColors.success
                                  : const Color(0xFFD4D4D8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Active Runtimes Section ─────────────────────────
            Expanded(
              child: agents.isEmpty
                  ? _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        HapticFeedback.mediumImpact();
                        await ref.read(agentsProvider.notifier).checkAllHealth();
                      },
                      color: AppColors.accentCyan,
                      backgroundColor: const Color(0xFF18181B),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 16),
                            child: Text(
                              'ACTIVE RUNTIMES',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 4.0,
                                color: const Color(0xFF3F3F46),
                              ),
                            ),
                          ),
                          // Agent Cards
                          ...agents.map(
                            (agent) => Dismissible(
                              key: ValueKey(agent.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                                ),
                                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                              ),
                              confirmDismiss: (direction) async {
                                HapticFeedback.heavyImpact();
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF18181B),
                                    title: Text('Delete Agent?', style: GoogleFonts.inter(color: Colors.white)),
                                    content: Text(
                                      'Are you sure you want to remove ${agent.name}?',
                                      style: GoogleFonts.inter(color: const Color(0xFFA1A1AA)),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (_) {
                                ref.read(agentsProvider.notifier).removeAgent(agent.id);
                              },
                              child: _AgentCard(
                                agent: agent,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.go('/agents/${agent.id}/chat');
                                },
                                onLongPress: () {
                                  HapticFeedback.mediumImpact();
                                  _showAgentActions(context, ref, agent);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentActions(BuildContext context, WidgetRef ref, Agent agent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                agent.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF737373)),
                title: Text('Chat', style: GoogleFonts.inter(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/agents/${agent.id}/chat');
                },
              ),
              ListTile(
                leading: const Icon(Icons.terminal, color: Color(0xFF737373)),
                title: Text('View Logs', style: GoogleFonts.inter(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/agents/${agent.id}/log');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: Text('Remove Agent', style: GoogleFonts.inter(color: const Color(0xFFEF4444))),
                onTap: () {
                  ref.read(agentsProvider.notifier).removeAgent(agent.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub, size: 48, color: const Color(0xFF3F3F46)),
          const SizedBox(height: 16),
          Text(
            'No agents configured',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF737373),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first agent',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: const Color(0xFF525252),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Agent agent;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _AgentCard({required this.agent, this.onTap, this.onLongPress});

  Color get _activityColor {
    switch (agent.status) {
      case AgentStatus.online:
        return const Color(0xFF737373);
      case AgentStatus.slow:
        return AppColors.accentPurple;
      case AgentStatus.standby:
        return const Color(0xFF52525B);
      case AgentStatus.offline:
        return const Color(0xFF3F3F46);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Icon(
                  agent.icon,
                  size: 28,
                  color: const Color(0xFFA1A1AA),
                ),
                const SizedBox(width: 20),
                // Name, status, details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            agent.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: agent.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${agent.latencyMs}ms • ${agent.version} • ${agent.contextInfo}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Activity label + chevron
                Row(
                  children: [
                    Text(
                      agent.activity.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: _activityColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: const Color(0xFF3F3F46),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
