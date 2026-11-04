import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'law_articles_screen.dart';

class AllIndicesScreen extends StatefulWidget {
  const AllIndicesScreen({Key? key}) : super(key: key);

  @override
  State<AllIndicesScreen> createState() => _AllIndicesScreenState();
}

class _AllIndicesScreenState extends State<AllIndicesScreen> {
  bool _isLoading = true;
  final List<Map<String, dynamic>> _headers = [];
  final List<Map<String, dynamic>> _preambles = [];
  final List<Map<String, dynamic>> _conclusions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final folders = [
      {'path': 'assets/laws/', 'type': 'قانون'},
      {'path': 'assets/regulations/', 'type': 'لائحة'},
      {'path': 'assets/instructions/', 'type': 'تعليمات'},
    ];

    try {
      // الطريقة المضمونة لجلب ملفات الـ assets
      final String manifestContent =
          await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final List<String> assets = manifestMap.keys.toList();

      for (var folder in folders) {
        final String folderPath = folder['path']!;
        final folderAssets = assets
            .where(
                (path) => path.contains(folderPath) && path.endsWith('.json'))
            .toList();

        for (String assetPath in folderAssets) {
          try {
            final String content = await rootBundle.loadString(assetPath);
            final List<dynamic> dataList = json.decode(content);

            // استخراج اسم القانون من أول عنصر preamble أو استخدام اسم الملف
            String lawName = assetPath.split('/').last.replaceAll('.json', '');
            if (dataList.isNotEmpty && dataList[0]['type'] == 'preamble') {
              lawName = dataList[0]['text'].split('\n')[0];
            }

            for (int i = 0; i < dataList.length; i++) {
              final item = dataList[i];
              final String itemType =
                  (item['type']?.toString() ?? '').toLowerCase();

              final Map<String, dynamic> entry = {
                'title': item['title'] ?? item['text'] ?? 'بدون عنوان',
                'lawName': lawName,
                'fileName': assetPath.split('/').last,
                'basePath': folderPath,
                'articleId': i.toString(), // استخدام الفهرس للوصول السريع
                'type': folder['type'],
              };

              if (itemType == 'section') {
                _headers.add(entry);
              } else if (itemType == 'preamble') {
                _preambles.add(entry);
              } else if (i > dataList.length - 10 &&
                  (item['text']?.toString().contains('يلغى') ?? false)) {
                // تصنيف المواد الختامية التي تحتوي على كلمة "يلغى" في نهاية الملف
                _conclusions.add(entry);
              }
            }
          } catch (e) {
            debugPrint("Error reading file $assetPath: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("General Error: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildList(List<Map<String, dynamic>> items, String emptyMsg) {
    if (items.isEmpty) return Center(child: Text(emptyMsg));

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isHeader = _headers.contains(item);
        final bool isPreamble = _preambles.contains(item);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LawArticlesScreen(
                  lawFileName: item['fileName'],
                  lawName: item['lawName'],
                  basePath: item['basePath'],
                  initialArticleId: item['articleId'],
                ),
              ),
            );
          },
          child: isHeader
              ? Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF457C96),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  item['title'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "المصدر: ${item['lawName']}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border:
                        Border.all(color: const Color(0xFFE0E0E0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isPreamble ? Icons.verified_user : Icons.gavel_rounded,
                        color: const Color(0xFF936E3E),
                        size: 30,
                      ),
                      const SizedBox(height: 15),
                      const Divider(color: Color(0xFFE0E0E0)),
                      const SizedBox(height: 15),
                      Text(
                        item['title'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "المصدر: ${item['lawName']}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF936E3E).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فهارس ومكونات الملفات'),
          backgroundColor: const Color(0xFF457C96),
          bottom: const TabBar(
            tabs: [
              Tab(
                  text: 'العناوين',
                  icon: Icon(Icons.format_list_bulleted_rounded)),
              Tab(text: 'المقدمات', icon: Icon(Icons.description_outlined)),
              Tab(text: 'الخواتيم', icon: Icon(Icons.gavel_rounded)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(_headers, 'لا توجد عناوين'),
                  _buildList(_preambles, 'لا توجد مقدمات'),
                  _buildList(_conclusions, 'لا توجد خواتيم'),
                ],
              ),
      ),
    );
  }
}
