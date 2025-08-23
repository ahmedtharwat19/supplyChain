/* import '../models/company.dart';
import '../services/firestore_service.dart';

class CompanyRepository {
  final FirestoreService _firestore;
  final String path = 'companies';

  CompanyRepository(this._firestore);

  Stream<List<Company>> getUserCompanies(String userId) {
    return _firestore.streamCollection(
      collectionPath: path,
      queryBuilder: (q) => q.where('userId', isEqualTo: userId),
    ).map((snapshot) =>
        snapshot.docs.map((doc) => Company.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addCompany(Company company) async {
    await _firestore.addDocument(collectionPath: path, data: company.toMap());
  }

  Future<void> updateCompany(Company company) async {
    await _firestore.updateDocument(
      collectionPath: path,
      docId: company.id!,
      data: company.toMap(),
    );
  }

  Future<void> deleteCompany(String id) async {
    await _firestore.deleteDocument(collectionPath: path, docId: id);
  }
}
 */