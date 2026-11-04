// add_device.js
const admin = require("firebase-admin");
const fs = require("fs");

// تحميل مفتاح الخدمة
const serviceAccount = require("./serviceAccountKey.json");

// تهيئة Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// الاتصال بقاعدة بيانات Firestore
const db = admin.firestore();

// دالة لإضافة جهاز جديد
async function addDevice() {
  const deviceData = {
    deviceId: "deviceId1",
    deviceName: "هاتف سامسونج",
    deviceType: "هاتف",
    status: "نشط",
    userEmail: "example@email.com",
    addedAt: new Date().toISOString()
  };

  try {
    await db.collection("devices").doc(deviceData.deviceId).set(deviceData);
    console.log("✅ تمت إضافة الجهاز بنجاح إلى مجموعة devices");
  } catch (error) {
    console.error("❌ حدث خطأ أثناء الإضافة:", error);
  }
}

// استدعاء الدالة
addDevice();