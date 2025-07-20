import 'package:cloud_firestore/cloud_firestore.dart';

class FinishedProduct {
  // ➤ ثابتات أسماء الحقول
  static const fieldName = 'name';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldManufacturingOrderId = 'manufacturing_order_id';
  static const fieldDate = 'date';
  static const fieldCompanyId = 'company_id';
  static const fieldUserId = 'user_id';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;
  final String name;
  final double quantity;
  final String unit;
  final String manufacturingOrderId;
  final Timestamp date;
  final String companyId;
  final String userId;
  final Timestamp createdAt;

  FinishedProduct({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.manufacturingOrderId,
    required this.date,
    required this.companyId,
    required this.userId,
    required this.createdAt,
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
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
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
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
