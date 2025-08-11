"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewLicenseRequest = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
exports.onNewLicenseRequest = (0, firestore_1.onDocumentCreated)("license_requests/{requestId}", async (event) => {
    console.log("New license request triggered for ID:", event.params.requestId);
    try {
        const snap = event.data;
        if (!snap)
            return;
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
        const tokens = [];
        adminsSnap.forEach(doc => {
            const data = doc.data();
            if (data === null || data === void 0 ? void 0 : data.fcmTokens) {
                if (Array.isArray(data.fcmTokens)) {
                    tokens.push(...data.fcmTokens);
                }
                else if (typeof data.fcmTokens === "string") {
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
        const response = await admin.messaging().sendMulticast(Object.assign({ tokens: uniqueTokens }, message));
        console.log("FCM response:", response.successCount, "success,", response.failureCount, "failures");
        if (response.failureCount > 0) {
            const failedTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success)
                    failedTokens.push(uniqueTokens[idx]);
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
                    if (!existing || existing.length === 0)
                        return;
                    const filtered = (Array.isArray(existing) ? existing : [existing])
                        .filter(t => !failedTokens.includes(t));
                    batch.update(adminDoc.ref, { fcmTokens: filtered });
                });
                await batch.commit();
            }
        }
        return null;
    }
    catch (err) {
        console.error("onNewLicenseRequest error:", err);
        return null;
    }
});
//# sourceMappingURL=index.js.map