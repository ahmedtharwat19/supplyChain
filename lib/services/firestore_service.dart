import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/stock_movement.dart';
import '../models/manufacturing_order.dart';
import '../models/factory.dart';
import '../models/finished_product.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ─────────────────────── Items ───────────────────────
  Future<void> addItem(String companyId, Item item) async {
    await _firestore.collection('companies/$companyId/items').add(item.toMap());
  }

  Stream<List<Item>> getItems(String companyId, String userId) {
    return _firestore
        .collection('companies/$companyId/items')
        .where(Item.fieldUserId, isEqualTo: userId)
        .orderBy(Item.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Item.fromMap(doc.data(), doc.id)).toList());
  }

  /// ──────────────── Stock Movements ────────────────
  Future<void> addStockMovement(String companyId, StockMovement movement) async {
    await _firestore
        .collection('companies/$companyId/stock_movements')
        .add(movement.toMap());
  }

  Stream<List<StockMovement>> getStockMovements(String companyId, String userId) {
    return _firestore
        .collection('companies/$companyId/stock_movements')
        .where(StockMovement.fieldUserId, isEqualTo: userId)
        .orderBy(StockMovement.fieldDate, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockMovement.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ──────────────── Manufacturing Orders ────────────────
  Future<void> addManufacturingOrder(String companyId, ManufacturingOrder order) async {
    await _firestore
        .collection('companies/$companyId/manufacturing_orders')
        .add(order.toMap());
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders(
      String companyId, String userId) {
    return _firestore
        .collection('companies/$companyId/manufacturing_orders')
        .where(ManufacturingOrder.fieldUserId, isEqualTo: userId)
        .orderBy(ManufacturingOrder.fieldStartDate, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManufacturingOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ──────────────── Factories ────────────────
  Future<void> addFactory(String companyId, Factory factory) async {
    await _firestore
        .collection('companies/$companyId/factories')
        .add(factory.toMap());
  }

  Stream<List<Factory>> getFactories(String companyId, String userId) {
    return _firestore
        .collection('companies/$companyId/factories')
        .where(Factory.fieldUserId, isEqualTo: userId)
        .orderBy(Factory.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Factory.fromMap(doc.data(), doc.id)).toList());
  }

  /// ──────────────── Finished Products ────────────────
  Future<void> addFinishedProduct(String companyId, FinishedProduct product) async {
    await _firestore
        .collection('companies/$companyId/finished_products')
        .add(product.toMap());
  }

  Stream<List<FinishedProduct>> getFinishedProducts(String companyId, String userId) {
    return _firestore
        .collection('companies/$companyId/finished_products')
        .where(FinishedProduct.fieldUserId, isEqualTo: userId)
        .orderBy(FinishedProduct.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ──────────────── Generic CRUD Methods ────────────────

  /// إضافة مستند جديد داخل مجموعة
  Future<DocumentReference> addDocument({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    return await _firestore.collection(collectionPath).add(data);
  }

  /// تحديث مستند داخل مجموعة
  Future<void> updateDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    return await _firestore.collection(collectionPath).doc(docId).update(data);
  }

  /// حذف مستند داخل مجموعة
  Future<void> deleteDocument({
    required String collectionPath,
    required String docId,
  }) async {
    return await _firestore.collection(collectionPath).doc(docId).delete();
  }

  /// جلب جميع المستندات داخل مجموعة (مع دعم userId اختياري)
  Future<List<QueryDocumentSnapshot>> getCollection({
    required String collectionPath,
    String? userId,
  }) async {
    Query query = _firestore.collection(collectionPath);
    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    final snapshot = await query.orderBy('createdAt', descending: true).get();
    return snapshot.docs;
  }

  /// جلب مستند واحد
  Future<DocumentSnapshot> getDocument({
    required String collectionPath,
    required String docId,
  }) async {
    return await _firestore.collection(collectionPath).doc(docId).get();
  }
}
