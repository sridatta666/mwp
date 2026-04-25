import 'package:hive_flutter/hive_flutter.dart';

/// App settings stored in Hive (e.g. notifications).
class SettingsService {
  static const _boxName = 'settings';
  static const _keyNotifications = 'notifications_enabled';

  Box get _box => Hive.box(_boxName);

  bool get notificationsEnabled => _box.get(_keyNotifications, defaultValue: true) as bool;

  Future<void> setNotificationsEnabled(bool value) async {
    await _box.put(_keyNotifications, value);
  }
}
