import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:puresip_purchasing/models/finished_product.dart';

class ManufacturingService {
  final _firestore = FirebaseFirestore.instance;
//  final _auth = FirebaseAuth.instance;

  // Future<void> createManufacturingOrder(ManufacturingOrder order) async {
  //   final id = _firestore.collection('manufacturing_orders').doc().id;
  //   await _firestore.collection('manufacturing_orders').doc(id).set(order.copyWith(id: id).toMap());
  // }

    Future<void> createManufacturingOrder(ManufacturingOrder order) async {
    try {
      debugPrint('Creating manufacturing order with data: ${order.toMap()}');
      await _firestore.collection('manufacturing_orders').add(order.toMap());
      debugPrint('Manufacturing order created successfully');
    } catch (e) {
      debugPrint('Error creating manufacturing order: $e');
      rethrow;
    }
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders() {
    return _firestore.collection('manufacturing_orders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ManufacturingOrder.fromMap(doc.data()..['id'] = doc.id);
      }).toList();
    });
  }

  Future<void> updateOrderStatus(String orderId, ManufacturingStatus status) async {
    await _firestore.collection('manufacturing_orders').doc(orderId).update({
      'status': status.toString(),
    });
  }

  Future<void> deductRawMaterials(List<RawMaterial> materials, int totalQuantity, String batchNumber) async {
    // هنا تضع منطق خصم المواد الخام بناءً على الكمية الكلية المطلوبة (totalQuantity)
    // مثال (اختياري حسب نظام المخزون لديك)
  }

  Future<void> addFinishedProductToInventory(FinishedProduct product) async {
    await _firestore.collection('finished_products_inventory').add(product.toMap());
  }

  // تحديث تشغيل معين (run) داخل أمر التصنيع مثلا لتحديد حالة التشغيل أو تاريخ الانتهاء
  Future<void> updateRunCompletion(String orderId, String batchNumber, DateTime completedAt) async {
    final docRef = _firestore.collection('manufacturing_orders').doc(orderId);

    final orderSnapshot = await docRef.get();
    if (!orderSnapshot.exists) return;

    final orderData = orderSnapshot.data()!;
    List<dynamic> runs = orderData['runs'] ?? [];

    // تحديث تشغيل معين
    final updatedRuns = runs.map((run) {
      if (run['batchNumber'] == batchNumber) {
        run['completedAt'] = Timestamp.fromDate(completedAt);
      }
      return run;
    }).toList();

    await docRef.update({'runs': updatedRuns});
  }

   // مثال لاسترجاع الطلبات التي على وشك الانتهاء
  Stream<List<ManufacturingOrder>> getExpiringProducts() {
    // هنا استعلامك أو المصدر المناسب للبيانات
    // على سبيل المثال:
    // return firestore.collection('manufacturing_orders')
    //   .where('expiryDate', isLessThan: DateTime.now().add(Duration(days: 7)))
    //   .snapshots()
    //   .map((snapshot) => snapshot.docs.map((doc) => ManufacturingOrder.fromFirestore(doc)).toList());
    throw UnimplementedError(); // استبدل هذا بالكود الحقيقي
  }

  // مثال لاسترجاع المواد الخام ذات المخزون المنخفض
  Stream<List<RawMaterial>> getLowStockMaterials() {
    // استعلام مشابه هنا
    throw UnimplementedError(); // استبدل هذا بالكود الحقيقي
  }
  
}
