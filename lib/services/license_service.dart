import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A comprehensive license management service for handling device registration,
/// license validation, and license request processing.
class LicenseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Connectivity _connectivity;
  final DeviceInfoPlugin _deviceInfo;
  final NetworkInfo _networkInfo;
  final Uuid _uuid;

  /// Creates a [LicenseService] instance with optional dependencies for testing.
  LicenseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Connectivity? connectivity,
    DeviceInfoPlugin? deviceInfo,
    NetworkInfo? networkInfo,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _connectivity = connectivity ?? Connectivity(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _networkInfo = networkInfo ?? NetworkInfo(),
        _uuid = uuid ?? const Uuid();

  /// Initializes the license service and performs any required setup.
  Future<void> initialize() async {
    debugPrint('LicenseService initialized');

    // فحص الاتصال
    final connectivityResult = await _connectivity.checkConnectivity();
    debugPrint('Connectivity: $connectivityResult');

    // ✅ تأكد أنك لا تستخدم Platform في الويب
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final deviceInfo = await _deviceInfo.deviceInfo;
      debugPrint('Device info: ${deviceInfo.data}');
    }

    // معلومات الشبكة (يدعم الويب أيضًا إذا كانت المكتبة تدعمه)
    if (!kIsWeb) {
      try {
        final wifiName = await _networkInfo.getWifiName();
        debugPrint('Wifi name: $wifiName');
      } catch (e) {
        debugPrint('Failed to get wifi name: $e');
      }
    } else {
      debugPrint('getWifiName() is not supported on Web');
    }
  }

  /// Generates a standardized ID for licenses or requests
  String generateStandardizedId({required bool isLicense}) {
    final now = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return '${isLicense ? 'LIC' : 'REQ'}-${now.year}${now.month.toString().padLeft(2, '0')}-$random';
  }

  /// Creates a new license and links it to the original request
  Future<String> createLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
    required String requestId,
  }) async {
    if (!await _checkAdminStatus()) {
      throw LicenseException('ADMIN_PERMISSION_REQUIRED'.tr());
    }

    final licenseKey = generateStandardizedId(isLicense: true);
    final expiryDate = _calculateExpiryDate(durationMonths);
    // final now = DateTime.now();
    // final expiryDate = now.add(Duration(days: durationMonths * 30));
    // final expiryTimestamp = Timestamp.fromDate(expiryDate);

    await _firestore.collection('licenses').doc(licenseKey).set({
      'licenseKey': licenseKey,
      'userId': userId,
      'originalRequestId': requestId,
      'maxDevices': maxDevices,
      'expiryDate': expiryDate,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'deviceIds': [],
    });

    await _linkRequestToLicense(requestId, licenseKey);
    await _updateUserLicense(userId, expiryDate, licenseKey, maxDevices);

    // تحديث المستخدم
    await _firestore.collection('users').doc(userId).update({
      'licenseKey': licenseKey,
      'license_expiry': expiryDate,
      'maxDevices': maxDevices,
      'isActive': true,
    });

    return licenseKey;
  }

  Future<void> requestLicense({
    required String userId,
    required int durationMonths,
    required int allowedDevices,
    required String currentDeviceId,
  }) async {
    final requestId = generateStandardizedId(isLicense: false);

    await _firestore.collection('license_requests').doc(requestId).set({
      'requestId': requestId,
      'userId': userId,
      'durationMonths': durationMonths,
      'allowedDevices': allowedDevices,
      'currentDeviceId': currentDeviceId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Checks the current license status for the authenticated user
  Future<LicenseStatus> checkLicenseStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return LicenseStatus.invalid(reason: 'USER_NOT_LOGGED_IN'.tr());
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      return LicenseStatus.invalid(reason: 'USER_NOT_FOUND'.tr());
    }

    final data = userDoc.data()!;
    if (data['isActive'] != true) {
      return LicenseStatus.invalid(reason: 'USER_NOT_ACTIVE'.tr());
    }

    final expiryDate = data['license_expiry']?.toDate();
    if (expiryDate == null) {
      return LicenseStatus.invalid(reason: 'NO_EXPIRY_DATE'.tr());
    }

    final now = DateTime.now();
    final isValid = expiryDate.isAfter(now);
    final daysLeft = expiryDate.difference(now).inDays;

    // (اختياري) طباعة للمساعدة في التصحيح
    debugPrint('''
  [LicenseCheck]
  Now: $now
  Expiry: $expiryDate
  Is Valid: $isValid
  Days Left: $daysLeft
  ''');

    return LicenseStatus(
      isValid: isValid,
      licenseKey: data['licenseKey'],
      expiryDate: expiryDate,
      maxDevices: data['maxDevices'] ?? 1,
      usedDevices: (data['deviceIds'] as List?)?.length ?? 0,
      daysLeft: daysLeft,
    );
  }

  /*  Future<LicenseStatus> checkLicenseStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return LicenseStatus.invalid(reason: 'USER_NOT_LOGGED_IN'.tr());
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      return LicenseStatus.invalid(reason: 'USER_NOT_FOUND'.tr());
    }

    final data = userDoc.data()!;
    if (data['isActive'] != true) {
      return LicenseStatus.invalid(reason: 'USER_NOT_ACTIVE'.tr());
    }

    final expiryDate = data['license_expiry']?.toDate();
    if (expiryDate == null) {
      return LicenseStatus.invalid(reason: 'NO_EXPIRY_DATE'.tr());
    }

    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    final isValid = daysLeft > 0;

    return LicenseStatus(
      isValid: isValid,
      licenseKey: data['licenseKey'],
      expiryDate: expiryDate,
      maxDevices: data['maxDevices'] ?? 1,
      usedDevices: (data['deviceIds'] as List?)?.length ?? 0,
      daysLeft: daysLeft,
    );
  }
 */

  /// Validates both the user account and device registration status
  Future<void> validateDeviceAndLicense(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();

    // Check user account status
    if (!userDoc.exists || !(userDoc.data()?['isActive'] ?? false)) {
      throw LicenseException('USER_NOT_ACTIVE'.tr());
    }

    // Check license existence
    final licenseKey = userDoc.data()?['licenseKey'];
    if (licenseKey == null) {
      throw LicenseException('NO_LICENSE_FOUND'.tr());
    }

    // Check device registration
    if (!await isDeviceRegistered(licenseKey)) {
      try {
        await registerCurrentDevice(licenseKey);
      } catch (e) {
        throw LicenseException(
            '${'DEVICE_REGISTRATION_FAILED'.tr()}: ${e.toString()}');
      }
    }
  }

  /// Registers the current device with the specified license key
  Future<void> registerCurrentDevice(String licenseKey) async {
    final deviceId = await getDeviceUniqueId();
    await registerDevice(licenseKey: licenseKey, deviceId: deviceId);
  }

  /// Checks if the current device is registered with the given license
  Future<bool> isDeviceRegistered(String licenseKey) async {
    final deviceId = await getDeviceUniqueId();
    final licenseDoc =
        await _firestore.collection('licenses').doc(licenseKey).get();

    if (!licenseDoc.exists) return false;

    final deviceIds = List<String>.from(licenseDoc['deviceIds'] ?? []);
    return deviceIds.contains(deviceId);
  }

  /// Gets a unique identifier for the current device
  Future<String> getDeviceUniqueId() async {
    try {
      if (kIsWeb) {
        // تخزين ID في localStorage للثبات
        final prefs = await SharedPreferences.getInstance();
        var id = prefs.getString('web_device_id');
        if (id == null) {
          id = _uuid.v4();
          await prefs.setString('web_device_id', id);
        }
        return 'web_$id';
      }

      // باقي المنصات
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor ?? _uuid.v4()}';
      } else {
        return 'other_${_uuid.v4()}';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'unknown_${_uuid.v4()}';
    }
  }

/*   Future<String> getDeviceUniqueId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor ?? _uuid.v4()}';
      }
      return 'web_${_uuid.v4()}';
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'unknown_${_uuid.v4()}';
    }
  }
 */
  /// Registers a specific device with a license
  Future<void> registerDevice({
    required String licenseKey,
    required String deviceId,
  }) async {
    final licenseRef = _firestore.collection('licenses').doc(licenseKey);

    await _firestore.runTransaction((transaction) async {
      final licenseDoc = await transaction.get(licenseRef);

      if (!licenseDoc.exists) {
        throw LicenseException('LICENSE_NOT_FOUND'.tr());
      }

      final deviceIds = List<String>.from(licenseDoc['deviceIds'] ?? []);
      final maxDevices = licenseDoc['maxDevices'] ?? 1;

      if (deviceIds.length >= maxDevices) {
        throw LicenseException(
            'MAX_DEVICES_REACHED'.tr(args: [maxDevices.toString()]));
      }

      if (deviceIds.contains(deviceId)) {
        return; // Already registered
      }

      transaction.update(licenseRef, {
        'deviceIds': FieldValue.arrayUnion([deviceId]),
      });
    });
  }

  /// Checks if there are any pending license requests
  Future<bool> hasPendingLicenseRequests() async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ========== PRIVATE HELPER METHODS ==========

  Future<bool> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['isAdmin'] ?? false;
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    // بافتراض أن كل شهر = 30 يوم (للتبسيط)
    final expiry = now.add(Duration(days: months * 30));
    return Timestamp.fromDate(expiry);
  }

  Future<void> _updateUserLicense(
    String userId,
    Timestamp expiryDate,
    String licenseKey,
    int maxDevices,
  ) async {
    await _firestore.collection('users').doc(userId).update({
      'license_expiry': expiryDate,
      'licenseKey': licenseKey,
      'maxDevices': maxDevices,
      'isActive': true,
    });
  }

  Future<void> _linkRequestToLicense(
      String requestId, String licenseKey) async {
    await _firestore.collection('license_requests').doc(requestId).update({
      'approvedLicenseId': licenseKey,
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Custom exception for license-related errors
class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => 'LicenseException: $message';
}
