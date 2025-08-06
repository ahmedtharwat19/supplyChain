/* //

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company.dart';
import '../models/factory.dart';
import '../models/finished_product.dart';
import '../models/item.dart';
import '../models/manufacturing_order.dart';
import '../models/purchase_order.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<List<QueryDocumentSnapshot>> getDocumentsWithWhereInChunked({
  required String collectionPath,
  required String field,
  required List<String> values,
  String? userId,
  String? orderByField,
  bool descending = true,
}) async {
  final List<QueryDocumentSnapshot> allDocs = [];

  for (int i = 0; i < values.length; i += 10) {
    final chunk = values.sublist(i, i + 10 > values.length ? values.length : i + 10);
    Query query = _firestore.collection(collectionPath).where(field, whereIn: chunk);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }

    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }

    final snapshot = await query.get();
    allDocs.addAll(snapshot.docs);
  }

  return allDocs;
}





  /// ─────────────── شركات ───────────────
  Future<void> addCompany(Company company) async {
    await _firestore.collection('companies').add(company.toMap());
  }

  Stream<List<Company>> getCompanies(String userId) {
    return _firestore
        .collection('companies')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Company.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── الموردين ───────────────
  Future<void> addVendor(Supplier vendor) async {
    await _firestore.collection('vendors').add(vendor.toMap());
  }

  Stream<List<Supplier>> getVendors(String userId) {
    return _firestore
        .collection('vendors')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Supplier.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── الأصناف ───────────────
  Future<void> addItem(Item item) async {
    await _firestore.collection('items').add(item.toMap());
  }

  Stream<List<Item>> getItems(String userId) {
    return _firestore
        .collection('items')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Item.fromMap(doc.data()))
            .toList());
  }

  /// ─────────────── أوامر الشراء ───────────────
  Future<void> addPurchaseOrder(PurchaseOrder order) async {
    await _firestore.collection('purchase_orders').add(order.toMap());
  }

  Stream<List<PurchaseOrder>> getPurchaseOrders(String userId) {
    return _firestore
        .collection('purchase_orders')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PurchaseOrder.fromMap(doc)).toList());
  }

  /// ─────────────── الحركات المخزنية ───────────────
  /// ─────────────── الحركات المخزنية ───────────────
  Future<void> addStockMovement(StockMovement movement) async {
    await _firestore.collection('stock_movements').add(movement.toMap());
  }

  Stream<List<StockMovement>> getStockMovements(String userId) {
    return _firestore
        .collection('stock_movements')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockMovement.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── أوامر التصنيع ───────────────
  Future<void> addManufacturingOrder(ManufacturingOrder order) async {
    await _firestore.collection('manufacturing_orders').add(order.toMap());
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders(String userId) {
    return _firestore
        .collection('manufacturing_orders')
        .where('user_id', isEqualTo: userId)
        .orderBy('start_date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManufacturingOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── المنتجات التامة ───────────────
  Future<void> addFinishedProduct(FinishedProduct product) async {
    await _firestore.collection('finished_products').add(product.toMap());
  }

  Stream<List<FinishedProduct>> getFinishedProducts(String userId) {
    return _firestore
        .collection('finished_products')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── المصانع ───────────────
  Future<void> addFactory(Factory factory) async {
    await _firestore.collection('factories').add(factory.toMap());
  }

  Stream<List<Factory>> getFactories(
      String userId, List<String> userCompanyIds) {
    return _firestore
        .collection('factories')
        .where('companyIds', arrayContainsAny: userCompanyIds)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) =>
                doc.data()['user_id'] == userId ||
                (doc.data()['companyIds'] as List)
                    .any((id) => userCompanyIds.contains(id)))
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── عمليات عامة ───────────────
  Future<void> updateDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collectionPath).doc(docId).update(data);
  }

  Future<void> deleteDocument({
    required String collectionPath,
    required String docId,
  }) async {
    await _firestore.collection(collectionPath).doc(docId).delete();
  }

  Future<DocumentSnapshot> getDocument({
    required String collectionPath,
    required String docId,
  }) async {
    return await _firestore.collection(collectionPath).doc(docId).get();
  }

  Future<List<QueryDocumentSnapshot>> getCollection({
    required String collectionPath,
    String? userId,
  }) async {
    Query query = _firestore.collection(collectionPath);
    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    return (await query.orderBy('created_at', descending: true).get()).docs;
  }

  Future<String> generatePoNumber(String companyId) async {
    final now = DateTime.now();
    final yyMM = '${now.year % 100}${now.month.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('purchase_orders')
        .where('companyId', isEqualTo: companyId)
        .get();

    final orderCount = snapshot.docs.length + 1;
    final formattedCount = orderCount.toString().padLeft(3, '0');

    // PS: ثابت حاليًا، يمكن تغييره لاحقًا حسب رمز الشركة مثلاً
    return 'PO-PS-$yyMM$formattedCount';
  }

  Future<void> createPurchaseOrder(PurchaseOrder order) async {
  final generatedPoNumber = await generatePoNumber(order.companyId);
  final newDoc = _firestore.collection('purchase_orders').doc();

  final newOrder = order.copyWith(
    poNumber: generatedPoNumber,
    id: newDoc.id,
    orderDate: order.orderDate,
  );

  await newDoc.set(newOrder.toMap());
}


}
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/company.dart';
import '../models/factory.dart';
import '../models/finished_product.dart';
import '../models/item.dart';
import '../models/manufacturing_order.dart';
import '../models/purchase_order.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ─────────────── الشركات ───────────────
  Future<List<Company>> getUserCompanies(List<String> companyIds) async {
    if (companyIds.isEmpty) return [];

    final query = _firestore
        .collection('companies')
        .where(FieldPath.documentId, whereIn: companyIds);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Company.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// ─────────────── الموردين ───────────────
  Future<void> addVendor(Supplier vendor) async {
    await _firestore.collection('vendors').add(vendor.toMap());
  }

/*   Future<List<Supplier>> getUserVendors(String userId) async {
    final snapshot = await _firestore
        .collection('vendors')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Supplier.fromMap(doc.data(), doc.id))
        .toList();
  } */
  Future<List<Supplier>> getUserVendors(
      String userId, List<String> supplierIds) async {
    final List<Supplier> allSuppliers = [];

    // استعلام الموردين التي أنشأها المستخدم
    final createdByUserSnapshot = await _firestore
        .collection('vendors')
        .where('user_id', isEqualTo: userId)
        .get();

    allSuppliers.addAll(
      createdByUserSnapshot.docs.map(
        (doc) => Supplier.fromMap(doc.data(), doc.id),
      ),
    );

    // الموردين المرتبطين بـ supplierIds
    if (supplierIds.isNotEmpty) {
      for (int i = 0; i < supplierIds.length; i += 10) {
        final chunk = supplierIds.sublist(
          i,
          i + 10 > supplierIds.length ? supplierIds.length : i + 10,
        );

        final byIdSnapshot = await _firestore
            .collection('vendors')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allSuppliers.addAll(
          byIdSnapshot.docs.map(
            (doc) => Supplier.fromMap(doc.data(), doc.id),
          ),
        );
      }
    }

    // إزالة التكرار في حال وُجد مورد في كلا الاستعلامين
    final uniqueSuppliers = {
      for (var s in allSuppliers) s.id: s,
    }.values.toList();

    return uniqueSuppliers;
  }

  /// ─────────────── الأصناف ───────────────
  Future<void> addItem(Item item) async {
    await _firestore.collection('items').add(item.toMap());
  }
/* 
  Future<List<Item>> getUserItems(String userId) async {
    final querySnapshot = await _firestore
        .collection('items')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
  } */

  Future<List<Item>> getUserItems(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('user_id', isEqualTo: userId)
          .orderBy('createdAt', descending: true) // تأكد من اسم الحقل هنا
          .get();

      debugPrint('✅ getUserItems: returned ${querySnapshot.docs.length} items');
      return querySnapshot.docs
          .map((doc) => Item.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e, st) {
      debugPrint('❌ Error in getUserItems: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  /// ─────────────── أوامر الشراء ───────────────
  Future<void> addPurchaseOrder(PurchaseOrder order) async {
    await _firestore.collection('purchase_orders').add(order.toMap());
  }

  Stream<List<PurchaseOrder>> getPurchaseOrders(String userId) {
    return _firestore
        .collection('purchase_orders')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PurchaseOrder.fromMap(doc)).toList());
  }

  Future<void> createPurchaseOrder(PurchaseOrder order) async {
    final generatedPoNumber = await generatePoNumber(order.companyId);
    //  final newDoc = _firestore.collection('purchase_orders').doc();

    final newOrder = order.copyWith(
      poNumber: generatedPoNumber,
      //    id: newDoc.id,
      orderDate: order.orderDate,
    );

    //   await newDoc.set(newOrder.toMap());
    await _firestore
        .collection('purchase_orders')
        .doc(order.id) // ← استخدم الـ id الذي أرسلته
        .set(newOrder.toMap());
  }

  Future<String> generatePoNumber(String companyId) async {
    final now = DateTime.now();
    final yyMM = '${now.year % 100}${now.month.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('purchase_orders')
        .where('companyId', isEqualTo: companyId)
        .get();

    final orderCount = snapshot.docs.length + 1;
    final formattedCount = orderCount.toString().padLeft(3, '0');

    return 'PO-PS-$yyMM$formattedCount';
  }

  Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchase_orders')
          .doc(order.id)
          .update(order.toMap());
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  /// ─────────────── الحركات المخزنية ───────────────
  Future<void> addStockMovement(StockMovement movement) async {
    await _firestore.collection('stock_movements').add(movement.toMap());
  }

  Stream<List<StockMovement>> getStockMovements(String userId) {
    return _firestore
        .collection('stock_movements')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockMovement.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── أوامر التصنيع ───────────────
  Future<void> addManufacturingOrder(ManufacturingOrder order) async {
    await _firestore.collection('manufacturing_orders').add(order.toMap());
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders(String userId) {
    return _firestore
        .collection('manufacturing_orders')
        .where('user_id', isEqualTo: userId)
        .orderBy('start_date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManufacturingOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── المنتجات التامة ───────────────
  Future<void> addFinishedProduct(FinishedProduct product) async {
    await _firestore.collection('finished_products').add(product.toMap());
  }

  Stream<List<FinishedProduct>> getFinishedProducts(String userId) {
    return _firestore
        .collection('finished_products')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ─────────────── المصانع ───────────────
  Stream<List<Factory>> getUserFactories(
      String userId, List<String> companyIds) {
    return _firestore
        .collection('factories')
        .where('companyIds', arrayContainsAny: companyIds)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['user_id'] == userId)
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addFactory(Factory factory) async {
    await _firestore.collection('factories').add(factory.toMap());
  }

  /// ─────────────── عمليات عامة ───────────────
  Future<void> updateDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collectionPath).doc(docId).update(data);
  }

  Future<void> deleteDocument({
    required String collectionPath,
    required String docId,
  }) async {
    await _firestore.collection(collectionPath).doc(docId).delete();
  }

  Future<DocumentSnapshot> getDocument({
    required String collectionPath,
    required String docId,
  }) async {
    return await _firestore.collection(collectionPath).doc(docId).get();
  }

  Future<List<QueryDocumentSnapshot>> getCollection({
    required String collectionPath,
    String? userId,
  }) async {
    Query query = _firestore.collection(collectionPath);
    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    return (await query.orderBy('created_at', descending: true).get()).docs;
  }

  /// ─────────────── دعم whereIn بأكثر من 10 عناصر ───────────────
  Future<List<QueryDocumentSnapshot>> getDocumentsWithWhereInChunked({
    required String collectionPath,
    required String field,
    required List<String> values,
    String? userId,
    String? orderByField,
    bool descending = true,
  }) async {
    final List<QueryDocumentSnapshot> allDocs = [];

    for (int i = 0; i < values.length; i += 10) {
      final chunk =
          values.sublist(i, i + 10 > values.length ? values.length : i + 10);
      Query query =
          _firestore.collection(collectionPath).where(field, whereIn: chunk);

      if (userId != null) {
        query = query.where('user_id', isEqualTo: userId);
      }

      if (orderByField != null) {
        query = query.orderBy(orderByField, descending: descending);
      }

      final snapshot = await query.get();
      allDocs.addAll(snapshot.docs);
    }

    return allDocs;
  }

  Future<Map<String, String>> getCompanyName(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return {
          'name_ar': (data?['name_ar'] ?? 'غير معروف').toString(),
          'name_en': (data?['name_en'] ?? 'Unknown').toString(),
        };
      }
      return {'name_ar': 'غير معروف', 'name_en': 'Unknown'};
    } catch (e) {
      return {'name_ar': 'غير معروف', 'name_en': 'Unknown'};
    }
  }

  Future<Map<String, String>> getSupplierName(String supplierId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(supplierId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return {
          'name_ar': (data?['name_ar'] ?? 'غير معروف').toString(),
          'name_en': (data?['name_en'] ?? 'Unknown').toString(),
        };
      }
      return {'name_ar': 'غير معروف', 'name_en': 'Unknown'};
    } catch (e) {
      return {'name_ar': 'غير معروف', 'name_en': 'Unknown'};
    }
  }
}
