/* /* import 'dart:math';
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

/*   Future<LicenseStatus> checkLicenseStatus() async {
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
 */

// في license_service.dart
/* Future<LicenseStatus> checkLicenseStatus() async {
  try {
    debugPrint('Starting license check...');
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return LicenseStatus.invalid(reason: 'not_logged_in');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    debugPrint('User document: ${userDoc.data()}');

    final isActive = userDoc.data()?['isActive'] ?? false;
    if (!isActive) {
      debugPrint('Account not active');
      return LicenseStatus.invalid(reason: 'account_inactive');
    }
// ✅ أكمل التحقق هنا، أو على الأقل:
    return LicenseStatus.invalid(reason: 'incomplete_logic'); // مؤقتًا

    // ... باقي التحقق
  } catch (e) {
    debugPrint('License check error: $e');
    return LicenseStatus.invalid(reason: 'check_failed');
  }
}
 */
 
/*  Future<LicenseStatus> checkLicenseStatus() async {
  try {
    debugPrint('Starting license check...');
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return LicenseStatus.invalid(reason: 'not_logged_in');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      debugPrint('User document not found');
      return LicenseStatus.invalid(reason: 'user_not_found');
    }

    final data = userDoc.data()!;
    debugPrint('User document: $data');

    // 1. Check if account is active
    final isActive = data['isActive'] as bool? ?? false;
    if (!isActive) {
      debugPrint('Account not active');
      return LicenseStatus.invalid(reason: 'account_inactive');
    }

    // 2. Validate subscription dates
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final durationDays = data['subscriptionDurationInDays'] as int? ?? 0;
    
    if (createdAt == null) {
      debugPrint('Invalid creation date');
      return LicenseStatus.invalid(reason: 'invalid_creation_date');
    }

    if (durationDays <= 0) {
      debugPrint('Invalid subscription duration');
      return LicenseStatus.invalid(reason: 'invalid_duration');
    }

    // 3. Calculate expiration
    final expiryDate = createdAt.add(Duration(days: durationDays));
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    final isValid = daysLeft > 0;

    debugPrint('''
      Subscription Status:
      - Created: $createdAt
      - Duration: $durationDays days
      - Expires: $expiryDate
      - Days Left: $daysLeft
      - Valid: $isValid
    ''');

    return LicenseStatus(
      isValid: isValid,
      expiryDate: expiryDate,
      daysLeft: daysLeft,
      reason: isValid ? null : 'subscription_expired',
    );
  } catch (e) {
    debugPrint('License check error: $e');
    return LicenseStatus.invalid(reason: 'check_failed');
  }
}
 */ 
  
  
  
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
  final int daysLeft;
    final String? reason;

  LicenseStatus._({
    required this.isValid,
    this.isExpired = false,
    this.licenseKey,
    this.expiryDate,
    this.maxDevices,
    this.usedDevices,
    this.invalidReason,
     this.daysLeft = 0,
         this.reason,
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

  factory LicenseStatus.invalid({String? reason}) => LicenseStatus._(
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
      await Future.wait([
        _firestore.collection('licenses').limit(1).get(),
        _firestore.collection('license_requests').limit(1).get(),
      ]);
      debugPrint('Firestore collections are accessible');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw LicenseException('Admin privileges required');
      }
      throw LicenseException('Firestore access error: ${e.code}');
    } catch (e) {
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
      }
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      return false;
    }
  }

  Future<LicenseStatus> checkLicenseStatus() async {
    try {
      debugPrint('Starting license check...');
      final user = _auth.currentUser;
      if (user == null) {
        return LicenseStatus.invalid(reason: 'not_logged_in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return LicenseStatus.invalid(reason: 'user_not_found');
      }

      final data = userDoc.data()!;
      final isActive = data['isActive'] as bool? ?? false;
      if (!isActive) {
        return LicenseStatus.invalid(reason: 'account_inactive');
      }

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final durationDays = data['subscriptionDurationInDays'] as int? ?? 0;
      
      if (createdAt == null || durationDays <= 0) {
        return LicenseStatus.invalid(reason: 'invalid_subscription_data');
      }

      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;

      if (daysLeft <= 0) {
        await userDoc.reference.update({'isActive': false});
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      // Optional: Check device license if exists
      try {
        final licenseQuery = await _firestore
            .collection('licenses')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (licenseQuery.docs.isNotEmpty) {
          final license = licenseQuery.docs.first.data();
          return LicenseStatus.valid(
            licenseKey: license['licenseKey'],
            expiryDate: expiryDate,
            maxDevices: license['maxDevices'] ?? 1,
            usedDevices: (license['deviceIds'] as List?)?.length ?? 0,
            daysLeft: daysLeft,
          );
        }
      } catch (e) {
        debugPrint('Device license check skipped: $e');
      }

      return LicenseStatus.valid(
        licenseKey: 'system_subscription',
        expiryDate: expiryDate,
        maxDevices: 1,
        usedDevices: 1,
        daysLeft: daysLeft,
      );
    } catch (e) {
      debugPrint('License check error: $e');
      return LicenseStatus.invalid(reason: 'check_failed');
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

      final licenseKey = _generateComplexKey();
      final deviceId = await getDeviceUniqueId();

      final licenseData = {
        'userId': userId,
        'licenseKey': licenseKey,
        'deviceIds': FieldValue.arrayUnion([deviceId]),
        'maxDevices': maxDevices,
        'expirationDate': _calculateExpiryDate(durationMonths),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('licenses').doc(licenseKey).set(licenseData);
      await _logLicenseActivity(
        userId: userId,
        licenseKey: licenseKey,
        action: 'generated',
        deviceId: deviceId,
      );

      return licenseKey;
    } catch (e) {
      throw LicenseException('License generation failed: ${e.toString()}');
    }
  }

  Future<String> getDeviceUniqueId() async {
    try {
      if (kIsWeb) return await _getWebDeviceId();

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
        if (ipAddress != null) return 'ip_${ipAddress.replaceAll('.', '')}';
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

  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    try {
      final deviceId = await getDeviceUniqueId();
      await _firestore.collection('license_requests').add({
        'userId': userId,
        'deviceId': deviceId,
        'durationMonths': durationMonths,
        'maxDevices': maxDevices,
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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'LIC-${List.generate(12, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day, 23, 59, 59);
    return Timestamp.fromDate(expiry);
  }

  Future<String> _getWebDeviceId() async {
    final storage = await SharedPreferences.getInstance();
    String? deviceId = storage.getString('device_id');
    if (deviceId == null) {
      deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await storage.setString('device_id', deviceId);
    }
    return deviceId;
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
  final int daysLeft;

  LicenseStatus._({
    required this.isValid,
    this.isExpired = false,
    this.licenseKey,
    this.expiryDate,
    this.maxDevices,
    this.usedDevices,
    this.invalidReason,
    required this.daysLeft,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
  }) => LicenseStatus._(
    isValid: true,
    licenseKey: licenseKey,
    expiryDate: expiryDate,
    maxDevices: maxDevices,
    usedDevices: usedDevices,
    daysLeft: daysLeft,
  );

  factory LicenseStatus.expired({required DateTime expiryDate}) => LicenseStatus._(
    isValid: false,
    isExpired: true,
    expiryDate: expiryDate,
    invalidReason: 'license_expired',
    daysLeft: 0,
  );

  factory LicenseStatus.invalid({required String reason}) => LicenseStatus._(
    isValid: false,
    invalidReason: reason,
    daysLeft: 0,
  );

  @override
  String toString() {
    return '''
LicenseStatus:
- Valid: $isValid
- Expired: $isExpired
- Key: ${licenseKey ?? 'N/A'}
- Expires: ${expiryDate?.toIso8601String() ?? 'N/A'}
- Days Left: $daysLeft
- Devices: $usedDevices/$maxDevices
- Reason: ${invalidReason ?? 'N/A'}
''';
  }
}

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);
  
  @override
  String toString() => 'LicenseException: $message';
}

 */
/* 
import 'dart:math';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
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
      await Future.wait([
        _firestore.collection('licenses').limit(1).get(),
        _firestore.collection('license_requests').limit(1).get(),
      ]);
      debugPrint('Firestore collections are accessible');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw LicenseException('Admin privileges required');
      }
      throw LicenseException('Firestore access error: ${e.code}');
    } catch (e) {
      throw LicenseException('Initialization failed: ${e.toString()}');
    }
  }

  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (kIsWeb) {
        try {
          final response = await http
              .get(Uri.parse('https://www.google.com/favicon.ico'), headers: {
            'Cache-Control': 'no-cache'
          }).timeout(const Duration(seconds: 5));
          return response.statusCode == 200;
        } catch (e) {
          return result.isNotEmpty;
        }
      }
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      return false;
    }
  }

  Future<LicenseStatus> checkLicenseStatus() async {
    try {
      debugPrint('Starting license check...');
      final user = _auth.currentUser;
      if (user == null) {
        return LicenseStatus.invalid(reason: 'not_logged_in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return LicenseStatus.invalid(reason: 'user_not_found');
      }

      final data = userDoc.data()!;
      final isActive = data['isActive'] as bool? ?? false;
      if (!isActive) {
        return LicenseStatus.invalid(reason: 'account_inactive');
      }

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final durationDays = data['subscriptionDurationInDays'] as int? ?? 0;

      if (createdAt == null || durationDays <= 0) {
        return LicenseStatus.invalid(reason: 'invalid_subscription_data');
      }

      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;

      if (daysLeft <= 0) {
        await userDoc.reference.update({'isActive': false});
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      try {
        final licenseQuery = await _firestore
            .collection('licenses')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (licenseQuery.docs.isNotEmpty) {
          final license = licenseQuery.docs.first.data();
          return LicenseStatus.valid(
            licenseKey: license['licenseKey'],
            expiryDate: expiryDate,
            maxDevices: license['maxDevices'] ?? 1,
            usedDevices: (license['deviceIds'] as List?)?.length ?? 0,
            daysLeft: daysLeft,
          );
        }
      } catch (e) {
        debugPrint('Device license check skipped: $e');
      }

      return LicenseStatus.valid(
        licenseKey: 'system_subscription',
        expiryDate: expiryDate,
        maxDevices: 1,
        usedDevices: 1,
        daysLeft: daysLeft,
      );
    } catch (e) {
      debugPrint('License check error: $e');
      return LicenseStatus.invalid(reason: 'check_failed');
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

      final licenseKey = _generateComplexKey();
      final deviceId = await getDeviceUniqueId();

      final licenseData = {
        'userId': userId,
        'licenseKey': licenseKey,
        'deviceIds': FieldValue.arrayUnion([deviceId]),
        'maxDevices': maxDevices,
        'expirationDate': _calculateExpiryDate(durationMonths),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('licenses').doc(licenseKey).set(licenseData);
      await _logLicenseActivity(
        userId: userId,
        licenseKey: licenseKey,
        action: 'generated',
        deviceId: deviceId,
      );

      return licenseKey;
    } catch (e) {
      throw LicenseException('License generation failed: ${e.toString()}');
    }
  }

  Future<String> getDeviceUniqueId() async {
    try {
      if (kIsWeb) return await _getWebDeviceId();

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
        if (ipAddress != null) return 'ip_${ipAddress.replaceAll('.', '')}';
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

 /*   Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    try {
      final deviceId = await getDeviceUniqueId();
      await _firestore.collection('license_requests').add({
        'userId': userId,
        'deviceId': deviceId,
        'durationMonths': durationMonths,
        'maxDevices': maxDevices,
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
 */

  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    debugPrint(
        'License Request Params: duration=$durationMonths, devices=$maxDevices');

    try {
      if (durationMonths <= 0 || maxDevices <= 0) {
        throw LicenseException('Invalid license parameters');
      }

      final deviceId = await getDeviceUniqueId();

      await _firestore.collection('license_requests').add({
        'userId': userId,
        'deviceId': deviceId,
        'durationMonths': durationMonths,
        'maxDevices': maxDevices,
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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'LIC-${List.generate(12, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day, 23, 59, 59);
    return Timestamp.fromDate(expiry);
  }

  Future<String> _getWebDeviceId() async {
    final storage = await SharedPreferences.getInstance();
    String? deviceId = storage.getString('device_id');
    if (deviceId == null) {
      deviceId =
          'web_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await storage.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /*   Future<void> _logLicenseActivity({
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
  } */

  Future<void> _logLicenseActivity({
    required String userId,
    String? licenseKey,
    required String action,
    required String deviceId,
  }) async {
    try {
      String platform;
      try {
        platform = Platform.operatingSystem;
      } catch (_) {
        platform = 'unknown';
      }

      await _firestore.collection('license_audit_log').add({
        'userId': userId,
        'licenseKey': licenseKey,
        'action': action,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': platform,
      });
    } catch (e) {
      debugPrint('License activity log failed: $e');
    }
  }

  // ✅ دالة فحص وجود طلبات ترخيص قيد الانتظار
  Future<bool> hasPendingLicenseRequests() async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
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
  final int daysLeft;

  LicenseStatus._({
    required this.isValid,
    this.isExpired = false,
    this.licenseKey,
    this.expiryDate,
    this.maxDevices,
    this.usedDevices,
    this.invalidReason,
    required this.daysLeft,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
  }) =>
      LicenseStatus._(
        isValid: true,
        licenseKey: licenseKey,
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: usedDevices,
        daysLeft: daysLeft,
      );

  factory LicenseStatus.expired({required DateTime expiryDate}) =>
      LicenseStatus._(
        isValid: false,
        isExpired: true,
        expiryDate: expiryDate,
        invalidReason: 'license_expired',
        daysLeft: 0,
      );

  factory LicenseStatus.invalid({required String reason}) => LicenseStatus._(
        isValid: false,
        invalidReason: reason,
        daysLeft: 0,
      );

  @override
  String toString() {
    return '''
LicenseStatus:
- Valid: $isValid
- Expired: $isExpired
- Key: ${licenseKey ?? 'N/A'}
- Expires: ${expiryDate?.toIso8601String() ?? 'N/A'}
- Days Left: $daysLeft
- Devices: $usedDevices/$maxDevices
- Reason: ${invalidReason ?? 'N/A'}
''';
  }
}

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => 'LicenseException: $message';
}
 */
/* 
import 'dart:math';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
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
      await Future.wait([
        _firestore.collection('licenses').limit(1).get(),
        _firestore.collection('license_requests').limit(1).get(),
      ]);
      debugPrint('Firestore collections are accessible');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw LicenseException('Admin privileges required');
      }
      throw LicenseException('Firestore access error: ${e.code}');
    } catch (e) {
      throw LicenseException('Initialization failed: ${e.toString()}');
    }
  }

  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (kIsWeb) {
        try {
          final response = await http
              .get(Uri.parse('https://www.google.com/favicon.ico'), headers: {
            'Cache-Control': 'no-cache'
          }).timeout(const Duration(seconds: 5));
          return response.statusCode == 200;
        } catch (e) {
          return result.isNotEmpty;
        }
      }
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      return false;
    }
  }

  Future<LicenseStatus> checkLicenseStatus() async {
    try {
      debugPrint('Starting license check...');
      final user = _auth.currentUser;
      if (user == null) {
        return LicenseStatus.invalid(reason: 'not_logged_in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return LicenseStatus.invalid(reason: 'user_not_found');
      }

      final data = userDoc.data()!;
      final isActive = data['isActive'] as bool? ?? false;
      if (!isActive) {
        return LicenseStatus.invalid(reason: 'account_inactive');
      }

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final durationDays = data['subscriptionDurationInDays'] as int? ?? 0;

      if (createdAt == null || durationDays <= 0) {
        return LicenseStatus.invalid(reason: 'invalid_subscription_data');
      }

      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;

      if (daysLeft <= 0) {
        await userDoc.reference.update({'isActive': false});
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      try {
        final licenseQuery = await _firestore
            .collection('licenses')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (licenseQuery.docs.isNotEmpty) {
          final license = licenseQuery.docs.first.data();
          return LicenseStatus.valid(
            licenseKey: license['licenseKey'],
            expiryDate: expiryDate,
            maxDevices: license['maxDevices'] ?? 1,
            usedDevices: (license['deviceIds'] as List?)?.length ?? 0,
            daysLeft: daysLeft,
          );
        }
      } catch (e) {
        debugPrint('Device license check skipped: $e');
      }

      return LicenseStatus.valid(
        licenseKey: 'system_subscription',
        expiryDate: expiryDate,
        maxDevices: 1,
        usedDevices: 1,
        daysLeft: daysLeft,
      );
    } catch (e) {
      debugPrint('License check error: $e');
      return LicenseStatus.invalid(reason: 'check_failed');
    }
  }

  // تحقق هل للمستخدم طلب ترخيص معتمد (approved)
  Future<bool> hasApprovedLicenseRequest(String userId) async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

// تحقق هل للمستخدم طلب ترخيص معلق (pending)
  Future<bool> hasPendingLicenseRequest(String userId) async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
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

      final licenseKey = _generateComplexKey();
      final deviceId = await getDeviceUniqueId();

      final licenseData = {
        'userId': userId,
        'licenseKey': licenseKey,
        'deviceIds': FieldValue.arrayUnion([deviceId]),
        'maxDevices': maxDevices,
        'expirationDate': _calculateExpiryDate(durationMonths),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('licenses').doc(licenseKey).set(licenseData);
      await _logLicenseActivity(
        userId: userId,
        licenseKey: licenseKey,
        action: 'generated',
        deviceId: deviceId,
      );

      return licenseKey;
    } catch (e) {
      throw LicenseException('License generation failed: ${e.toString()}');
    }
  }

  Future<String> getDeviceUniqueId() async {
    try {
      if (kIsWeb) return await _getWebDeviceId();

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
        if (ipAddress != null) return 'ip_${ipAddress.replaceAll('.', '')}';
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

  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    debugPrint(
        'License Request Params: duration=$durationMonths, devices=$maxDevices');

    try {
      if (durationMonths <= 0 || maxDevices <= 0) {
        throw LicenseException('Invalid license parameters');
      }

      final deviceId = await getDeviceUniqueId();

      await _firestore.collection('license_requests').add({
        'userId': userId,
        'deviceId': deviceId,
        'durationMonths': durationMonths,
        'maxDevices': maxDevices,
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

  // دالة تدفق (Stream) لطلب الترخيص الحالي للمستخدم
  Stream<DocumentSnapshot<Map<String, dynamic>>> licenseRequestStream(
      String userId) {
    return _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
            (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null)
        .where((doc) => doc != null)
        .cast<DocumentSnapshot<Map<String, dynamic>>>();
  }

  String _generateComplexKey() {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'LIC-${List.generate(12, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day, 23, 59, 59);
    return Timestamp.fromDate(expiry);
  }

  Future<String> _getWebDeviceId() async {
    final storage = await SharedPreferences.getInstance();
    String? deviceId = storage.getString('device_id');
    if (deviceId == null) {
      deviceId =
          'web_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await storage.setString('device_id', deviceId);
    }
    return deviceId;
  }

  Future<void> _logLicenseActivity({
    required String userId,
    String? licenseKey,
    required String action,
    required String deviceId,
  }) async {
    try {
      String platform;
      try {
        platform = Platform.operatingSystem;
      } catch (_) {
        platform = 'unknown';
      }

      await _firestore.collection('license_audit_log').add({
        'userId': userId,
        'licenseKey': licenseKey,
        'action': action,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': platform,
      });
    } catch (e) {
      debugPrint('License activity log failed: $e');
    }
  }

  // ✅ دالة فحص وجود طلبات ترخيص قيد الانتظار
  Future<bool> hasPendingLicenseRequests() async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
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
  final int daysLeft;

  LicenseStatus._({
    required this.isValid,
    this.isExpired = false,
    this.licenseKey,
    this.expiryDate,
    this.maxDevices,
    this.usedDevices,
    this.invalidReason,
    required this.daysLeft,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
  }) =>
      LicenseStatus._(
        isValid: true,
        licenseKey: licenseKey,
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: usedDevices,
        daysLeft: daysLeft,
      );

  factory LicenseStatus.expired({required DateTime expiryDate}) =>
      LicenseStatus._(
        isValid: false,
        isExpired: true,
        expiryDate: expiryDate,
        invalidReason: 'license_expired',
        daysLeft: 0,
      );

  factory LicenseStatus.invalid({required String reason}) => LicenseStatus._(
        isValid: false,
        invalidReason: reason,
        daysLeft: 0,
      );

  @override
  String toString() {
    return '''
LicenseStatus:
- Valid: $isValid
- Expired: $isExpired
- Key: ${licenseKey ?? 'N/A'}
- Expires: ${expiryDate?.toIso8601String() ?? 'N/A'}
- Days Left: $daysLeft
- Devices: $usedDevices/$maxDevices
- Reason: ${invalidReason ?? 'N/A'}
''';
  }
}

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => 'LicenseException: $message';
}
 */
/* 
import 'dart:math';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  /// تهيئة الخدمة للمشرفين
  Future<void> initializeForAdmin() async {
    try {
      if (_auth.currentUser == null) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

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
      await Future.wait([
        _firestore.collection('licenses').limit(1).get(),
        _firestore.collection('license_requests').limit(1).get(),
      ]);
      debugPrint('Firestore collections are accessible');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw LicenseException('Admin privileges required');
      }
      throw LicenseException('Firestore access error: ${e.code}');
    } catch (e) {
      throw LicenseException('Initialization failed: ${e.toString()}');
    }
  }

  /// التحقق من اتصال الإنترنت
  Future<bool> checkInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (kIsWeb) {
        try {
          final response = await http
              .get(Uri.parse('https://www.google.com/favicon.ico'), headers: {
            'Cache-Control': 'no-cache'
          }).timeout(const Duration(seconds: 5));
          return response.statusCode == 200;
        } catch (e) {
          return result.isNotEmpty;
        }
      }
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      return false;
    }
  }

  /// التحقق من حالة الترخيص
  Future<LicenseStatus> checkLicenseStatus() async {
    try {
      debugPrint('Starting license check...');
      final user = _auth.currentUser;
      if (user == null) {
        return LicenseStatus.invalid(reason: 'not_logged_in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return LicenseStatus.invalid(reason: 'user_not_found');
      }

      final data = userDoc.data()!;
      final isActive = data['isActive'] as bool? ?? false;
      if (!isActive) {
        return LicenseStatus.invalid(reason: 'account_inactive');
      }

      // التحقق من تاريخ انتهاء الترخيص مباشرة
      final expiryDate = (data['license_expiry'] as Timestamp?)?.toDate();

      if (expiryDate == null) {
        return LicenseStatus.invalid(reason: 'missing_expiry_date');
      }

      final daysLeft = expiryDate.difference(DateTime.now()).inDays;

      if (daysLeft <= 0) {
        await userDoc.reference.update({'isActive': false});
        return LicenseStatus.expired(expiryDate: expiryDate);
      }

      // التحقق من تفاصيل الرخصة إذا وجدت
      try {
        final licenseQuery = await _firestore
            .collection('licenses')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (licenseQuery.docs.isNotEmpty) {
          final license = licenseQuery.docs.first.data();
          return LicenseStatus.valid(
            licenseKey: license['licenseKey'],
            expiryDate: expiryDate,
            maxDevices: license['maxDevices'] ?? 1,
            usedDevices: (license['deviceIds'] as List?)?.length ?? 0,
            daysLeft: daysLeft,
          );
        }
      } catch (e) {
        debugPrint('Device license check skipped: $e');
      }

      // الرخصة النظامية الافتراضية
      return LicenseStatus.valid(
        licenseKey: 'system_subscription',
        expiryDate: expiryDate,
        maxDevices: 1,
        usedDevices: 1,
        daysLeft: daysLeft,
      );
    } catch (e) {
      debugPrint('License check error: $e');
      return LicenseStatus.invalid(reason: 'check_failed');
    }
  }

  /// الحصول على طلب الترخيص للمستخدم
  Future<Map<String, dynamic>?> getUserLicenseRequest(String userId) async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
  }

  /// التحقق من وجود طلب ترخيص معتمد للمستخدم
  Future<bool> hasApprovedLicenseRequest(String userId) async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .where('expiryDate', isGreaterThan: Timestamp.now())
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// التحقق من وجود طلب ترخيص معلق للمستخدم
  Future<bool> hasPendingLicenseRequest(String userId) async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// إنشاء مفتاح ترخيص جديد
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
      final expiryDate = _calculateExpiryDate(durationMonths);

      final licenseData = {
        'userId': userId,
        'licenseKey': licenseKey,
        'deviceIds': FieldValue.arrayUnion([deviceId]),
        'maxDevices': maxDevices,
        'expiryDate': expiryDate,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // حفظ الرخصة الجديدة
      await _firestore.collection('licenses').doc(licenseKey).set(licenseData);

      // تحديث تاريخ الانتهاء في ملف المستخدم
      await _firestore.collection('users').doc(userId).update({
        'license_expiry': expiryDate,
        'isActive': true,
      });

      await _logLicenseActivity(
        userId: userId,
        licenseKey: licenseKey,
        action: 'generated',
        deviceId: deviceId,
      );

      return licenseKey;
    } catch (e) {
      throw LicenseException('License generation failed: ${e.toString()}');
    }
  }

  /// تجديد الترخيص الحالي
  Future<void> renewLicense({
    required String userId,
    required int additionalMonths,
  }) async {
    try {
      if (!await checkInternetConnection()) {
        throw LicenseException('No internet connection');
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw LicenseException('User not found');
      }

      final currentExpiry =
          (userDoc.data()!['license_expiry'] as Timestamp?)?.toDate();
      final newExpiry =
          currentExpiry?.add(Duration(days: 30 * additionalMonths)) ??
              _calculateExpiryDate(additionalMonths).toDate();

      await userDoc.reference.update({
        'license_expiry': Timestamp.fromDate(newExpiry),
        'isActive': true,
      });

      await _logLicenseActivity(
        userId: userId,
        action: 'renewed',
        deviceId: await getDeviceUniqueId(),
      );
    } catch (e) {
      throw LicenseException('License renewal failed: ${e.toString()}');
    }
  }

  /// الحصول على معرف فريد للجهاز
  Future<String> getDeviceUniqueId() async {
    try {
      if (kIsWeb) return await _getWebDeviceId();

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
        if (ipAddress != null) return 'ip_${ipAddress.replaceAll('.', '')}';
      } catch (e) {
        debugPrint('IP address error: $e');
      }

      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// التحقق من تسجيل الجهاز
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

  /// طلب ترخيص جديد
  Future<void> requestNewLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
  }) async {
    debugPrint(
        'License Request Params: duration=$durationMonths, devices=$maxDevices');

    try {
      if (durationMonths <= 0 || maxDevices <= 0) {
        throw LicenseException('Invalid license parameters');
      }

      final deviceId = await getDeviceUniqueId();
      final expiryDate = _calculateExpiryDate(durationMonths);

      await _firestore.collection('license_requests').add({
        'userId': userId,
        'deviceId': deviceId,
        'durationMonths': durationMonths,
        'maxDevices': maxDevices,
        'expiryDate': expiryDate,
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

  /// دفق طلبات الترخيص للمستخدم
  Stream<DocumentSnapshot<Map<String, dynamic>>> licenseRequestStream(
      String userId) {
    return _firestore
        .collection('license_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
            (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null)
        .where((doc) => doc != null)
        .cast<DocumentSnapshot<Map<String, dynamic>>>();
  }

  /// دفق حالة الترخيص للمستخدم
  Stream<LicenseStatus> getLicenseStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap(
          (snapshot) => checkLicenseStatus(),
        );
  }

  /// توليد مفتاح ترخيص معقد
  String _generateComplexKey() {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'LIC-${List.generate(12, (_) => chars[random.nextInt(chars.length)]).join()}';
  }

  /// حساب تاريخ الانتهاء
  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day, 23, 59, 59);
    return Timestamp.fromDate(expiry);
  }

  /// الحصول على معرف جهاز الويب
  Future<String> _getWebDeviceId() async {
    final storage = await SharedPreferences.getInstance();
    String? deviceId = storage.getString('device_id');
    if (deviceId == null) {
      deviceId =
          'web_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await storage.setString('device_id', deviceId);
    }
    return deviceId;
  }

  /// تسجيل نشاط الترخيص
  Future<void> _logLicenseActivity({
    required String userId,
    String? licenseKey,
    required String action,
    required String deviceId,
  }) async {
    try {
      String platform;
      try {
        platform = Platform.operatingSystem;
      } catch (_) {
        platform = 'unknown';
      }

      await _firestore.collection('license_audit_log').add({
        'userId': userId,
        'licenseKey': licenseKey,
        'action': action,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': platform,
      });
    } catch (e) {
      debugPrint('License activity log failed: $e');
    }
  }

  /// التحقق من وجود طلبات ترخيص قيد الانتظار
  Future<bool> hasPendingLicenseRequests() async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}

/// حالة الترخيص
class LicenseStatus {
  final bool isValid;
  final bool isExpired;
  final String? licenseKey;
  final DateTime? expiryDate;
  final int? maxDevices;
  final int? usedDevices;
  final String? invalidReason;
  final int daysLeft;

  LicenseStatus._({
    required this.isValid,
    this.isExpired = false,
    this.licenseKey,
    this.expiryDate,
    this.maxDevices,
    this.usedDevices,
    this.invalidReason,
    required this.daysLeft,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
  }) =>
      LicenseStatus._(
        isValid: true,
        licenseKey: licenseKey,
        expiryDate: expiryDate,
        maxDevices: maxDevices,
        usedDevices: usedDevices,
        daysLeft: daysLeft,
      );

  factory LicenseStatus.expired({required DateTime expiryDate}) =>
      LicenseStatus._(
        isValid: false,
        isExpired: true,
        expiryDate: expiryDate,
        invalidReason: 'license_expired',
        daysLeft: 0,
      );

  factory LicenseStatus.invalid({required String reason}) => LicenseStatus._(
        isValid: false,
        invalidReason: reason,
        daysLeft: 0,
      );

  @override
  String toString() {
    return '''
LicenseStatus:
- Valid: $isValid
- Expired: $isExpired
- Key: ${licenseKey ?? 'N/A'}
- Expires: ${expiryDate?.toIso8601String() ?? 'N/A'}
- Days Left: $daysLeft
- Devices: $usedDevices/$maxDevices
- Reason: ${invalidReason ?? 'N/A'}
''';
  }
}

/// استثناءات الترخيص
class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => 'LicenseException: $message';
}
 */

/* 

import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/license_status.dart';
import 'package:uuid/uuid.dart';

class LicenseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Connectivity _connectivity;
  final DeviceInfoPlugin _deviceInfo;
  final NetworkInfo _networkInfo;
  final Uuid _uuid = const Uuid();

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

  // --- الجديد: تحسينات نظام الترقيم ---
  String _generateStandardizedId({required bool isLicense}) {
    final now = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return '${isLicense ? 'LIC' : 'REQ'}-${now.year}${now.month.toString().padLeft(2, '0')}-$random';
  }

  // --- الجديد: ربط الطلب بالترخيص ---
  Future<String> createLicense({
    required String userId,
    required int durationMonths,
    required int maxDevices,
    required String requestId,
  }) async {
    if (!await _checkAdminStatus()) {
      throw LicenseException('ADMIN_PERMISSION_REQUIRED'.tr());
    }

    final licenseKey = _generateStandardizedId(isLicense: true);
    final expiryDate = _calculateExpiryDate(durationMonths);

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
    await _updateUserLicense(userId, expiryDate);

    return licenseKey;
  }

  Future<void> initialize() async {
    // يمكنك إضافة أي تهيئة مطلوبة هنا
    debugPrint('LicenseService initialized');

    // مثال لاستخدام الحقول التي كانت غير مستخدمة:
    final connectivityResult = await _connectivity.checkConnectivity();
    debugPrint('Connectivity: $connectivityResult');

    if (Platform.isAndroid || Platform.isIOS) {
      final deviceInfo = await _deviceInfo.deviceInfo;
      debugPrint('Device info: ${deviceInfo.data}');
    }

    final wifiName = await _networkInfo.getWifiName();
    debugPrint('Wifi name: $wifiName');
  }

  Future<LicenseStatus> checkLicenseStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return LicenseStatus.invalid(reason: 'User not logged in');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      return LicenseStatus.invalid(reason: 'User not found');
    }

    final data = userDoc.data()!;
    final expiryDate = data['license_expiry']?.toDate();
    final daysLeft = expiryDate?.difference(DateTime.now()).inDays ?? 0;

    return LicenseStatus(
      isValid: data['isActive'] == true && daysLeft > 0,
      licenseKey: data['licenseKey'],
      expiryDate: expiryDate,
      maxDevices: data['maxDevices'] ?? 1,
      usedDevices: (data['deviceIds'] as List?)?.length ?? 0,
      daysLeft: daysLeft,
    );
  }

  Future<void> _updateUserLicense(String userId, Timestamp expiryDate) async {
    await _firestore.collection('users').doc(userId).update({
      'license_expiry': expiryDate,
      'isActive': true,
    });
  }

  Future<bool> hasPendingLicenseRequests() async {
    final snapshot = await _firestore
        .collection('license_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  String generateStandardizedId({required bool isLicense}) {
    final now = DateTime.now();
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return '${isLicense ? 'LIC' : 'REQ'}-${now.year}${now.month.toString().padLeft(2, '0')}-$random';
  }

  Future<void> _linkRequestToLicense(
      String requestId, String licenseKey) async {
    await _firestore.collection('license_requests').doc(requestId).update({
      'approvedLicenseId': licenseKey,
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- الجديد: إدارة الأجهزة المحسنة ---
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
        throw LicenseException('MAX_DEVICES_REACHED'.tr());
      }

      transaction.update(licenseRef, {
        'deviceIds': FieldValue.arrayUnion([deviceId]),
      });
    });
  }

  // --- الباقي من الوظائف الأساسية ---
  Future<bool> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['isAdmin'] ?? false;
  }

  Timestamp _calculateExpiryDate(int months) {
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + months, now.day);
    return Timestamp.fromDate(expiry);
  }

  // ... (ابقاء باقي الوظائف كما هي مع تعديلات طفيفة)

  Future<String> _getDeviceUniqueId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return androidInfo.id; // أو استخدام أي معرف فريد آخر للجهاز
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        return iosInfo.identifierForVendor ?? const Uuid().v4();
      }
      return const Uuid().v4(); // Fallback for other platforms
    } catch (e) {
      return const Uuid().v4(); // Fallback in case of error
    }
  }
}

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);

  @override
  String toString() => 'LicenseException: $message';
}
 */

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
    try {
      final wifiName = await _networkInfo.getWifiName();
      debugPrint('Wifi name: $wifiName');
    } catch (e) {
      debugPrint('Failed to get wifi name: $e');
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
