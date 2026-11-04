import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laws_yemen/services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔴 إضافة: لاستخدام url_launcher
import 'home_screen.dart';
import 'dart:io';
// استدعاء دالة فحص النسخة وتواصل واتساب
import '../version/check_version.dart';

enum ActivationState {
  loading,
  notActivated,
  activated,
  expired,
  overLimit,
}

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({Key? key}) : super(key: key);

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  ActivationState _activationState = ActivationState.loading;
  bool _isLoading = false;
  String? _message;
  DateTime? _startDate, _endDate;
  bool versionChecked = false; // للتأكد من انتهاء فحص النسخة

  // رقم التواصل
  static const String contactNumber = '+967777533034';
  static const String whatsAppMessage =
      'السلام عليكم، أود الإشتراك في تطبيق القوانين اليمنية وشراء كود التفعيل';

  // عدد الأجهزة المسموح بها (تم الرفع إلى 10)
  static const int maxPhones = 10;
  static const int maxLaptops = 10;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      setState(() {});
    });
    _checkBlockedStatus();
    _checkVersionAndActivation();
  }

  // فحص الحظر المحلي بسبب النسخة القديمة
  Future<void> _checkBlockedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isBlocked = prefs.getBool('isBlockedForOldVersion') ?? false;
    if (isBlocked) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('عذراً'),
            content: const Text(
              'هذه النسخة قديمة وغير صالحة للاستخدام\nيوجد إصدار جديد من التطبيق.\nيرجى التواصل معنا عبر واتساب للحصول على النسخة الصحيحة.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.chat, color: Colors.green),
                label: const Text('تواصل عبر واتساب'),
                onPressed: () {
                  _launchWhatsAppOrTelegram();
                },
              ),
              TextButton(
                onPressed: () {
                  exit(0);
                },
                child: const Text('خروج'),
              ),
            ],
          ),
        ),
      );
    }
  }

  // فحص النسخة أولاً ثم فحص حالة الاشتراك
  Future<void> _checkVersionAndActivation() async {
    final isValidVersion = await checkAppVersion(context);
    setState(() {
      versionChecked = true;
    });
    if (!isValidVersion) {
      // إذا كانت النسخة قديمة، لا تكمل فحص الاشتراك
      return;
    }
    _checkActivationStatus();
  }

  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // 🔴 إضافة: دالة لفتح الواتساب أو التليجرام
  Future<void> _launchWhatsAppOrTelegram() async {
    final encodedMessage = Uri.encodeComponent(whatsAppMessage);
    final whatsAppUrl =
        'whatsapp://send?phone=$contactNumber&text=$encodedMessage';
    final telegramUrl = 'https://t.me/$contactNumber';

    if (mounted) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.green),
                  title: const Text('التواصل عبر واتساب'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (await canLaunchUrl(Uri.parse(whatsAppUrl))) {
                      await launchUrl(Uri.parse(whatsAppUrl));
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تعذر فتح تطبيق واتساب.')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.send, color: Colors.blue),
                  title: const Text('التواصل عبر تليجرام'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (await canLaunchUrl(Uri.parse(telegramUrl))) {
                      await launchUrl(Uri.parse(telegramUrl),
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تعذر فتح تطبيق تليجرام.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // التحقق من حالة الاشتراك بناءً على بيانات المستخدم فقط
  Future<void> _checkActivationStatus() async {
    setState(() {
      _activationState = ActivationState.loading;
      _isLoading = true;
      _message = null;
    });

    if (!await _isConnected()) {
      bool active = await SubscriptionService.isActiveLocal();
      if (active) {
        setState(() {
          _activationState = ActivationState.activated;
          _isLoading = false;
        });
      } else {
        setState(() {
          _activationState = ActivationState.notActivated;
          _isLoading = false;
          _message = "عذراً يرجى الإتصال بالانترنت أولاً";
        });
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      // 🔴 تعديل: جلب البصمة المشفرة بدلاً من deviceId
      final deviceFingerprint = prefs.getString('deviceFingerprint');
      final currentEmail = prefs.getString('userEmail') ?? '';

      // 🔴 تعديل: التحقق من البصمة المشفرة بدلاً من deviceId
      if (userId == null || deviceFingerprint == null) {
        setState(() {
          _activationState = ActivationState.notActivated;
          _isLoading = false;
          _message = "يرجى تسجيل الدخول أولاً.";
        });
        return;
      }

      // جلب بيانات الاشتراك من وثيقة المستخدم
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists || userDoc.data()?['subscription'] == null) {
        setState(() {
          _activationState = ActivationState.notActivated;
          _isLoading = false;
          _message =
              "لا يوجد إشتراك مدفوع مرتبط بهذا الحساب قم بشراء كود التفعيل أولاً";
        });
        return;
      }

      final sub = userDoc.data()!['subscription'];
      final subEmail = sub['email'] ?? '';
      final planType = sub['planType'] ?? '';
      final paidStart =
          sub['startDate'] != null ? DateTime.parse(sub['startDate']) : null;
      final paidEnd =
          sub['endDate'] != null ? DateTime.parse(sub['endDate']) : null;

      if (currentEmail != subEmail) {
        setState(() {
          _activationState = ActivationState.notActivated;
          _isLoading = false;
          _message =
              "يجب عليك تسجيل الدخول بنفس الإيميل الذي اشتركت به أول مرة ($subEmail)";
        });
        return;
      }

      if (paidEnd != null && DateTime.now().isBefore(paidEnd)) {
        // فحص الأجهزة
        final devicesSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('devices')
            .get();

        final phoneDevices =
            devicesSnap.docs.where((d) => d['deviceType'] == 'phone').toList();
        final laptopDevices =
            devicesSnap.docs.where((d) => d['deviceType'] == 'laptop').toList();

        // 🔴 التحقق من وجود الجهاز الحالي بين الأجهزة المصرح بها
        final currentDevice =
            devicesSnap.docs.where((d) => d.id == deviceFingerprint).toList();

        if (currentDevice.isNotEmpty) {
          // الجهاز مسجل مسبقًا
          await SubscriptionService.saveSubscriptionLocal(
              start: paidStart!,
              end: paidEnd,
              type: planType,
              code: sub['code'] ?? '');

          await prefs.setBool('isActivated', true);
          await prefs.setString('paidType', planType);
          await prefs.setInt('paidStartMs', paidStart!.millisecondsSinceEpoch);
          await prefs.setInt('paidEndMs', paidEnd.millisecondsSinceEpoch);

          setState(() {
            _activationState = ActivationState.activated;
            _startDate = paidStart;
            _endDate = paidEnd;
            _isLoading = false;
          });
          return;
        } else {
          // الجهاز الحالي غير موجود في الأجهزة المصرح بها (ربما تم حذفه)
          // لا نقوم بمسح SharedPreferences هنا، بل نحاول تسجيل الجهاز تلقائيًا إن أمكن
          final deviceTypePref = prefs.getString('deviceType') ?? 'phone';
          final deviceNamePref = prefs.getString('deviceModel') ?? '';
          final nowDt = DateTime.now();

          // إذا كان العدد من نفس النوع لم يتجاوز الحد المسموح، نسجل الجهاز تلقائيًا
          if ((deviceTypePref == 'phone' && phoneDevices.length < maxPhones) ||
              (deviceTypePref == 'laptop' &&
                  laptopDevices.length < maxLaptops)) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('devices')
                  .doc(deviceFingerprint)
                  .set({
                'userId': userId,
                'fingerprint': deviceFingerprint,
                'deviceName': deviceNamePref,
                'deviceType': deviceTypePref,
                'addedAt': nowDt.toIso8601String(),
                'status': 'نشط',
              });

              // احفظ بيانات الاشتراك محلياً اذا كانت متاحة
              if (paidStart != null) {
                await SubscriptionService.saveSubscriptionLocal(
                    start: paidStart,
                    end: paidEnd,
                    type: planType,
                    code: sub['code'] ?? '');

                await prefs.setBool('isActivated', true);
                await prefs.setString('paidType', planType);
                await prefs.setInt(
                    'paidStartMs', paidStart.millisecondsSinceEpoch);
                await prefs.setInt('paidEndMs', paidEnd.millisecondsSinceEpoch);
              }

              setState(() {
                _activationState = ActivationState.activated;
                _startDate = paidStart;
                _endDate = paidEnd;
                _isLoading = false;
              });
              return;
            } catch (e) {
              // في حال فشل تسجيل الجهاز، نعرض رسالة مناسبة بدون مسح prefs
              setState(() {
                _activationState = ActivationState.notActivated;
                _isLoading = false;
                _message = "تعذر تسجيل الجهاز تلقائيًا: $e";
              });
              return;
            }
          } else {
            // تجاوز حد الأجهزة المسموح به — نوجّه المستخدم لإدارة أجهزته أو التواصل مع الدعم
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                  title: const Text("الحد الأقصى للأجهزة تم الوصول إليه"),
                  content: Text(
                      "تم تسجيل الدخول مسبقًا من ${devicesSnap.docs.length} أجهزة. الحد المسموح به للأجهزة من نوع ${deviceTypePref == 'phone' ? 'الهواتف' : 'أجهزة الحاسوب'} هو ${deviceTypePref == 'phone' ? maxPhones : maxLaptops}.\n\nيمكنك حذف أحد الأجهزة القديمة من صفحة إدارة الأجهزة أو التواصل معنا لإلغاء تفعيل أحد الأجهزة."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء"),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.chat, color: Colors.green),
                      label: const Text('تواصل عبر واتساب'),
                      onPressed: () {
                        Navigator.pop(context);
                        _launchWhatsAppOrTelegram();
                      },
                    ),
                  ],
                ),
              );
            }
            setState(() {
              _activationState = ActivationState.notActivated;
              _isLoading = false;
              _message = "هذا الجهاز غير مسجل ضمن أجهزتك المصرح بها.";
            });
            return;
          }
        }

        // باقي منطقك الخاص بعدد الأجهزة المسموح بها (يمكنك الإبقاء عليه أو تعديله)
        // مثل الحد الأعلى للهواتف/لابتوبات...
      } else if (paidEnd != null && DateTime.now().isAfter(paidEnd)) {
        setState(() {
          _activationState = ActivationState.expired;
          _startDate = paidStart;
          _endDate = paidEnd;
          _isLoading = false;
          _message =
              "عذراُ إشتراكك منتهي الصلاحية\nتاريخ بدء الإشتراك: ${_formatDate(paidStart)}\nتاريخ انتهاء الإشتراك: ${_formatDate(paidEnd)}";
        });
        return;
      } else {
        setState(() {
          _activationState = ActivationState.notActivated;
          _isLoading = false;
          _message = "لا يوجد اشتراك فعال لهذا المستخدم";
        });
        return;
      }
    } catch (e) {
      setState(() {
        _activationState = ActivationState.notActivated;
        _isLoading = false;
        _message = "حدث خطأ أثناء التحقق: $e";
      });
    }
  }

  // تفعيل الكود لأول مرة
  Future<void> _activateCode() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    if (!await _isConnected()) {
      setState(() {
        _isLoading = false;
        _message = "يرجى الاتصال بالإنترنت أولاً";
      });
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _message = "يرجى إدخال كود الشراء أولاً لتفعيل الإشتراك السنوي";
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final deviceFingerprint = prefs.getString('deviceFingerprint');
      final userEmail = prefs.getString('userEmail') ?? '';
      final deviceType = prefs.getString('deviceType') ?? 'phone';
      final deviceName = prefs.getString('deviceModel') ?? '';

      if (userId == null || deviceFingerprint == null) {
        setState(() {
          _isLoading = false;
          _message = "يرجى تسجيل الدخول أولاً.";
        });
        return;
      }

      final codeCollections = [
        'daily_codes',
        'three_day_codes',
        'weekly_codes',
        'monthly_codes',
        'yearly_codes'
      ];
      String? usedCollection;
      DocumentSnapshot<Map<String, dynamic>>? codeDoc;
      int planDays = 1;

      for (final col in codeCollections) {
        final doc =
            await FirebaseFirestore.instance.collection(col).doc(code).get();
        if (doc.exists) {
          usedCollection = col;
          codeDoc = doc;
          if (col == 'daily_codes') planDays = 1;
          if (col == 'three_day_codes') planDays = 3; // ⬅️ إضافة 3 أيام
          if (col == 'weekly_codes') planDays = 7; // ⬅️ إضافة 7 أيام (أسبوع)
          if (col == 'monthly_codes') planDays = 30;
          if (col == 'yearly_codes') planDays = 365;
          break;
        }
      }

      if (codeDoc == null) {
        setState(() {
          _isLoading = false;
          _message = "كود غير صحيح!";
        });
        return;
      }

      final data = codeDoc.data()!;
      if (data['status'] == 'used') {
        setState(() {
          _isLoading = false;
          _message = "الكود مستخدم مسبقاً.";
        });
        return;
      }

      final now = DateTime.now();
      final end = now.add(Duration(days: planDays));

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'subscription': {
          'planType': usedCollection,
          'startDate': now.toIso8601String(),
          'endDate': end.toIso8601String(),
          'status': 'active',
          'email': userEmail,
          'code': code,
        },
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceFingerprint)
          .set({
        'userId': userId,
        'fingerprint': deviceFingerprint,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'addedAt': now.toIso8601String(),
        'status': 'نشط',
      });

      await SubscriptionService.saveSubscriptionLocal(
          start: now, end: end, type: usedCollection!, code: code);

      await prefs.setBool('isActivated', true);
      await prefs.setString('paidType', usedCollection!);
      await prefs.setInt('paidStartMs', now.millisecondsSinceEpoch);
      await prefs.setInt('paidEndMs', end.millisecondsSinceEpoch);

      try {
        await FirebaseFirestore.instance
            .collection(usedCollection!)
            .doc(code)
            .delete();
        debugPrint("✅ تم حذف الكود من $usedCollection بنجاح.");
      } catch (e) {
        debugPrint("⚠️ فشل حذف الكود: $e");
      }

      setState(() {
        _isLoading = false;
        _activationState = ActivationState.activated;
        _startDate = now;
        _endDate = end;
        _message = "تم تفعيل الاشتراك بنجاح!";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = "حدث خطأ أثناء التفعيل: $e";
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'شاشة الإشتراك',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFFF8F4FF)],
            stops: [0.0, 0.4],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _isLoading && _activationState == ActivationState.loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          const SizedBox(height: kToolbarHeight + 40),
                          // بطاقة حالة الاشتراك
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  if (_activationState ==
                                      ActivationState.activated) ...[
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 60),
                                    const SizedBox(height: 10),
                                    const Text("إشتراكك فعال الآن",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                    if (_startDate != null && _endDate != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          "ينتهي في: ${_formatDate(_endDate)}",
                                          style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 14),
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        minimumSize:
                                            const Size(double.infinity, 50),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const HomeScreen())),
                                      child: const Text('الدخول للتطبيق',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ] else ...[
                                    Icon(Icons.stars_rounded,
                                        color: Colors.amber.shade700, size: 60),
                                    const SizedBox(height: 10),
                                    const Text("مميزات الإشتراك",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 15),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildFeatureItem(
                                            "الوصول الكامل إلى جميع أقسام التطبيق دون قيود."),
                                        _buildFeatureItem(
                                            "إمكانية البحث الشامل في جميع أقسام التطبيق أو في قسم محدد."),
                                        _buildFeatureItem(
                                            "البحث داخل نصوص المواد بسهولة ودقة."),
                                        _buildFeatureItem(
                                            "إمكانية نسخ المواد القانونية بنقرة واحدة."),
                                        _buildFeatureItem(
                                            "تصفح الفهرس مع الانتقال السريع إلى أي مادة أو موضوع."),
                                        _buildFeatureItem(
                                            "الحصول على التحديثات الدورية."),
                                        _buildFeatureItem(
                                            "إضافة القوانين والمواد للمفضلة ومزامنتها وحفظها على حسابك لإستعادتها في حال تغيير الهاتف."),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          if (_activationState !=
                              ActivationState.activated) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5))
                                ],
                              ),
                              child: TextField(
                                controller: _codeController,
                                decoration: InputDecoration(
                                  hintText: 'قم بلصق كود الشراء هنا',
                                  prefixIcon:
                                      const Icon(Icons.vpn_key_outlined),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_codeController.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _codeController.clear(),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.content_paste,
                                            color: Color(0xFF1A237E)),
                                        onPressed: () async {
                                          ClipboardData? data =
                                              await Clipboard.getData(
                                                  'text/plain');
                                          if (data != null) {
                                            _codeController.text =
                                                data.text ?? '';
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                minimumSize: const Size(double.infinity, 55),
                                elevation: 2,
                              ),
                              onPressed: _isLoading ? null : _activateCode,
                              child: const Text('تفعيل الإشتراك الآن',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 15),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text("التحقق من وجود إشتراك نشط"),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                                side:
                                    const BorderSide(color: Color(0xFF1A237E)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed:
                                  _isLoading ? null : _checkActivationStatus,
                            ),
                          ],
                          if (_message != null) ...[
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: _message!.contains('نجاح')
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(_message!,
                                  style: TextStyle(
                                      color: _message!.contains('نجاح')
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ),
                          ],
                          if (_activationState !=
                              ActivationState.activated) ...[
                            const SizedBox(height: 35),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Text("باقات الاشتراك",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54))),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPriceCard(
                                      "إشتراك شهري بـ",
                                      "\$ 4",
                                      Colors.blue.shade50,
                                      Colors.blue,
                                      "السلام عليكم، أود الإشتراك في تطبيق القوانين اليمنية وشراء كود التفعيل (الشهري)"),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: _buildPriceCard(
                                              "إشتراك سنوي بـ",
                                              "\$ 19",
                                              Colors.green.shade50,
                                              Colors.green,
                                              "السلام عليكم، أود الإشتراك في تطبيق القوانين اليمنية وشراء كود التفعيل (السنوي)"),
                                        ),
                                        Positioned(
                                          top: -15,
                                          right: 20,
                                          left: 20,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 4)
                                              ],
                                            ),
                                            child: const Text(
                                              "الأكثر توفيراً",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextButton.icon(
                              icon: const Icon(Icons.support_agent),
                              label:
                                  const Text('تواصل معنا لشراء كود الإشتراك'),
                              onPressed:
                                  _isLoading ? null : _launchWhatsAppOrTelegram,
                              style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1A237E)),
                            ),
                            const SizedBox(height: 20),
                            const Divider(thickness: 1),
                            const SizedBox(height: 15),
                            const Text(
                              "كما يمكنكم الاستمرار في استخدام التطبيق مجاناً ولكن بمزايا محدودة",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.lock_open_outlined,
                                  size: 20),
                              label: const Text(
                                "مواصلة الاستخدام المجاني المحدود",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueGrey,
                                side: const BorderSide(color: Colors.blueGrey),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: () => _showLimitedModeDialog(context),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPriceCard(String title, String price, Color bgColor,
      Color borderColor, String customMessage) {
    return GestureDetector(
      onTap: () => _launchCustomWhatsApp(customMessage),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: borderColor.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  price,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: borderColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchCustomWhatsApp(String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    final whatsAppUrl =
        'whatsapp://send?phone=$contactNumber&text=$encodedMessage';

    if (await canLaunchUrl(Uri.parse(whatsAppUrl))) {
      await launchUrl(Uri.parse(whatsAppUrl));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق واتساب.')),
        );
      }
    }
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showLimitedModeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.lock_open, size: 42, color: Color(0xFF1A237E)),
              SizedBox(height: 12),
              Text(
                'الاستخدام المجاني المحدود',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'يمكنك الدخول للتطبيق واستخدامه مجاناً بمزايا محدودة\nللاستفادة من جميع المميزات، يتوجب شراء كود الإشتراك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLimitedModeActive', true);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()),
                    );
                  }
                },
                child: const Text(
                  'الدخول للتطبيق',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
