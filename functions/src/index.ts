import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const onNewLicenseRequest = onDocumentCreated(
  "license_requests/{requestId}",
  async (event) => {
        console.log("New license request triggered for ID:", event.params.requestId);
    try {
      const snap = event.data;
      if (!snap) return;
      const requestData = snap.data();

      if (!requestData || requestData.status !== "pending") {
        return null;
      }

      // بقية الكود بدون تغيير كبير، ولكن ملاحظة أن event.params بدلاً من context.params
      const title = "License Request";
      const body = `New license request from ${requestData.userId}`;

      // الباقي كما هو، مع تعديل بسيط للوصول للمعاملات من event.params

      const adminsSnap = await db
        .collection("users")
        .where("isAdmin", "==", true)
        .get();

      const tokens: string[] = [];
      adminsSnap.forEach(doc => {
        const data = doc.data();
        if (data?.fcmTokens) {
          if (Array.isArray(data.fcmTokens)) {
            tokens.push(...data.fcmTokens);
          } else if (typeof data.fcmTokens === "string") {
            tokens.push(data.fcmTokens);
          }
        }
      });

      if (tokens.length === 0) {
        console.log("No admin tokens found. Skipping notification.");
        return null;
      }

      const uniqueTokens = [...new Set(tokens)];

      const message = {
        notification: { title, body },
        data: {
          type: "new_license_request",
          requestId: event.params.requestId,
        },
      };

      const response = await admin.messaging().sendMulticast({
        tokens: uniqueTokens,
        ...message,
      });

      console.log(
        "FCM response:",
        response.successCount,
        "success,",
        response.failureCount,
        "failures"
      );

      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) failedTokens.push(uniqueTokens[idx]);
        });

        if (failedTokens.length > 0) {
          const batch = db.batch();
          const admins = await db
            .collection("users")
            .where("isAdmin", "==", true)
            .get();
          admins.forEach(adminDoc => {
            const data = adminDoc.data();
            const existing = data.fcmTokens || [];
            if (!existing || existing.length === 0) return;
            const filtered = (Array.isArray(existing) ? existing : [existing])
              .filter(t => !failedTokens.includes(t));
            batch.update(adminDoc.ref, { fcmTokens: filtered });
          });
          await batch.commit();
        }
      }

      return null;
    } catch (err) {
      console.error("onNewLicenseRequest error:", err);
      return null;
    }
  }
);
