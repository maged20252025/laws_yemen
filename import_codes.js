// import_codes.js
const admin = require('firebase-admin');
const fs = require('fs'); 

// قراءة ملفات JSON الثلاثة
const serviceAccount = JSON.parse(fs.readFileSync('./serviceAccountKey.json', 'utf8')); 
const codes3Day = JSON.parse(fs.readFileSync('./three_day_codes.json', 'utf8'));
const codesWeekly = JSON.parse(fs.readFileSync('./weekly_codes.json', 'utf8'));

// 1. تهيئة Admin SDK 
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 🔴 دالة معالجة الدفعات - تم تعديلها لاستخدام كود التفعيل كـ Document ID
async function processBatch(codesArray, collectionName) {
  let batch = db.batch();
  let count = 0;
  const batchSize = 500;
  
  // نستخدم حلقة for...of للتكرار على العناصر (الأكواد) مباشرة في المصفوفة
  for (const codeObject of codesArray) {
    
    // استخدام قيمة حقل 'code' كمعرّف للمستند
    const docRef = db.collection(collectionName).doc(codeObject.code); 
    
    // البيانات التي سيتم رفعها للمستند (حقل 'plan' فقط)
    const dataToUpload = { plan: codeObject.plan };
    
    batch.set(docRef, dataToUpload);
    
    count++;
    
    // تنفيذ كل 500 عملية دفعة واحدة
    if (count % batchSize === 0) {
      await batch.commit();
      console.log(`تم إضافة 500 كود إلى ${collectionName}.`);
      batch = db.batch(); // بدء دفعة جديدة
    }
  }

  // تنفيذ العمليات المتبقية
  if (count % batchSize !== 0) {
    await batch.commit();
    const remaining = codesArray.length % batchSize;
    if (remaining > 0) {
        console.log(`تم إضافة ${remaining} كود متبقٍ إلى ${collectionName}.`);
    }
  }
}

async function uploadCodes() {
  console.log('بدء رفع أكواد الثلاثة أيام...');
  await processBatch(codes3Day, 'three_day_codes');
  
  console.log('بدء رفع أكواد الأسبوع...');
  await processBatch(codesWeekly, 'weekly_codes');

  console.log('تم إكمال رفع جميع الأكواد بنجاح.');
}

uploadCodes().catch(console.error);