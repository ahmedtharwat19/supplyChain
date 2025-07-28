import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  // ➤ ثابتات أسماء الحقول
  static const fieldNameAr = 'name_ar';
  static const fieldNameEn = 'name_en';
  static const fieldCategory = 'category';
  static const fieldUnit = 'unit';
  static const fieldDescription = 'description';
  static const fieldUserId = 'user_id';
  static const fieldCreatedAt = 'createdAt';
  static const fieldUnitPrice = 'unit_price'; // 🆕 مضاف

  // ➤ القيم المسموح بها لطبيعة الصنف
  static const List<String> allowedCategories = [
    'raw_material',
    'packaging',
    'finished_product',
    'service',
    'accessory',
    'other',
  ];

  // ➤ القيم المسموح بها للوحدة
  static const List<String> allowedUnits = [
    'kg',
    'gram',
    'piece',
    'box',
    'meter',
    'liter',
    'pack',
    'unit',
  ];

  // ➤ الخصائص
  final String? id;
  final String nameAr;
  final String nameEn;
  final String category;
  final String unit;
  final String? description;
  final double? unitPrice; // 🆕 مضاف
  final String userId;
  final Timestamp createdAt;

  Item({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.unit,
    this.description,
    this.unitPrice, // 🆕
    required this.userId,
    required this.createdAt,
  });

  // ➤ من Firestore
  factory Item.fromMap(Map<String, dynamic> data, String documentId) {
    return Item(
      id: documentId,
      nameAr: data[fieldNameAr] ?? '',
      nameEn: data[fieldNameEn] ?? '',
      category: data[fieldCategory] ?? '',
      unit: data[fieldUnit] ?? '',
      description: data[fieldDescription],
      unitPrice: (data[fieldUnitPrice] != null)
          ? (data[fieldUnitPrice] as num).toDouble()
          : null, // 🆕 يدعم التحويل من num إلى double
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldNameAr: nameAr,
      fieldNameEn: nameEn,
      fieldCategory: category,
      fieldUnit: unit,
      fieldDescription: description,
      fieldUnitPrice: unitPrice, // 🆕
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
