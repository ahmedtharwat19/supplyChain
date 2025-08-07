import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class UserSubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SubscriptionResult> checkUserSubscription() async {
    try {
      // التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        return await _checkLocalSubscription();
      } else {
        return await _checkFirebaseSubscription();
      }
    } catch (e) {
      debugPrint('🔥 Error in checkUserSubscription: $e');
      return SubscriptionResult.error(error: e.toString());
    }
  }

  Future<SubscriptionResult> _checkLocalSubscription() async {
    debugPrint('📴 Checking local subscription...');
    final localUser = await UserLocalStorage.getUser();
    
    if (localUser == null) {
      debugPrint('🚫 No local user found');
      return SubscriptionResult.invalid(reason: 'no_user');
    }

    final createdAtString = localUser['createdAt'] as String?;
    final createdAt = createdAtString != null ? DateTime.tryParse(createdAtString) : null;
    final duration = localUser['subscriptionDurationInDays'] as int? ?? 30;
    final isActive = localUser['isActive'] as bool? ?? false;

    if (createdAt == null) {
      debugPrint('⚠️ createdAt not found in local user data');
      return SubscriptionResult.invalid(reason: 'invalid_data');
    }

    final now = DateTime.now();
    final expiryDate = createdAt.add(Duration(days: duration));
    final daysLeft = expiryDate.difference(now).inDays;

    if (!isActive) {
      debugPrint('🔴 Account is inactive');
      return SubscriptionResult.expired(expiryDate: expiryDate);
    }

    if (now.isAfter(expiryDate)) {
      debugPrint('🔴 Local subscription expired on $expiryDate');
      return SubscriptionResult.expired(expiryDate: expiryDate);
    }

    debugPrint('🟢 Local subscription valid until $expiryDate ($daysLeft days left)');
    return SubscriptionResult.valid(
      expiryDate: expiryDate,
      daysLeft: daysLeft,
      isActive: isActive,
    );
  }

  Future<SubscriptionResult> _checkFirebaseSubscription() async {
    debugPrint('🌐 Checking Firebase subscription...');
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        debugPrint('❌ No Firebase user logged in');
        return SubscriptionResult.invalid(reason: 'not_logged_in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        debugPrint('⛔️ User document not found');
        await _auth.signOut();
        return SubscriptionResult.invalid(reason: 'no_document');
      }

      final data = userDoc.data()!;
      final isActive = data['is_active'] == true;
      final durationDays = data['subscriptionDurationInDays'] ?? 30;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      if (createdAt == null) {
        debugPrint('⛔️ createdAt not found in user document');
        return SubscriptionResult.invalid(reason: 'invalid_data');
      }

      final now = DateTime.now();
      final expiryDate = createdAt.add(Duration(days: durationDays));
      final daysLeft = expiryDate.difference(now).inDays;

      await _updateLocalUserData(user, data, createdAt, durationDays, isActive);

      if (!isActive) {
        debugPrint('🔴 Account is inactive in Firebase');
        return SubscriptionResult.expired(expiryDate: expiryDate);
      }

      if (now.isAfter(expiryDate)) {
        debugPrint('🔴 Firebase subscription expired on $expiryDate');
        await _firestore.collection('users').doc(user.uid).update({'is_active': false});
        await _auth.signOut();
        return SubscriptionResult.expired(expiryDate: expiryDate);
      }

      debugPrint('🟢 Firebase subscription valid until $expiryDate ($daysLeft days left)');
      return SubscriptionResult.valid(
        expiryDate: expiryDate,
        daysLeft: daysLeft,
        isActive: isActive,
      );
    } catch (e) {
      debugPrint('🔥 Firestore error: $e');
      await _auth.signOut();
      return SubscriptionResult.error(error: e.toString());
    }
  }

  Future<void> _updateLocalUserData(
    User user,
    Map<String, dynamic> data,
    DateTime createdAt,
    int durationDays,
    bool isActive,
  ) async {
    try {
      final localUser = await UserLocalStorage.getUser();
      bool needUpdate = localUser == null;

      if (localUser != null) {
        final localCreatedAt = localUser['createdAt'] as DateTime?;
        final localDuration = localUser['subscriptionDurationInDays'] as int?;
        final localIsActive = localUser['isActive'] as bool?;

        if (localCreatedAt == null || 
            !localCreatedAt.isAtSameMomentAs(createdAt) ||
            localDuration != durationDays ||
            localIsActive != isActive) {
          needUpdate = true;
        }
      }

      if (needUpdate) {
        await UserLocalStorage.saveUser(
          userId: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          subscriptionDurationInDays: durationDays,
          createdAt: createdAt,
          companyIds: List<String>.from(data['companyIds'] ?? []),
          factoryIds: List<String>.from(data['factoryIds'] ?? []),
          supplierIds: List<String>.from(data['supplierIds'] ?? []),
          isActive: isActive,
        );
        debugPrint('📦 Local user data updated');
      }
    } catch (e) {
      debugPrint('❌ Error updating local user data: $e');
    }
  }
}

class SubscriptionResult {
  final bool isValid;
  final bool isActive;
  final bool isExpired;
  final bool isExpiringSoon;
  final DateTime? expiryDate;
  final int daysLeft;
  final String? invalidReason;
  final String? error;

  SubscriptionResult._({
    required this.isValid,
    required this.isActive,
    required this.isExpired,
    required this.isExpiringSoon,
    this.expiryDate,
    this.daysLeft = 0,
    this.invalidReason,
    this.error,
  });

  factory SubscriptionResult.valid({
    required DateTime expiryDate,
    required int daysLeft,
    required bool isActive,
  }) {
    return SubscriptionResult._(
      isValid: true,
      isActive: isActive,
      isExpired: false,
      isExpiringSoon: daysLeft <= 3,
      expiryDate: expiryDate,
      daysLeft: daysLeft,
    );
  }

  factory SubscriptionResult.expired({required DateTime expiryDate}) {
    return SubscriptionResult._(
      isValid: false,
      isActive: false,
      isExpired: true,
      isExpiringSoon: false,
      expiryDate: expiryDate,
      daysLeft: 0,
    );
  }

  factory SubscriptionResult.invalid({required String reason}) {
    return SubscriptionResult._(
      isValid: false,
      isActive: false,
      isExpired: false,
      isExpiringSoon: false,
      invalidReason: reason,
    );
  }

  factory SubscriptionResult.error({required String error}) {
    return SubscriptionResult._(
      isValid: false,
      isActive: false,
      isExpired: false,
      isExpiringSoon: false,
      error: error,
    );
  }
}

// فئة منفصلة لعرض التنبيهات
class SubscriptionNotifier {
  static void showExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(tr('membership_expired_title')),
        content: Text(tr('membership_expired_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('ok')),),
        ],
      ),
    );
  }

  static void showWarning(BuildContext context, SubscriptionResult result) {
    if (result.isExpiringSoon && !result.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subscription_expires_soon', 
              args: [result.daysLeft.toString()])),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subscription_expired')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }
}