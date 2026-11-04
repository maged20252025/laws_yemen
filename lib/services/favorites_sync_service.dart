import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../main.dart' as main_file;
import '../version/check_version.dart';

class FavoriteItem {
  final String lawFile;
  final String articleNumber;

  FavoriteItem({
    required this.lawFile,
    required this.articleNumber,
  });

  Map<String, dynamic> toJson() => {
        'lawFile': lawFile,
        'articleNumber': articleNumber,
      };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        lawFile: json['lawFile'],
        articleNumber: json['articleNumber'],
      );
}

class FavoritesSyncService extends ChangeNotifier {
  final String userEmail;
  final FirebaseFirestore firestore;
  final SharedPreferences _prefs;
  final String storageKey;

  // 🔑 أضف هذا السطر هنا لحل كل أخطاء _saveLock
  Future<void> _saveLock = Future.value();

  FavoritesSyncService({
    required this.userEmail,
//...
    required this.firestore,
    required SharedPreferences prefs,
    this.storageKey = 'favorite_laws', // الافتراضي للقوانين
  }) : _prefs = prefs;

  void startSyncListeners() {
    listenToFavoritesChanges();
    _listenToInternetAndSync();
  }

  static const String lawsKey = 'favorite_laws';
  static String articlesKey(String lawFile) => 'favorites_$lawFile';

  // ---------------- الدوال المحلية المُعدّلة باستخدام القفل ----------------

  Future<Set<String>> getLocalFavoriteLaws() async {
    // 🔒 ننتظر انتهاء أي عملية كتابة سابقة
    await _saveLock;
    // 🔑 التغيير هنا: نستخدم storageKey بدلاً من lawsKey
    final laws = _prefs.getStringList(storageKey) ?? [];
    return laws.toSet();
  }

  // 🛠️ التعديل الأهم: إزالة 'async' لضمان التسلسل الكامل
  Future<void> saveLocalFavoriteLaws(Set<String> lawFiles) {
    // 🔒 نُدخِل عملية الكتابة الجديدة في سلسلة الانتظار
    _saveLock = _saveLock.then((_) async {
      // ✅ التعديل هنا: استخدمنا storageKey
      await _prefs.setStringList(storageKey, lawFiles.toList());
    });
    return _saveLock; // نرجع السلسلة مباشرة
  }

  Future<Set<String>> getLocalFavoriteArticles(String lawFile) async {
    // 🔒 ننتظر انتهاء أي عملية كتابة سابقة
    await _saveLock;
    final articles = _prefs.getStringList(articlesKey(lawFile)) ?? [];
    return articles.toSet();
  }

  // 🛠️ التعديل الأهم: إزالة 'async' لضمان التسلسل الكامل
  Future<void> saveLocalFavoriteArticles(
      String lawFile, Set<String> articleNumbers) {
    // 🔒 نُدخِل عملية الكتابة الجديدة في سلسلة الانتظار
    _saveLock = _saveLock.then((_) async {
      await _prefs.setStringList(articlesKey(lawFile), articleNumbers.toList());
    });
    return _saveLock; // نرجع السلسلة مباشرة
  }
  // -------------------------------------------------------------------------

  Future<void> syncFavoriteLawsWithFirebase(Set<String> lawFiles) async {
    try {
      await firestore.collection('usersFavorites').doc(userEmail).set({
        // ✅ التعديل هنا: جعلنا اسم الحقل متغير حسب القسم
        storageKey: lawFiles.toList(),
        'lastSync': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('خطأ مزامنة القوانين مع Firebase: $e');
    }
  }

  Future<void> syncFavoriteArticlesWithFirebase(
      String lawFile, Set<String> articleNumbers) async {
    try {
      await firestore.collection('usersFavorites').doc(userEmail).set({
        'favoriteArticles': {
          lawFile: articleNumbers.toList(),
        },
        'lastSync': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('خطأ مزامنة المقالات مع Firebase: $e');
    }
  }

  Future<void> restoreFavoritesFromFirebase() async {
    print('استرجاع المفضلات من السحابة...');
    try {
      final doc =
          await firestore.collection('usersFavorites').doc(userEmail).get();
      if (doc.exists) {
        final data = doc.data() ?? {};

        final List<dynamic> lawFilesList = data[storageKey] ?? [];
        await saveLocalFavoriteLaws(
            lawFilesList.map((e) => e.toString()).toSet());

        if (data['favoriteArticles'] != null &&
            data['favoriteArticles'] is Map) {
          final Map<String, dynamic> favArticles =
              Map<String, dynamic>.from(data['favoriteArticles']);
          for (final entry in favArticles.entries) {
            final String lawFile = entry.key;
            final List<dynamic> articles = entry.value as List<dynamic>;
            await saveLocalFavoriteArticles(
                lawFile, articles.map((a) => a.toString()).toSet());
          }
        }
        print('تم استرجاع المفضلات بنجاح!');
        // لا حاجة لـ notifyListeners هنا، لأن الشاشات تستمع بالفعل لـ Firestore
      } else {
        print('لا توجد بيانات مفضلة لهذا المستخدم في السحابة.');
      }
    } catch (e) {
      print('خطأ أثناء استرجاع المفضلات من السحابة: $e');
    }
  }

  void listenToFavoritesChanges() {
    firestore
        .collection('usersFavorites')
        .doc(userEmail)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        final List<dynamic> lawFilesList = data[storageKey] ?? [];
        await saveLocalFavoriteLaws(
            lawFilesList.map((e) => e.toString()).toSet());

        if (data['favoriteArticles'] != null &&
            data['favoriteArticles'] is Map) {
          final Map<String, dynamic> favArticles =
              Map<String, dynamic>.from(data['favoriteArticles']);
          for (final entry in favArticles.entries) {
            final String lawFile = entry.key;
            final List<dynamic> articles = entry.value as List<dynamic>;
            await saveLocalFavoriteArticles(
                lawFile, articles.map((a) => a.toString()).toSet());
          }
        }

        print('[Firestore] تحديث المفضلات بشكل تلقائي!');
        notifyListeners();
      }
    });
  }

  // ======== دوال الإضافة/الإزالة (التحديث الفوري محفوظ) ===========

  Future<void> addFavoriteLaw(BuildContext context, String lawFile) async {
    // 1. 🟢 الحفظ المحلي الفوري وتحديث الواجهة (الآن آمن 100%)
    final laws = await getLocalFavoriteLaws();
    if (laws.contains(lawFile)) {
      return;
    }
    laws.add(lawFile);
    await saveLocalFavoriteLaws(laws);
    notifyListeners(); // 🟢 يتم تحديث الواجهة فوراً!

    // 2. ⏳ التحقق البطيء والمزامنة (في الخلفية)
    final isBlocked = _prefs.getBool('isBlockedForOldVersion') ?? false;
    if (isBlocked) {
      await _showBlockedDialog(context);
      return;
    }
    final isValid = await checkAppVersion(context);
    if (!isValid) return;

    syncFavoriteLawsWithFirebase(laws);
  }

  Future<void> removeFavoriteLaw(BuildContext context, String lawFile) async {
    // 1. 🟢 الحفظ المحلي الفوري وتحديث الواجهة
    final laws = await getLocalFavoriteLaws();
    if (!laws.contains(lawFile)) {
      return;
    }
    laws.remove(lawFile);
    await saveLocalFavoriteLaws(laws);
    notifyListeners(); // 🟢 يتم تحديث الواجهة فوراً!

    // 2. ⏳ التحقق البطيء والمزامنة (في الخلفية)
    final isBlocked = _prefs.getBool('isBlockedForOldVersion') ?? false;
    if (isBlocked) {
      await _showBlockedDialog(context);
      return;
    }
    final isValid = await checkAppVersion(context);
    if (!isValid) return;

    syncFavoriteLawsWithFirebase(laws);
  }

  Future<void> addFavoriteArticle(
      BuildContext context, String lawFile, String articleNumber) async {
    // 1. 🟢 الحفظ المحلي الفوري وتحديث الواجهة
    final articles = await getLocalFavoriteArticles(lawFile);
    if (articles.contains(articleNumber)) {
      return;
    }
    articles.add(articleNumber);
    await saveLocalFavoriteArticles(lawFile, articles);
    notifyListeners(); // 🟢 يتم تحديث الأيقونة فوراً!

    // 2. ⏳ التحقق البطيء والمزامنة (في الخلفية)
    final isBlocked = _prefs.getBool('isBlockedForOldVersion') ?? false;
    if (isBlocked) {
      await _showBlockedDialog(context);
      return;
    }
    final isValid = await checkAppVersion(context);
    if (!isValid) return;

    syncFavoriteArticlesWithFirebase(lawFile, articles);
  }

  Future<void> removeFavoriteArticle(
      BuildContext context, String lawFile, String articleNumber) async {
    // 1. 🟢 الحفظ المحلي الفوري وتحديث الواجهة
    final articles = await getLocalFavoriteArticles(lawFile);
    if (!articles.contains(articleNumber)) {
      return;
    }
    articles.remove(articleNumber);
    await saveLocalFavoriteArticles(lawFile, articles);
    notifyListeners(); // 🟢 يتم تحديث الأيقونة فوراً!

    // 2. ⏳ التحقق البطيء والمزامنة (في الخلفية)
    final isBlocked = _prefs.getBool('isBlockedForOldVersion') ?? false;
    if (isBlocked) {
      await _showBlockedDialog(context);
      return;
    }
    final isValid = await checkAppVersion(context);
    if (!isValid) return;

    syncFavoriteArticlesWithFirebase(lawFile, articles);
  }
  // =========================================================================

  void _listenToInternetAndSync() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        print('الاتصال بالإنترنت متاح - المزامنة مع السحابة...');

        final laws = await getLocalFavoriteLaws();
        await syncFavoriteLawsWithFirebase(laws);

        for (final lawFile in laws) {
          final articles = await getLocalFavoriteArticles(lawFile);
          await syncFavoriteArticlesWithFirebase(lawFile, articles);
        }

        await restoreFavoritesFromFirebase();
      }
    });
  }

  Future<void> _showBlockedDialog(BuildContext context) async {
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
                main_file.openWhatsAppChat();
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
