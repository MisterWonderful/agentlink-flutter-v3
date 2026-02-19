import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../models/tool_event.dart';
import '../../providers/agent_providers.dart';
import '../../providers/chat_providers.dart';
import '../../widgets/chat_input_bar.dart';

/// Matches Stitch "Minimalist AI Chat Terminal" screen.
/// Reads from chatMessagesProvider; sends messages via ChatNotifier.
class ChatScreen extends ConsumerStatefulWidget {
  final String agentId;

  const ChatScreen({super.key, required this.agentId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Set this as the active agent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeAgentIdProvider.notifier).set(widget.agentId);
    });
  }

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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text,
      {List<Map<String, dynamic>>? attachments}) async {
    if (text.trim().isEmpty) return;
    final chatNotifier = ref.read(chatProvider.notifier);
    await chatNotifier.sendMessage(widget.agentId, text,
        attachments: attachments);
  }

  Future<void> _handleStop() async {
    ref.read(chatProvider.notifier).stopGenerating(widget.agentId);
  }

  Future<void> _handleApproval(bool approved) async {
    ref.read(chatProvider.notifier).resolveApproval(widget.agentId, approved);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatMessagesProvider(widget.agentId));
    final agent = ref.watch(activeAgentProvider);
    final agentName = agent?.name ?? widget.agentId;

    // Auto-scroll when messages change
    ref.listen(chatMessagesProvider(widget.agentId), (_, _) => _scrollToBottom());

    final isStreaming = chatState.isStreaming;
    final hasError = chatState.messages.isNotEmpty &&
        chatState.messages.last.status == MessageStatus.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            _ChatHeader(agentName: agentName, agentId: widget.agentId),

            // ── Messages ─────────────────────────────────────────
            Expanded(
              child: chatState.messages.isEmpty
                  ? _EmptyConversation(agentName: agentName)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      itemCount:
                          chatState.messages.length + (hasError ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatState.messages.length) {
                          // Error / Retry Button
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Failed to generate response',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: AppColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Retry'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: BorderSide(
                                          color: AppColors.error
                                              .withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 0),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        }

                        final msg = chatState.messages[index];
                        if (msg.role == MessageRole.user) {
                          return _UserMessage(message: msg);
                        } else {
                          return _AssistantMessage(message: msg);
                        }
                      },
                    ),
            ),

            // Stop Generating Button
            if (isStreaming)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      onPressed: _handleStop,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      label: Text('Stop Generating',
                          style: GoogleFonts.inter(fontSize: 12)),
                    ),
                  ),
                ),
              ),

            // Fix 6: Tool cards
            if (chatState.activeTools.isNotEmpty)
              ...chatState.activeTools.map((t) => _ToolCard(tool: t)),

            // Fix 7: Approval banner
            if (chatState.approvalRequest != null)
              _ApprovalBanner(
                request: chatState.approvalRequest!,
                onApprove: () => _handleApproval(true),
                onDeny: () => _handleApproval(false),
              ),

            // Thinking Bar (if active)
            if (chatState.thinkingContent != null)
              _ThinkingBar(content: chatState.thinkingContent!),

            // ── Input Bar ────────────────────────────────────────
            ChatInputBar(
              onSend: _handleSend,
              enabled: !chatState.isStreaming,
            ),
            const SizedBox(height: 80), // Space for floating dock
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String agentName;
  final String agentId;

  const _ChatHeader({required this.agentName, required this.agentId});

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
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF737373), size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Session active',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.success,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          _TabSwitcher(agentId: agentId),
        ],
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final String agentId;
  const _TabSwitcher({required this.agentId});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tabIcon(Icons.chat_bubble_outline, 'Chat',
            isActive: true, onTap: () {}),
        const SizedBox(width: 8),
        _tabIcon(Icons.psychology_outlined, 'Thinking', onTap: () {
          context.go('/agents/$agentId/thinking');
        }),
        const SizedBox(width: 8),
        _tabIcon(Icons.terminal, 'Log', onTap: () {
          context.go('/agents/$agentId/log');
        }),
      ],
    );
  }

  Widget _tabIcon(IconData icon, String tooltip,
      {bool isActive = false, VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? AppColors.textPrimary : const Color(0xFF52525B),
          ),
        ),
      ),
    );
  }
}

// Fix 6: Tool card widget
class _ToolCard extends StatelessWidget {
  final ToolEvent tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final isRunning = tool.phase == 'start';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(Icons.check_circle_outline,
                size: 14, color: AppColors.success),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tool.toolName,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Fix 7: Approval banner
class _ApprovalBanner extends StatelessWidget {
  final ApprovalRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _ApprovalBanner({
    required this.request,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Execution Approval Required',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              request.command,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (request.reason != null) ...[
            const SizedBox(height: 4),
            Text(
              request.reason!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDeny,
                child: Text('Deny',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.error)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
                child: Text('Approve',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinkingBar extends StatelessWidget {
  final String content;

  const _ThinkingBar({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withValues(alpha: 0.08),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF18181B), width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.accentPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.accentPurple,
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  final String agentName;

  const _EmptyConversation({required this.agentName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 40, color: const Color(0xFF3F3F46)),
          const SizedBox(height: 16),
          Text(
            'Start a conversation with $agentName',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF737373),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a message below to begin',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF525252),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  final ChatMessage message;

  const _UserMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            message.content,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFFD4D4D8),
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

// Fix 13: Markdown rendering for assistant messages
class _AssistantMessage extends StatelessWidget {
  final ChatMessage message;

  const _AssistantMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, right: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message content (or streaming indicator)
          if (message.isStreaming && message.content.isEmpty)
            _StreamingIndicator()
          else
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.7,
                ),
                h1: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                h2: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                h3: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                code: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: AppColors.accentPurple,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: AppColors.accentPurple.withValues(alpha: 0.5),
                        width: 3),
                  ),
                ),
                blockquotePadding:
                    const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                listBullet: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                strong: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                em: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                ),
                a: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.accentPurple,
                  decoration: TextDecoration.underline,
                ),
              ),
              selectable: true,
            ),

          // Error state
          if (message.hasError) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.errorMessage ?? 'An error occurred',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Streaming cursor
          if (message.isStreaming && message.content.isNotEmpty)
            _StreamingCursor(),
        ],
      ),
    );
  }
}

class _StreamingIndicator extends StatefulWidget {
  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.3;
            final opacity = 0.3 +
                0.7 *
                    (((_controller.value + delay) % 1.0) > 0.5 ? 1.0 : 0.3);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
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
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 16,
        margin: const EdgeInsets.only(top: 4),
        color: AppColors.accentPurple,
      ),
    );
  }
}
