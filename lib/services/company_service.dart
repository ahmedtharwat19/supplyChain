import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyService {
  static Future<List<Map<String, dynamic>>> fetchUserCompanies(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);

    final List<Map<String, dynamic>> companies = [];
    for (final id in companyIds) {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(id).get();
      if (doc.exists) {
        companies.add({'id': doc.id, 'name': doc['name']});
      }
    }
    return companies;
  }
}
