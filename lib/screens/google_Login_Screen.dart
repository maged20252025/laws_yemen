import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

// خدمة المفضلة
import '../services/favorites_sync_service.dart';
import 'devices_management_screen.dart'; // تأكد من مسار الملف

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({Key? key}) : super(key: key);

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  bool isLoading = false;
  String? errorMessage;
  static const int maxAllowedDevices = 5; // يمكنك تعديل الحد حسب الحاجة

  // دالة التحقق من الاتصال بالانترنت
  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // جمع كل بيانات الجهاز الممكنة بدون أذونات خاصة
  Future<Map<String, dynamic>> _getDeviceData() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = {};
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceData = {
          'androidId': info.id ?? 'unknown',
          'model': info.model ?? 'unknown',
          'manufacturer': info.manufacturer ?? 'unknown',
          'brand': info.brand ?? 'unknown',
          'device': info.device ?? 'unknown',
          'product': info.product ?? 'unknown',
          'supportedAbis': (info.supportedAbis ?? []).join(','),
          'osVersion': info.version.release ?? 'unknown',
          'deviceType': 'phone',
        };
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceData = {
          'identifierForVendor': info.identifierForVendor ?? 'unknown',
          'utsname': (info.utsname.machine ?? 'unknown'),
          'model': info.name ?? 'unknown',
          'systemName': info.systemName ?? 'unknown',
          'systemVersion': info.systemVersion ?? 'unknown',
          'deviceType': 'phone',
        };
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        deviceData = {
          'deviceId': info.deviceId,
          'model': info.productName,
          'manufacturer': info.registeredOwner,
          'osVersion': '${info.majorVersion}.${info.minorVersion}',
          'numberOfCores': info.numberOfCores.toString(),
          'deviceType': 'windows_pc',
        };
      } else {
        deviceData = {
          'deviceId': 'unknown',
          'deviceType': 'unknown',
        };
      }
    } catch (e) {
      deviceData = {
        'deviceId': 'unknown',
        'deviceModel': 'unknown',
        'deviceType': 'unknown',
        'osVersion': 'unknown',
      };
    }
    return deviceData;
  }

  // إنشاء بصمة من الحقول المتوفرة ثم تجزئتها SHA256
  String _computeFingerprintHash(Map<String, dynamic> deviceData) {
    // جمع الحقول بترتيب ثابت — ضع كل الحقول الممكنة ضمن هذه القائمة بالترتيب
    final parts = <String>[];
    // أضف الحقول المتاحة إن وجدت
    void addIfExists(String key) {
      final v = deviceData[key];
      parts.add((v == null) ? '' : v.toString());
    }

    addIfExists('androidId');
    addIfExists('identifierForVendor');
    addIfExists('serial');
    addIfExists('model');
    addIfExists('manufacturer');
    addIfExists('brand');
    addIfExists('device');
    addIfExists('product');
    addIfExists('supportedAbis');
    addIfExists('osVersion');
    addIfExists('utsname');
    addIfExists('systemName');

    final combined = parts.join('|');
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString(); // سلسلة الهاش
  }

  // البحث عن المستخدم الموحد في فايربيز -> الآن يعتمد فقط على الايميل
  Future<String?> _findUserIdByEmail(String email) async {
    final firestore = FirebaseFirestore.instance;
    final usersByEmail = await firestore
        .collection('users')
        .where('emails', arrayContains: email)
        .limit(1)
        .get();
    if (usersByEmail.docs.isNotEmpty) {
      return usersByEmail.docs.first.id;
    }
    return null;
  }

  // حفظ أو تحديث بيانات المستخدم الموحد في فايربيز
  // تعديل: إذا لم يوجد doc بنفس الايميل -> ننشئ doc جديد دائماً
  Future<String> _saveOrCreateUserToFirebase(
      String email, Map<String, dynamic> deviceData, String fingerprint) async {
    final firestore = FirebaseFirestore.instance;

    // ابحث فقط بالإيميل أولاً
    String? userId = await _findUserIdByEmail(email);

    if (userId != null) {
      // حدّث بيانات المستخدم الموجود (أضف الإيميل إن لم يكن موجوداً، وأضف بصمة الجهاز في حقل deviceFingerprints)
      final userRef = firestore.collection('users').doc(userId);
      await userRef.set({
        'emails': FieldValue.arrayUnion([email]),
        'deviceFingerprints': FieldValue.arrayUnion([fingerprint]),
        'lastLogin': FieldValue.serverTimestamp(),
        'deviceModels':
            FieldValue.arrayUnion([deviceData['model'] ?? 'unknown']),
        'deviceTypes':
            FieldValue.arrayUnion([deviceData['deviceType'] ?? 'unknown']),
        'osVersions': FieldValue.arrayUnion([
          deviceData['osVersion'] ?? deviceData['systemVersion'] ?? 'unknown'
        ]),
        // احفظ أيضاً rawDeviceData للرجوع إليه إذا احتجنا
        'rawDeviceData': FieldValue.arrayUnion([deviceData]),
      }, SetOptions(merge: true));
      return userId;
    } else {
      // أنشئ مستخدم جديد للـ email هذا (حتى لو البصمة كانت موجودة في doc آخر)
      final newUserRef = firestore.collection('users').doc();
      await newUserRef.set({
        'emails': [email],
        'deviceFingerprints': [fingerprint],
        'lastLogin': FieldValue.serverTimestamp(),
        'deviceModels': [deviceData['model'] ?? 'unknown'],
        'deviceTypes': [deviceData['deviceType'] ?? 'unknown'],
        'osVersions': [
          deviceData['osVersion'] ?? deviceData['systemVersion'] ?? 'unknown'
        ],
        'rawDeviceData': [deviceData],
      });
      return newUserRef.id;
    }
  }

  // دالة زيادة عدد المستخدمين عند دخول مستخدم جديد
  Future<void> incrementUserCount() async {
    final statsRef =
        FirebaseFirestore.instance.collection('app_stats').doc('total_users');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(statsRef);

      int currentCount = 0;
      if (snapshot.exists &&
          snapshot.data() != null &&
          snapshot.data()!['count'] != null) {
        currentCount = snapshot.data()!['count'] as int;
      }

      transaction.set(
          statsRef, {'count': currentCount + 1}, SetOptions(merge: true));
    });
  }

  /// دالة تسجيل الدخول وتخزين بيانات المستخدم واستعادة المفضلة إذا لزم الأمر
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (!await _isConnected()) {
      setState(() {
        errorMessage = "قم بالاتصال بشبكة الانترنت أولاً";
        isLoading = false;
      });
      return;
    }

    try {
      await GoogleSignIn().signOut();

      GoogleSignInAccount? account;
      if (Platform.isWindows) {
        // تسجيل الدخول للويندوز عبر المتصفح
        account = await GoogleSignIn(
          signInOption: SignInOption.standard,
        ).signIn();
      } else {
        // تسجيل الدخول المعتاد للأندرويد
        account = await GoogleSignIn().signIn();
      }

      if (account == null) {
        setState(() {
          isLoading = false;
          errorMessage = "لم يتم اختيار أي حساب.";
        });
        return;
      }

      // جمع بيانات الجهاز
      final deviceData = await _getDeviceData();
      final fingerprint = _computeFingerprintHash(deviceData);
      final deviceIdForDoc =
          fingerprint; // نستخدم الهاش كمفتاح في subcollection

      // حفظ أو إنشاء مستخدم جديد في فايربيز (اعتماداً على الإيميل فقط)
      final userId = await _saveOrCreateUserToFirebase(
          account.email, deviceData, fingerprint);

      // التحقق من حالة الاشتراك المدفوع وبيانات الأجهزة (محدث ليتوافق مع شاشة التفعيل)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      
      // استخراج بيانات الاشتراك من حقل subscription (Map)
      final subData = userData['subscription'] as Map<String, dynamic>?;
      final DateTime? paidEnd = subData != null && subData['endDate'] != null
          ? DateTime.tryParse(subData['endDate'])
          : null;
      final DateTime? paidStart = subData != null && subData['startDate'] != null
          ? DateTime.tryParse(subData['startDate'])
          : null;
      
      final bool isSubscriptionValid = paidEnd != null && DateTime.now().isBefore(paidEnd);

      final devicesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices');
      
      // تسجيل الجهاز أو تحديثه (تم دمجها لضمان وجود الجهاز قبل الانتقال)
      await devicesRef.doc(deviceIdForDoc).set({
        'userId': userId,
        'fingerprint': fingerprint,
        'deviceData': deviceData,
        'deviceName': deviceData['model'] ?? '',
        'deviceType': deviceData['deviceType'] ?? '',
        'addedAt': DateTime.now().toIso8601String(),
        'status': 'نشط',
      }, SetOptions(merge: true));

      // حفظ البيانات الأساسية محلياً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', account.email);
      await prefs.setString('deviceFingerprint', fingerprint);
      await prefs.setString('deviceModel', deviceData['model'] ?? '');
      await prefs.setString('osVersion',
          deviceData['osVersion'] ?? deviceData['systemVersion'] ?? '');
      await prefs.setBool('hasLoggedInGoogle', true);
      await prefs.setString('userId', userId);

      // في حال وجود اشتراك سارٍ، يتم التفعيل محلياً فوراً والتوجيه لشاشة التفعيل
      if (isSubscriptionValid) {
        await prefs.setBool('isActivated', true);
        await prefs.setString('paidType', subData?['planType'] ?? 'مدفوع');
        if (paidStart != null) {
          await prefs.setInt('paidStartMs', paidStart.millisecondsSinceEpoch);
        }
        await prefs.setInt('paidEndMs', paidEnd.millisecondsSinceEpoch);
        
        // حفظ تفاصيل الاشتراك الإضافية للتوافق مع دالة استعادة الخدمة
        await prefs.setString('subscriptionStartDate', paidStart?.toIso8601String() ?? '');
        await prefs.setString('subscriptionEndDate', paidEnd.toIso8601String());
        await prefs.setString('subscriptionType', subData?['planType'] ?? 'مدفوع');
        await prefs.setString('subscriptionCode', subData?['code'] ?? '');
      }

      // زيادة عدد المستخدمين الجدد
      if (userDoc.exists && userData['isCounted'] != true) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set(
          {'isCounted': true},
          SetOptions(merge: true),
        );
        await incrementUserCount();
      }

      if (!mounted) return;

      // الانتقال الذكي: إذا كان مشتركاً يذهب للتفعيل، وإذا لم يكن يذهب للتجربة المجانية
      if (isSubscriptionValid) {
        Navigator.pushReplacementNamed(context, '/activate');
      } else {
        Navigator.pushReplacementNamed(context, '/freeTrial');
      }
    } catch (e) {
      String finalMessage;
      if (e.toString().contains('network_error')) {
        finalMessage = "قم بالاتصال بشبكة الانترنت أولاً";
      } else {
        finalMessage = "حدث خطأ أثناء تسجيل الدخول: $e";
      }
      setState(() {
        errorMessage = finalMessage;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.blue,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'سجّل دخولك بحساب Google للوصول إلى ميزات التطبيق الكاملة بشكل آمن وسريع.',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                                color: Colors.blueAccent, width: 1.5),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(
                          Icons.account_circle,
                          size: 28,
                          color: Colors.red,
                        ),
                        label: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'تسجيل الدخول باستخدام Google',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                        onPressed: isLoading ? null : _handleGoogleSignIn,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
