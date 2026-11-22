import 'package:material_ui/material_ui.dart';
import 'local_storage.dart';

/// Lightweight native session memory shared by the shell, sign-in and settings.
class ApexSession {
  const ApexSession._();

  static final ValueNotifier<int> expired = ValueNotifier<int>(0);
  static String name = '';
  static String email = '';

  static Future<void> loadFromDisk() async {
    try {
      final data = await LocalVault.read('user_session');
      if (data is Map) {
        if (data['name'] is String && (data['name'] as String).isNotEmpty) {
          name = data['name'];
        }
        if (data['email'] is String && (data['email'] as String).isNotEmpty) {
          email = data['email'];
        }
      }
    } catch (_) {}
  }

  static void remember({String? displayName, String? address}) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      name = displayName.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      email = address.trim();
    }
    LocalVault.save('user_session', {'name': name, 'email': email});
  }

  static void clear() {
    name = '';
    email = '';
    LocalVault.remove('user_session');
  }

  static void expire() {
    expired.value++;
  }
}
