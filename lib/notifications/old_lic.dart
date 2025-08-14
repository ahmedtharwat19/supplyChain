/* import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LicenseNotifications {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  static Future<void> sendApprovalNotification({
    required String userId,
    required String licenseKey,
    required String requestId,
  }) async {
    // استخدم هذا البديل الحديث
    await FirebaseMessaging.instance.subscribeToTopic('user_$userId');

    // أو استخدم الإشعارات المحلية فقط
    _showLocalNotification(
      title: 'license_approved_title'.tr(),
      body:  'license_approved_body'.tr(args: [licenseKey]),//'Your license $licenseKey has been approved',
    );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      importance: Importance.high,
    );

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
  /* static Future<void> sendApprovalNotification({
    required String userId,
    required String licenseKey,
    required String requestId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      channelDescription: 'Notifications for license status changes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    
    await _notifications.show(
      0,
      'license_approved_title'.tr(),
      'license_approved_body'.tr(args: [licenseKey]),
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: 'license/$licenseKey',
    );

    // Also send via FCM for background delivery
    await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
      /*       to: '/topics/user_$userId',
            data: {
              'type': 'license_approved',
              'licenseKey': licenseKey,
              'requestId': requestId,
            },
          ); */
  } */
}
 */
/* 
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseNotifications {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    // تهيئة الإشعارات المحلية
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // تهيئة FCM
    await _setupFCM();
  }

  static Future<void> _setupFCM() async {
    await _fcm.requestPermission();
    FirebaseMessaging.onMessage.listen(_showFcmNotification);
  }

  static void _onNotificationTap(NotificationResponse response) {
    // معالجة النقر على الإشعار
  }

  static Future<void> sendAdminNotification({
    required String requestId,
    required String userEmail,
  }) async {
    try {
      final admins = await _firestore
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();

      final adminTokens = admins.docs
          .map((admin) => admin['fcmToken'] as String? ?? '')
          .where((token) => token.isNotEmpty)
          .toList();

      // إرسال إشعار محلي
      await _showLocalNotification(
        title: 'license_request.admin_notification_title'.tr(),
        body: 'license_request.admin_notification_body'.tr(args: [userEmail]),
      );

      // إرسال إشعار FCM لكل مدير
      for (final token in adminTokens) {
        await _sendFcmToTopic(
          topic: 'admin_$token', // أو استخدام token مباشرة إذا أردت
          title: 'license_request.admin_notification_title'.tr(),
          body: 'license_request.admin_notification_body'.tr(args: [userEmail]),
          data: {
            'type': 'license_request',
            'requestId': requestId,
          },
        );
      }
    } catch (e) {
      FirebaseCrashlytics.instance.log('Error in sendAdminNotification: $e');
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      channelDescription: 'license_notifications_channel_desc'.tr(),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    final iosDetails = const DarwinNotificationDetails();

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  static Future<void> _showFcmNotification(RemoteMessage message) async {
    await _showLocalNotification(
      title: message.notification?.title ?? 'new_notification'.tr(),
      body: message.notification?.body ?? 'new_license_notification'.tr(),
      payload: message.data['type'],
    );
  }

  static Future<void> _sendFcmToTopic({
    required String topic,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // الطريقة الموصى بها حاليًا - إرسال عبر Topics
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      
      // في الواقع، لإرسال إشعارات إلى Topics تحتاج إلى استخدام
      // Firebase Cloud Functions أو الخادم الخاص بك
      // هذا مثال للهيكل فقط
      debugPrint('Should send notification to topic: $topic');
      debugPrint('Title: $title, Body: $body, Data: $data');
      
      // في التطبيق الحقيقي، استدعي هنا دالة في Cloud Functions
      // أو API في خادمك الخاص لإرسال الإشعارات
    } catch (e) {
      FirebaseCrashlytics.instance.log('Error sending FCM: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
} */