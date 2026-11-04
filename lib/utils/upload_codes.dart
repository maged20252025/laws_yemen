import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 📝 دالة لتحميل القوانين من مجلد assets/laws
Future<List<Map<String, String>>> loadLawFiles() async {
  try {
    // احصل على الملفات من مجلد assets/laws
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    // استخرج جميع ملفات القوانين التي تنتهي بـ .txt
    final lawsPaths = manifestMap.keys
        .where(
            (path) => path.startsWith('assets/laws/') && path.endsWith('.txt'))
        .toList();

    // حوّلها إلى قائمة تحتوي الاسم والملف
    return lawsPaths.map((path) {
      final name = path.split('/').last.replaceAll('.txt', '');
      return {
        "name": name,
        "file": path,
      };
    }).toList();
  } catch (e) {
    print("❌ خطأ أثناء تحميل القوانين: $e");
    return [];
  }
}

/// 📤 دالة لرفع الأكواد إلى Firebase
Future<void> uploadActivationCodes() async {
  try {
    // 📂 اقرأ الملف من assets
    final String response =
        await rootBundle.loadString('assets/activation_codes.json');

    // 📦 فك JSON
    final Map<String, dynamic> data = json.decode(response);

    // 🎫 استخرج المصفوفة "codes"
    final List<dynamic> codes = data['codes'];

    final firestore = FirebaseFirestore.instance;

    for (var code in codes) {
      await firestore.collection('activation_codes').doc(code['code']).set({
        'plan': code['plan'],
        'used': false, // اجعلها false عند الرفع لأول مرة
      });
    }

    print("✅ تم رفع جميع الأكواد إلى Firestore بنجاح");
  } catch (e) {
    print("❌ خطأ أثناء رفع الأكواد: $e");
  }
}
