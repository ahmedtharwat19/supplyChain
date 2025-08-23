import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovement {
  // ➤ ثابتات أسماء الحقول
  static const fieldItemId = 'itemId';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldType = 'type'; // 'in' or 'out'
  static const fieldDate = 'date';
  static const fieldCompanyId = 'companyId';
  static const fieldFactoryId = 'factoryId';
  static const fieldUserId = 'userId';
  static const fieldReferenceId = 'referenceId';

  // ➤ الخصائص
  final String? id;
  final String productId;
  final double quantity;
  final String unit;
  final String type;
  final Timestamp date;
  final String companyId;
  final String factoryId;
  final String userId;
  final String referenceId;

  StockMovement({
    this.id,
    required this.productId,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.date,
    required this.companyId,
    required this.factoryId,
    required this.userId,
    required this.referenceId,
  });

  factory StockMovement.fromMap(Map<String, dynamic> data, String documentId) {
    return StockMovement(
      id: documentId,
      productId: data[fieldItemId] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      referenceId: data[fieldReferenceId] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      fieldItemId: productId,
      fieldQuantity: quantity,
      fieldUnit: unit,
      fieldType: type,
      fieldDate: date,
      fieldCompanyId: companyId,
      fieldFactoryId: factoryId,
      fieldUserId: userId,
      fieldReferenceId: referenceId,
    };
  }

  factory StockMovement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockMovement(
      id: doc.id,
      productId: data[fieldItemId] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      companyId: data[fieldCompanyId] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      userId: data[fieldUserId] ?? '',
      referenceId: data[fieldReferenceId] ?? '',
    );
  }
}
