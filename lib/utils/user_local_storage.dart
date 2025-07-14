import 'package:shared_preferences/shared_preferences.dart';

class UserLocalStorage {
  // ══════════════ User Info ══════════════
  static const String _keyUserId = 'userId';
  static const String _keyEmail = 'email';
  static const String _keyDisplayName = 'displayName';

  // ══════════════ Dashboard Stats ══════════════
  static const String _keyTotalCompanies = 'totalCompanies';
  static const String _keyTotalSuppliers = 'totalSuppliers';
  static const String _keyTotalOrders = 'totalOrders';
  static const String _keyTotalAmount = 'totalAmount';

  // ══════════════ Manufacturing & Inventory Stats (جديدة) ══════════════
  static const String _keyTotalFactories = 'totalFactories';
  static const String _keyTotalItems = 'totalItems';
  static const String _keyTotalStockMovements = 'totalStockMovements';
  static const String _keyTotalManufacturingOrders = 'totalManufacturingOrders';
  static const String _keyTotalFinishedProducts = 'totalFinishedProducts';

  // ══════════════ User Methods ══════════════

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

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDisplayName);
  }

  // ══════════════ Dashboard Methods ══════════════

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

  static Future<Map<String, dynamic>> getDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalCompanies': prefs.getInt(_keyTotalCompanies) ?? 0,
      'totalSuppliers': prefs.getInt(_keyTotalSuppliers) ?? 0,
      'totalOrders': prefs.getInt(_keyTotalOrders) ?? 0,
      'totalAmount': prefs.getDouble(_keyTotalAmount) ?? 0.0,
    };
  }

  static Future<void> clearDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalCompanies);
    await prefs.remove(_keyTotalSuppliers);
    await prefs.remove(_keyTotalOrders);
    await prefs.remove(_keyTotalAmount);
  }

  // ══════════════ Extended Stats Methods (مصانع، تشغيلات، إلخ) ══════════════

  static Future<void> saveExtendedStats({
    required int totalFactories,
    required int totalItems,
    required int totalStockMovements,
    required int totalManufacturingOrders,
    required int totalFinishedProducts,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalFactories, totalFactories);
    await prefs.setInt(_keyTotalItems, totalItems);
    await prefs.setInt(_keyTotalStockMovements, totalStockMovements);
    await prefs.setInt(_keyTotalManufacturingOrders, totalManufacturingOrders);
    await prefs.setInt(_keyTotalFinishedProducts, totalFinishedProducts);
  }

  static Future<Map<String, int>> getExtendedStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalFactories': prefs.getInt(_keyTotalFactories) ?? 0,
      'totalItems': prefs.getInt(_keyTotalItems) ?? 0,
      'totalStockMovements': prefs.getInt(_keyTotalStockMovements) ?? 0,
      'totalManufacturingOrders':
          prefs.getInt(_keyTotalManufacturingOrders) ?? 0,
      'totalFinishedProducts': prefs.getInt(_keyTotalFinishedProducts) ?? 0,
    };
  }

  static Future<void> clearExtendedStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalFactories);
    await prefs.remove(_keyTotalItems);
    await prefs.remove(_keyTotalStockMovements);
    await prefs.remove(_keyTotalManufacturingOrders);
    await prefs.remove(_keyTotalFinishedProducts);
  }

  // ══════════════ All Clear ══════════════

  static Future<void> clearAll() async {
    await clearUser();
    await clearDashboardData();
    await clearExtendedStats();
  }
}
