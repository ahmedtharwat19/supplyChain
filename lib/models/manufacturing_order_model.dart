import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

enum ManufacturingStatus {
  pending,
  inProgress,
  completed,
  cancelled
}

enum QualityStatus {
  pending,
  passed,
  failed
}

class ManufacturingOrder {
  final String id;
  final String batchNumber;
  final String productId;
  final String productName;
  final int quantity;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final ManufacturingStatus status;
  final bool isFinished;
  final List<RawMaterial> rawMaterials;
  final DateTime createdAt;
  final DateTime? completedAt;
  final QualityStatus qualityStatus;
  final String? qualityNotes;
  final String? barcodeUrl;

  ManufacturingOrder({
    required this.id,
    required this.batchNumber,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.status,
    required this.isFinished,
    required this.rawMaterials,
    required this.createdAt,
    this.completedAt,
    this.qualityStatus = QualityStatus.pending,
    this.qualityNotes,
    this.barcodeUrl,
  });

  // إضافة دالة للتحقق من انتهاء الصلاحية
  bool get isExpiringSoon {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7; // تنبيه قبل 7 أيام من الانتهاء
  }

  // إضافة دالة للحصول على نص الحالة مترجم
  String get statusText {
    switch (status) {
      case ManufacturingStatus.pending:
        return 'manufacturing.status_pending'.tr();
      case ManufacturingStatus.inProgress:
        return 'manufacturing.status_inProgress'.tr();
      case ManufacturingStatus.completed:
        return 'manufacturing.status_completed'.tr();
      case ManufacturingStatus.cancelled:
        return 'manufacturing.status_cancelled'.tr();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchNumber': batchNumber,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'manufacturingDate': manufacturingDate,
      'expiryDate': expiryDate,
      'status': status.toString(),
      'isFinished': isFinished,
      'rawMaterials': rawMaterials.map((rm) => rm.toMap()).toList(),
      'createdAt': createdAt,
      'completedAt': completedAt,
      'qualityStatus': qualityStatus.toString(),
      'qualityNotes': qualityNotes,
      'barcodeUrl': barcodeUrl,
    };
  }

  static ManufacturingOrder fromMap(Map<String, dynamic> map) {
    return ManufacturingOrder(
      id: map['id'],
      batchNumber: map['batchNumber'],
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      manufacturingDate: (map['manufacturingDate'] as Timestamp).toDate(),
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      status: _parseStatus(map['status']),
      isFinished: map['isFinished'],
      rawMaterials: List<RawMaterial>.from(
          map['rawMaterials'].map((rm) => RawMaterial.fromMap(rm))),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
      qualityStatus: _parseQualityStatus(map['qualityStatus']),
      qualityNotes: map['qualityNotes'],
      barcodeUrl: map['barcodeUrl'],
    );
  }

  static ManufacturingStatus _parseStatus(String status) {
    switch (status) {
      case 'ManufacturingStatus.pending': return ManufacturingStatus.pending;
      case 'ManufacturingStatus.inProgress': return ManufacturingStatus.inProgress;
      case 'ManufacturingStatus.completed': return ManufacturingStatus.completed;
      case 'ManufacturingStatus.cancelled': return ManufacturingStatus.cancelled;
      default: return ManufacturingStatus.pending;
    }
  }

  static QualityStatus _parseQualityStatus(String? status) {
    switch (status) {
      case 'QualityStatus.passed': return QualityStatus.passed;
      case 'QualityStatus.failed': return QualityStatus.failed;
      default: return QualityStatus.pending;
    }
  }

  ManufacturingOrder copyWith({
    String? id,
    String? batchNumber,
    String? productId,
    String? productName,
    int? quantity,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
    ManufacturingStatus? status,
    bool? isFinished,
    List<RawMaterial>? rawMaterials,
    DateTime? createdAt,
    DateTime? completedAt,
    QualityStatus? qualityStatus,
    String? qualityNotes,
    String? barcodeUrl,
  }) {
    return ManufacturingOrder(
      id: id ?? this.id,
      batchNumber: batchNumber ?? this.batchNumber,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      isFinished: isFinished ?? this.isFinished,
      rawMaterials: rawMaterials ?? this.rawMaterials,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      qualityNotes: qualityNotes ?? this.qualityNotes,
      barcodeUrl: barcodeUrl ?? this.barcodeUrl,
    );
  }
}

class RawMaterial {
  final String materialId;
  final String materialName;
  final double quantityRequired;
  final String unit;
  final double minStockLevel; // الحد الأدنى للمخزون

  RawMaterial({
    required this.materialId,
    required this.materialName,
    required this.quantityRequired,
    required this.unit,
    this.minStockLevel = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId,
      'materialName': materialName,
      'quantityRequired': quantityRequired,
      'unit': unit,
      'minStockLevel': minStockLevel,
    };
  }

  static RawMaterial fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      materialId: map['materialId'],
      materialName: map['materialName'],
      quantityRequired: map['quantityRequired'].toDouble(),
      unit: map['unit'],
      minStockLevel: map['minStockLevel']?.toDouble() ?? 0,
    );
  }
}