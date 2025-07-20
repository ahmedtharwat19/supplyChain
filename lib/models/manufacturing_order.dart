import 'package:cloud_firestore/cloud_firestore.dart';

/// حالة أمر التشغيل
enum ManufacturingStatus { pending, inProgress, done }

extension ManufacturingStatusExtension on ManufacturingStatus {
  /// القيمة التي يتم تخزينها في Firestore
  String get value {
    switch (this) {
      case ManufacturingStatus.pending:
        return 'pending';
      case ManufacturingStatus.inProgress:
        return 'in_progress';
      case ManufacturingStatus.done:
        return 'done';
    }
  }

  /// تسمية الحالة باللغة العربية (يمكن ربطها بـ easy_localization لاحقًا)
  String get label {
    switch (this) {
      case ManufacturingStatus.pending:
        return 'قيد الانتظار';
      case ManufacturingStatus.inProgress:
        return 'قيد التنفيذ';
      case ManufacturingStatus.done:
        return 'مكتمل';
    }
  }

  /// تحويل النص المخزن إلى enum
  static ManufacturingStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return ManufacturingStatus.inProgress;
      case 'done':
        return ManufacturingStatus.done;
      case 'pending':
      default:
        return ManufacturingStatus.pending;
    }
  }
}

/// نموذج أمر التشغيل
class ManufacturingOrder {
  // ➤ أسماء الحقول
  static const fieldTitle = 'title';
  static const fieldFactoryId = 'factory_id';
  static const fieldFactoryName = 'factory_name';
  static const fieldStatus = 'status';
  static const fieldStartDate = 'start_date';
  static const fieldEndDate = 'end_date';
  static const fieldNote = 'note';
  static const fieldCompanyId = 'company_id';
  static const fieldUserId = 'user_id';
  static const fieldCreatedAt = 'createdAt';

  // ➤ الخصائص
  final String? id;
  final String title;
  final String factoryId;
  final String factoryName;
  final ManufacturingStatus status;
  final Timestamp startDate;
  final Timestamp? endDate;
  final String? note;
  final String companyId;
  final String userId;
  final Timestamp createdAt;

  ManufacturingOrder({
    this.id,
    required this.title,
    required this.factoryId,
    required this.factoryName,
    required this.status,
    required this.startDate,
    this.endDate,
    this.note,
    required this.companyId,
    required this.userId,
    required this.createdAt,
  });

  /// إنشاء من Firestore
  factory ManufacturingOrder.fromMap(Map<String, dynamic> data, String documentId) {
    return ManufacturingOrder(
      id: documentId,
      title: data[fieldTitle] ?? '',
      factoryId: data[fieldFactoryId] ?? '',
      factoryName: data[fieldFactoryName] ?? '',
      status: ManufacturingStatusExtension.fromString(data[fieldStatus] ?? 'pending'),
      startDate: data[fieldStartDate] ?? Timestamp.now(),
      endDate: data[fieldEndDate],
      note: data[fieldNote],
      companyId: data[fieldCompanyId] ?? '',
      userId: data[fieldUserId] ?? '',
      createdAt: data[fieldCreatedAt] ?? Timestamp.now(),
    );
  }

  /// تحويل إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      fieldTitle: title,
      fieldFactoryId: factoryId,
      fieldFactoryName: factoryName,
      fieldStatus: status.value,
      fieldStartDate: startDate,
      fieldEndDate: endDate,
      fieldNote: note,
      fieldCompanyId: companyId,
      fieldUserId: userId,
      fieldCreatedAt: createdAt,
    };
  }
}
