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
  final String productUnit;
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
    required this.productUnit,
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

  bool get isExpiringSoon {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7;
  }

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
      'productUnit': productUnit,
      'manufacturingDate': Timestamp.fromDate(manufacturingDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'status': status.toString(),
      'isFinished': isFinished,
      'rawMaterials': rawMaterials.map((rm) => rm.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'qualityStatus': qualityStatus.toString(),
      'qualityNotes': qualityNotes,
      'barcodeUrl': barcodeUrl,
    };
  }

  factory ManufacturingOrder.fromMap(Map<String, dynamic> map) {
    return ManufacturingOrder(
      id: map['id'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      productUnit: map['productUnit'] ?? '',
      manufacturingDate: (map['manufacturingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(map['status']),
      isFinished: map['isFinished'] ?? false,
      rawMaterials: List<RawMaterial>.from(
          (map['rawMaterials'] as List<dynamic>?)?.map((rm) => RawMaterial.fromMap(rm)) ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      qualityStatus: _parseQualityStatus(map['qualityStatus']),
      qualityNotes: map['qualityNotes'],
      barcodeUrl: map['barcodeUrl'],
    );
  }

  static ManufacturingStatus _parseStatus(String? status) {
    switch (status) {
      case 'ManufacturingStatus.pending':
        return ManufacturingStatus.pending;
      case 'ManufacturingStatus.inProgress':
        return ManufacturingStatus.inProgress;
      case 'ManufacturingStatus.completed':
        return ManufacturingStatus.completed;
      case 'ManufacturingStatus.cancelled':
        return ManufacturingStatus.cancelled;
      default:
        return ManufacturingStatus.pending;
    }
  }

  static QualityStatus _parseQualityStatus(String? status) {
    switch (status) {
      case 'QualityStatus.passed':
        return QualityStatus.passed;
      case 'QualityStatus.failed':
        return QualityStatus.failed;
      default:
        return QualityStatus.pending;
    }
  }

  ManufacturingOrder copyWith({
    String? id,
    String? batchNumber,
    String? productId,
    String? productName,
    int? quantity,
    String? productUnit,
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
      productUnit: productUnit ?? this.productUnit,
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
  final double minStockLevel;

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

  factory RawMaterial.fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      materialId: map['materialId'] ?? '',
      materialName: map['materialName'] ?? '',
      quantityRequired: (map['quantityRequired'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      minStockLevel: (map['minStockLevel'] as num?)?.toDouble() ?? 0,
    );
  }
}