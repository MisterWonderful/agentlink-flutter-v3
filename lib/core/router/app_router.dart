import 'package:go_router/go_router.dart';
import '../../screens/main_shell.dart';
import '../../screens/agents/agent_directory_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/chat/thought_stream_screen.dart';
import '../../screens/agents/terminal_log_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/agents/add_agent_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/agents',
  routes: [
    // Add Agent Wizard (Full Screen)
    GoRoute(
      path: '/agents/new',
      builder: (context, state) => const AddAgentScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // ── Agents tab ──────────────────────────────
        GoRoute(
          path: '/agents',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AgentDirectoryScreen(),
          ),
          routes: [
            // Agent chat
            GoRoute(
              path: ':agentId/chat',
              pageBuilder: (context, state) => NoTransitionPage(
                child: ChatScreen(
                  agentId: state.pathParameters['agentId']!,
                ),
              ),
            ),
            // Agent thinking stream
            GoRoute(
              path: ':agentId/thinking',
              pageBuilder: (context, state) => NoTransitionPage(
                child: ThoughtStreamScreen(
                  agentId: state.pathParameters['agentId']!,
                ),
              ),
            ),
            // Agent terminal log
            GoRoute(
              path: ':agentId/log',
              pageBuilder: (context, state) => NoTransitionPage(
                child: TerminalLogScreen(
                  agentId: state.pathParameters['agentId']!,
                ),
              ),
            ),
          ],
        ),
        // ── Search tab ──────────────────────────────
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SearchScreen(),
          ),
        ),
        // ── Notifications tab ───────────────────────
        GoRoute(
          path: '/notifications',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsScreen(),
          ),
        ),
        // ── Settings tab ────────────────────────────
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);
