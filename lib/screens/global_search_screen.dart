import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:laws_yemen/services/free_trial_manager.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String searchPath;
  final String title;
  final String searchHint; // 🆕 لإضافة "أكتب كلمة للبحث في اللوائح" مثلاً
  final Color themeColor; // 🆕 لتغيير لون البحث حسب القسم

  const GlobalSearchScreen({
    super.key,
    this.searchPath = 'assets/laws/',
    this.title = 'بحث شامل في القوانين',
    this.searchHint = 'أكتب كلمة للبحث ... ', // نص افتراضي
    this.themeColor = const Color(0xFF457C96), // لون افتراضي (أزرق)
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final AutoScrollController _scrollController = AutoScrollController();

  List<Map<String, dynamic>> _results = [];
  Set<String> _allFilteredLaws = {};
  Set<String> _selectedLaws = {};
  final Map<int, bool> _expanded = {};

  // 🆕 الميزات المضافة
  bool _exactMatch = false; // تطابق تام
  bool _searchByNumber = false; // بحث بالرقم

  bool _showFilterSheet = false;
  bool _isDark = false;
  double _fontSize = 18.0;
  static const String _kFontKey = 'global_font_size';

  int? _resultsCount;
  int? _wordMatchesCount;
  bool isSubscribed = false; // 🆕 تعريف المتغير

  @override
  void initState() {
    super.initState();
    _loadFontSize();
    _checkAccess(); // 🆕 استدعاء الفحص
    _controller.addListener(_onSearchChanged);
  }

  // 🆕 دالة الفحص الموحدة لضمان عمل التجربة المجانية
  Future<void> _checkAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isPaid = prefs.getBool('isActivated') ?? false;
    final bool isTrialValid = await FreeTrialManager.isTrialActive();
    if (mounted) {
      setState(() {
        isSubscribed = isPaid || isTrialValid;
      });
    }
  }

  // 🆕 دالة لإظهار التنبيه الموحد
  void _showLimitedAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("عـــذراً",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        content: const Text(
            "هذه الميزة (البحث المتقدم والنسخ) مخصصة لمشتركي النسخة الكاملة فقط.\n\nيمكنكم الاستمتاع بكافة المزايا عبر تفعيل الاشتراك.",
            textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("فهمت ذلك"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_kFontKey);
    if (v != null && mounted) {
      setState(() => _fontSize = v);
    }
  }

  Future<void> _saveFontSize(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontKey, v);
  }

  void _increaseFont() {
    setState(() {
      _fontSize = (_fontSize + 1).clamp(12.0, 32.0);
    });
    _saveFontSize(_fontSize);
  }

  void _decreaseFont() {
    setState(() {
      _fontSize = (_fontSize - 1).clamp(12.0, 32.0);
    });
    _saveFontSize(_fontSize);
  }

  Future<List<String>> _getLawFiles() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = assetManifest.listAssets();

    // الحالة الأولى: البحث الشامل في كل المجلدات (للززر الموجود في الهوم)
    if (widget.searchPath == 'all') {
      return allAssets
          .where((key) =>
              (key.startsWith('assets/laws/') ||
                  key.startsWith('assets/regulations/') ||
                  key.startsWith('assets/prosecutions/') ||
                  key.startsWith('assets/judgments/')) &&
              key.endsWith('.json') &&
              !key.contains('laws_index.json'))
          .toList();
    }

    // الحالة الثانية: البحث في المجلد الممرر فقط (قوانين أو لوائح أو تعليمات)
    return allAssets
        .where((key) =>
            (key.startsWith(widget.searchPath) ||
                key.startsWith('assets/${widget.searchPath}')) &&
            key.endsWith('.json') &&
            !key.contains('laws_index.json'))
        .toList();
  }

  void _onSearchChanged() {
    _search(_controller.text);
  }

  Future<void> _search(String query) async {
    // 💡 تعديل: إيقاف البحث إذا كان وضع البحث بالرقم مفعلاً والاستعلام فارغاً
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _allFilteredLaws.clear();
        _selectedLaws.clear();
        _resultsCount = null;
        _wordMatchesCount = null;
      });
      return;
    }

    List<Map<String, dynamic>> matches = [];
    Set<String> foundLaws = {};

    final normalizedQuery = query.trim().toLowerCase();
    RegExp matchingRegExp = _exactMatch
        ? RegExp(r'(?<=\s|^)' + RegExp.escape(normalizedQuery) + r'(?=\s|$)')
        : RegExp(RegExp.escape(normalizedQuery));

    final lawFiles = await _getLawFiles();
    for (final filePath in lawFiles) {
      try {
        final String data = await rootBundle.loadString(filePath);
        final dynamic jsonData = json.decode(data);

        String lawName = filePath.split('/').last.replaceAll('.json', '');
        List articles = [];

        if (jsonData is Map<String, dynamic>) {
          // استعادة المنطق القديم حرفياً
          lawName = jsonData['name'] ?? lawName;
          articles = jsonData['articles'] ?? jsonData['data'] ?? [];
        } else if (jsonData is List) {
          articles = jsonData;
          // فحص خاص بالقواعد القضائية فقط: إذا وجدنا حقل rule_number
          if (articles.isNotEmpty &&
              articles[0] is Map &&
              articles[0].containsKey('rule_number')) {
            lawName = articles[0]['type'] ?? lawName;
          }
        }

        for (var article in articles) {
          // تمكين البحث في المقالات (القوانين) أو العناصر التي تحتوي على محتوى (القواعد)
          if (article is Map &&
              (article['type'] == null ||
                  article['type'] == 'article' ||
                  article['content'] != null)) {
            bool isMatch = false;
            final hasQuery = normalizedQuery.isNotEmpty;

            // دعم rule_number للقواعد القضائية مع الإبقاء على مسميات القوانين
            // جلب الرقم: القوانين تستخدم article_number/num ، والقواعد تستخدم rule_number
            final articleNumber = (article['article_number'] ??
                    article['num'] ??
                    article['rule_number'] ??
                    '')
                .toString();

            if (hasQuery) {
              if (_searchByNumber) {
                String cleanQuery = normalizedQuery.replaceAllMapped(
                    RegExp(r'[٠-٩]'),
                    (m) => (m.group(0)!.codeUnitAt(0) - 1632).toString());
                isMatch = articleNumber == cleanQuery;
              } else {
                // تحديد النص المراد البحث فيه بناءً على المتوفر
                final contentToSearch =
                    (article['text'] ?? article['content'] ?? '')
                        .toString()
                        .toLowerCase();
                if (contentToSearch.isNotEmpty) {
                  if (_exactMatch) {
                    isMatch = matchingRegExp.hasMatch(contentToSearch);
                  } else {
                    isMatch = contentToSearch.contains(normalizedQuery);
                  }
                }
              }
            }

            if (isMatch) {
              // 🆕 تحديد اسم المجموعة للفلترة (قواعد قضائية فقط)
              String filterName = lawName;
              if (widget.searchPath.contains('judgments')) {
                filterName = _getCleanCategoryName(lawName);
              }

              matches.add({
                'law': lawName,
                'filterGroup':
                    filterName, // 🆕 تخزين مسمى المجموعة للفلترة الذكية
                'article_number': articleNumber,
                'text': article['text'] ?? article['content'],
                'subject': article['subject'],
              });

              // 🆕 إضافة مسمى المجموعة للفلترة بدلاً من اسم الملف التقني
              foundLaws.add(filterName);
            }
          }
        }
      } catch (e) {
        debugPrint('خطأ في تحميل $filePath : $e');
      }
    }

    // 💡 حساب عدد مرات تكرار الكلمة بناءً على التطابق التام أو العادي
    int wordMatches = 0;
    if (!_searchByNumber) {
      // ⭐️ لا تحسب الكلمات عند البحث بالرقم
      for (final item in matches) {
        final text = (item['text'] ?? '').toString();
        final textLower = text.toLowerCase();
        wordMatches += matchingRegExp.allMatches(textLower).length;
      }
    }

    setState(() {
      _results = matches;
      _allFilteredLaws = foundLaws;
      if (_selectedLaws.isEmpty ||
          !_allFilteredLaws.containsAll(_selectedLaws)) {
        _selectedLaws = Set.from(foundLaws);
      }
      _expanded.clear();
      _resultsCount = matches.length;
      // ⭐️ تعيين إحصائية الكلمات إلى null عند البحث بالرقم لتبديل عرض الإحصائية
      _wordMatchesCount = _searchByNumber ? null : wordMatches;
    });
  }

  void _showFilterDropdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // للسماح بالتحكم الكامل في الارتفاع
      backgroundColor: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState2) {
            final screenHeight = MediaQuery.of(context).size.height;
            final sheetHeight = screenHeight * 0.80; // تحديد الارتفاع بنسبة 80%

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                height: sheetHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Text(
                        'استبعد النتائج التي لا ترغب بظهورها',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8), // تقليل المسافة
                      if (_allFilteredLaws.isEmpty)
                        const Expanded(
                            child:
                                Center(child: Text('لا توجد قوانين لفلترتها')))
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState2(() =>
                                    _selectedLaws = Set.from(_allFilteredLaws));
                                setState(() {});
                              },
                              icon: const Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 20),
                              label: const Text('تحديد الكل',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const VerticalDivider(),
                            TextButton.icon(
                              onPressed: () {
                                setState2(() => _selectedLaws.clear());
                                setState(() {});
                              },
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 20),
                              label: const Text('إلغاء التحديد',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(thickness: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _allFilteredLaws.length,
                            separatorBuilder: (context, index) => Divider(
                                color: Colors.grey.withOpacity(0.1), height: 1),
                            itemBuilder: (context, index) {
                              String lawName =
                                  _allFilteredLaws.elementAt(index);
                              final isSelected =
                                  _selectedLaws.contains(lawName);

                              // تحسين مسمى القسم حصراً للقواعد القضائية دون المساس بالقوانين
                              // بما أننا قمنا بتنظيف الأسماء في خطوة البحث، نعرضها مباشرة
                              String displayTitle = lawName;
                              // لا حاجة لعمليات replace إضافية هنا لأن lawName أصبح هو "المجموعة"

                              return CheckboxListTile(
                                title: Text(
                                  displayTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? widget.themeColor
                                        : (_isDark
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                ),
                                value: isSelected,
                                activeColor: widget.themeColor,
                                checkboxShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                                onChanged: (val) {
                                  setState2(() {
                                    if (val == true) {
                                      _selectedLaws.add(lawName);
                                    } else {
                                      _selectedLaws.remove(lawName);
                                    }
                                  });
                                  setState(() {});
                                },
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                              );
                            },
                          ),
                        ),
                        // شريط الإحصائيات التفاعلي المتطابق مع الشاشة الرئيسية
                        Builder(builder: (context) {
                          // 1. حساب النتائج المفلترة حالياً داخل النافذة
                          final currentFilteredResults = _results.where((item) {
                            if (widget.searchPath.contains('judgments')) {
                              return _selectedLaws
                                  .contains(item['filterGroup']);
                            }
                            return _selectedLaws.contains(item['law']);
                          }).toList();

                          // 2. حساب عدد الكلمات (المطابقات) في هذه النتائج
                          int currentWordMatches = 0;
                          final query = _controller.text.trim().toLowerCase();
                          if (query.isNotEmpty && !_searchByNumber) {
                            RegExp regExp = _exactMatch
                                ? RegExp(r'(?<=\s|^)' +
                                    RegExp.escape(query) +
                                    r'(?=\s|$)')
                                : RegExp(RegExp.escape(query));

                            for (final item in currentFilteredResults) {
                              final text =
                                  (item['text'] ?? '').toString().toLowerCase();
                              currentWordMatches +=
                                  regExp.allMatches(text).length;
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: widget.themeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: widget.themeColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 18, color: widget.themeColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _searchByNumber
                                        ? 'تم العثور على ${formatArticlesCount(currentFilteredResults.length)} في ${formatLawsCount(_selectedLaws.length)}'
                                        : 'تم العثور على ${formatWordsCount(currentWordMatches)} في ${formatArticlesCount(currentFilteredResults.length)} ضمن ${formatLawsCount(_selectedLaws.length)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  TextSpan _highlightSearchText(String text, String query) {
    // 💡 التعديل: لا يجب التمييز عند البحث بالرقم، أو عند عدم وجود نص للمادة
    if (query.trim().isEmpty || _searchByNumber) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: _isDark ? Colors.white : Colors.black,
          fontSize: _fontSize,
          height: 1.9,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    final normQuery = query.trim().toLowerCase();
    final source = text;
    final normText = text.toLowerCase();

    List<TextSpan> spans = [];
    int start = 0;

    // 💡 تطبيق منطق التطابق التام أو العادي على التمييز
    RegExp regExp = _exactMatch
        ? RegExp(r'(?<=\s|^)' + RegExp.escape(normQuery) + r'(?=\s|$)')
        : RegExp(RegExp.escape(normQuery));

    for (final match in regExp.allMatches(normText)) {
      if (match.start > start) {
        spans.add(TextSpan(
            text: source.substring(start, match.start),
            style: TextStyle(
              color: _isDark ? Colors.white : Colors.black,
              fontSize: _fontSize,
              height: 1.9,
              fontWeight: FontWeight.bold,
            )));
      }
      spans.add(TextSpan(
        text: source.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Colors.amberAccent,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontSize: _fontSize,
          height: 1.9,
        ),
      ));
      start = match.end;
    }

    if (start < source.length) {
      spans.add(TextSpan(
          text: source.substring(start),
          style: TextStyle(
            color: _isDark ? Colors.white : Colors.black,
            fontSize: _fontSize,
            height: 1.9,
            fontWeight: FontWeight.bold,
          )));
    }
    return TextSpan(children: spans);
  }

  String formatArticlesCount(int count) {
    final bool isJudgments = widget.searchPath.contains('judgments');
    if (count <= 0) return isJudgments ? '0 قاعدة' : '0 مادة';
    if (count == 1) return isJudgments ? 'قاعدة واحدة' : 'مادة واحدة';
    if (count == 2) return isJudgments ? 'قاعدتين' : 'مادتين';
    if (count >= 3 && count <= 10)
      return isJudgments ? '$count قواعد' : '$count مواد';
    return isJudgments ? '$count قاعدة قضائية' : '$count مادة';
  }

  String formatWordsCount(int count) {
    if (count <= 0) return '0 كلمة';
    if (count == 1) return 'كلمة واحدة';
    if (count == 2) return 'كلمتين';
    if (count >= 3 && count <= 10) return '$count كلمات';
    return '$count كلمة';
  }

  // 🆕 دالة تنسيق عدد القوانين
  String formatLawsCount(int count) {
    final bool isJudgments = widget.searchPath.contains('judgments');
    if (count <= 0) return isJudgments ? '0 قسم' : '0 قانون';
    if (count == 1) return isJudgments ? 'قسم واحد' : 'قانون واحد';
    if (count == 2) return isJudgments ? 'قسمين' : 'قانونين';
    if (count >= 3 && count <= 10)
      return isJudgments ? '$count أقسام' : '$count قوانين';
    return isJudgments ? '$count قسم' : '$count قانون';
  }

  @override
  Widget build(BuildContext context) {
    // تحديد الألوان بناءً على ما إذا كان البحث شاملاً (all) أو فرعياً
    final bool isGlobal = widget.searchPath == 'all';
    final Color primaryDark =
        const Color(0xFF101D3D); // الكحلي من الشاشة الرئيسية
    final Color accentGold =
        const Color(0xFFC5A358); // الذهبي من الشاشة الرئيسية

    final Color effectiveThemeColor =
        isGlobal ? primaryDark : widget.themeColor;

    final Color bgColor = _isDark ? const Color(0xFF121212) : Colors.white;
    final Color textColor = _isDark ? Colors.white : Colors.black;
    final Color cardColor =
        _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);

    // 💡 حساب النتائج المعروضة بعد الفلترة
    final filteredResults = _results.where((item) {
      // للقواعد القضائية نستخدم filterGroup، وللبقية نستخدم law الأصلي
      if (widget.searchPath.contains('judgments')) {
        return _selectedLaws.contains(item['filterGroup']);
      }
      return _selectedLaws.contains(item['law']);
    }).toList();

    final displayedArticleCount = filteredResults.length;
    // 🆕 حساب عدد الأقسام/القوانين بشكل صحيح بناءً على نوع البحث
    final displayedLawCount = filteredResults
        .map((e) {
          if (widget.searchPath.contains('judgments')) {
            return e['filterGroup']; // يحسب (مدني، تجاري...) كمجموعة واحدة
          }
          return e['law']; // يحسب القوانين كملفات منفصلة كما هي
        })
        .toSet()
        .length;

    int displayedWordMatches = 0;
    final rawQuery = _controller.text.trim();
    final normalizedQuery = rawQuery.toLowerCase();

    // 💡 حساب عدد كلمات التطابق فقط في حالة البحث بالنص
    if (rawQuery.isNotEmpty && !_searchByNumber) {
      RegExp regExp = _exactMatch
          ? RegExp(r'(?<=\s|^)' + RegExp.escape(normalizedQuery) + r'(?=\s|$)')
          : RegExp(RegExp.escape(normalizedQuery));

      for (final item in filteredResults) {
        final text = (item['text'] ?? '').toString();
        final textLower = text.toLowerCase();
        displayedWordMatches += regExp.allMatches(textLower).length;
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          // ✅ تم إضافة التدرج اللوني الذي يستخدم اللون الممرر من الشاشة السابقة (widget.themeColor)
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [effectiveThemeColor, const Color(0xFF2A2E38)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          actions: [],
        ),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      readOnly: false,
                      onTap: () {
                        // استخدام المتغير الموحد بدلاً من الفحص المباشر
                        if (!isSubscribed) {
                          FocusScope.of(context).unfocus();
                          _showLimitedAccessDialog();
                        }
                      },
                      keyboardType: _searchByNumber
                          ? TextInputType.number
                          : TextInputType.text,
                      inputFormatters: _searchByNumber
                          ? [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9٠-٩]'))
                            ]
                          : [],
                      decoration: InputDecoration(
                        // ✅ التعديل البرمجي: استخدام النص الممرر من الأقسام (searchHint)
                        hintText: _searchByNumber
                            ? 'ابحث برقم المادة فقط'
                            : widget.searchHint,
                        hintStyle: TextStyle(
                          color: _isDark ? Colors.grey[600] : Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor:
                            _isDark ? Colors.grey[900] : Colors.grey[200],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 12),
                        // 🆕 زر مسح النص
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  _search('');
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_allFilteredLaws.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _showFilterDropdown(context),
                      icon: const Icon(Icons.filter_list),
                      label: const Text("فلترة النتائج"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isGlobal ? accentGold : Colors.blue[700],
                        foregroundColor: isGlobal ? primaryDark : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 🆕 شريط خيارات البحث بتصميم احترافي
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDark ? 0.3 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // خيار البحث بالرقم (يظهر فقط إذا لم نكن في قسم القواعد القضائية)
                        if (!widget.searchPath.contains('judgments')) ...[
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _searchByNumber = !_searchByNumber;
                                  _controller.clear();
                                  _search('');
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                  children: [
                                    Icon(Icons.search,
                                        size: 20,
                                        color: _searchByNumber
                                            ? effectiveThemeColor
                                            : Colors.grey),
                                    const SizedBox(height: 4),
                                    Text(
                                        _searchByNumber
                                            ? "بحث بالكلمة"
                                            : "بحث برقم المادة",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: _searchByNumber
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _searchByNumber
                                                ? effectiveThemeColor
                                                : textColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          VerticalDivider(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                              indent: 10,
                              endIndent: 10),
                        ],
                        // خيار التطابق التام
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _exactMatch = !_exactMatch;
                                _search(_controller.text);
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Icon(
                                      _exactMatch
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 20,
                                      color: _exactMatch
                                          ? Colors.green
                                          : Colors.grey),
                                  const SizedBox(height: 4),
                                  Text("تطابق",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: _exactMatch
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _exactMatch
                                              ? Colors.green
                                              : textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                            indent: 10,
                            endIndent: 10),
                        // خيار الوضع الليلي
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isDark = !_isDark),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Icon(
                                      _isDark
                                          ? Icons.light_mode
                                          : Icons.dark_mode,
                                      size: 20,
                                      color: Colors.orangeAccent),
                                  const SizedBox(height: 4),
                                  Text(_isDark ? "نهاري" : "ليلي",
                                      style: TextStyle(
                                          fontSize: 11, color: textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                            indent: 10,
                            endIndent: 10),
                        // خيار حجم الخط
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                builder: (ctx) {
                                  return StatefulBuilder(
                                    builder: (BuildContext context,
                                        StateSetter setState2) {
                                      return Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text("تغيير حجم الخط",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18)),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    onPressed: () {
                                                      _increaseFont();
                                                      setState2(() {});
                                                    },
                                                    icon: const Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                        size: 35,
                                                        color: Colors.blue),
                                                  ),
                                                  const SizedBox(width: 20),
                                                  Text(
                                                      _fontSize
                                                          .toInt()
                                                          .toString(),
                                                      style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  const SizedBox(width: 20),
                                                  IconButton(
                                                    onPressed: () {
                                                      _decreaseFont();
                                                      setState2(() {});
                                                    },
                                                    icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                        size: 35,
                                                        color: Colors.red),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                  "سيتم حفظ الحجم المختار تلقائياً",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                              const SizedBox(height: 10),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Icon(Icons.format_size,
                                      size: 20,
                                      color:
                                          isGlobal ? accentGold : Colors.blue),
                                  const SizedBox(height: 4),
                                  Text("الخط",
                                      style: TextStyle(
                                          fontSize: 11, color: textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ⭐️ التعديل 4: الإحصائية المخصصة
              if (displayedArticleCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _searchByNumber
                        // ⭐️ إحصائية البحث بالرقم
                        ? 'تم العثور على ${formatArticlesCount(displayedArticleCount)} في ${formatLawsCount(displayedLawCount)}'
                        // ⭐️ إحصائية البحث بالنص
                        : 'تم العثور على ${formatWordsCount(displayedWordMatches)} في ${formatArticlesCount(displayedArticleCount)} ضمن ${formatLawsCount(displayedLawCount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isGlobal ? accentGold : Colors.cyan,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: filteredResults.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.isEmpty
                              ? 'أكتب كلمة للبحث في الشريط أعلاه أولاً'
                              : 'لا توجد نتائج',
                          style: TextStyle(
                            fontSize: 18,
                            color: _controller.text.isEmpty
                                ? Colors.grey
                                : textColor,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredResults.length,
                        itemBuilder: (context, index) {
                          final item = filteredResults[index];
                          final text = item['text'] ?? '';
                          final law = item['law'] ?? '';
                          final articleNumber = item['article_number'] ?? '';
                          final query = _controller.text;
                          final isExpanded = _expanded[index] ?? false;

                          final words = text.split(RegExp(r'\s+'));
                          final bool isLongText = words.length > 60;
                          final displayText = isExpanded
                              ? text
                              : words.take(60).join(' ') +
                                  (isLongText ? '...' : '');

                          return AutoScrollTag(
                            key: ValueKey('$law-$articleNumber-$index'),
                            controller: _scrollController,
                            index: index,
                            child: Card(
                              color: cardColor,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: RichText(
                                            softWrap: true,
                                            text: TextSpan(
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: (_fontSize + 2)
                                                    .clamp(14.0, 30.0),
                                                color: isGlobal
                                                    ? accentGold
                                                    : Colors.blue[700],
                                                fontFamily:
                                                    'Roboto', // أو أي خط افتراضي لديك
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: item['subject'] != null
                                                      ? 'قاعدة ($articleNumber): ${item['subject']}'
                                                      : 'مادة ($articleNumber): $law',
                                                ),
                                                if (widget.searchPath
                                                    .contains('judgments')) ...[
                                                  const TextSpan(
                                                    text: ' (',
                                                    style: TextStyle(
                                                        color: Colors.red),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        law, // اسم القسم (جزائي، مدني..)
                                                    style: const TextStyle(
                                                        color: Colors.red),
                                                  ),
                                                  const TextSpan(
                                                    text: ')',
                                                    style: TextStyle(
                                                        color: Colors.red),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.copy,
                                              color: textColor, size: 22),
                                          tooltip: "نسخ النص",
                                          onPressed: () {
                                            if (!isSubscribed) {
                                              _showLimitedAccessDialog();
                                            } else {
                                              final fullText =
                                                  "$law - مادة ($articleNumber):\n$text";
                                              Clipboard.setData(ClipboardData(
                                                  text: fullText));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "✅ تم نسخ النص إلى الحافظة")),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText.rich(
                                      _highlightSearchText(displayText, query),
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.justify,
                                    ),
                                    if (isLongText)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          child: Text(
                                            isExpanded
                                                ? 'عرض أقل'
                                                : 'عرض المزيد',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _expanded[index] = !isExpanded;
                                            });
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCleanCategoryName(String rawName) {
    if (rawName.contains('الدستورية')) return 'القواعد القضائية الدستورية';
    if (rawName.contains('الإدارية')) return 'القواعد القضائية الإدارية';
    if (rawName.contains('الشخصية')) return 'القواعد القضائية الشخصية';
    if (rawName.contains('التجارية')) return 'القواعد القضائية التجارية';
    if (rawName.contains('المدنية')) return 'القواعد القضائية المدنية';
    if (rawName.contains('الجزائية')) return 'القواعد القضائية الجزائية';
    return rawName; // في حال لم يطابق شيء يعود بالاسم الأصلي
  }
}
