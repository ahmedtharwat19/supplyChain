import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelper {
  static Future<void> updateItemsTaxableField() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();
    
    for (final doc in snapshot.docs) {
      await doc.reference.update({
        'is_taxable': true
      });
    }
  }
}