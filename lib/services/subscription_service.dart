import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const _startKey = 'subscriptionStartDate';
  static const _endKey = 'subscriptionEndDate';
  static const _typeKey = 'subscriptionType';
  static const _codeKey = 'subscriptionCode';

  // حفظ بيانات الاشتراك محليًا
  static Future<void> saveSubscriptionLocal({
    required DateTime start,
    required DateTime end,
    required String type,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startKey, start.toIso8601String());
    await prefs.setString(_endKey, end.toIso8601String());
    await prefs.setString(_typeKey, type);
    await prefs.setString(_codeKey, code);
  }

  // جلب بيانات الاشتراك المحلي
  static Future<Map<String, dynamic>> getSubscriptionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getString(_startKey);
    final end = prefs.getString(_endKey);
    final type = prefs.getString(_typeKey);
    final code = prefs.getString(_codeKey);
    return {
      'start': start != null ? DateTime.tryParse(start) : null,
      'end': end != null ? DateTime.tryParse(end) : null,
      'type': type,
      'code': code,
    };
  }

  // فحص صلاحية الاشتراك محليًا
  static Future<bool> isActiveLocal() async {
    final data = await getSubscriptionLocal();
    if (data['end'] == null) return false;
    return DateTime.now().isBefore(data['end']);
  }

  // حذف بيانات الاشتراك المحلية
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_startKey);
    await prefs.remove(_endKey);
    await prefs.remove(_typeKey);
    await prefs.remove(_codeKey);
  }
}
