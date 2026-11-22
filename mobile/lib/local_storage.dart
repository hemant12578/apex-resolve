import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Permanent local persistence for offline-first operation.
/// Saves chats, messages, directories, and credentials on the phone disk,
/// allowing the app to open instantly without internet (like WhatsApp).
class LocalVault {
  const LocalVault._();

  static Directory? _cacheDir;

  static Directory getDirSync() {
    if (_cacheDir != null) return _cacheDir!;
    final fallback = Directory('${Directory.systemTemp.path}/apex_vault');
    if (!fallback.existsSync()) fallback.createSync(recursive: true);
    _cacheDir = fallback;
    return fallback;
  }

  static Future<Directory> getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    try {
      final path = await const MethodChannel('apex/session').invokeMethod<String>('getStorageDir');
      if (path != null && path.isNotEmpty && !path.startsWith('{') && (path.startsWith('/') || path.contains(':\\'))) {
        final d = Directory(path);
        if (!d.existsSync()) d.createSync(recursive: true);
        _cacheDir = d;
        return d;
      }
    } catch (_) {}
    return getDirSync();
  }

  static Future<void> save(String key, dynamic data) async {
    try {
      final dir = await getDir();
      final file = File('${dir.path}/$key.json');
      file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  static Future<dynamic> read(String key) async {
    try {
      final dir = await getDir();
      final file = File('${dir.path}/$key.json');
      if (file.existsSync()) {
        final str = file.readAsStringSync();
        return jsonDecode(str);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> remove(String key) async {
    try {
      final dir = await getDir();
      final file = File('${dir.path}/$key.json');
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
