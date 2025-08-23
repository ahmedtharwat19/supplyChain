import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';


class ManufacturingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ... (الوظائف الحالية تبقى كما هي)

  // إنشاء أمر تصنيع جديد
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

  // تحديث حالة أمر التصنيع
  Future<void> updateOrderStatus(String orderId, ManufacturingStatus status) async {
    try {
      await _firestore.collection('manufacturing_orders').doc(orderId).update({
        'status': status.toString(),
        'isFinished': status == ManufacturingStatus.completed,
        'completedAt': status == ManufacturingStatus.completed 
            ? DateTime.now() 
            : null,
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  // استرجاع جميع أوامر التصنيع
  Stream<List<ManufacturingOrder>> getManufacturingOrders() {
    return _firestore
        .collection('manufacturing_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ManufacturingOrder.fromMap(doc.data()))
            .toList());
  }

  // خصم المواد الخام من المخزون
  Future<void> deductRawMaterials(List<RawMaterial> materials, String batchNumber) async {
    try {
      final batch = _firestore.batch();
      
      for (final material in materials) {
        // تحديث جدول المخزون
        final inventoryRef = _firestore.collection('inventory').doc(material.materialId);
        batch.update(inventoryRef, {
          'quantity': FieldValue.increment(-material.quantityRequired)
        });

        // إضافة حركة مخزون للخصم
        final movementRef = _firestore.collection('stock_movements').doc();
        batch.set(movementRef, {
          'id': movementRef.id,
          'itemId': material.materialId,
          'itemName': material.materialName,
          'quantity': -material.quantityRequired,
          'type': 'manufacturing_deduction',
          'batchNumber': batchNumber,
          'date': DateTime.now(),
          'createdAt': DateTime.now(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to deduct raw materials: $e');
    }
  }

  // إضافة المنتج التام إلى المخزون
  Future<void> addFinishedProduct(FinishedProduct product) async {
    try {
      final batch = _firestore.batch();
      
      // تحديث جدول المخزون للمنتج التام
      final inventoryRef = _firestore.collection('inventory').doc(product.id);
      batch.set(inventoryRef, {
        'quantity': FieldValue.increment(product.quantity),
        'lastUpdated': DateTime.now(),
      }, SetOptions(merge: true));

      // إضافة حركة مخزون للإضافة
      final movementRef = _firestore.collection('stock_movements').doc();
      batch.set(movementRef, {
        'id': movementRef.id,
        'itemId': product.id,
        'itemName': product.name,
        'quantity': product.quantity,
        'type': 'manufacturing_addition',
        'batchNumber': product.batchNumber,
        'date': DateTime.now(),
        'createdAt': DateTime.now(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add finished product: $e');
    }
  }

  // استرجاع المنتجات التامة
  Stream<List<FinishedProduct>> getFinishedProducts() {
    return _firestore
        .collection('finished_products')
        .orderBy('manufacturingDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinishedProduct.fromMap(doc.data(), doc.id))
            .toList());
  }
  // التحقق من المنتجات المنتهية الصلاحية قريباً
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

  // التحقق من المخزون المنخفض
  Stream<List<RawMaterial>> getLowStockMaterials() {
    return _firestore
        .collection('inventory')
        .snapshots()
        .map((snapshot) {
          final lowStockMaterials = <RawMaterial>[];
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final currentStock = data['quantity']?.toDouble() ?? 0;
            final minStock = data['minStockLevel']?.toDouble() ?? 0;
            
            if (currentStock <= minStock) {
              lowStockMaterials.add(RawMaterial(
                materialId: doc.id,
                materialName: data['name'] ?? doc.id,
                quantityRequired: 0,
                unit: data['unit'] ?? '',
                minStockLevel: minStock,
              ));
            }
          }
          
          return lowStockMaterials;
        });
  }

  // تحديث حالة الجودة
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

  // إنشاء باركود للتشغيلة (يمكن دمج مع مكتبة باركود لاحقاً)
  Future<String> generateBarcode(String batchNumber) async {
    // هنا يمكنك دمج مع مكتبة مثل barcode أو qr_code_scanner
    // للآن نرجع رابط وهمي
    return 'https://barcode.tec-it.com/barcode.ashx?data=$batchNumber&code=Code128&dpi=96';
  }

  // الحصول على إحصائيات الإنتاج
  Future<Map<String, dynamic>> getProductionStats(DateTime startDate, DateTime endDate) async {
    final completedOrders = await _firestore
        .collection('manufacturing_orders')
        .where('status', isEqualTo: ManufacturingStatus.completed.toString())
        .where('completedAt', isGreaterThanOrEqualTo: startDate)
        .where('completedAt', isLessThanOrEqualTo: endDate)
        .get();

    int totalProducts = 0;
    final materialsConsumed = <String, double>{};

    for (final doc in completedOrders.docs) {
      final order = ManufacturingOrder.fromMap(doc.data());
      totalProducts += order.quantity;

      for (final material in order.rawMaterials) {
        materialsConsumed.update(
          material.materialName,
          (value) => value + material.quantityRequired,
          ifAbsent: () => material.quantityRequired,
        );
      }
    }

    return {
      'totalProducts': totalProducts,
      'materialsConsumed': materialsConsumed,
      'ordersCount': completedOrders.size,
    };
  }
}