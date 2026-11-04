import 'dart:async';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // 👈 إضافة استيراد البروفايدر
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 إضافة استيراد الفايرستور
import 'firebase_options.dart';

// استيراد خدمة المزامنة (تأكد من صحة المسار في مشروعك)
import 'services/favorites_sync_service.dart';

// استدعاء متغيرات الإصدار
import 'version/version.dart';

// استدعاء دالة التحقق من التحديث
import 'version/check_version.dart';

// الشاشات
import 'screens/intro_screen.dart';
import 'screens/google_Login_Screen.dart';
import 'screens/activation_screen.dart';
import 'screens/free_trial_screen.dart';
import 'screens/home_screen.dart';
import 'screens/law_selection_screen.dart'; // تأكد من وجود هذا الاستيراد للراوتس
import 'screens/judgments_selection_screen.dart';
// استيراد مدير التجربة المجانية
import 'services/free_trial_manager.dart';

// إضافة: استيراد خدمة الاشعارات
import 'services/fcm_service.dart';

// استيراد خدمة الاشتراك للتحقق من التفعيل المدفوع
import 'services/subscription_service.dart';

// دالة مساعدة لفتح محادثة واتساب
void openWhatsAppChat() {
  // منطق فتح الواتساب
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قاعدة البيانات للعمل على أنظمة التشغيل المكتبية
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Platform.isAndroid) {
    await FcmService().setupFCM();
  }

  // جلب الإيميل والـ SharedPreferences قبل تشغيل التطبيق
  final prefs = await SharedPreferences.getInstance();
  final userEmail = prefs.getString('userEmail') ?? "";

  runApp(
    MultiProvider(
      providers: [
        // ⚖️ صندوق مفضلة القوانين
        ChangeNotifierProvider(
          create: (_) => FavoritesSyncService(
            userEmail: userEmail,
            firestore: FirebaseFirestore.instance,
            prefs: prefs,
            storageKey: 'favorite_laws',
          ),
        ),
        // 📋 صندوق مفضلة اللوائح
        ChangeNotifierProvider(
          create: (_) => FavoritesSyncService(
            userEmail: userEmail,
            firestore: FirebaseFirestore.instance,
            prefs: prefs,
            storageKey: 'favorite_regulations',
          ),
        ),
        // ⚖️ صندوق مفضلة القواعد القضائية (إضافة ضرورية)
        ChangeNotifierProvider(
          create: (_) => FavoritesSyncService(
            userEmail: userEmail,
            firestore: FirebaseFirestore.instance,
            prefs: prefs,
            storageKey: 'favorite_judgments',
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool showSplash = true;
  bool hasSeenIntro = false;
  bool hasLoggedInGoogle = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAppVersion(context);
    });

    _checkPrefs();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showSplash = false;
        });
      }
    });
  }

  Future<void> _checkPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;
      hasLoggedInGoogle = prefs.getBool('hasLoggedInGoogle') ?? false;
    });
  }

  Future<void> _handleIntroComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntro', true);
    setState(() {
      hasSeenIntro = true;
    });
  }

  Future<void> _handleLoginComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLoggedInGoogle', true);
    setState(() {
      hasLoggedInGoogle = true;
    });
  }

  Future<bool> _isBlockedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isBlockedForOldVersion') ?? false;
  }

  Future<void> _showBlockedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.system_update_rounded,
              size: 50, color: Colors.blue),
          title: const Text(
            'تنبيه: ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'عزيزي المستخدم، نودّ إحاطتك  بأنه تم إصدار نسخة جديدة ومحدّثة، تم خلالها إضافة قسم "القواعد القضائية". يرجى حذف النسخة الحالية وتنزيل التحديث من الروابط أدناه:',
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 12, height: 1.4),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              const Divider(),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Telegram',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('انقر هنا للتحميل',
                    style: TextStyle(fontSize: 10)),
                trailing:
                    const Icon(Icons.telegram, color: Colors.blue, size: 24),
                onTap: () => _launchURL("https://t.me/lawsyem"),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Google Drive',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('رابط مباشر APK',
                    style: TextStyle(fontSize: 10)),
                trailing: const Icon(Icons.cloud_download,
                    color: Colors.orange, size: 24),
                onTap: () => _launchURL(
                    "https://drive.google.com/drive/folders/1rgT8nna5WCiC3wbMxhH9Oz1lb-5uaYb2"),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('WhatsApp',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle:
                    const Text('الدعم الفني', style: TextStyle(fontSize: 10)),
                trailing: const Icon(Icons.chat, color: Colors.green, size: 24),
                onTap: () => _launchURL("https://wa.me/+967777533034"),
              ),
              const Divider(),
              const Center(
                child: Text(
                  'مع خالص الشكر، فريق الدعم',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: const Text('إغلاق التطبيق',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القوانين اليمنية',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/intro': (context) =>
            IntroScreen(onIntroComplete: _handleIntroComplete),
        '/login': (context) => const GoogleLoginScreen(),
        '/lawSelection': (context) => const LawSelectionScreen(),
        '/judgmentsSelection': (context) =>
            const JudgmentsSelectionScreen(), // إضافة المسار
        '/home': (context) => const HomeScreen(),
        '/activate': (context) => const ActivationScreen(),
        '/freeTrial': (context) => const FreeTrialScreen(),
      },
      home: Builder(
        builder: (context) {
          if (showSplash) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'الإصدار: $appVersion\nتاريخ الإصدار: $appReleaseDate',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!hasSeenIntro) {
            return IntroScreen(
              onIntroComplete: () async {
                await _handleIntroComplete();
                if (context.mounted)
                  Navigator.of(context).pushReplacementNamed('/login');
              },
            );
          }

          if (!hasLoggedInGoogle) {
            return const GoogleLoginScreen();
          }

          return FutureBuilder<bool>(
            future: _isBlockedVersion(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

              final blocked = snapshot.data ?? false;
              if (blocked) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showBlockedDialog(context);
                });
                return const Scaffold(
                    body: Center(child: Text('الرجاء تحديث التطبيق...')));
              }

              return FutureBuilder<bool>(
                future: FreeTrialManager.isTrialActive(),
                builder: (context, trialSnapshot) {
                  if (trialSnapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }

                  final trialValid = trialSnapshot.data ?? false;

                  // 1. إذا كانت الفترة التجريبية سارية، يدخل للتطبيق مباشرة
                  if (trialValid) return const HomeScreen();

                  // 2. إذا انتهت التجربة، نتحقق: هل هو مشترك أم اختار "الوضع المحدود"؟
                  return FutureBuilder<bool>(
                    future: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final isPaid = await SubscriptionService.isActiveLocal();
                      final isLimited =
                          prefs.getBool('isLimitedModeActive') ?? false;

                      // تحديث حالة الاشتراك في التفضيلات لضمان المزامنة مع الشاشات الأخرى
                      await prefs.setBool('isActivated', isPaid);

                      // التحقق من حالة التجربة المجانية الأصلية عبر الدالة الصحيحة
                      final bool isValidTrial =
                          await FreeTrialManager.isTrialActive();

                      // يسمح بالدخول إذا كان: مشتركاً، أو في فترة تجربة سارية، أو اختار الوضع المحدود
                      return isPaid || isValidTrial || isLimited;
                    }(),
                    builder: (context, accessSnapshot) {
                      if (accessSnapshot.connectionState !=
                          ConnectionState.done) {
                        return const Scaffold(
                            body: Center(child: CircularProgressIndicator()));
                      }

                      final bool accessAllowed = accessSnapshot.data ?? false;

                      if (accessAllowed) {
                        // يدخل هنا المشترك، صاحب التجربة السارية، والمستخدم في الوضع المحدود
                        return const HomeScreen();
                      } else {
                        // إذا انتهت التجربة ولم يشترك ولم يفعّل الوضع المحدود
                        return const FreeTrialScreen();
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
