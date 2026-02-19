import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/agent.dart';

/// Animated pulsing status dot matching Stitch agent directory design.
class StatusBadge extends StatefulWidget {
  final AgentStatus status;
  final double size;

  const StatusBadge({
    super.key,
    required this.status,
    this.size = 8,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (_shouldAnimate) {
      _controller.repeat(reverse: true);
    }
  }

  bool get _shouldAnimate =>
      widget.status == AgentStatus.online || widget.status == AgentStatus.slow;

  Color get _color {
    switch (widget.status) {
      case AgentStatus.online:
        return AppColors.success;
      case AgentStatus.slow:
        return AppColors.warning;
      case AgentStatus.standby:
        return const Color(0xFF525252);
      case AgentStatus.offline:
        return const Color(0xFF3F3F46);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size;
    final innerSize = dotSize * 0.75;

    return SizedBox(
      width: dotSize,
      height: dotSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          if (_shouldAnimate)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withValues(alpha: 0.75),
                      boxShadow: [
                        BoxShadow(
                          color: _color.withValues(
                            alpha: _opacityAnimation.value,
                          ),
                          blurRadius: 4,
                          spreadRadius: 4 * _opacityAnimation.value,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // Inner solid dot
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color,
              boxShadow: _shouldAnimate
                  ? [BoxShadow(color: _color.withValues(alpha: 0.6), blurRadius: 8)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
