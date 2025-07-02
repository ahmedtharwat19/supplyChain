import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String? id;
  final String nameAr;
  final String nameEn;
  final String address;
  final String managerName;
  final String managerPhone;
  final String? logoBase64;
  final String userId;
  final Timestamp createdAt;

  Company({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.address,
    required this.managerName,
    required this.managerPhone,
    this.logoBase64,
    required this.userId,
    required this.createdAt,
  });

  factory Company.fromMap(Map<String, dynamic> data, String documentId) {
    return Company(
      id: documentId,
      nameAr: data['name_ar'] ?? '',
      nameEn: data['name_en'] ?? '',
      address: data['address'] ?? '',
      managerName: data['manager_name'] ?? '',
      managerPhone: data['manager_phone'] ?? '',
      logoBase64: data['logo_base64'],
      userId: data['user_id'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name_ar': nameAr,
      'name_en': nameEn,
      'address': address,
      'manager_name': managerName,
      'manager_phone': managerPhone,
      'logo_base64': logoBase64,
      'user_id': userId,
      'createdAt': createdAt,
    };
  }
}
