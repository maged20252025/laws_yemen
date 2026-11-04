import 'package:flutter/material.dart';
import 'package:laws_yemen/services/free_trial_manager.dart';
import 'home_screen.dart';
import 'activation_screen.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../version/check_version.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FreeTrialScreen extends StatefulWidget {
  const FreeTrialScreen({super.key});

  @override
  State<FreeTrialScreen> createState() => _FreeTrialScreenState();
}

enum TrialState { loading, newUser, validTrial, expiredTrial }

class _FreeTrialScreenState extends State<FreeTrialScreen> {
  bool isLoading = false;
  TrialState trialState = TrialState.loading;
  DateTime? trialStart, trialEnd;
  String? message;
  bool showActivateBtn = false;
  bool versionChecked = false;
  bool isSubscribed = false; // 🆕 متغير لمتابعة حالة الاشتراك المدفوع

  @override
  void initState() {
    super.initState();
    _checkBlockedStatus();
    _checkVersionAndInitTrial();
  }

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
                  // openWhatsAppChat(); // دالة محادثة واتساب إن وجدت
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

  Future<void> _checkVersionAndInitTrial() async {
    final isValidVersion = await checkAppVersion(context);
    setState(() {
      versionChecked = true;
    });
    if (!isValidVersion) return;
    _initTrialState();
  }

  Future<void> _initTrialState() async {
    setState(() {
      trialState = TrialState.loading;
      showActivateBtn = false;
      message = null;
    });

    // 🆕 فحص حالة الاشتراك المدفوع من ملفات التفضيلات
    final prefs = await SharedPreferences.getInstance();
    isSubscribed = prefs.getBool('isActivated') ?? false;

    await _fetchAndDetectTrial();
  }

  Future<void> _fetchAndDetectTrial() async {
    try {
      final hasTrial = await FreeTrialManager.hasLocalTrial();
      final isValid = await FreeTrialManager.isTrialActive();

      if (!hasTrial) {
        setState(() {
          trialState = TrialState.newUser;
          showActivateBtn = true;
          message = null;
        });
        return;
      }

      trialStart = await FreeTrialManager.getTrialStart();
      trialEnd = await FreeTrialManager.getTrialEnd();

      if (isValid) {
        setState(() {
          trialState = TrialState.validTrial;
          showActivateBtn = false;
          message = null;
        });
      } else {
        String startStr = trialStart != null
            ? DateFormat('yyyy/MM/dd').format(trialStart!)
            : 'غير متوفر';
        String endStr = trialEnd != null
            ? DateFormat('yyyy/MM/dd').format(trialEnd!)
            : 'غير متوفر';
        setState(() {
          trialState = TrialState.expiredTrial;
          showActivateBtn = true;
          message =
              "عــذراً، لقد انتهت فترة التجربة المجانية.\nسبق لكم الاستفادة من التجربة المجانية على هذا الهاتف\nوذلك خلال الفترة من $startStr\nإلى $endStr.";
        });
      }
    } catch (e) {
      setState(() {
        message = "حدث خطأ أثناء فحص حالة التجربة المجانية: $e";
        trialState = TrialState.loading;
        showActivateBtn = false;
      });
    }
  }

  Future<void> _startTrial() async {
    setState(() {
      isLoading = true;
      message = null;
    });

    final isOnline = await _checkInternet();
    if (!isOnline) {
      setState(() {
        isLoading = false;
        message =
            "⚠️ لا يوجد اتصال بالإنترنت.\nيرجى الاتصال بالإنترنت لإتمام العملية.";
      });
      return;
    }

    try {
      final result = await FreeTrialManager.startTrial(days: 10);

      if (result.startsWith('new') || result.startsWith('active')) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (result.startsWith('expired')) {
        // تعديل طريقة تقسيم الرسالة لتفادي مشاكل التاريخ
        // استخدم فاصل | في Manager و هنا
        final parts = result.split('|');
        String start = parts.length > 1 ? parts[1] : '';
        String end = parts.length > 2 ? parts[2] : '';
        // استخدم تنسيق التاريخ
        DateTime? startDate = DateTime.tryParse(start);
        DateTime? endDate = DateTime.tryParse(end);
        String startStr = startDate != null
            ? DateFormat('yyyy/MM/dd').format(startDate)
            : start;
        String endStr =
            endDate != null ? DateFormat('yyyy/MM/dd').format(endDate) : end;

        setState(() {
          message =
              "عــذراً، لقد انتهت فترة التجربة المجانية.\nسبق لكم الاستفادة من التجربة المجانية على هذا الهاتف\nوذلك خلال الفترة من $startStr\nإلى $endStr.";
          trialState = TrialState.expiredTrial;
          showActivateBtn = true;
          isLoading = false;
        });
      } else {
        setState(() {
          message = "حدث خطأ أثناء بدء التجربة المجانية: $result";
          showActivateBtn = false;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        message = "حدث خطأ: $e";
        showActivateBtn = false;
        isLoading = false;
      });
    }
  }

  void _goToActivation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
    );
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleEnterApp() async {
    final isOnline = await _checkInternet();
    if (!isOnline) {
      setState(() {
        message =
            "⚠️ لا يوجد اتصال بالإنترنت\nيرجى الاتصال بالإنترنت لإتمام العملية";
      });
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('التجربة المجانية'),
        backgroundColor: const Color.fromARGB(255, 169, 226, 220),
        centerTitle: true,
        elevation: 3,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: isLoading || trialState == TrialState.loading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "يتم التحقق من حالتك، يرجى الانتظار...",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium,
                        size: 80, color: Color(0xFF00897B)),
                    const SizedBox(height: 25),
                    if (trialState != TrialState.expiredTrial)
                      const Text(
                        "استمتع بتجربة جميع مزايا التطبيق مجاناً لمدة ( 7 أيــام)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00897B),
                          height: 1.6,
                        ),
                      ),
                    const SizedBox(height: 35),
                    if (trialState == TrialState.newUser)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_circle_fill, size: 26),
                          label: const Text(
                            "بدء التجربة المجانية",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009688),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          onPressed: showActivateBtn ? _startTrial : null,
                        ),
                      ),
                    if (trialState == TrialState.validTrial || isSubscribed)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified, size: 26),
                          label: const Text(
                            "الدخول للتطبيق",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 5,
                          ),
                          onPressed: _handleEnterApp,
                        ),
                      ),
                    if (trialState == TrialState.expiredTrial &&
                        !isSubscribed) ...[
                      // =========================
                      // رسالة انتهاء التجربة المجانية بعد AppBar مباشرة
                      // =========================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 5),
                        margin: const EdgeInsets.only(
                            top: 8), // تم تقليل الهامش العلوي
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBEAEA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF2B8B5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            Text(
                              "عــذراً لقد انتهت فترة التجربة المجانية",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "سبق لكم الاستفادة من التجربة المجانية على هذا الهاتف\nوذلك خلال الفترة من 2025/12/05 إلى 2025/12/12",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16), // تم تقليل المسافة

                      // =========================
                      // بطاقة التفعيل المدفوع
                      // =========================
                      Column(
                        children: [
                          const Text(
                            "للاستمرار في استخدام التطبيق والاستفادة من جميع المميزات، يرجى تفعيل الاشتراك السنوي",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5D4037),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.vpn_key, size: 24),
                              label: const Text(
                                "الانتقال إلى شاشة تفعيل الاشتراك",
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4C41),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _goToActivation,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20), // تم تقليل المسافة

                      // =========================
                      // فاصل أنيق
                      // =========================
                      const Divider(thickness: 1, color: Colors.grey),
                      const SizedBox(height: 12),

                      // =========================
                      // خيار الاستخدام المحدود
                      // =========================
                      Column(
                        children: [
                          const Text(
                            "كما يمكنكم الاستمرار في استخدام التطبيق مجاناً ولكن بمزايا محدودة",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.lock_open_outlined, size: 22),
                            label: const Text(
                              "مواصلة الاستخدام المجاني المحدود",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey,
                              side: const BorderSide(color: Colors.blueGrey),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: () => _showLimitedModeDialog(context),
                          ),
                        ],
                      ),
                    ],
                    if (message != null &&
                        trialState != TrialState.expiredTrial)
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: Text(
                          message!,
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  // --- إضافة الدالة هنا قبل القوس الأخير للكلاس ---
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
              Icon(Icons.lock_open, size: 42, color: Color(0xFF00695C)),
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
            'يمكنك الدخول للتطبيق واستخدامه مجاناً بمزايا محدودة\nللاستفادة من جميع المميزات، يمكنك تفعيل الاشتراك في أي وقت',
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
                  backgroundColor: const Color(0xFF00695C),
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
} // إغلاق الكلاس _FreeTrialScreenState
