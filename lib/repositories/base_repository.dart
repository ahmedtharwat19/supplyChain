/* import '../services/firestore_service.dart';

abstract class BaseRepository<T> {
  final FirestoreService _firestore;
  final String path;
  final T Function(Map<String, dynamic> data, String docId) fromMap;

  BaseRepository(this._firestore, this.path, this.fromMap);

  Future<void> add(T entity, Map<String, dynamic> Function() toMap) {
    return _firestore.addDocument(
      collectionPath: path,
      data: toMap(),
    );
  }

  Future<void> update(String id, Map<String, dynamic> Function() toMap) {
    return _firestore.updateDocument(
      collectionPath: path,
      docId: id,
      data: toMap(),
    );
  }

  Future<void> delete(String id) {
    return _firestore.deleteDocument(
      collectionPath: path,
      docId: id,
    );
  }

  Future<T?> getById(String id) async {
    final snapshot = await _firestore.getDocument(
      collectionPath: path,
      docId: id,
    );
    if (snapshot.exists) {
      return fromMap(snapshot.data()!, snapshot.id);
    }
    return null;
  }

Future<List<T>> getAll() async {
  final snapshot = await _firestore.getCollection(
    collectionPath: path,
  );
  return snapshot
      .map((doc) => fromMap(doc.data(), doc.id))
      .toList();
}

Stream<List<T>> streamAll() {
  return _firestore.streamCollection(
    collectionPath: path,
  ).map(
    (snapshot) => snapshot.docs
        .map((doc) => fromMap(doc.data(), doc.id))
        .toList(),
  );
}

}
 */