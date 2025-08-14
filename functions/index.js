const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendAdminNotification = functions.firestore
  .document('license_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    
    // 1. الحصول على جميع المديرين
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('isAdmin', '==', true)
      .get();

    // 2. إرسال إشعار لكل مدير
    const promises = adminsSnapshot.docs.map(async (adminDoc) => {
      const adminToken = adminDoc.data().fcmToken;
      if (!adminToken) return;

      const message = {
        token: adminToken,
        notification: {
          title: 'New License Request',
          body: `New request from ${requestData.userEmail}`,
        },
        data: {
          type: 'license_request',
          requestId: context.params.requestId,
          userId: requestData.userId,
        },
      };

      return admin.messaging().send(message);
    });

    await Promise.all(promises);
  });