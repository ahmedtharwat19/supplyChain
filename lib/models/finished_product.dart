import 'package:cloud_firestore/cloud_firestore.dart';

class FinishedProduct {
  // ➤ ثابتات أسماء الحقول
  static const fieldName = 'name';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldManufacturingOrderId = 'manufacturing_order_id';
  static const fieldDate = 'date';
  static const fieldCompanyId = 'companyId';
  static const fieldFactoryId = 'factoryId';
  static const fieldUserId = 'userId';
  static const fieldCreatedAt = 'createdAt';
  static const fieldBatchNumber = 'batchNumber'; // ➤ إضافة حقل رقم التشغيلة
  static const fieldExpiryDate = 'expiryDate'; // ➤ إضافة حقل تاريخ الانتهاء

  // ➤ الخصائص
  final String? id;
  final String name;
  final double quantity;
  final String unit;
  final String manufacturingOrderId;
  final Timestamp date;
  final String companyId;
  final String factoryId;
  final String userId;
  final Timestamp createdAt;
  final String batchNumber; // ➤ إضافة خاصية رقم التشغيلة
  final Timestamp expiryDate; // ➤ إضافة خاصية تاريخ الانتهاء

  FinishedProduct({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.manufacturingOrderId,
    required this.date,
    required this.companyId,
    required this.factoryId,
    required this.userId,
    required this.createdAt,
    required this.batchNumber, // ➤ إضافة معامل مطلوب
    required this.expiryDate, // ➤ إضافة معامل مطلوب
  });

  // ➤ من Firestore
  factory FinishedProduct.fromMap(Map<String, dynamic> data, String documentId) {
    return FinishedProduct(
      id: documentId,
      name: data[fieldName] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      manufacturingOrderId: data[fieldManufacturingOrderId] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
      batchNumber: data[fieldBatchNumber] ?? '', // ➤ معالجة حقل رقم التشغيلة
      expiryDate: data[fieldExpiryDate] ?? Timestamp.now(), // ➤ معالجة حقل تاريخ الانتهاء
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldName: name,
      fieldQuantity: quantity,
      fieldUnit: unit,
      fieldManufacturingOrderId: manufacturingOrderId,
      fieldDate: date,
      fieldCompanyId: companyId,
      fieldFactoryId: factoryId,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
      fieldBatchNumber: batchNumber, // ➤ إضافة حقل رقم التشغيلة
      fieldExpiryDate: expiryDate, // ➤ إضافة حقل تاريخ الانتهاء
    };
  }

  // ➤ دالة نسخ مع إمكانية تحديث الحقول
  FinishedProduct copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? manufacturingOrderId,
    Timestamp? date,
    String? companyId,
    String? factoryId,
    String? userId,
    Timestamp? createdAt,
    String? batchNumber,
    Timestamp? expiryDate,
  }) {
    return FinishedProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      manufacturingOrderId: manufacturingOrderId ?? this.manufacturingOrderId,
      date: date ?? this.date,
      companyId: companyId ?? this.companyId,
      factoryId: factoryId ?? this.factoryId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  // ➤ دالة لتحويل Timestamp إلى DateTime
  DateTime get expiryDateTime => expiryDate.toDate();
  DateTime get dateTime => date.toDate();
  DateTime get createdAtDateTime => createdAt.toDate();

  // ➤ دالة للتحقق من انتهاء الصلاحية
  bool get isExpired => DateTime.now().isAfter(expiryDateTime);
  bool get isExpiringSoon {
    final daysUntilExpiry = expiryDateTime.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7; // ➤ تنبيه قبل 7 أيام من الانتهاء
  }
}