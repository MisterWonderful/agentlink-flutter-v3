import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/log_entry.dart';

/// Notification state provider.
final notificationsProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
        NotificationNotifier.new);

class NotificationNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [];

  int _nextId = 1;

  void add(String title, String body, {String? agentId}) {
    state = [
      AppNotification(
        id: 'notif_${_nextId++}',
        title: title,
        body: body,
        timestamp: DateTime.now(),
        agentId: agentId,
      ),
      ...state,
    ];
  }

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }

  void clear() {
    state = [];
  }
}

/// Convenience provider for unread count (for badge).
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});
