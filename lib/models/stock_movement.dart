import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovement {
  // ➤ ثابتات أسماء الحقول
  static const fieldItemId = 'item_id';
  static const fieldItemName = 'item_name';
  static const fieldQuantity = 'quantity';
  static const fieldUnit = 'unit';
  static const fieldType = 'type'; // 'in' or 'out'
  static const fieldDate = 'date';
  static const fieldNote = 'note';
  static const fieldCompanyId = 'company_id';
  static const fieldUserId = 'userId';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;
  final String itemId;
  final String itemName;
  final double quantity;
  final String unit;
  final String type;
  final Timestamp date;
  final String? note;
  final String companyId;
  final String userId;
  final Timestamp createdAt;

  StockMovement({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.date,
    this.note,
    required this.companyId,
    required this.userId,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, dynamic> data, String documentId) {
    return StockMovement(
      id: documentId,
      itemId: data[fieldItemId] ?? '',
      itemName: data[fieldItemName] ?? '',
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0.0,
      unit: data[fieldUnit] ?? '',
      type: data[fieldType] ?? '',
      date: data[fieldDate] ?? Timestamp.now(),
      note: data[fieldNote],
      companyId: data[fieldCompanyId] ?? '',
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      fieldItemId: itemId,
      fieldItemName: itemName,
      fieldQuantity: quantity,
      fieldUnit: unit,
      fieldType: type,
      fieldDate: date,
      fieldNote: note,
      fieldCompanyId: companyId,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
