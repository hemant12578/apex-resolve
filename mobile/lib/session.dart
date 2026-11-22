import 'package:material_ui/material_ui.dart';

/// Lightweight native session memory shared by the shell, sign-in and settings.
class ApexSession {
  const ApexSession._();

  static final ValueNotifier<int> expired = ValueNotifier<int>(0);
  static String name = '';
  static String email = '';

  static void remember({String? displayName, String? address}) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      name = displayName.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      email = address.trim();
    }
  }

  static void clear() {
    name = '';
    email = '';
  }

  static void expire() {
    expired.value++;
  }
}
