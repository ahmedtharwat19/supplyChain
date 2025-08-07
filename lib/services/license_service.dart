/* import 'dart:math';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LicenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // توليد مفتاح ترخيص جديد
  Future<String> generateLicenseKey({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    final licenseKey = _generateRandomKey();
    final deviceId = await getDeviceUniqueId();

    await _firestore.collection('licenses').doc(licenseKey).set({
      'userId': userId,
      'licenseKey': licenseKey,
      'deviceIds': [deviceId],
      'maxDevices': maxDevices,
      'expirationDate': _calculateExpiryDate(durationMonths),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return licenseKey;
  }

  // الحصول على معرف فريد للجهاز
  Future<String> getDeviceUniqueId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }

      final macAddress = await NetworkInfo().getWifiBSSID();
      return macAddress ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'error:${e.toString()}';
    }
  }

  // التحقق من الترخيص
  Future<LicenseStatus> checkLicenseStatus() async {
    final user = _auth.currentUser;
    if (user == null) return LicenseStatus.invalid(reason: 'not_logged_in');

    final currentDeviceId = await getDeviceUniqueId();
    final licenseSnapshot = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (licenseSnapshot.docs.isEmpty) {
      return LicenseStatus.invalid(reason: 'no_license');
    }

    final license = licenseSnapshot.docs.first.data();
    final expiryDate = DateTime.parse(license['expirationDate']);
    final deviceIds = List<String>.from(license['deviceIds'] ?? []);
    final maxDevices = license['maxDevices'] ?? 1;

    if (DateTime.now().isAfter(expiryDate)) {
      await _firestore
          .collection('licenses')
          .doc(licenseSnapshot.docs.first.id)
          .update({'isActive': false});
      return LicenseStatus.expired(expiryDate: expiryDate);
    }

    if (!deviceIds.contains(currentDeviceId)) {
      if (deviceIds.length >= maxDevices) {
        return LicenseStatus.invalid(reason: 'device_limit_reached');
      }
      await _firestore
          .collection('licenses')
          .doc(licenseSnapshot.docs.first.id)
          .update({
        'deviceIds': FieldValue.arrayUnion([currentDeviceId])
      });
    }

    return LicenseStatus.valid(
      licenseKey: license['licenseKey'],
      expiryDate: expiryDate,
      maxDevices: maxDevices,
      usedDevices: deviceIds.length,
    );
  }

  // طلب ترخيص جديد
  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    final isConnected = await checkInternetConnection();
    if (!isConnected) {
      throw Exception('no_internet_connection');
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
  }

  // وظائف مساعدة
  String _generateRandomKey() {
    final random = Random();
    return List.generate(
        4, (_) => random.nextInt(9999).toString().padLeft(4, '0')).join('-');
  }

  String _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day);
    return expiry.toIso8601String();
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
  }) {
    return LicenseStatus._(
      isValid: true,
      licenseKey: licenseKey,
      expiryDate: expiryDate,
      maxDevices: maxDevices,
      usedDevices: usedDevices,
    );
  }

  factory LicenseStatus.expired({required DateTime expiryDate}) {
    return LicenseStatus._(
      isValid: false,
      isExpired: true,
      expiryDate: expiryDate,
      invalidReason: 'license_expired',
    );
  }

  factory LicenseStatus.invalid({required String reason}) {
    return LicenseStatus._(
      isValid: false,
      invalidReason: reason,
    );
  }
}
 */
/* 

import 'dart:math';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LicenseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Connectivity _connectivity;
  final DeviceInfoPlugin _deviceInfo;
  final NetworkInfo _networkInfo;

  // Dependency injection for better testability
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

  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      //return result != ConnectivityResult.none;
          return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  Future<String> generateLicenseKey({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    if (!await checkInternetConnection()) {
      throw LicenseException('No internet connection');
    }

    final licenseKey = _generateRandomKey();
    final deviceId = await getDeviceUniqueId();

    await _firestore.collection('licenses').doc(licenseKey).set({
      'userId': userId,
      'licenseKey': licenseKey,
      'deviceIds': FieldValue.arrayUnion([deviceId]),
      'maxDevices': maxDevices,
      'expirationDate': _calculateExpiryDate(durationMonths),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return licenseKey;
  }


/* 
  Future<String> getDeviceUniqueId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      }

      final macAddress = await _networkInfo.getWifiBSSID();
      return macAddress ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
 */
  
  Future<String> getDeviceUniqueId() async {
  try {
    // المحاولة الأولى: الحصول على عنوان MAC
    final macAddress = await _networkInfo.getWifiBSSID();
    
    if (macAddress != null && macAddress.isNotEmpty && macAddress != '02:00:00:00:00:00') {
      return 'mac_${macAddress.replaceAll(':', '').toLowerCase()}';
    }

    // المحاولة الثانية: معرفات أخرى للجهاز
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return 'android_${androidInfo.id}';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return 'ios_${iosInfo.identifierForVendor ?? 'unknown'}';
    }

    // إذا فشل كل شيء نستخدم عنوان IP كبديل
    final ipAddress = await _networkInfo.getWifiIP();
    return 'ip_${ipAddress ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}'}';
  } catch (e) {
    return 'error_${DateTime.now().millisecondsSinceEpoch}';
  }
}
Future<bool> isDeviceRegistered(String userId, String deviceId) async {
  try {
    final query = await _firestore
        .collection('licenses')
        .where('userId', isEqualTo: userId)
        .where('deviceIds', arrayContains: deviceId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  } catch (e) {
    return false;
  }
}

  
  Future<LicenseStatus> checkLicenseStatus() async {
    if (!await checkInternetConnection()) {
      return LicenseStatus.invalid(reason: 'no_internet');
    }

    final user = _auth.currentUser;
    if (user == null) return LicenseStatus.invalid(reason: 'not_logged_in');

    try {
      final currentDeviceId = await getDeviceUniqueId();
      final querySnapshot = await _firestore
          .collection('licenses')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return LicenseStatus.invalid(reason: 'no_active_license');
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final expiryDate = (data['expirationDate'] as Timestamp).toDate();
      final deviceIds = List<String>.from(data['deviceIds'] ?? []);
      final maxDevices = data['maxDevices'] ?? 1;

      if (DateTime.now().isAfter(expiryDate)) {
        await doc.reference.update({'isActive': false});
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      if (!deviceIds.contains(currentDeviceId)) {
        if (deviceIds.length >= maxDevices) {
          return LicenseStatus.invalid(reason: 'device_limit_reached');
        }
        await doc.reference.update({
          'deviceIds': FieldValue.arrayUnion([currentDeviceId])
        });
      }

      return LicenseStatus.valid(
        licenseKey: data['licenseKey'],
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: deviceIds.length,
      );
    } catch (e) {
      return LicenseStatus.invalid(reason: 'check_failed');
    }
  }

  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
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
  }

  // Helper methods
  String _generateRandomKey() {
    final random = Random.secure();
    final parts = List.generate(4, (_) => random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'));
    return parts.join('-').toUpperCase();
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day);
    return Timestamp.fromDate(expiry);
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
} */

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

/*   Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (kIsWeb) {
        // Web-specific connectivity check
        return result.isNotEmpty;
      }
       return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  } */

  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      
      if (kIsWeb) {
        // تحقق إضافي للويب
        try {
          final response = await http.get(
            Uri.parse('https://www.google.com/favicon.ico'),
            headers: {'Cache-Control': 'no-cache'}
          );
          return response.statusCode == 200;
        } catch (e) {
          return result.isNotEmpty;
        }
      } else {
        // للجوال والأجهزة الأخرى
        if (result.isEmpty) return false;
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
      // Validate internet connection
      if (!await checkInternetConnection()) {
        throw LicenseException('No internet connection');
      }

      // Validate input parameters
      if (durationMonths <= 0 || maxDevices <= 0) {
        throw LicenseException('Invalid license parameters');
      }

      // Generate unique license key
      final licenseKey = _generateComplexKey();
      final deviceId = await getDeviceUniqueId();

      // Verify device isn't already registered
      if (await isDeviceRegistered(deviceId)) {
        throw LicenseException('Device already registered to another license');
      }

      // Create license document
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

      // Log license creation
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
      throw LicenseException('Failed to generate license');
    }
  }

  Future<String> getDeviceUniqueId() async {
    try {
      // For web platform
      if (kIsWeb) {
        return await _getWebDeviceId();
      }

      // Try MAC address first
      if (!Platform.isWindows && !Platform.isMacOS) {
        try {
          final macAddress = await _networkInfo.getWifiBSSID();
          if (macAddress != null && 
              macAddress.isNotEmpty && 
              macAddress != '02:00:00:00:00:00') {
            return 'mac_${macAddress.replaceAll(':', '').toLowerCase()}';
          }
        } catch (e) {
          debugPrint('MAC address error: $e');
        }
      }

      // Platform-specific IDs
if (Platform.isAndroid) {
  final androidInfo = await _deviceInfo.androidInfo;
  try {
    // افتراض أن fingerprint غير nullable - استخدامه مباشرة
    return 'android_${androidInfo.fingerprint}';
  } catch (e) {
    // fallback آمن في حالة الخطأ
    return 'android_${androidInfo.id}';
  }
}
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor ?? 'unknown'}';
      }

      // Fallback to IP address
      try {
        final ipAddress = await _networkInfo.getWifiIP();
        if (ipAddress != null) {
          return 'ip_${ipAddress.replaceAll('.', '')}';
        }
      } catch (e) {
        debugPrint('IP address error: $e');
      }

      // Final fallback
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
      // Check internet connection
      if (!await checkInternetConnection()) {
        return LicenseStatus.invalid(reason: 'no_internet');
      }

      // Verify user authentication
      final user = _auth.currentUser;
      if (user == null) return LicenseStatus.invalid(reason: 'not_logged_in');

      // Get current device ID
      final currentDeviceId = await getDeviceUniqueId();
      if (currentDeviceId.startsWith('error_')) {
        return LicenseStatus.invalid(reason: 'device_id_error');
      }

      // Find active licenses for user
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

      // Check license expiration
      if (DateTime.now().isAfter(expiryDate)) {
        await licenseDoc.reference.update({
          'isActive': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      // Handle new device registration
      if (!deviceIds.contains(currentDeviceId)) {
        if (deviceIds.length >= maxDevices) {
          return LicenseStatus.invalid(reason: 'device_limit_reached');
        }

        // Verify device isn't registered to another license
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
      return LicenseStatus.invalid(reason: 'check_failed');
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
      throw LicenseException('Failed to submit license request');
    }
  }

  // Helper methods
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
      // For web, use a combination of browser fingerprint and local storage
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
      debugPrint('Failed to log license activity: $e');
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