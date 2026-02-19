import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_providers.dart';
import '../widgets/floating_dock.dart';

/// Main shell that wraps pages with the floating dock nav.
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);
    final location = GoRouterState.of(context).uri.toString();

    // Sync dock selection with current route
    if (location.startsWith('/agents') && !location.contains('search')) {
      _currentIndex = 0;
    } else if (location == '/search') {
      _currentIndex = 1;
    } else if (location == '/notifications') {
      _currentIndex = 2;
    } else if (location == '/settings') {
      _currentIndex = 3;
    }

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingDock(
              currentIndex: _currentIndex,
              notificationBadge: unreadCount,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/agents');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/notifications');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}
