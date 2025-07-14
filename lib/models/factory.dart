import 'package:cloud_firestore/cloud_firestore.dart';

class Factory {
  // ➤ ثابتات أسماء الحقول
  static const fieldName = 'name';
  static const fieldAddress = 'address';
  static const fieldPhone = 'phone';
  static const fieldCompanyId = 'company_id';
  static const fieldUserId = 'user_id';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;
  final String name;
  final String address;
  final String phone;
  final String companyId;
  final String userId;
  final Timestamp createdAt;

  Factory({
    this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.companyId,
    required this.userId,
    required this.createdAt,
  });

  // ➤ من Firestore
  factory Factory.fromMap(Map<String, dynamic> data, String documentId) {
    return Factory(
      id: documentId,
      name: data[fieldName] ?? '',
      address: data[fieldAddress] ?? '',
      phone: data[fieldPhone] ?? '',
      companyId: data[fieldCompanyId] ?? '',
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldName: name,
      fieldAddress: address,
      fieldPhone: phone,
      fieldCompanyId: companyId,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
