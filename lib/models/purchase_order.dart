/* import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrder {
  final String id;
  final String userId;
  final String companyId;
  final String? factoryId; // يمكن أن يكون null إذا كان للشركة فقط
  final String supplierId;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String status; // 'pending', 'approved', 'delivered', 'cancelled'
  final List<Item> items;
  final double totalAmount;
  final bool isDelivered;
  final String? deliveryNotes;

  PurchaseOrder({
    required this.id,
    required this.userId,
    required this.companyId,
    this.factoryId,
    required this.supplierId,
    required this.orderDate,
    this.deliveryDate,
    this.status = 'pending',
    required this.items,
    required this.totalAmount,
    this.isDelivered = false,
    this.deliveryNotes,
  });

  // دوال التحويل من/إلى Firestore
  factory PurchaseOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      id: doc.id,
      userId: data['userId'],
      companyId: data['companyId'],
      factoryId: data['factoryId'],
      supplierId: data['supplierId'],
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      deliveryDate: data['deliveryDate'] != null 
          ? (data['deliveryDate'] as Timestamp).toDate() 
          : null,
      status: data['status'] ?? 'pending',
      items: (data['items'] as List).map((item) => Item.fromMap(item)).toList(),
      totalAmount: data['totalAmount']?.toDouble() ?? 0.0,
      isDelivered: data['isDelivered'] ?? false,
      deliveryNotes: data['deliveryNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'companyId': companyId,
      'factoryId': factoryId,
      'supplierId': supplierId,
      'orderDate': Timestamp.fromDate(orderDate),
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'isDelivered': isDelivered,
      'deliveryNotes': deliveryNotes,
    };
  }
}



class Item {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final bool isTaxable; // تحديد إذا كان الصنف خاضعًا للضريبة
  final double taxRate; // نسبة الضريبة (14% كقيمة افتراضية)
  final double taxAmount; // مبلغ الضريبة
  final double totalAfterTaxAmount; // الإجمالي بعد الضريبة

  Item({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.isTaxable = true, // قيمة افتراضية true
    this.taxRate = 14.0, // 14% كقيمة افتراضية
    this.taxAmount = 0.0,
    this.totalAfterTaxAmount = 0.0,
  });

  // دالة إنشاء صنف مع حساب تلقائي للضريبة
  factory Item.create({
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    required double unitPrice,
    bool isTaxable = true,
    double taxRate = 14.0, // 14% كقيمة افتراضية
  }) {
    final totalPrice = unitPrice * quantity;
    final taxAmount = isTaxable ? totalPrice * (taxRate / 100) : 0.0;
    final totalAfterTax = totalPrice + taxAmount;

    return Item(
      itemId: itemId,
      name: name,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      isTaxable: isTaxable,
      taxRate: isTaxable ? taxRate : 0.0, // إذا كان معفى تصبح النسبة 0
      taxAmount: taxAmount,
      totalAfterTaxAmount: totalAfterTax,
    );
  }

  // باقي الدوال (fromMap, toMap, copyWith) تبقى كما هي
  // ...
}

/* class Item {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  // 🔧 Add these:
  final double taxRate;
  final double taxAmount;
  final double totalAfterTaxAmount;

  Item({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.totalAfterTaxAmount = 0.0,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      itemId: map['itemId'],
      name: map['name'],
      quantity: map['quantity']?.toDouble() ?? 0.0,
      unit: map['unit'],
      unitPrice: map['unitPrice']?.toDouble() ?? 0.0,
      totalPrice: map['totalPrice']?.toDouble() ?? 0.0,
      taxRate: map['taxRate']?.toDouble() ?? 0.0,
      taxAmount: map['taxAmount']?.toDouble() ?? 0.0,
      totalAfterTaxAmount: map['totalAfterTaxAmount']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'totalAfterTaxAmount': totalAfterTaxAmount,
    };
  }

  // ✅ Also add copyWith to fix other errors:
  Item copyWith({
    String? itemId,
    String? name,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    double? taxRate,
    double? taxAmount,
    double? totalAfterTaxAmount,
  }) {
    return Item(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAfterTaxAmount: totalAfterTaxAmount ?? this.totalAfterTaxAmount,
    );
  }
}

 */

/* class Item { 

  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  

  Item({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      itemId: map['itemId'],
      name: map['name'],
      quantity: map['quantity']?.toDouble() ?? 0.0,
      unit: map['unit'],
      unitPrice: map['unitPrice']?.toDouble() ?? 0.0,
      totalPrice: map['totalPrice']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}*/

 */



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/item.dart';


class PurchaseOrder {
  final String id;
  final String poNumber;
  final String userId;
  final String companyId;
  final String? factoryId;
  final String supplierId;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String status;
  final List<Item> items;
  final double totalAmount;
  final bool isDelivered;
  final String? deliveryNotes;
  final double taxRate;
  final double totalTax;
  final double totalAmountAfterTax;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.userId,
    required this.companyId,
    this.factoryId,
    required this.supplierId,
    required this.orderDate,
    this.deliveryDate,
    this.status = 'pending',
    required this.items,
    required this.totalAmount,
    this.isDelivered = false,
    this.deliveryNotes,
    required this.taxRate,
    required this.totalTax,
    required this.totalAmountAfterTax,
  });

  factory PurchaseOrder.fromMap(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      id: doc.id,
      poNumber: data['poNumber'] ?? '',
      userId: data['userId'] ?? '',
      companyId: data['companyId'] ?? '',
      factoryId: data['factoryId'],
      supplierId: data['supplierId'] ?? '',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      deliveryDate: data['deliveryDate'] != null
          ? (data['deliveryDate'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'pending',
      items: (data['items'] as List<dynamic>)
          .map((item) => Item.fromMap(item))
          .toList(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      taxRate: (data['taxRate'] ?? 0).toDouble(), // إضافة هذا السطر
      totalTax: (data['totalTax'] ?? 0).toDouble(), // إضافة هذا السطر
      totalAmountAfterTax:
          (data['totalAmountAfterTax'] ?? 0).toDouble(), // إضافة هذا السطر
      isDelivered: data['isDelivered'] ?? false,
      deliveryNotes: data['deliveryNotes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'poNumber': poNumber,
      'companyId': companyId,
      'factoryId': factoryId,
      'supplierId': supplierId,
      'orderDate': Timestamp.fromDate(orderDate),
      'deliveryDate':
          deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'taxRate': taxRate, // إضافة هذا السطر
      'totalTax': totalTax, // إضافة هذا السطر
      'totalAmountAfterTax': totalAmountAfterTax, // إضافة هذا السطر
      'isDelivered': isDelivered,
      'deliveryNotes': deliveryNotes,
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? poNumber,
    String? userId,
    String? companyId,
    String? factoryId,
    String? supplierId,
    DateTime? orderDate,
    DateTime? deliveryDate,
    String? status,
    List<Item>? items,
    double? totalAmount,
    double? taxRate,
    double? totalTax,
    double? totalAmountAfterTax,
    bool? isDelivered,
    String? deliveryNotes,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      factoryId: factoryId ?? this.factoryId,
      supplierId: supplierId ?? this.supplierId,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      taxRate: taxRate ?? this.taxRate,
      totalTax: totalTax ?? this.totalTax,
      totalAmountAfterTax: totalAmountAfterTax ?? this.totalAmountAfterTax,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
    );
  }

  factory PurchaseOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      id: doc.id,
      poNumber: data['poNumber'] ?? '',
      userId: data['userId'] ?? '',
      companyId: data['companyId'] ?? '',
      factoryId: data['factoryId'],
      supplierId: data['supplierId'] ?? '',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      deliveryDate: data['deliveryDate'] != null
          ? (data['deliveryDate'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'pending',
      items: (data['items'] as List<dynamic>)
          .map((item) => Item.fromMap(item))
          .toList(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      taxRate: (data['taxRate'] ?? 0).toDouble(),
      totalTax: (data['totalTax'] ?? 0).toDouble(),
      totalAmountAfterTax: (data['totalAmountAfterTax'] ?? 0).toDouble(),
      isDelivered: data['isDelivered'] ?? false,
      deliveryNotes: data['deliveryNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poNumber': poNumber,
      'userId': userId,
      'companyId': companyId,
      'factoryId': factoryId,
      'supplierId': supplierId,
      'orderDate': orderDate,
      'deliveryDate': deliveryDate,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'taxRate': taxRate,
      'totalTax': totalTax,
      'totalAmountAfterTax': totalAmountAfterTax,
      'isDelivered': isDelivered,
      'deliveryNotes': deliveryNotes,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
