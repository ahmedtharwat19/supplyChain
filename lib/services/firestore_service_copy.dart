/* /* //

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
      query = query.where('userId', isEqualTo: userId);
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
                doc.data()['userId'] == userId ||
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
      query = query.where('userId', isEqualTo: userId);
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


/* 
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
  } */

  Future<List<Item>> getUserItems(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
        .where('userId', isEqualTo: userId)
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
            .where((doc) => doc.data()['userId'] == userId)
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
      query = query.where('userId', isEqualTo: userId);
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
        query = query.where('userId', isEqualTo: userId);
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
          'nameAr': (data?['nameAr'] ?? 'غير معروف').toString(),
          'nameEn': (data?['nameEn'] ?? 'Unknown').toString(),
        };
      }
      return {'nameAr': 'غير معروف', 'nameEn': 'Unknown'};
    } catch (e) {
      return {'nameAr': 'غير معروف', 'nameEn': 'Unknown'};
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
          'nameAr': (data?['nameAr'] ?? 'غير معروف').toString(),
          'nameEn': (data?['nameEn'] ?? 'Unknown').toString(),
        };
      }
      return {'nameAr': 'غير معروف', 'nameEn': 'Unknown'};
    } catch (e) {
      return {'nameAr': 'غير معروف', 'nameEn': 'Unknown'};
    }
  }

   Future<void> processStockDelivery({
  required String companyId,
  required String factoryId,
  required String orderId,
  required String userId,
  required List<Item> items,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  final stockMovementsRef = FirebaseFirestore.instance
      .collection('companies/$companyId/stock_movements');

  final inventoryCollection = FirebaseFirestore.instance
      .collection('factories/$factoryId/inventory');

  for (final item in items) {
    final productId = item.itemId;
    final quantity = item.quantity;

    if (productId.isEmpty || quantity <= 0) continue;

    final newMovementRef = stockMovementsRef.doc();

    batch.set(newMovementRef, {
      'type': 'purchase',
      'productId': productId,
      'quantity': quantity,
      'date': FieldValue.serverTimestamp(),
      'referenceId': orderId,
      'userId': userId,
      'factoryId': factoryId,
    });

    final stockRef = inventoryCollection.doc(productId);

    batch.set(
      stockRef,
      {
        'quantity': FieldValue.increment(quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();
}
 */

  Future<void> processStockDelivery({
    required String companyId,
    required String factoryId,
    required String orderId,
    required String userId,
    required List<dynamic> items,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final stockMovementsRef = FirebaseFirestore.instance
        .collection('companies/$companyId/stock_movements');
    final inventoryRef =
        FirebaseFirestore.instance.collection('factories/$factoryId/inventory');

    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final productId = itemMap['itemId']?.toString();
      final quantity = _parseQuantity(itemMap['quantity']);

      if (productId == null || productId.isEmpty || quantity <= 0) continue;

      final newMovementRef = stockMovementsRef.doc();

      batch.set(newMovementRef, {
        'type': 'purchase',
        'productId': productId,
        'quantity': quantity,
        'date': FieldValue.serverTimestamp(),
        'referenceId': orderId,
        'userId': userId,
        'factoryId': factoryId,
      });

      final stockDoc = inventoryRef.doc(productId);
      batch.set(
          stockDoc,
          {
            'quantity': FieldValue.increment(quantity),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }

  double _parseQuantity(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> getCompanies(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snapshot = await _firestore.collection('companies')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'nameAr': data['nameAr'] ?? doc.id,
        'nameEn': data['nameEn'] ?? doc.id,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getFactories(String companyId) async {
    final snapshot = await _firestore.collection('factories')
        .where('companyIds', arrayContains: companyId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'nameAr': data['nameAr'] ?? doc.id,
        'nameEn': data['nameEn'] ?? doc.id,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final snapshot = await _firestore.collection('items').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'nameAr': data['nameAr'] ?? doc.id,
        'nameEn': data['nameEn'] ?? doc.id,
      };
    }).toList();
  }

  Stream<List<StockMovement>> getStockMovementsStream({
    required String companyId,
    required String factoryId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    bool desc = true,
  }) {
    Query query = _firestore.collection('companies')
        .doc(companyId)
        .collection('stock_movements')
        .where('factoryId', isEqualTo: factoryId);

    if (productId != null) query = query.where('productId', isEqualTo: productId);
    if (startDate != null) query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    query = query.orderBy('date', descending: desc);

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => StockMovement.fromFirestore(doc)).toList());
  }

} */