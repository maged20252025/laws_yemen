import 'dart:io';
import 'dart:convert';

void main() async {
  final lawsDir = Directory('assets/laws');
  final indexFile = File('assets/laws/index.json');

  if (!await lawsDir.exists()) {
    print('❌ مجلد القوانين assets/laws غير موجود!');
    return;
  }

  final List<Map<String, dynamic>> allArticles = [];

  final files = lawsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'));

  for (final file in files) {
    final content = await file.readAsString();
    try {
      final List<dynamic> articles = jsonDecode(content);
      final lawName = _extractLawName(file);

      // استخراج الاسم العربي للقانون من أول مادة
      final lawNameAr = articles.isNotEmpty && articles.first.containsKey('law')
          ? articles.first['law']
          : 'قانون غير معروف';

      for (final article in articles) {
        final text = article['text'] ?? '';
        final num = article['article_number'] ?? '';

        allArticles.add({
          'lawName': lawName,
          'lawNameAr': lawNameAr,
          'text': text,
          'num': num.toString(),
        });
      }
    } catch (e) {
      print('⚠️ خطأ في الملف ${file.path}: $e');
    }
  }

  await indexFile.writeAsString(JsonEncoder.withIndent('  ').convert(allArticles));
  print('✅ تم توليد الملف index.json بنجاح! عدد المواد: ${allArticles.length}');
}

String _extractLawName(File file) {
  final fileName = file.uri.pathSegments.last.replaceAll('.json', '');
  final parts = fileName.split('_');
  if (parts.length <= 1) return fileName;
  if (parts.first.toLowerCase() == 'law') {
    parts.removeAt(0);
  }
  return parts.join(' ').replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());
}