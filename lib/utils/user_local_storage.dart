import 'package:shared_preferences/shared_preferences.dart';

class UserLocalStorage {
  // مفاتيح المستخدم
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';

  // مفاتيح بيانات لوحة التحكم
  static const String _keyTotalCompanies = 'totalCompanies';
  static const String _keyTotalSuppliers = 'totalSuppliers';
  static const String _keyTotalOrders = 'totalOrders';
  static const String _keyTotalAmount = 'totalAmount';

  /// حفظ بيانات المستخدم
  static Future<void> saveUser({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

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

  /// حذف بيانات المستخدم
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
  }

  /// حفظ بيانات الإحصائيات للوحة التحكم
  static Future<void> saveDashboardData({
    required int totalCompanies,
    required int totalSuppliers,
    required int totalOrders,
    required double totalAmount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalCompanies, totalCompanies);
    await prefs.setInt(_keyTotalSuppliers, totalSuppliers);
    await prefs.setInt(_keyTotalOrders, totalOrders);
    await prefs.setDouble(_keyTotalAmount, totalAmount);
  }

  /// استرجاع بيانات الإحصائيات
  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
    };
  }

  /// حذف بيانات الإحصائيات فقط
  static Future<void> clearDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalCompanies);
    await prefs.remove(_keyTotalSuppliers);
    await prefs.remove(_keyTotalOrders);
    await prefs.remove(_keyTotalAmount);
  }

  /// حذف كل البيانات (المستخدم + لوحة التحكم)
  static Future<void> clearAll() async {
    await clearUser();
    await clearDashboardData();
  }
}
