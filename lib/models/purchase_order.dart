import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrder {
  final String id;
  final String userId;
  final String companyId;
  final String? factoryId; // يمكن أن يكون null إذا كان للشركة فقط
  final String supplierId;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String status; // 'pending', 'approved', 'delivered', 'cancelled'
  final List<OrderItem> items;
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
      items: (data['items'] as List).map((item) => OrderItem.fromMap(item)).toList(),
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

class OrderItem {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  OrderItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
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
}