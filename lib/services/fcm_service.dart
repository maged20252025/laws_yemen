import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🟢 إضافة

// --------------------------------------------------------------------------
// 1. تعريف مُهيئ الإشعارات المحلية (Local Notifications Plugin)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 2. الدالة المسؤولة عن معالجة الإشعارات في الخلفية (عندما يكون التطبيق مغلقاً)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}
// --------------------------------------------------------------------------

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> setupFCM() async {
    // 3. تهيئة إعدادات الإشعارات المحلية (Android و iOS)
    await _initializeLocalNotifications();

    // 4. تسجيل المعالج للرسائل في الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. طلب الأذونات
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 6. الحصول على رمز الجهاز (Token)
    final token = await _fcm.getToken();
    print("FCM Token: $token");

    // 7. معالجة رسائل الواجهة الأمامية (وعرضها يدوياً)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');

      // 🟢 الخطوة الحاسمة: عرض الإشعار محلياً إذا كان التطبيق مفتوحاً
      if (message.notification != null) {
        _showLocalNotification(message.notification!);
      }
    });

    // 8. معالجة تفاعل المستخدم مع الإشعار (عند الضغط عليه)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // يمكنك إضافة منطق توجيه المستخدم لشاشة معينة هنا
    });
  }

  // --------------------------------------------------------------------------
  // دوال الإشعارات المحلية
  // --------------------------------------------------------------------------

  Future<void> _initializeLocalNotifications() async {
    // إعدادات الأندرويد (نستخدم ic_launcher كأيقونة مؤقتاً)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _showLocalNotification(RemoteNotification notification) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel', // يجب أن يكون هذا الـ ID فريداً وثابتاً
      'قناة الإشعارات الأساسية', // الاسم الذي يراه المستخدم في إعدادات التطبيق
      channelDescription: 'قناة الإشعارات الهامة من القوانين اليمنية',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher', // استخدام الأيقونة المؤقتة
      // 🟢 هنا يمكن إضافة صوت مخصص إذا كان لديك ملف صوتي
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    flutterLocalNotificationsPlugin.show(
      0, // ID الإشعار (يمكنك تغييره إذا أردت إشعارات متعددة)
      notification.title,
      notification.body,
      platformChannelSpecifics,
      // يمكنك هنا إضافة payload إذا كنت تريد معالجة النقر على الإشعار
      // payload: 'item x',
    );
  }
}
