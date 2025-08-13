const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
});

const db = admin.firestore();

async function sendFCMToAdmins(title, body, data = {}) {
  const adminsSnapshot = await db.collection('users').where('isAdmin', '==', true).get();
  const tokens = [];

  adminsSnapshot.forEach(doc => {
    const user = doc.data();
    if (user.fcmTokens) {
      tokens.push(...user.fcmTokens);
    }
  });

  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    tokens,
    data,
    android: { priority: 'high' },
    apns: { payload: { aps: { contentAvailable: true } }, headers: { 'apns-priority': '10' } },
  };

  const response = await admin.messaging().sendMulticast(message);
  console.log(`FCM sent: success ${response.successCount}, failed ${response.failureCount}`);
}

const app = express();
app.use(bodyParser.json());

app.post('/notify-admins', async (req, res) => {
  const { title, body, data } = req.body;
  try {
    await sendFCMToAdmins(title, body, data);
    res.send('Notification sent to admins');
  } catch (e) {
    console.error(e);
    res.status(500).send('Error sending notifications');
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`FCM server listening at port ${PORT}`));
