import 'dart:math';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Connectivity _connectivity;
  final DeviceInfoPlugin _deviceInfo;
  final NetworkInfo _networkInfo;

  String? get currentUserId => _auth.currentUser?.uid;

  LicenseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Connectivity? connectivity,
    DeviceInfoPlugin? deviceInfo,
    NetworkInfo? networkInfo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _connectivity = connectivity ?? Connectivity(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _networkInfo = networkInfo ?? NetworkInfo();

  Future<void> initializeForAdmin() async {
    try {
      if (_auth.currentUser == null) return;
      
      // تحقق من صلاحية المستخدم كمدير
      final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      final isAdmin = userDoc.data()?['isAdmin'] ?? false;
      
      if (isAdmin) {
        await _initializeFirestoreCollections();
      }
    } catch (e) {
      debugPrint('Admin initialization error: $e');
    }
  }


 Future<void> _initializeFirestoreCollections() async {
  try {
    // التحقق البسيط من إمكانية الوصول إلى المجموعات
    await Future.wait([
      _firestore.collection('licenses').limit(1).get(),
      _firestore.collection('license_requests').limit(1).get(),
    ]);
    
    debugPrint('Firestore collections are accessible');
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      debugPrint('Permission denied. Admin access required');
      throw LicenseException('Admin privileges required to access collections');
    }
    debugPrint('Firestore access error: ${e.code}');
    throw LicenseException('Failed to access Firestore: ${e.code}');
  } catch (e) {
    debugPrint('Unexpected initialization error: $e');
    throw LicenseException('Initialization failed: ${e.toString()}');
  }
}

  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      if (kIsWeb) {
        try {
          final response = await http.get(
            Uri.parse('https://www.google.com/favicon.ico'),
            headers: {'Cache-Control': 'no-cache'}
          ).timeout(const Duration(seconds: 5));
          return response.statusCode == 200;
        } catch (e) {
          return result.isNotEmpty;
        }
      } else {
        return !result.contains(ConnectivityResult.none);
      }
    } on PlatformException catch (e) {
      debugPrint('Connectivity error: $e');
      return false;
    } catch (e) {
      debugPrint('Unexpected connectivity error: $e');
      return false;
    }
  }

  Future<String> generateLicenseKey({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    try {
      if (!await checkInternetConnection()) {
        throw LicenseException('No internet connection');
      }

      if (durationMonths <= 0 || maxDevices <= 0) {
        throw LicenseException('Invalid license parameters');
      }

      final licenseKey = _generateComplexKey();
      final deviceId = await getDeviceUniqueId();

      if (await isDeviceRegistered(deviceId)) {
        throw LicenseException('Device already registered');
      }

      final licenseData = {
        'userId': userId,
        'licenseKey': licenseKey,
        'deviceIds': FieldValue.arrayUnion([deviceId]),
        'maxDevices': maxDevices,
        'expirationDate': _calculateExpiryDate(durationMonths),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('licenses').doc(licenseKey).set(licenseData);

      await _logLicenseActivity(
        userId: userId,
        licenseKey: licenseKey,
        action: 'generated',
        deviceId: deviceId,
      );

      return licenseKey;
    } on FirebaseException catch (e) {
      throw LicenseException('Firebase error: ${e.code}');
    } catch (e) {
      throw LicenseException('License generation failed: ${e.toString()}');
    }
  }

  Future<String> getDeviceUniqueId() async {
    try {
      if (kIsWeb) {
        return await _getWebDeviceId();
      }

      if (!Platform.isWindows && !Platform.isMacOS) {
        try {
          final macAddress = await _networkInfo.getWifiBSSID();
          if (macAddress != null && macAddress != '02:00:00:00:00:00') {
            return 'mac_${macAddress.replaceAll(':', '').toLowerCase()}';
          }
        } catch (e) {
          debugPrint('MAC address error: $e');
        }
      }

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'android_${androidInfo.fingerprint}';
      } 
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor ?? 'unknown'}';
      }

      try {
        final ipAddress = await _networkInfo.getWifiIP();
        if (ipAddress != null) {
          return 'ip_${ipAddress.replaceAll('.', '')}';
        }
      } catch (e) {
        debugPrint('IP address error: $e');
      }

      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<bool> isDeviceRegistered(String deviceId) async {
    try {
      final query = await _firestore
          .collection('licenses')
          .where('deviceIds', arrayContains: deviceId)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<LicenseStatus> checkLicenseStatus() async {
    try {
      if (!await checkInternetConnection()) {
        return LicenseStatus.invalid(reason: 'no_internet');
      }

      final user = _auth.currentUser;
      if (user == null) return LicenseStatus.invalid(reason: 'not_logged_in');

      final currentDeviceId = await getDeviceUniqueId();
      if (currentDeviceId.startsWith('error_')) {
        return LicenseStatus.invalid(reason: 'device_id_error');
      }

      final licenseQuery = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (licenseQuery.docs.isEmpty) {
        return LicenseStatus.invalid(reason: 'no_active_license');
      }

      final licenseDoc = licenseQuery.docs.first;
      final licenseData = licenseDoc.data();
      final expiryDate = (licenseData['expirationDate'] as Timestamp).toDate();
      final deviceIds = List<String>.from(licenseData['deviceIds'] ?? []);
      final maxDevices = licenseData['maxDevices'] ?? 1;

      if (DateTime.now().isAfter(expiryDate)) {
        await licenseDoc.reference.update({
          'isActive': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      if (!deviceIds.contains(currentDeviceId)) {
        if (deviceIds.length >= maxDevices) {
          return LicenseStatus.invalid(reason: 'device_limit_reached');
        }
        if (await isDeviceRegistered(currentDeviceId)) {
          return LicenseStatus.invalid(reason: 'device_already_registered');
        }
        await licenseDoc.reference.update({
          'deviceIds': FieldValue.arrayUnion([currentDeviceId]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      return LicenseStatus.valid(
        licenseKey: licenseData['licenseKey'],
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: deviceIds.length,
      );
    } on FirebaseException catch (e) {
      return LicenseStatus.invalid(reason: 'firebase_error: ${e.code}');
    } catch (e) {
      return LicenseStatus.invalid(reason: 'check_failed: ${e.toString()}');
    }
  }

  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    try {
      if (!await checkInternetConnection()) {
        throw LicenseException('No internet connection');
      }

      final deviceId = await getDeviceUniqueId();
      
      await _firestore.collection('license_requests').add({
        'userId': userId,
        'deviceId': deviceId,
        'requestedDevices': maxDevices,
        'durationMonths': durationMonths,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _logLicenseActivity(
        userId: userId,
        action: 'requested',
        deviceId: deviceId,
      );
    } catch (e) {
      throw LicenseException('License request failed: ${e.toString()}');
    }
  }

  String _generateComplexKey() {
    final random = Random.secure();
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'LIC-${List.generate(12, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day, 23, 59, 59);
    return Timestamp.fromDate(expiry);
  }

  Future<String> _getWebDeviceId() async {
    try {
      final storage = await SharedPreferences.getInstance();
      String? deviceId = storage.getString('device_id');
      
      if (deviceId == null) {
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
        await storage.setString('device_id', deviceId);
      }
      
      return deviceId;
    } catch (e) {
      return 'web_fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _logLicenseActivity({
    required String userId,
    String? licenseKey,
    required String action,
    required String deviceId,
  }) async {
    try {
      await _firestore.collection('license_audit_log').add({
        'userId': userId,
        'licenseKey': licenseKey,
        'action': action,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      debugPrint('License activity log failed: $e');
    }
  }
}

class LicenseStatus {
  final bool isValid;
  final bool isExpired;
  final String? licenseKey;
  final DateTime? expiryDate;
  final int? maxDevices;
  final int? usedDevices;
  final String? invalidReason;

  LicenseStatus._({
    required this.isValid,
    this.isExpired = false,
    this.licenseKey,
    this.expiryDate,
    this.maxDevices,
    this.usedDevices,
    this.invalidReason,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
  }) => LicenseStatus._(
    isValid: true,
    licenseKey: licenseKey,
    expiryDate: expiryDate,
    maxDevices: maxDevices,
    usedDevices: usedDevices,
  );

  factory LicenseStatus.expired({required DateTime expiryDate}) => LicenseStatus._(
    isValid: false,
    isExpired: true,
    expiryDate: expiryDate,
    invalidReason: 'license_expired',
  );

  factory LicenseStatus.invalid({required String reason}) => LicenseStatus._(
    isValid: false,
    invalidReason: reason,
  );
}

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);
  
  @override
  String toString() => 'LicenseException: $message';
}