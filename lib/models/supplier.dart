import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  // ➤ ثابتات أسماء الحقول

  static const fieldName = 'name';
  static const fieldCompany = 'company';
  static const fieldPhone = 'phone';
  static const fieldEmail = 'email';
  static const fieldAddress = 'address';
  static const fieldNotes = 'notes';
  static const fieldUserId = 'user_id';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;

  final String name;
  final String company;
  final String phone;
  final String email;
  final String address;
  final String? notes;
  final String userId;
  final Timestamp createdAt;

  Supplier({
    this.id,
    required this.name,
    required this.company,
    required this.phone,
    required this.email,
    required this.address,
    this.notes,
    required this.userId,
    required this.createdAt,
  });

  // ➤ من Firestore
  factory Supplier.fromMap(Map<String, dynamic> data, String documentId) {
    return Supplier(
      id: documentId,
      name: data[fieldName] ?? '',
      company: data[fieldCompany] ?? '',
      phone: data[fieldPhone] ?? '',
      email: data[fieldEmail] ?? '',
      address: data[fieldAddress] ?? '',
      notes: data[fieldNotes],
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  // ➤ إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldName: name,
      fieldCompany: company,
      fieldPhone: phone,
      fieldEmail: email,
      fieldAddress: address,
      fieldNotes: notes,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
