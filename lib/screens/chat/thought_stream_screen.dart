import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/chat_providers.dart';

/// Shows the raw "thinking" trace from the agent (e.g. `<think>` content).
class ThoughtStreamScreen extends ConsumerWidget {
  final String agentId;
  const ThoughtStreamScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatMessagesProvider(agentId));
    final thinkingContent = chatState.thinkingContent ?? '';
    final isThinking = chatState.isThinking;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Top status bar ─────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SYS.THOUGHT_LAYER::${isThinking ? 'ACTIVE' : 'IDLE'}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 3.0,
                      color: isThinking 
                          ? AppColors.textPrimary 
                          : const Color(0xFF525252).withValues(alpha: 0.5),
                    ),
                  ),
                  if (isThinking)
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentCyan.withValues(alpha: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentCyan.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PROCESSING',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            letterSpacing: 3.0,
                            color: AppColors.accentCyan.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.05, 0.95, 1.0],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: thinkingContent.isEmpty
                    ? Center(
                        child: Text(
                          'No active thought stream.',
                          style: GoogleFonts.jetBrainsMono(
                            color: AppColors.textSecondary.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 200),
                        reverse: true, // Auto-scroll to bottom
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Render Markdown for better readability of structured thought
                            MarkdownBody(
                              data: thinkingContent,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  color: const Color(0xFFA3A3A3),
                                  height: 1.6,
                                ),
                                code: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  backgroundColor: const Color(0xFF18181B),
                                  color: AppColors.accentCyan,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: const Color(0xFF18181B),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                              ),
                            ),
                            if (isThinking) ...[
                              const SizedBox(height: 16),
                              _ActiveCursor(),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCursor extends StatefulWidget {
  @override
  State<_ActiveCursor> createState() => _ActiveCursorState();
}

class _ActiveCursorState extends State<_ActiveCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value > 0.5 ? 1.0 : 0.0,
          child: Container(
            width: 8,
            height: 16,
            color: AppColors.accentCyan,
          ),
        );
      },
    );
  }
}
