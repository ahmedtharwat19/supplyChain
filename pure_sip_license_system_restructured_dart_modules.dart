/* // File: models/license_state.dart

enum LicenseState { valid, expired, invalid, pending }

// File: models/license_status.dart

class LicenseStatus {
  final String licenseId;
  final LicenseState state;
  final DateTime? expiresAt;
  final Map<String, dynamic>? meta;

  const LicenseStatus({
    required this.licenseId,
    required this.state,
    this.expiresAt,
    this.meta,
  });

  bool get isValid => state == LicenseState.valid && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory LicenseStatus.fromMap(Map<String, dynamic> map) {
    return LicenseStatus(
      licenseId: map['licenseId'] as String? ?? '',
      state: _parseState(map['state'] as String?),
      expiresAt: map['expiresAt'] != null ? DateTime.tryParse(map['expiresAt'] as String) : null,
      meta: Map<String, dynamic>.from(map['meta'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'licenseId': licenseId,
        'state': state.name,
        'expiresAt': expiresAt?.toIso8601String(),
        'meta': meta ?? {},
      };

  static LicenseState _parseState(String? s) {
    switch (s) {
      case 'valid':
        return LicenseState.valid;
      case 'expired':
        return LicenseState.expired;
      case 'pending':
        return LicenseState.pending;
      default:
        return LicenseState.invalid;
    }
  }
}

// File: models/license_exception.dart

class LicenseException implements Exception {
  final String message;
  final Object? cause;

  LicenseException(this.message, [this.cause]);

  @override
  String toString() => 'LicenseException: $message${cause != null ? " (cause: $cause)" : ''}';
}

// File: utils/license_utils.dart

import 'dart:convert';
import 'dart:math';

class LicenseUtils {
  const LicenseUtils._();

  /// Generates a stable, URL-safe id from input text.
  static String generateStandardizedId(String input) {
    final normalized = input.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    final hash = _simpleHash(bytes);
    return hash;
  }

  static String _simpleHash(List<int> bytes) {
    // lightweight, deterministic hash for ids. Replace with HMAC/SHA if security needed.
    int value = 0x811C9DC5;
    for (final b in bytes) {
      value ^= b;
      value = (value * 0x01000193) & 0xFFFFFFFF;
    }
    // convert to hex
    return value.toRadixString(16);
  }

  static String generateRandomKey([int length = 24]) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }
}

// File: services/abstract_db.dart

/// Abstract DB interface so services can be tested and not tightly coupled to Firestore.
abstract class AbstractDb {
  Future<Map<String, dynamic>?> getDocument(String collection, String id);
  Future<void> setDocument(String collection, String id, Map<String, dynamic> data);
  Future<void> updateDocument(String collection, String id, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> query(String collection, {Map<String, dynamic>? where});
}

// File: services/device_service.dart

import '../models/license_exception.dart';
import '../utils/license_utils.dart';

class DeviceService {
  final AbstractDb db;
  final String collectionName;

  DeviceService({required this.db, this.collectionName = 'devices'});

  /// Registers a device with provided metadata. Throws LicenseException on failure.
  Future<void> registerDevice(String deviceId, Map<String, dynamic> meta) async {
    final id = LicenseUtils.generateStandardizedId(deviceId);
    try {
      final existing = await db.getDocument(collectionName, id);
      if (existing != null) {
        // idempotent: update meta but don't create duplicate
        await db.updateDocument(collectionName, id, {'meta': meta, 'updatedAt': DateTime.now().toIso8601String()});
        return;
      }

      final data = {
        'deviceId': deviceId,
        'meta': meta,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await db.setDocument(collectionName, id, data);
    } catch (e) {
      throw LicenseException('Failed to register device', e);
    }
  }

  Future<bool> isDeviceRegistered(String deviceId) async {
    final id = LicenseUtils.generateStandardizedId(deviceId);
    try {
      final doc = await db.getDocument(collectionName, id);
      return doc != null;
    } catch (e) {
      // Bubble up as exception so callers can distinguish between 'not registered' and 'error'.
      throw LicenseException('Failed to check device registration', e);
    }
  }
}

// File: services/license_service.dart

import '../models/license_status.dart';
import '../models/license_exception.dart';
import '../utils/license_utils.dart';

class LicenseService {
  final AbstractDb db;
  final String collectionName;

  LicenseService({required this.db, this.collectionName = 'licenses'});

  /// Create or update a license (idempotent). Returns the produced license id.
  Future<String> createOrUpdateLicense({required String ownerId, required DateTime expiresAt, Map<String, dynamic>? meta}) async {
    final licenseId = LicenseUtils.generateStandardizedId(ownerId);
    final data = {
      'licenseId': licenseId,
      'ownerId': ownerId,
      'state': expiresAt.isAfter(DateTime.now()) ? 'valid' : 'expired',
      'expiresAt': expiresAt.toIso8601String(),
      'meta': meta ?? {},
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      final existing = await db.getDocument(collectionName, licenseId);
      if (existing == null) {
        await db.setDocument(collectionName, licenseId, data);
      } else {
        await db.updateDocument(collectionName, licenseId, data);
      }
      return licenseId;
    } catch (e) {
      throw LicenseException('Failed to create/update license', e);
    }
  }

  Future<LicenseStatus> getLicenseStatus(String ownerId) async {
    final licenseId = LicenseUtils.generateStandardizedId(ownerId);
    try {
      final doc = await db.getDocument(collectionName, licenseId);
      if (doc == null) {
        return LicenseStatus(licenseId: licenseId, state: LicenseState.invalid, expiresAt: null);
      }
      return LicenseStatus.fromMap(doc);
    } catch (e) {
      throw LicenseException('Failed to fetch license status', e);
    }
  }

  Future<bool> validateLicenseForDevice({required String ownerId, required String deviceId}) async {
    try {
      final license = await getLicenseStatus(ownerId);
      if (!license.isValid) return false;

      // Optional: check license->devices mapping in DB
      final mappingId = "${license.licenseId}_devices";
      final mapping = await db.getDocument('${collectionName}_mappings', mappingId);
      if (mapping == null) return false;
      final List devices = mapping['devices'] ?? [];
      return devices.contains(deviceId);
    } catch (e) {
      throw LicenseException('Failed to validate license for device', e);
    }
  }

  /// Attach a device to a license (idempotent)
  Future<void> attachDeviceToLicense(String ownerId, String deviceId) async {
    final licenseId = LicenseUtils.generateStandardizedId(ownerId);
    final mappingId = "${licenseId}_devices";
    try {
      final mapping = await db.getDocument('${collectionName}_mappings', mappingId);
      final devices = List<String>.from(mapping?['devices'] ?? []);
      if (!devices.contains(deviceId)) {
        devices.add(deviceId);
        await db.setDocument('${collectionName}_mappings', mappingId, {
          'licenseId': licenseId,
          'devices': devices,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw LicenseException('Failed to attach device to license', e);
    }
  }

  /// Revoke (expire) license
  Future<void> revokeLicense(String ownerId) async {
    final licenseId = LicenseUtils.generateStandardizedId(ownerId);
    try {
      final doc = await db.getDocument(collectionName, licenseId);
      if (doc == null) throw LicenseException('License not found');
      await db.updateDocument(collectionName, licenseId, {'state': 'expired', 'updatedAt': DateTime.now().toIso8601String()});
    } catch (e) {
      throw LicenseException('Failed to revoke license', e);
    }
  }
}

// File: services/firestore_db.dart

// This is a small adapter that maps AbstractDb to Firestore.
// Put this file in your project only where Firestore is available.

/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'abstract_db.dart';

class FirestoreDb implements AbstractDb {
  final FirebaseFirestore firestore;
  FirestoreDb(this.firestore);

  @override
  Future<void> setDocument(String collection, String id, Map<String, dynamic> data) async {
    await firestore.collection(collection).doc(id).set(data);
  }

  @override
  Future<Map<String, dynamic>?> getDocument(String collection, String id) async {
    final doc = await firestore.collection(collection).doc(id).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  @override
  Future<void> updateDocument(String collection, String id, Map<String, dynamic> data) async {
    await firestore.collection(collection).doc(id).update(data);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String collection, {Map<String, dynamic>? where}) async {
    // implement simple where= equality queries or other helpers as needed.
    throw UnimplementedError();
  }
}
*/

// File: example/main.dart

/*
import 'package:flutter/material.dart';
import 'services/firestore_db.dart';
import 'services/license_service.dart';
import 'services/device_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firestore = FirebaseFirestore.instance; // init firebase
  final db = FirestoreDb(firestore);
  final licenseService = LicenseService(db: db);
  final deviceService = DeviceService(db: db);

  // usage examples
}
*/

// End of restructured modules
 */