import 'package:flutter/services.dart';
import 'dart:convert';

class LawLoader {
  /// تحميل القوانين / اللوائح من مجلد محدد
  static Future<List<Map<String, String>>> loadFromFolder(
      String folderPath) async {
    // الطريقة الرسمية لـ Flutter 3.38+ لجلب الملفات من الـ Assets
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = assetManifest.listAssets();

    final lawFiles = allAssets.where((key) {
      return (key.startsWith(folderPath) ||
              key.startsWith('assets/$folderPath')) &&
          key.endsWith('.json') &&
          !key.contains('laws_index.json');
    }).toList();

    // 🔹 نحدد هل نحن داخل قسم القوانين فقط
    final bool isLawsFolder = folderPath.contains('laws');

    final lawList = await Future.wait(
      lawFiles.map((filePath) async {
        final fileName = filePath.split('/').last;
        final nameWithoutExtension = fileName.replaceAll('.json', '');

        int year = 0;
        int number = 0;

        final regex = RegExp(r'\d+');
        final matches = regex.allMatches(nameWithoutExtension);

        for (final m in matches) {
          final value = int.tryParse(m.group(0) ?? '') ?? 0;
          if (value >= 1990 && value <= 2100) {
            year = value;
          } else if (value >= 1 && value <= 99) {
            number = value;
          }
        }

        // الاسم الافتراضي دائمًا اسم الملف
        String displayName = nameWithoutExtension;

        // 🔹 استخراج الاسم الكامل
        try {
          final fileContent = await rootBundle.loadString(filePath);

          // التعديل حصراً لقسم اللوائح: البحث عن النمط +++اسم اللائحة+++
          if (folderPath.contains('regulations')) {
            final regex = RegExp(r'\+\+\+(.*?)\+\+\+');
            final match = regex.firstMatch(fileContent);
            if (match != null && match.group(1) != null) {
              displayName = match.group(1)!.trim();
            }
          }
          // بقية التطبيق (القوانين) تظل كما هي دون تغيير
          else if (isLawsFolder) {
            displayName = extractLawNameFromFirstCard(fileContent, displayName);
          }
        } catch (_) {
          // في حال أي خطأ نحتفظ بالاسم الافتراضي
        }

        // 🔹 تحسين وتنسيق الاسم
        // 1. إزالة المدود (التطويل)
        displayName = displayName.replaceAll('\u0640', '');

        // 2. تنسيق المسافات داخل الأقواس (55 ) -> (55)
        displayName =
            displayName.replaceAllMapped(RegExp(r'\(\s*(.*?)\s*\)'), (match) {
          return '(${match.group(1)})';
        });

        // 3. فصل الأقواس الملتصقة بالكلمات
        displayName = displayName.replaceAllMapped(
            RegExp(r'(\S)\('), (match) => '${match.group(1)} (');
        displayName = displayName.replaceAllMapped(
            RegExp(r'\)(\S)'), (match) => ') ${match.group(1)}');

        // 4. دمج حرف الميم بالسنة (1990 م) -> (1990م)
        displayName = displayName.replaceAllMapped(
            RegExp(r'(\d{4})\s+م'), (match) => '${match.group(1)}م');

        // 5. توحيد المسافات الزائدة (أكثر من مسافة تصبح مسافة واحدة)
        displayName = displayName.replaceAll(RegExp(r'\s+'), ' ').trim();

        return {
          "name": displayName,
          "file": fileName,
          "year": year.toString(),
          "number": number.toString(),
        };
      }),
    );

    lawList.sort((a, b) {
      final yearA = int.tryParse(a["year"] ?? "0") ?? 0;
      final yearB = int.tryParse(b["year"] ?? "0") ?? 0;
      final numberA = int.tryParse(a["number"] ?? "0") ?? 0;
      final numberB = int.tryParse(b["number"] ?? "0") ?? 0;

      if (yearA != yearB) {
        return yearA.compareTo(yearB);
      }
      return numberA.compareTo(numberB);
    });

    return lawList;
  }

  /// استخراج اسم القانون من بطاقة المقدمة فقط
  static String extractLawNameFromFirstCard(
      String fileContent, String fallbackName) {
    try {
      final data = json.decode(fileContent);

      if (data is! List || data.isEmpty) {
        return fallbackName;
      }

      for (final item in data) {
        if (item is! Map) continue;

        final type = item['type']?.toString() ?? '';
        final text = item['text']?.toString().trim() ?? '';

        // ❗ إذا أول بطاقة مادة أو فصل → لا استخراج اسم
        if (type == 'article' || type == 'section') {
          return fallbackName;
        }

        if (text.isEmpty) continue;

        final stopPhrases = [
          // صيغ باسم الشعب
          'باسم الشعب',
          'بإسم الشعب',
          'بأسم الشعب',
          'بـإســم الشعــب',
          'بـاســم الشعــب',
          'ﺑﺈﺳﻢ ﺍﻟﺸﻌﺐ',
          'بــاســم الشعــب',

          // صيغ التوقيع
          'رئيس مجلس الرئاسة',
          'رئيس الجمهورية',
          'رئيس المجلس الرئاسي',
          'رئيس مجلس النواب',
          'رئيس المجلس السياسي الأعلى',
        ];

        for (final phrase in stopPhrases) {
          if (text.contains(phrase)) {
            final index = text.indexOf(phrase);
            return text.substring(0, index).trim();
          }
        }

        // إن لم نجد أي عبارة إيقاف نعتبر النص اسمًا
        return text;
      }
    } catch (_) {}

    return fallbackName;
  }
}
