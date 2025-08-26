// composition_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';

class CompositionService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب بيان التركيب بواسطة معرف المنتج
  Stream<ProductComposition?> getCompositionByProductId(String productId) {
    return _firestore
        .collection('product_compositions')
        .where('productId', isEqualTo: productId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return ProductComposition.fromMap(doc.data(), doc.id);
        })
        .handleError((error) {
          if (kDebugMode) {
            print('Error loading composition: $error');
          }
          return null;
        });
  }

  // جلب بيان التركيب بواسطة ID
  Future<ProductComposition?> getCompositionById(String compositionId) async {
    try {
      final doc = await _firestore
          .collection('product_compositions')
          .doc(compositionId)
          .get();
      return doc.exists ? ProductComposition.fromMap(doc.data()!, doc.id) : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting composition: $e');
      }
      return null;
    }
  }

  // حفظ بيان تركيب جديد
  Future<void> saveComposition(ProductComposition composition) async {
    try {
      if (composition.id == null) {
        await _firestore
            .collection('product_compositions')
            .add(composition.toMap());
      } else {
        await _firestore
            .collection('product_compositions')
            .doc(composition.id)
            .update(composition.toMap());
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving composition: $e');
      }
      rethrow;
    }
  }
}