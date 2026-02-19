import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/log_providers.dart';

/// Matches Stitch "Raw OpenClaw Terminal Log" screen.
/// Now reads from terminalLogsProvider with filtering.
class TerminalLogScreen extends ConsumerStatefulWidget {
  final String agentId;

  const TerminalLogScreen({super.key, required this.agentId});

  @override
  ConsumerState<TerminalLogScreen> createState() => _TerminalLogScreenState();
}

class _TerminalLogScreenState extends ConsumerState<TerminalLogScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'INFO':
        return AppColors.logInfo;
      case 'DEBG':
        return AppColors.logDebug;
      case 'API':
        return AppColors.logApi;
      case 'SYS':
        return AppColors.logSys;
      case 'WARN':
        return AppColors.warning;
      case 'ERR':
        return AppColors.error;
      case 'AGNT':
        return AppColors.logAgent;
      case 'AUTH':
        return AppColors.logAuth;
      case 'NET':
        return AppColors.logNet;
      case 'DB':
        return AppColors.logDb;
      default:
        return const Color(0xFF737373);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(terminalLogsProvider(widget.agentId));
    final filteredEntries = logState.filteredEntries;

    // Auto-scroll when new entries arrive
    ref.listen(terminalLogsProvider(widget.agentId), (_, next) {
      if (next.autoScroll) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────
            _LogHeader(
              agentId: widget.agentId,
              entryCount: logState.entries.length,
              activeFilters: logState.activeFilters,
              onFilterTap: () => _showFilterSheet(context),
              onClearTap: () {
                ref.read(logProvider.notifier).clearLogs(widget.agentId);
              },
            ),

            // // ── Active Filters Bar ─────────────────────────────
            if (logState.activeFilters.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: Colors.white.withValues(alpha: 0.02),
                child: Row(
                  children: [
                    Text(
                      'FILTERS: ',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: const Color(0xFF52525B),
                        letterSpacing: 1,
                      ),
                    ),
                    ...logState.activeFilters.map((f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => ref.read(logProvider.notifier).toggleFilter(widget.agentId, f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _levelColor(f).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            f,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: _levelColor(f),
                            ),
                          ),
                        ),
                      ),
                    )),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref.read(logProvider.notifier).clearFilters(widget.agentId),
                      child: Text(
                        'CLEAR',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: const Color(0xFF52525B),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Log Stream ─────────────────────────────────────
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: Text(
                        logState.entries.isEmpty
                            ? 'No log entries'
                            : 'No entries match filters',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: const Color(0xFF52525B),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      itemCount: filteredEntries.length + 1, // +1 for awaiting line
                      itemBuilder: (context, index) {
                        if (index == filteredEntries.length) {
                          return _AwaitingLine();
                        }
                        final entry = filteredEntries[index];
                        return _LogLine(
                          time: entry.timeString,
                          level: entry.level,
                          message: entry.message,
                          color: _levelColor(entry.level),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final levels = ['INFO', 'DEBG', 'API', 'SYS', 'WARN', 'ERR', 'AGNT', 'AUTH', 'NET', 'DB'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final activeFilters = ref.watch(terminalLogsProvider(widget.agentId)).activeFilters;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FILTER BY LEVEL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: const Color(0xFF52525B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: levels.map((level) {
                      final isActive = activeFilters.contains(level);
                      return GestureDetector(
                        onTap: () => ref.read(logProvider.notifier).toggleFilter(widget.agentId, level),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? _levelColor(level).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: isActive
                                ? Border.all(color: _levelColor(level).withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Text(
                            level,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive ? _levelColor(level) : const Color(0xFF737373),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────────

class _LogHeader extends StatelessWidget {
  final String agentId;
  final int entryCount;
  final Set<String> activeFilters;
  final VoidCallback onFilterTap;
  final VoidCallback onClearTap;

  const _LogHeader({
    required this.agentId,
    required this.entryCount,
    required this.activeFilters,
    required this.onFilterTap,
    required this.onClearTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF18181B), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF737373), size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Live Log',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Ping dot
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$entryCount entries',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: const Color(0xFF737373),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Filter button
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: activeFilters.isNotEmpty
                    ? AppColors.accentPurple.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.filter_list,
                size: 18,
                color: activeFilters.isNotEmpty
                    ? AppColors.accentPurple
                    : const Color(0xFF52525B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clear button
          GestureDetector(
            onTap: onClearTap,
            child: const Icon(Icons.block, size: 18, color: Color(0xFF52525B)),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final String time;
  final String level;
  final String message;
  final Color color;

  const _LogLine({
    required this.time,
    required this.level,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF3F3F46),
            ),
          ),
          const SizedBox(width: 12),
          // Level badge
          Container(
            width: 36,
            alignment: Alignment.centerLeft,
            child: Text(
              level,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Message
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: const Color(0xFFA1A1AA),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwaitingLine extends StatefulWidget {
  @override
  State<_AwaitingLine> createState() => _AwaitingLineState();
}

class _AwaitingLineState extends State<_AwaitingLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            '  >>>  ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF3F3F46),
            ),
          ),
          Text(
            'Awaiting',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF3F3F46),
            ),
          ),
          const SizedBox(width: 4),
          FadeTransition(
            opacity: _controller,
            child: Container(
              width: 7,
              height: 14,
              color: AppColors.accentPurple,
            ),
          ),
        ],
      ),
    );
  }
}
