import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version.dart';

Future<void> _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<bool> checkAppVersion(BuildContext context) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('version')
        .doc('current')
        .get();
    final prefs = await SharedPreferences.getInstance();

    if (!doc.exists) {
      return true;
    }

    final serverVersion = doc['appVersion'] as String? ?? '';
    if (serverVersion != appVersion) {
      await prefs.setBool('isBlockedForOldVersion', true);

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
                  trailing:
                      const Icon(Icons.chat, color: Colors.green, size: 24),
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
      return false;
    } else {
      await prefs.setBool('isBlockedForOldVersion', false);
    }
    return true;
  } catch (e) {
    return true;
  }
}
