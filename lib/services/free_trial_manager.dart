import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';

class FreeTrialManager {
  static const String _trialStartKey = 'trialStart';
  static const String _trialEndKey = 'trialEnd';
  static const String _fingerprintKey = 'deviceFingerprint';

  // دالة توليد بصمة قوية وفريدة للجهاز
// دالة توليد بصمة قوية وفريدة للجهاز
  static Future<String> _getDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = {};

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      // الاعتماد على خصائص قوية ومتاحة في الإصدار 9+
      deviceData = {
        'id': info.id ?? '', // معرّف البناء (Build ID)
        'device': info.device ?? '', // اسم الكود الداخلي للجهاز
        'product': info.product ?? '', // اسم المنتج/البناء
        'board': info.board ?? '', // اللوحة الأم/الشريحة
        'fingerprint': info.fingerprint ?? '', // بصمة النظام (قوية جدًا)
        'hardware': info.hardware ?? '', // نوع العتاد (Hardware)
        'type': 'android',
      };
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      deviceData = {
        'identifierForVendor': info.identifierForVendor ?? '',
        'name': info.name ?? '',
        'systemName': info.systemName ?? '',
        'systemVersion': info.systemVersion ?? '',
        'utsname': info.utsname.machine ?? '',
        'type': 'ios',
      };
    } else {
      deviceData = {
        'deviceId': 'unknown',
        'type': 'unknown',
      };
    }

    // دمج القيم وتحويلها إلى بصمة مشفّرة
    final combined = deviceData.values.join('|');
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // بدء التجربة المجانية بشرط التحقق من البصمة في فايربيس
  static Future<String> startTrial({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = await _getDeviceFingerprint();

    // حفظ البصمة محلياً (للاستخدامات لاحقة)
    await prefs.setString(_fingerprintKey, fingerprint);

    final firestore = FirebaseFirestore.instance;
    final trialsRef = firestore.collection('free_trials');

    // تحقق صارم في فايربيس: هل هذه البصمة استخدمت من قبل؟
    final query = await trialsRef
        .where('fingerprint', isEqualTo: fingerprint)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // تم الحصول على تجربة مسبقاً، جلب التاريخ من السجل
      final data = query.docs.first.data();
      final startDate = data['startDate'];
      final endDate = data['endDate'];
      // إذا كانت التجربة لازالت سارية، احفظها محلياً واسمح بالدخول
      final now = DateTime.now();
      final end = DateTime.tryParse(endDate);
      if (end != null && now.isBefore(end)) {
        await prefs.setString(_trialStartKey, startDate);
        await prefs.setString(_trialEndKey, endDate);
        // !! تم التعديل هنا: استخدم الفاصل | بدلاً من :
        return "active|$startDate|$endDate";
      }
      // إذا كانت منتهية، امنع الدخول وأعرض رسالة للمستخدم
      // !! تم التعديل هنا: استخدم الفاصل | بدلاً من :
      return "expired|$startDate|$endDate";
    }

    // لم يحصل على تجربة مسبقًا، يمنح تجربة جديدة
    final now = DateTime.now();
    final end = now.add(Duration(days: days));

    // حفظ التجربة في فايربيس مرتبطة بالبصمة
    await trialsRef.add({
      'fingerprint': fingerprint,
      'startDate': now.toIso8601String(),
      'endDate': end.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // حفظ بيانات التجربة محلياً
    await prefs.setString(_trialStartKey, now.toIso8601String());
    await prefs.setString(_trialEndKey, end.toIso8601String());

    // !! تم التعديل هنا أيضاً للفاصل
    return 'new|${now.toIso8601String()}|${end.toIso8601String()}';
  }

  // التحقق محلياً هل التجربة فعالة (بدون انترنت)
  static Future<bool> isTrialActive() async {
    final prefs = await SharedPreferences.getInstance();
    final endStr = prefs.getString(_trialEndKey);
    if (endStr == null) return false;
    final endDate = DateTime.tryParse(endStr);
    if (endDate == null) return false;
    return DateTime.now().isBefore(endDate);
  }

  // حذف بيانات التجربة المجانية محلياً (للاختبار فقط أو عند انتهاء التجربة)
  static Future<void> cancelTrialLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trialStartKey);
    await prefs.remove(_trialEndKey);
    await prefs.remove(_fingerprintKey);
  }

  // جلب بيانات التجربة من فايربيس بالبصمة (عند الاتصال بالانترنت)
  static Future<Map<String, dynamic>?> getTrialInfoFromFirebase() async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprint =
        prefs.getString(_fingerprintKey) ?? await _getDeviceFingerprint();

    final firestore = FirebaseFirestore.instance;
    final trialsRef = firestore.collection('free_trials');
    final query = await trialsRef
        .where('fingerprint', isEqualTo: fingerprint)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  // التحقق إذا كانت بيانات التجربة المجانية محفوظة محلياً
  static Future<bool> hasLocalTrial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_trialStartKey) != null &&
        prefs.getString(_trialEndKey) != null;
  }

  // جلب تاريخ بداية التجربة المجانية من التخزين المحلي
  static Future<DateTime?> getTrialStart() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString(_trialStartKey);
    if (startStr == null) return null;
    return DateTime.tryParse(startStr);
  }

  // جلب تاريخ نهاية التجربة المجانية من التخزين المحلي
  static Future<DateTime?> getTrialEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final endStr = prefs.getString(_trialEndKey);
    if (endStr == null) return null;
    return DateTime.tryParse(endStr);
  }
}
