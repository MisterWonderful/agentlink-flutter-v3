import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Chat input bar with send functionality.
/// Manages its own TextEditingController and calls onSend with the text.
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool enabled;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!_hasText || !widget.enabled) return;
    HapticFeedback.lightImpact();
    widget.onSend(_controller.text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Attach button
          IconButton(
            icon: const Icon(Icons.attach_file, size: 20),
            color: const Color(0xFF52525B),
            onPressed: () {}, // TODO: Phase 4 — file attachment
            visualDensity: VisualDensity.compact,
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              onSubmitted: widget.enabled ? (_) => _handleSend() : null,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.enabled ? 'Message...' : 'Generating...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF52525B),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // Voice button
          IconButton(
            icon: const Icon(Icons.mic_none, size: 20),
            color: const Color(0xFF52525B),
            onPressed: () {}, // TODO: Phase later — voice input
            visualDensity: VisualDensity.compact,
          ),
          // Send button — lights up when text present
          GestureDetector(
            onTap: _handleSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasText && widget.enabled
                    ? AppColors.accentPurple
                    : Colors.transparent,
              ),
              child: Icon(
                Icons.arrow_upward,
                size: 16,
                color: _hasText && widget.enabled
                    ? Colors.white
                    : const Color(0xFF52525B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
