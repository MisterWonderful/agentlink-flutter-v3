import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';

/// Chat input bar with send and attachment functionality.
class ChatInputBar extends StatefulWidget {
  final void Function(String text, {List<Map<String, dynamic>>? attachments})
      onSend;
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
  final _picker = ImagePicker();
  bool _hasText = false;
  final List<XFile> _pendingAttachments = [];

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
    if (!_hasText && _pendingAttachments.isEmpty) return;
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();

    List<Map<String, dynamic>>? attachments;
    if (_pendingAttachments.isNotEmpty) {
      attachments = _pendingAttachments
          .map((f) => {
                'type': 'image',
                'path': f.path,
                'name': f.name,
              })
          .toList();
    }

    widget.onSend(_controller.text, attachments: attachments);
    _controller.clear();
    setState(() {
      _hasText = false;
      _pendingAttachments.clear();
    });
  }

  Future<void> _handleAttach() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _pendingAttachments.addAll(images);
        });
      }
    } catch (_) {
      // User cancelled or permission denied
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pending attachment preview
        if (_pendingAttachments.isNotEmpty)
          Container(
            height: 40,
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingAttachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return Chip(
                  label: Text(
                    _pendingAttachments[index].name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteIcon:
                      const Icon(Icons.close, size: 14, color: Color(0xFF737373)),
                  onDeleted: () {
                    setState(() => _pendingAttachments.removeAt(index));
                  },
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        // Input bar
        Container(
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
              // Attach button with badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, size: 20),
                    color: const Color(0xFF52525B),
                    onPressed: _handleAttach,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (_pendingAttachments.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_pendingAttachments.length}',
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
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
                    hintText:
                        widget.enabled ? 'Message...' : 'Generating...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF52525B),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              // Voice button
              IconButton(
                icon: const Icon(Icons.mic_none, size: 20),
                color: const Color(0xFF52525B),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
              // Send button
              GestureDetector(
                onTap: _handleSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_hasText || _pendingAttachments.isNotEmpty) &&
                            widget.enabled
                        ? AppColors.accentPurple
                        : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    size: 16,
                    color: (_hasText || _pendingAttachments.isNotEmpty) &&
                            widget.enabled
                        ? Colors.white
                        : const Color(0xFF52525B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
