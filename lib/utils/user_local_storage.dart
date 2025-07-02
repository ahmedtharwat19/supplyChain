import 'package:shared_preferences/shared_preferences.dart';

class UserLocalStorage {
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';

  /// حفظ بيانات المستخدم
  static Future<void> saveUser({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // استخدام الجزء قبل @ من البريد الإلكتروني إذا لم يتم تمرير displayName
    final nameToSave = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!
        : email.split('@').first;

    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyDisplayName, nameToSave);
  }

  /// استرجاع بيانات المستخدم
  static Future<Map<String, String>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail);
    final displayName = prefs.getString(_keyDisplayName);

    if (userId == null) return null;

    return {
      'userId': userId,
      'email': email ?? '',
      'displayName': displayName ?? '',
    };
  }

  /// حذف بيانات المستخدم عند تسجيل الخروج
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
  }
}
