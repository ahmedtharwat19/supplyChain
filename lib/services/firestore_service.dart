//

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
