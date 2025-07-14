import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/stock_movement.dart';
import '../models/manufacturing_order.dart';
import '../models/factory.dart';
import '../models/finished_product.dart';

class FirestoreService {
    // ➤ قاعدة البيانات Firestore
  static final _db = FirebaseFirestore.instance;

  /// ─────────────────────── Items ───────────────────────
  Future<void> addItem(String companyId, Item item) async {
    await _db.collection('companies/$companyId/items').add(item.toMap());
  }

  Stream<List<Item>> getItems(String companyId, String userId) {
    return _db
        .collection('companies/$companyId/items')
        .where(Item.fieldUserId, isEqualTo: userId)
        .orderBy(Item.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Item.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ──────────────── Stock Movements ────────────────
  Future<void> addStockMovement(String companyId, StockMovement movement) async {
    await _db.collection('companies/$companyId/stock_movements').add(movement.toMap());
  }

  Stream<List<StockMovement>> getStockMovements(String companyId, String userId) {
    return _db
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
    await _db.collection('companies/$companyId/manufacturing_orders').add(order.toMap());
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders(String companyId, String userId) {
    return _db
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
    await _db.collection('companies/$companyId/factories').add(factory.toMap());
  }

  Stream<List<Factory>> getFactories(String companyId, String userId) {
    return _db
        .collection('companies/$companyId/factories')
        .where(Factory.fieldUserId, isEqualTo: userId)
        .orderBy(Factory.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Factory.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ──────────────── Finished Products ────────────────
  Future<void> addFinishedProduct(String companyId, FinishedProduct product) async {
    await _db.collection('companies/$companyId/finished_products').add(product.toMap());
  }

  Stream<List<FinishedProduct>> getFinishedProducts(String companyId, String userId) {
    return _db
        .collection('companies/$companyId/finished_products')
        .where(FinishedProduct.fieldUserId, isEqualTo: userId)
        .orderBy(FinishedProduct.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// ──────────────── Common Operations ────────────────
  Future<void> updateDocument(String path, Map<String, dynamic> data) async {
    await _db.doc(path).update(data);
  }

  Future<void> deleteDocument(String path) async {
    await _db.doc(path).delete();
  }
}
