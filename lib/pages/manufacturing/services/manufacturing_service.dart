import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';

class ManufacturingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createManufacturingOrder(ManufacturingOrder order) async {
    try {
      final docRef = _firestore.collection('manufacturing_orders').doc();
      order = order.copyWith(id: docRef.id);
      await docRef.set(order.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create manufacturing order: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, ManufacturingStatus status) async {
    try {
      final updateData = {
        'status': status.toString(),
        'isFinished': status == ManufacturingStatus.completed,
      };

      if (status == ManufacturingStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('manufacturing_orders').doc(orderId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Stream<List<ManufacturingOrder>> getManufacturingOrders() {
    return _firestore
        .collection('manufacturing_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManufacturingOrder.fromMap(doc.data()))
            .toList());
  }

  Future<void> deductRawMaterials(List<RawMaterial> materials, int batchQuantity, String batchNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final companyId = await _getUserCompanyId(user.uid);
      final factoryId = await _getUserFactoryId(user.uid);

      final items = materials.map((material) {
        final totalQuantity = material.quantityRequired * batchQuantity;
        return {
          'itemId': material.materialId,
          'quantity': totalQuantity,
          'itemName': material.materialName,
        };
      }).toList();

      await _processManufacturingDeduction(
        companyId: companyId,
        factoryId: factoryId,
        batchNumber: batchNumber,
        userId: user.uid,
        items: items,
      );

    } catch (e) {
      throw Exception('Failed to deduct raw materials: $e');
    }
  }

  Future<void> _processManufacturingDeduction({
    required String companyId,
    required String factoryId,
    required String batchNumber,
    required String userId,
    required List<dynamic> items,
  }) async {
    final batch = _firestore.batch();
    final stockMovementsRef = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('stock_movements');
    final inventoryRef = _firestore
        .collection('factories')
        .doc(factoryId)
        .collection('inventory');

    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final productId = itemMap['itemId']?.toString();
      final quantity = _parseQuantity(itemMap['quantity']);
      final itemName = itemMap['itemName']?.toString() ?? productId ?? '';

      if (productId == null || productId.isEmpty || quantity <= 0) continue;

      final newMovementRef = stockMovementsRef.doc();
      batch.set(newMovementRef, {
        'type': 'manufacturing_deduction',
        'productId': productId,
        'itemName': itemName,
        'quantity': -quantity,
        'date': FieldValue.serverTimestamp(),
        'referenceId': batchNumber,
        'userId': userId,
        'factoryId': factoryId,
        'batchNumber': batchNumber,
      });

      final stockDoc = inventoryRef.doc(productId);
      batch.set(
        stockDoc,
        {
          'quantity': FieldValue.increment(-quantity),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> addFinishedProductToInventory(FinishedProduct product) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final companyId = await _getUserCompanyId(user.uid);
      final factoryId = await _getUserFactoryId(user.uid);

      final batch = _firestore.batch();

      // إضافة إلى finished_products
      final finishedProductRef = _firestore.collection('finished_products').doc();
      batch.set(finishedProductRef, product.copyWith(id: finishedProductRef.id).toMap());

      // تحديث المخزون
      final inventoryRef = _firestore
          .collection('factories')
          .doc(factoryId)
          .collection('inventory')
          .doc(finishedProductRef.id);

      batch.set(inventoryRef, {
        'quantity': FieldValue.increment(product.quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
        'name': product.name,
        'unit': product.unit,
        'batchNumber': product.batchNumber,
        'expiryDate': product.expiryDate,
      }, SetOptions(merge: true));

      // حركة مخزون
      final movementRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('stock_movements')
          .doc();

      batch.set(movementRef, {
        'type': 'manufacturing_addition',
        'productId': finishedProductRef.id,
        'itemName': product.name,
        'quantity': product.quantity,
        'date': FieldValue.serverTimestamp(),
        'referenceId': product.manufacturingOrderId,
        'userId': user.uid,
        'factoryId': factoryId,
        'batchNumber': product.batchNumber,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add finished product: $e');
    }
  }

  Stream<List<FinishedProduct>> getFinishedProducts() {
    return _firestore
        .collection('finished_products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ManufacturingOrder>> getExpiringProducts() {
    return _firestore
        .collection('manufacturing_orders')
        .where('status', isEqualTo: ManufacturingStatus.completed.toString())
        .where('isFinished', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManufacturingOrder.fromMap(doc.data()))
            .where((order) => order.isExpiringSoon)
            .toList());
  }

  Future<void> updateQualityStatus(String orderId, QualityStatus status, String notes) async {
    try {
      await _firestore.collection('manufacturing_orders').doc(orderId).update({
        'qualityStatus': status.toString(),
        'qualityNotes': notes,
      });
    } catch (e) {
      throw Exception('Failed to update quality status: $e');
    }
  }

  Future<String> generateBarcode(String batchNumber) async {
    return 'https://barcode.tec-it.com/barcode.ashx?data=$batchNumber&code=Code128&dpi=96';
  }

  Future<Map<String, dynamic>> getProductionStats(DateTime startDate, DateTime endDate) async {
    final completedOrders = await _firestore
        .collection('manufacturing_orders')
        .where('status', isEqualTo: ManufacturingStatus.completed.toString())
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    int totalProducts = 0;
    final materialsConsumed = <String, double>{};

    for (final doc in completedOrders.docs) {
      final order = ManufacturingOrder.fromMap(doc.data());
      totalProducts += order.quantity;

      for (final material in order.rawMaterials) {
        materialsConsumed.update(
          material.materialName,
          (value) => value + (material.quantityRequired * order.quantity),
          ifAbsent: () => material.quantityRequired * order.quantity,
        );
      }
    }

    return {
      'totalProducts': totalProducts,
      'materialsConsumed': materialsConsumed,
      'ordersCount': completedOrders.size,
    };
  }

  Future<String> _getUserCompanyId(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final companyIds = userData['companyIds'] as List<dynamic>?;
        if (companyIds != null && companyIds.isNotEmpty) {
          return companyIds.first.toString();
        }
      }
      return 'default_companyId';
    } catch (e) {
      return 'default_companyId';
    }
  }

  Future<String> _getUserFactoryId(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final factoryIds = userData['factoryIds'] as List<dynamic>?;
        if (factoryIds != null && factoryIds.isNotEmpty) {
          return factoryIds.first.toString();
        }
      }
      return 'default_factory_id';
    } catch (e) {
      return 'default_factory_id';
    }
  }

  double _parseQuantity(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  Stream<List<RawMaterial>> getLowStockMaterials() async* {
  try {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final factoryId = await _getUserFactoryId(user.uid);
    
    yield* _firestore
        .collection('factories')
        .doc(factoryId)
        .collection('inventory')
        .snapshots()
        .map((snapshot) {
          final lowStockMaterials = <RawMaterial>[];
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final currentStock = data['quantity']?.toDouble() ?? 0;
            final minStock = data['minStockLevel']?.toDouble() ?? 0;
            
            if (currentStock <= minStock && minStock > 0) {
              lowStockMaterials.add(RawMaterial(
                materialId: doc.id,
                materialName: data['name'] ?? 'Unknown Material',
                quantityRequired: 0,
                unit: data['unit'] ?? '',
                minStockLevel: minStock,
              ));
            }
          }
          
          return lowStockMaterials;
        });
  } catch (e) {
    throw Exception('Failed to get low stock materials: $e');
  }
}
}