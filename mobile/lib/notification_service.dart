import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'local_storage.dart';

enum NotificationType {
  contactRequest,
  resolutionReview,
  systemTip,
  chatMessage,
}

class ApexNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final String? peerId;
  final String? peerName;
  bool isRead;

  ApexNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.peerId,
    this.peerName,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'peerId': peerId,
    'peerName': peerName,
    'isRead': isRead,
  };

  factory ApexNotification.fromJson(Map<String, dynamic> json) =>
      ApexNotification(
        id: json['id'] as String? ?? UniqueKey().toString(),
        title: json['title'] as String? ?? 'Notification',
        body: json['body'] as String? ?? '',
        type: NotificationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NotificationType.systemTip,
        ),
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        peerId: json['peerId'] as String?,
        peerName: json['peerName'] as String?,
        isRead: json['isRead'] as bool? ?? false,
      );
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channel = MethodChannel('apex/session');
  final List<ApexNotification> _notifications = [];
  bool _initialized = false;

  List<ApexNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Load persisted notifications
    try {
      final saved = await LocalVault.read('apex_notifications');
      if (saved is List) {
        _notifications.clear();
        for (final item in saved) {
          if (item is Map) {
            _notifications.add(
              ApexNotification.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    } catch (_) {}

    // Request Android notification permission on start
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}

    // Add an initial engaging tip if empty
    if (_notifications.isEmpty) {
      addNotification(
        title: '🎉 Welcome to Apex Resolve',
        body:
            'Connect with teammates, create community rooms, or resolve issues with verifiable proof.',
        type: NotificationType.systemTip,
        showSystemNotification: false,
      );
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? peerId,
    String? peerName,
    bool showSystemNotification = true,
    String? eventId,
  }) async {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    final exists = _notifications.any((notification) {
      if (eventId != null) return notification.id == eventId;
      return notification.title == title &&
          notification.body == body &&
          notification.timestamp.isAfter(cutoff);
    });
    if (exists) return;

    final notif = ApexNotification(
      id: eventId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      peerId: peerId,
      peerName: peerName,
      isRead: false,
    );

    _notifications.insert(0, notif);
    if (_notifications.length > 50) _notifications.removeLast();
    notifyListeners();
    _persist();

    if (showSystemNotification) {
      try {
        await _channel.invokeMethod('showNotification', {
          'title': title,
          'body': body,
          'id': notif.id.hashCode,
        });
      } catch (_) {}
    }
  }

  void notifyContactRequest({
    required String peerId,
    required String peerName,
    String? requestId,
  }) {
    addNotification(
      title: '💬 New Chat Request',
      body:
          '$peerName sent you a chat request. Tap to accept and start messaging.',
      type: NotificationType.contactRequest,
      eventId: requestId == null ? null : 'contact:$requestId',
      peerId: peerId,
      peerName: peerName,
      showSystemNotification: true,
    );
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    _persist();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
      _persist();
    }
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final list = _notifications.map((n) => n.toJson()).toList();
      await LocalVault.save('apex_notifications', list);
    } catch (_) {}
  }
}
