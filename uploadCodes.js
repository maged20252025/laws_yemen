const admin = require("firebase-admin");
const fs = require("fs");

// تحميل مفتاح الخدمة
const serviceAccount = require("./serviceAccountKey.json");

// تهيئة Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// قراءة ملف الأكواد
const codesData = JSON.parse(fs.readFileSync("activation_codes.json",
"utf8"));

// رفع الأكواد إلى Firestore
codesData.codes.forEach(async (item) => {
  await db.collection("activation_codes").doc(item.code).set({
    plan: item.plan,
    used: false
    });
});

console.log("✅ All codes uploaded successfully!");