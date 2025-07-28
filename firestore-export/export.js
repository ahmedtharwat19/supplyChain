const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// استبدل المسار هنا بمسار ملف Service Account JSON اللي نزلته
const serviceAccount = require('./puresip-purchasing-d04a905166cf.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  let data = {};
  snapshot.forEach(doc => {
    data[doc.id] = doc.data();
  });

  const filePath = path.join(__dirname, `${collectionName}.json`);
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  console.log(`✅ تم تصدير مجموعة ${collectionName} إلى الملف: ${filePath}`);
}

async function main() {
  try {
    await exportCollection('companies');
    await exportCollection('users');
    await exportCollection('vendors');
    await exportCollection('items');
    console.log('🎉 تم التصدير بنجاح لجميع المجموعات!');
  } catch (error) {
    console.error('❌ خطأ أثناء التصدير:', error);
  }
}

main();
