import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../services/favorites_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laws_yemen/services/free_trial_manager.dart';
import 'activation_screen.dart';

class LawArticlesScreen extends StatefulWidget {
  final String lawFileName;
  final String lawName;
  final String basePath;
  final String? initialArticleId;
  final Color themeColor;

  const LawArticlesScreen({
    super.key,
    required this.lawFileName,
    required this.lawName,
    required this.basePath,
    this.initialArticleId,
    this.themeColor = const Color(
        0xFF457C96), // سيبقى هكذا ليعمل مع القوانين القديمة باللون الأزرق
  });

  @override
  State<LawArticlesScreen> createState() => _LawArticlesScreenState();
}

class _LawArticlesScreenState extends State<LawArticlesScreen> {
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _displayedItems = [];
  Map<String, bool> _expandedArticles = {};

  Set<String> _favorites = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool isSubscribed = false;
  Timer? _debounce;
  bool _searchByNumber =
      false; // تم حذف التكرار/ ✅ المتغير الجديد للتحكم في صلاحية البحث
  bool _exactMatch = false;
  int? _resultsCount;
  int? _wordMatchesCount;

  bool _showFavoritesOnly = false;
  bool _isDark = false;

  static const String _kFontKey = 'global_font_size';
  double _fontSize = 18.0;

  late AutoScrollController _scrollController;

  FavoritesSyncService? favoritesSyncService;
  String userEmail = "";

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController();
    _checkAccess(); // ✅ استدعاء دالة فحص الصلاحيات
    _initFavoritesSystem();
    _searchController.addListener(_onSearchChanged);
  }

  // ✅ دالة فحص الصلاحيات وتحديث حالة المتغير isSubscribed
  Future<void> _checkAccess() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. فحص هل المستخدم مشترك فعلياً (تفعيل مدفوع)
    final bool isPaid = prefs.getBool('isActivated') ?? false;

    // 2. فحص هل التجربة المجانية لا تزال سارية (باستخدام المديول الجديد)
    final bool isTrialValid = await FreeTrialManager.isTrialActive();

    if (mounted) {
      setState(() {
        // نمنحه الصلاحيات الكاملة إذا كان مشتركاً أو في فترة التجربة
        isSubscribed = isPaid || isTrialValid;
      });
    }
  }

  Future<void> _initFavoritesSystem() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail') ?? "";

    if (userEmail.isNotEmpty) {
      favoritesSyncService = FavoritesSyncService(
        userEmail: userEmail,
        firestore: FirebaseFirestore.instance,
        prefs: prefs, // 🔑 التعديل المطلوب: تمرير نسخة SharedPreferences
      );
      favoritesSyncService!.addListener(_onFavoritesChangedListener);
    }
    await _loadAppState();

    if (_favorites.isEmpty && favoritesSyncService != null) {
      await favoritesSyncService!.restoreFavoritesFromFirebase();
      await _loadFavorites();
      _applyFilter(fromToggleFav: true);
    }
  }

  // مزامنة المواد المفضلة لحظيًا عند أي تغيير من الخدمة (مزامنة لحظية)
  void _onFavoritesChangedListener() async {
    await _loadFavorites();
    if (mounted) {
      _applyFilter(fromToggleFav: true);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    favoritesSyncService?.removeListener(_onFavoritesChangedListener);
    favoritesSyncService?.dispose();
    super.dispose();
  }

  Future<void> _loadAppState() async {
    await _loadFontSize();
    await _loadItems();
    await _loadFavorites();
    _filterAndScroll();
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
    if (mounted) {
      setState(() {
        _fontSize = (_fontSize + 1).clamp(12.0, 32.0);
      });
      _saveFontSize(_fontSize);
    }
  }

  void _decreaseFont() {
    if (mounted) {
      setState(() {
        _fontSize = (_fontSize - 1).clamp(12.0, 32.0);
      });
      _saveFontSize(_fontSize);
    }
  }

  Future<void> _loadItems() async {
    try {
      final String jsonString = await rootBundle
          .loadString('${widget.basePath}${widget.lawFileName}');
      final List<dynamic> jsonData = json.decode(jsonString);

      final List<Map<String, dynamic>> processedItems = [];

      final RegExp starExp = RegExp(r'\*\*\*(.*?)\*\*\*');
      final RegExp slashExp = RegExp(r'\/\/\/(.*?)\/\/\/');
      int itemCounter = 0;

      for (var item in jsonData) {
        // --- 🟢 بداية التعديل الجديد 🟢 ---
        // التحقق من نوع البطاقة إذا كانت مقدمة أو خاتمة لإضافتها مباشرة دون تقطيع
        if (item['type'] == 'preamble' || item['type'] == 'conclusion') {
          processedItems.add(Map<String, dynamic>.from(item));
          continue; // تخطي بقية العمليات لهذه البطاقة والانتقال للعنصر التالي
        }
        // --- 🔴 نهاية التعديل الجديد 🔴 ---

        final String? dynamicText = item['text'] ?? item['title'];

        if (dynamicText != null) {
          final allMatches = [
            ...starExp.allMatches(dynamicText),
            ...slashExp.allMatches(dynamicText),
          ].toList()
            ..sort((a, b) => a.start.compareTo(b.start));

          if (allMatches.isEmpty) {
            processedItems.add(Map<String, dynamic>.from(item));
            continue;
          }

          int lastMatchEnd = 0;
          for (final match in allMatches) {
            if (match.start > lastMatchEnd) {
              final remainingText =
                  dynamicText.substring(lastMatchEnd, match.start).trim();
              if (remainingText.isNotEmpty) {
                final newItem = Map<String, dynamic>.from(item);
                if (item['type'] == 'article') {
                  newItem['text'] = remainingText;
                } else if (item['type'] == 'section') {
                  newItem['title'] = remainingText;
                }
                processedItems.add(newItem);
              }
            }

            final matchedText = match.group(1)!.trim();
            final matchedDelimiter =
                dynamicText.substring(match.start, match.end);
            itemCounter++;

            if (matchedDelimiter.contains('***')) {
              processedItems.add({
                'type': 'side_heading',
                'title': matchedText,
                'id': '${item['num']}_side_${itemCounter}',
              });
            } else if (matchedDelimiter.contains('///')) {
              processedItems.add({
                'type': 'sub_section',
                'title': matchedText,
                'id': '${item['num']}_sub_${itemCounter}',
              });
            }
            lastMatchEnd = match.end;
          }
          if (lastMatchEnd < dynamicText.length) {
            final remainingText = dynamicText.substring(lastMatchEnd).trim();
            if (remainingText.isNotEmpty) {
              final newItem = Map<String, dynamic>.from(item);
              if (item['type'] == 'article') {
                newItem['text'] = remainingText;
              } else if (item['type'] == 'section') {
                newItem['title'] = remainingText;
              }
              processedItems.add(newItem);
            }
          }
        } else {
          processedItems.add(Map<String, dynamic>.from(item));
        }
      }

      _allItems = processedItems
          .where((item) =>
              item['type'] != 'article' ||
              (item['text'] as String).trim().isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _displayedItems = List.from(_allItems);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل القانون: $e')),
        );
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(
            FavoritesSyncService.articlesKey(widget.lawFileName)) ??
        [];
    _favorites = saved.toSet();
  }

  Future<void> _toggleFavorite(String articleNum) async {
    if (favoritesSyncService != null) {
      if (_favorites.contains(articleNum)) {
        final confirmed = await _showConfirmationDialog();
        if (confirmed) {
          await favoritesSyncService!
              .removeFavoriteArticle(context, widget.lawFileName, articleNum);
        }
      } else {
        await favoritesSyncService!
            .addFavoriteArticle(context, widget.lawFileName, articleNum);
      }
      // لا حاجة لاستدعاء _loadFavorites أو _applyFilter هنا، سيتم التحديث عبر المستمع
    } else {
      // fallback محلي فقط
      final prefs = await SharedPreferences.getInstance();
      final isFav = _favorites.contains(articleNum);

      if (isFav) {
        final confirmed = await _showConfirmationDialog();
        if (confirmed && mounted) {
          setState(() {
            _favorites.remove(articleNum);
            _applyFilter(fromToggleFav: true);
          });
          await prefs.setStringList(
              FavoritesSyncService.articlesKey(widget.lawFileName),
              _favorites.toList());
        }
      } else {
        if (mounted) {
          setState(() {
            _favorites.add(articleNum);
            _applyFilter(fromToggleFav: true);
          });
          await prefs.setStringList(
              FavoritesSyncService.articlesKey(widget.lawFileName),
              _favorites.toList());
        }
      }
    }
  }

  String formatArticlesCount(int count) {
    bool isTaamim = widget.lawFileName == 'تعاميم النائب العام.json';
    if (count <= 0) return isTaamim ? '0 تعميم' : '0 مادة';
    if (count == 1) return isTaamim ? 'تعميم واحد' : 'مادة واحدة';
    if (count == 2) return isTaamim ? 'تعميمين' : 'مادتين';
    if (count >= 3 && count <= 10)
      return isTaamim ? '$count تعاميم' : '$count مواد';
    return isTaamim ? '$count تعميم' : '$count مادة';
  }

  String formatWordsCount(int count) {
    if (count <= 0) return '0 كلمة';
    if (count == 1) return 'كلمة واحدة';
    if (count == 2) return 'كلمتين';
    if (count >= 3 && count <= 10) return '$count كلمات';
    return '$count كلمة';
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تأكيد الإزالة'),
                content: const Text(
                    'هل أنت متأكد أنك تريد إزالة هذه المادة من المفضلة؟'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('إلغاء'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: const Text('إزالة'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  static final RegExp _arabicDiacritics =
      RegExp(r'[\u064B-\u0652\u0670\u0640]');
  String _normalizeArabic(String input) {
    String s = input;
    s = s.replaceAll(_arabicDiacritics, '');
    s = s.replaceAll(RegExp('[إأآا]'), 'ا');
    s = s.replaceAll(RegExp('[ىي]'), 'ي');
    s = s.replaceAll('ة', 'ه');
    return s;
  }

  String _normalizeNumbers(String input) {
    const arabicNums = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String output = input;
    for (int i = 0; i < arabicNums.length; i++) {
      output = output.replaceAll(arabicNums[i], i.toString());
    }
    return output;
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyFilter);
  }

  void _applyFilter({bool fromToggleFav = false}) {
    final rawQuery = _searchController.text.trim();
    final normalizedQueryNum = _normalizeNumbers(rawQuery);
    final normalizedQueryText =
        _normalizeArabic(normalizedQueryNum).toLowerCase();

    final filteredList = _allItems.where((item) {
      if (_showFavoritesOnly) {
        // إذا كان هذا العنصر تعميماً (article) وهو في المفضلة، نظهره
        if (item['type'] == 'article' &&
            _favorites.contains(item['num']?.toString())) {
          return true;
        }

        // 🟢 إضافة خاصة لتعاميم النائب العام لإظهار العناوين في المفضلة
        if (widget.lawFileName == 'تعاميم النائب العام.json') {
          if (item['type'] == 'side_heading' ||
              item['type'] == 'section' ||
              item['type'] == 'sub_section') {
            // نتحقق من العنصر التالي: هل هو تعميم موجود في المفضلة؟
            int currentIndex = _allItems.indexOf(item);
            if (currentIndex != -1 && currentIndex < _allItems.length - 1) {
              var nextItem = _allItems[currentIndex + 1];
              if (nextItem['type'] == 'article' &&
                  _favorites.contains(nextItem['num']?.toString())) {
                return true; // أظهر العنوان لأنه يتبع لتعميم مفضل
              }
            }
          }
        }
        return false;
      }

      if (rawQuery.isEmpty) {
        return true;
      }

      if (item['type'] == 'section' ||
          item['type'] == 'side_heading' ||
          item['type'] == 'sub_section') {
        return false;
      }

      final articleNumber = item['num'].toString();
      final articleText = (item['text'] ?? '').toString();

      if (_searchByNumber) {
        final normalizedArticleNum = _normalizeNumbers(articleNumber);
        return normalizedArticleNum == normalizedQueryNum;
      } else {
        final normalizedArticleText =
            _normalizeArabic(articleText).toLowerCase();

        if (_exactMatch) {
          final pattern = RegExp(
            r'(?<=\s|^)' + RegExp.escape(normalizedQueryText) + r'(?=\s|$)',
          );
          return pattern.hasMatch(normalizedArticleText);
        } else {
          return normalizedArticleText.contains(normalizedQueryText);
        }
      }
    }).toList();

    if (mounted) {
      setState(() {
        _displayedItems = filteredList;

        if (rawQuery.isNotEmpty) {
          if (_searchByNumber) {
            _resultsCount = null;
            _wordMatchesCount = null;
          } else {
            _resultsCount = _displayedItems.length;

            int totalMatches = 0;
            for (final item in _displayedItems) {
              if (item['type'] == 'article') {
                final articleText = (item['text'] ?? '').toString();
                final normalizedText =
                    _normalizeArabic(articleText).toLowerCase();
                final pattern = _exactMatch
                    ? RegExp(
                        r'(?<=\s|^)' +
                            RegExp.escape(normalizedQueryText) +
                            r'(?=\s|$)',
                      )
                    : RegExp(RegExp.escape(normalizedQueryText));
                final matches = pattern.allMatches(normalizedText).length;
                totalMatches += matches;
              }
            }
            _wordMatchesCount = totalMatches;
          }
        } else {
          _resultsCount = null;
          _wordMatchesCount = null;
        }
      });
    }
  }

  void _filterAndScroll() {
    _applyFilter();
    if (widget.initialArticleId != null && _allItems.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final itemToScroll = _allItems.firstWhere(
          (m) =>
              m['type'] == 'article' &&
              m['num'].toString() == widget.initialArticleId.toString(),
          orElse: () => <String, dynamic>{},
        );

        if (itemToScroll.isNotEmpty) {
          final idx = _displayedItems.indexOf(itemToScroll);
          if (idx != -1) _scrollToIndex(idx);
        }
      });
    }
  }

  String composeSectionLabel(String level, String title) {
    final lvl = (level).trim();
    String ttl = (title).trim();
    if (ttl.startsWith(lvl)) return ttl;
    return '$lvl $ttl'.trim();
  }

  String formatSectionTitle(String title) {
    // الكلمات المستهدفة بالتمييز والمد
    final keywords = ["الكتاب", "الباب", "الفصل", "القسم", "الجزء", "الفرع"];

    // دالة داخلية لإضافة المد (التطويل) بمقدار 3 درجات
    String addKashida(String word) {
      if (word.length < 2) return word;
      // إضافة المد بعد الحرف الثاني (مثال: الفصـــل)
      return word.substring(0, 2) + "ـــ" + word.substring(2);
    }

    String t = title.trim();
    // تطبيق المد على الكلمات المفتاحية أولاً داخل النص
    for (var word in keywords) {
      if (t.contains(word)) {
        t = t.replaceAll(word, addKashida(word));
      }
    }

    // إنشاء نمط البحث ليشمل الكلمات بعد تمطيطها
    final String pattern =
        keywords.map((w) => RegExp.escape(addKashida(w))).join('|');
    final RegExp regExp = RegExp('($pattern)\\s+[^\\s]+');

    // تقسيم النص إلى أسطر (وضع سطر جديد حول الكلمات المميزة)
    t = t.replaceAllMapped(regExp, (match) {
      return "\n${match.group(0)}\n";
    });

    return t
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  void _showFontSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "تغيير حجم الخط",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: "تكبير",
                          onPressed: () {
                            _increaseFont();
                            setState(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _fontSize.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          tooltip: "تصغير",
                          onPressed: () {
                            _decreaseFont();
                            setState(() {});
                          },
                          icon:
                              const Icon(Icons.remove_circle_outline, size: 30),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "التغيير يُطبق فوراً على كل القوانين ويتم حفظه تلقائياً",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openTOC() {
    // 1. تصفية العناوين (المواضيع/البواب/الفصول)
    final toc = _allItems
        .where((item) =>
            item['type'] == 'section' ||
            item['type'] == 'side_heading' ||
            item['type'] == 'sub_section')
        .toList();

    // 2. تصفية المواد فقط للتبويب الجديد
    final articlesOnly =
        _allItems.where((item) => item['type'] == 'article').toList();

    if (toc.isEmpty && articlesOnly.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عناوين فهرس في هذا القانون')),
      );
      return;
    }

    final ScrollController tocScrollController = ScrollController();
    final TextEditingController tocSearchController = TextEditingController();

    List<Map<String, dynamic>> filteredToc = List.from(toc);
    List<Map<String, dynamic>> filteredArticles = List.from(articlesOnly);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: DefaultTabController(
                length:
                    widget.lawFileName == 'تعاميم النائب العام.json' ? 1 : 2,
                child: SafeArea(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.85,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: tocSearchController,
                                style: TextStyle(
                                    color:
                                        _isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: widget.lawFileName ==
                                          'تعاميم النائب العام.json'
                                      ? 'ابحث في الفهرس...'
                                      : 'ابحث في الفهرس أو رقم المادة...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: _isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (value) {
                                  setModalState(() {
                                    filteredToc = toc
                                        .where((item) =>
                                            (item['title'] as String)
                                                .contains(value))
                                        .toList();
                                    filteredArticles = articlesOnly
                                        .where((item) =>
                                            (item['num'].toString())
                                                .contains(value))
                                        .toList();
                                  });
                                },
                              ),
                            ),
                            TabBar(
                              labelColor: Colors.blueAccent,
                              unselectedLabelColor:
                                  _isDark ? Colors.grey : Colors.black54,
                              indicatorColor: Colors.blueAccent,
                              tabs: [
                                Tab(
                                    text: widget.lawFileName ==
                                            'تعاميم النائب العام.json'
                                        ? "الفهرس الموضوعي"
                                        : "المواضيع والفصول"),
                                if (widget.lawFileName !=
                                    'تعاميم النائب العام.json')
                                  const Tab(text: "أرقام المواد"),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  // التبويب الأول
                                  ListView.builder(
                                    controller: tocScrollController,
                                    itemCount: filteredToc.length,
                                    itemBuilder: (context, i) {
                                      final item = filteredToc[i];
                                      final String title =
                                          item['title'] as String? ?? '';
                                      final display = formatSectionTitle(title);

                                      TextStyle style = TextStyle(
                                        fontSize: 14,
                                        color: _isDark
                                            ? Colors.white
                                            : Colors.black,
                                      );
                                      double indent = 0;

                                      if (RegExp(r'الكتاب\s').hasMatch(title)) {
                                        style = const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF003366));
                                      } else if (RegExp(r'الباب\s')
                                          .hasMatch(title)) {
                                        style = const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF006400));
                                      } else if (RegExp(r'الفصل\s')
                                          .hasMatch(title)) {
                                        style = const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF8B0000));
                                      } else if (RegExp(
                                              r'(القسم|الفرع|الجزء)\s')
                                          .hasMatch(title)) {
                                        style = TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: _isDark
                                                ? Colors.grey
                                                : const Color(0xFF555555));
                                        indent = 40;
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Card(
                                          elevation: 2,
                                          color: _isDark
                                              ? const Color(0xFF2C2C2C)
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            side: BorderSide(
                                                color: _isDark
                                                    ? Colors.grey.shade800
                                                    : const Color(0xFFB0B0B0),
                                                width: 1),
                                          ),
                                          child: ListTile(
                                            contentPadding: EdgeInsets.only(
                                                right: 16 + indent,
                                                left: 16,
                                                top: 10,
                                                bottom: 10),
                                            leading: const Icon(
                                                Icons.bookmark_border,
                                                color: Colors.blueAccent,
                                                size: 22),
                                            title: Text(display,
                                                textAlign: TextAlign.right,
                                                style: style),
                                            onTap: () => _handleSelection(item),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // التبويب الثاني
                                  if (widget.lawFileName !=
                                      'تعاميم النائب العام.json')
                                    GridView.builder(
                                      padding: const EdgeInsets.all(15),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 2.2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                      itemCount: filteredArticles.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredArticles[index];
                                        return InkWell(
                                          onTap: () => _handleSelection(item),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _isDark
                                                  ? Colors.blueGrey.shade900
                                                  : Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: Colors.blueAccent
                                                      .withOpacity(0.3)),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              "المادة (${item['num']})",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: _isDark
                                                    ? Colors.white
                                                    : Colors.blue.shade900,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: FloatingActionButton(
                            onPressed: () {
                              tocScrollController.animateTo(0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut);
                            },
                            backgroundColor: Colors.blueAccent,
                            mini: true,
                            child: const Icon(Icons.arrow_upward),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // هذه الدالة المساعدة لضمان عمل الانتقال بشكل صحيح وحل الخطأ الذي ظهر لك
  void _handleSelection(Map<String, dynamic> item) async {
    // ✅ التعديل: الاعتماد على المتغير الشامل isSubscribed واستدعاء التنبيه الموحد
    if (!isSubscribed) {
      if (mounted) {
        _showLimitedAccessDialog();
      }
      return; // توقف هنا ولا تكمل عملية الانتقال
    }

    // المنطق الأصلي للانتقال (يعمل فقط للنسخة الكاملة)
    if (mounted) Navigator.pop(context);
    if (mounted) {
      setState(() {
        _showFavoritesOnly = false;
        _searchController.clear();
        _applyFilter();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final idx = _displayedItems.indexWhere((element) {
        if (item['type'] == 'article') {
          return element['type'] == 'article' && element['num'] == item['num'];
        } else {
          return element['type'] == item['type'] &&
              element['title'] == item['title'];
        }
      });

      if (idx != -1) {
        _scrollToIndex(idx);
      }
    });
  }

  // تأكد من وجود هذه الدالة داخل الـ State لحل خطأ Error: The method '_scrollToIndex' isn't defined
  Future<void> _scrollToIndex(int index) async {
    if (_displayedItems.isNotEmpty &&
        index >= 0 &&
        index < _displayedItems.length) {
      await _scrollController.scrollToIndex(
        index,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

// 🔹 دالة الزر الجانبي (كما كانت سابقًا)
  Widget _drawerPill({
    required String text,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 1),
            borderRadius: BorderRadius.circular(26),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (favoritesSyncService == null) {
      // 💡 إذا لم يتم تهيئة الخدمة بعد، انتظر (يجب أن يتم تهيئتها سريعاً)
      return const Center(child: CircularProgressIndicator());
    }

    // 💡 تم تحسين تحديد الألوان للحالة المظلمة/النهارية
    // final Brightness brightness = Theme.of(context).brightness; // تم التعليق عليه: هذا السطر كان يلغي التبديل المحلي
    // _isDark = brightness == Brightness.dark; // تم التعليق عليه: هذا السطر كان يلغي التبديل المحلي

    final Color bgColor = _isDark ? const Color(0xFF121212) : Colors.white;
    final Color textColor = _isDark ? Colors.white : Colors.black;
    final Color cardColor = _isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color inputFill =
        _isDark ? Colors.grey.shade900 : (Colors.grey[200] ?? Colors.grey);

    return ListenableBuilder(
      // 1️⃣ تم التعديل: استخدام ListenableBuilder للاستماع
      listenable: favoritesSyncService!,
      builder: (context, child) {
        return WillPopScope(
          onWillPop: () async {
            if (_showFavoritesOnly) {
              if (mounted) {
                setState(() {
                  _showFavoritesOnly = false;
                  _applyFilter();
                });
              }
              return false;
            }
            return true;
          },
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                title: AutoSizeText(
                  _showFavoritesOnly
                      ? (widget.lawFileName == 'تعاميم النائب العام.json'
                          ? 'تعاميم النائب العام المفضلة'
                          : 'المواد المفضلة لـ ${widget.lawName}')
                      : (() {
                          String name = widget.lawName;
                          if (widget.basePath.contains('assets/laws')) {
                            final regExp =
                                RegExp(r'بشأ?ن\s+(.*)', caseSensitive: false);
                            final match = regExp.firstMatch(name);
                            if (match != null && match.group(1) != null) {
                              return 'قانون ${match.group(1)!.trim()}';
                            }
                          }
                          return name;
                        })(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  minFontSize: 16,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _showFavoritesOnly
                        ? Colors.black87
                        : (_isDark
                            ? Colors.white
                            : (widget.basePath.contains('prosecutions')
                                ? Colors.amber.shade200
                                : Colors.black)),
                  ),
                ),
                centerTitle: true,
                iconTheme: IconThemeData(
                  color: _showFavoritesOnly
                      ? Colors.black87
                      : (_isDark
                          ? Colors.white
                          : (widget.basePath.contains('prosecutions')
                              ? Colors.amber.shade200
                              : Colors.black)),
                ),
                // 💡 تم تعديل لون الـ AppBar ليتناسب مع _isDark
                backgroundColor: _showFavoritesOnly
                    ? const Color(0xFFFFF9C4)
                    : (_isDark
                        ? Colors.grey.shade900
                        : widget
                            .themeColor), // ✅ تم استبدال Colors.blue بـ widget.themeColor
                actions: [
                  if (!_showFavoritesOnly) ...[
                    IconButton(
                      tooltip: _isDark ? "الوضع النهاري" : "الوضع الليلي",
                      icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode,
                          color: _isDark
                              ? Colors.amber
                              : (widget.basePath.contains('prosecutions')
                                  ? Colors.amber.shade200
                                  : Colors.black)),
                      onPressed: () {
                        setState(() => _isDark = !_isDark);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.text_fields,
                          color: _isDark
                              ? Colors.white
                              : (widget.basePath.contains('prosecutions')
                                  ? Colors.amber.shade200
                                  : Colors.black)),
                      tooltip: "تغيير حجم الخط",
                      onPressed: _showFontSheet,
                    ),
                  ]
                ],
              ),
              drawer: Drawer(
                child: Column(
                  children: [
                    Container(
                      height: 130,
                      width: double.infinity,
                      padding:
                          const EdgeInsetsDirectional.only(start: 16, end: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade200,
                            Colors.amber.shade400
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book,
                                size: 42, color: Colors.brown.shade800),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.lawName,
                                overflow: TextOverflow.visible,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          _drawerPill(
                            text: widget.lawFileName ==
                                    'تعاميم النائب العام.json'
                                ? "تعاميم النائب العام المفضلة"
                                : "الـــمواد المفضـــلة لــــ ${widget.lawName}",
                            icon: Icons.star,
                            iconColor: Colors.amber,
                            onTap: () {
                              // ✅ التعديل: السماح لصاحب التجربة السارية بمشاهدة مفضلته
                              if (!isSubscribed) {
                                if (mounted) {
                                  // إغلاق القائمة الجانبية أولاً ثم إظهار التنبيه الموحد
                                  Navigator.pop(context);
                                  _showLimitedAccessDialog();
                                }
                              } else {
                                // المنطق الأصلي للمشتركين
                                if (mounted) {
                                  setState(() {
                                    _showFavoritesOnly = true;
                                    _applyFilter();
                                  });
                                }
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    if (!_showFavoritesOnly)
                      _buildSearchBar(
                          inputFill, textColor, cardColor), // ✅ التعديل هنا
                    const SizedBox(height: 8),
                    if (_resultsCount != null && _resultsCount! > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'تم العثور على ${formatWordsCount(_wordMatchesCount ?? 0)} في ${formatArticlesCount(_resultsCount ?? 0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _displayedItems.isEmpty
                        ? Expanded(
                            child: Center(
                              child: Text(
                                _searchController.text.isNotEmpty
                                    ? 'لا توجد نتائج بحث'
                                    : 'لا توجد مواد قانونية لعرضها',
                                style:
                                    TextStyle(fontSize: 18, color: textColor),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : Expanded(
                            child: RawScrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              trackVisibility: false,
                              thickness: 10.0,
                              radius: const Radius.circular(20),
                              interactive: true,
                              minThumbLength: 60,
                              thumbColor:
                                  (widget.basePath.contains('prosecutions')
                                          ? Colors.amber.shade400
                                          : widget.themeColor)
                                      .withOpacity(0.8),
                              pressDuration: Duration.zero,
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _displayedItems.length,
                                itemBuilder: (context, index) {
                                  final item = _displayedItems[index];
                                  // --- 🟢 التعديل النهائي هنا 🟢 ---
                                  if (item['type'] == 'preamble' ||
                                      item['type'] == 'conclusion') {
                                    return _buildIntroOutroCard(item, index);
                                  } else if (item['type'] == 'section') {
                                    return _buildSectionCard(item, index);
                                  } else if (item['type'] == 'side_heading' ||
                                      item['type'] == 'sub_section') {
                                    return _buildSubSectionCard(item, index);
                                  } else {
                                    return _buildArticleCard(
                                        item, index, cardColor, textColor);
                                  }
// -----------------------------
                                },
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  // 💡 الدوال المساعدة أصبحت الآن جزءًا من فئة الـ State

  Widget _buildSearchBar(Color inputFill, Color textColor, Color cardColor) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textAlign: TextAlign.justify,
          style: TextStyle(color: textColor),
          // السماح بالكتابة فقط إذا كان مشتركاً، وإلا يكون للقراءة فقط ليظهر التنبيه عند الضغط
          readOnly: !isSubscribed,
          onTap: () {
            if (!isSubscribed) {
              _showLimitedAccessDialog();
            } else {
              _searchFocusNode.requestFocus();
            }
          },
          keyboardType:
              _searchByNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFill,
            hintText: _searchByNumber
                ? 'ابحث برقم المادة...'
                : 'ابحث داخل نصوص المواد...',
            hintStyle: TextStyle(color: textColor.withOpacity(0.7)),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _applyFilter();
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _openTOC,
                icon: Icon(Icons.list_alt, size: 20, color: widget.themeColor),
                label:
                    Text('الفهرس', style: TextStyle(color: widget.themeColor)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (widget.lawFileName != 'تعاميم النائب العام.json')
                Row(
                  children: [
                    Text("بحث بالرقم",
                        style: TextStyle(color: textColor, fontSize: 13)),
                    const SizedBox(width: 6),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _searchByNumber,
                        onChanged: (val) {
                          if (mounted) {
                            setState(() {
                              _searchByNumber = val;
                              _searchController.clear();
                              _applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              Row(
                children: [
                  Text("تطابق تام",
                      style: TextStyle(color: textColor, fontSize: 13)),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: _exactMatch,
                      onChanged: (val) {
                        if (mounted) {
                          setState(() {
                            _exactMatch = val ?? false;
                            _applyFilter();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // دالة إظهار تنبيه الوصول المحدود (أضفها إذا لم تكن موجودة)
  void _showLimitedAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('عــــذراً',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'هذه الميزة متاحة لمشتركي النسخة المدفوعة فقط. قم بترقية حسابك الآن للوصول إلى جميع المزايا المتقدمة',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              // الانتقال لشاشة التفعيل
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ActivationScreen()));
            },
            child: const Text('تفعيل الاشتراك',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> item, int index) {
    final label = composeSectionLabel(item['level'] ?? '', item['title'] ?? '');
    final display = formatSectionTitle(label);

    // الكلمات المفتاحية بعد إضافة المد (تطابق ما تفعله دالة formatSectionTitle)
    final List<String> targetKeys = [
      "الكتــاب",
      "البـــاب",
      "الفصـــل",
      "القســـم",
      "الجزـــء",
      "الفرـــع"
    ];

    List<TextSpan> spans = [];
    // تقسيم النص إلى أسطر بناءً على السطر الجديد \n
    final lines = display.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String currentLine = lines[i];
      bool isKeywordLine = false;

      // فحص إذا كان السطر الحالي يبدأ بإحدى الكلمات الممدودة
      for (var key in targetKeys) {
        if (currentLine.trim().startsWith(key)) {
          isKeywordLine = true;
          break;
        }
      }

      if (isKeywordLine) {
        // تطبيق التنسيق الخاص (حجم أكبر + بولد + خط سفلي)
        spans.add(TextSpan(
          text: currentLine + (i == lines.length - 1 ? "" : "\n"),
          style: TextStyle(
            fontSize:
                (_fontSize.clamp(12.0, 32.0) + 2), // زيادة الحجم درجتين للبروز
            fontWeight: FontWeight.w900, // أقصى درجات الغمق (Bold)
            decoration: TextDecoration.underline, // وضع خط أسفل الكلمة
            color: Colors.white,
            height: 2.0,
          ),
        ));
      } else {
        // تنسيق بقية نص العنوان بشكل طبيعي
        spans.add(TextSpan(
          text: currentLine + (i == lines.length - 1 ? "" : "\n"),
          style: TextStyle(
            fontSize: _fontSize.clamp(12.0, 32.0),
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.6,
          ),
        ));
      }
    }

    return AutoScrollTag(
      key: ValueKey(item['title'] + item['level']),
      controller: _scrollController,
      index: index,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _isDark ? Colors.grey.shade900 : Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: _isDark
              ? Border.all(color: Colors.grey.shade800, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: spans),
          ),
        ),
      ),
    );
  }

  Widget _buildSubSectionCard(Map<String, dynamic> item, int index) {
    final bool isSideHeading = item['type'] == 'side_heading';
    final String title = item['title'] as String;

    return AutoScrollTag(
      key: ValueKey(item['id']),
      controller: _scrollController,
      index: index,
      child: isSideHeading
          ? Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color:
                        _isDark ? Colors.grey.shade700 : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
            )
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: _fontSize.clamp(14.0, 26.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildArticleCard(
      Map<String, dynamic> item, int index, Color cardColor, Color textColor) {
    final articleNumber = item['num'].toString();
    final String articleTextRaw =
        (item['text'] ?? '').toString().replaceFirst(RegExp(r'^[:：]\s*'), '');

    final isFav = _favorites.contains(articleNumber);
    final searchInput = _searchController.text;

    final List<String> words = articleTextRaw.split(RegExp(r'\s+'));
    final bool isLongText = words.length > 60;
    final bool isExpanded = _expandedArticles[articleNumber] ?? false;

    String displayedText;
    if (isLongText && !isExpanded) {
      // نأخذ أول 60 كلمة ونربطها بمسافات ثم نضيف نقاط الاختصار
      // سيقوم التنسيق التلقائي لاحقاً بكسر الأسطر عند الأرقام وعلامات الترقيم
      displayedText = words.take(60).join(' ') + '...';
    } else {
      displayedText = articleTextRaw;
    }

    return AutoScrollTag(
      key: ValueKey(item['num']),
      controller: _scrollController,
      index: index,
      child: Card(
        color: cardColor,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment:
                    widget.lawFileName == 'تعاميم النائب العام.json'
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.lawFileName != 'تعاميم النائب العام.json')
                    Text(
                      "المادة ($articleNumber)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: (_fontSize + 2).clamp(14.0, 34.0),
                        color: _isDark
                            ? Colors.white
                            : widget
                                .themeColor, // ✅ يظهر بلون القسم في الوضع النهاري
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, color: textColor),
                        tooltip: "نسخ النص",
                        onPressed: () {
                          // ✅ تم التعديل للاعتماد على المتغير الشامل isSubscribed واستدعاء التنبيه الموحد
                          if (!isSubscribed) {
                            if (mounted) {
                              _showLimitedAccessDialog();
                            }
                          } else {
                            // المنطق الأصلي للنسخ إذا لم يكن في الوضع المحدود
                            final fullText =
                                "المادة ($articleNumber):\n$articleTextRaw";
                            Clipboard.setData(ClipboardData(text: fullText));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("✅ تم نسخ النص إلى الحافظة")),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _showFavoritesOnly ? Icons.delete : Icons.favorite,
                          color: _showFavoritesOnly
                              ? Colors.red
                              : (isFav ? Colors.amber : Colors.grey),
                        ),
                        onPressed: () {
                          if (!isSubscribed) {
                            _showLimitedAccessDialog();
                          } else {
                            _toggleFavorite(articleNumber);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildArticleRichText(displayedText, searchInput),
              if (isLongText)
                InkWell(
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _expandedArticles[articleNumber] = !isExpanded;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      isExpanded ? 'عرض أقل' : 'عرض المزيد',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _highlightSearch(String text, String query, TextStyle style,
      {bool exactMatch = false}) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final normQuery = _normalizeArabic(_normalizeNumbers(query)).toLowerCase();
    final source = text;
    // 💡 تم إصلاح: يجب أن يكون تطبيع النص المصدر بالكامل للعثور على التطابقات
    final normSource =
        _normalizeArabic(_normalizeNumbers(source)).toLowerCase();

    RegExp regExp;
    if (exactMatch) {
      // 💡 تم تحسين التعبير النمطي للتطابق التام للكلمات
      regExp = RegExp(
        // يطابق في بداية السلسلة أو بعد محدد كلمة (مسافة، علامات ترقيم، إلخ)
        r'(^|[\s،.،؛:؛؟!\-\(\)\[\]\{\}])' +
            RegExp.escape(normQuery) +
            // يطابق قبل نهاية السلسلة أو قبل محدد كلمة
            r'(?=[\s،.،؛:؛؟!\-\(\)\[\]\{\}]|$)',
        caseSensitive: false,
      );
    } else {
      regExp = RegExp(RegExp.escape(normQuery), caseSensitive: false);
    }

    List<TextSpan> spans = [];
    int start = 0;

    for (final match in regExp.allMatches(normSource)) {
      int matchStart = match.start;
      int matchEnd = match.end;

      if (exactMatch) {
        // إذا كان تطابق تام، فإن match.start يشمل محدد البداية (مثل المسافة)
        // match.group(1) هو محدد البداية، ويجب تخطيه
        matchStart += match.group(1)?.length ?? 0;
        matchEnd = matchStart + normQuery.length;
      }

      // 💡 تم إصلاح: يجب استخدام مؤشرات matchStart و matchEnd على النص الأصلي
      if (matchStart > start) {
        spans.add(TextSpan(
            text: source.substring(start, matchStart.toInt()), style: style));
      }
      spans.add(TextSpan(
        text: source.substring(matchStart.toInt(), matchEnd.toInt()),
        style: style.copyWith(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ));
      start = matchEnd.toInt();
    }
    if (start < source.length) {
      spans.add(TextSpan(text: source.substring(start), style: style));
    }
    return TextSpan(children: spans);
  }

  TextSpan _processTextSegment(String segment, String query, TextStyle style,
      {bool exactMatch = false}) {
    final List<InlineSpan> spans = [];
    int currentIndex = 0;

    while (currentIndex < segment.length) {
      final int startRedaction = segment.indexOf('(((', currentIndex);

      if (startRedaction == -1) {
        spans.add(_highlightSearch(
          segment.substring(currentIndex),
          query,
          style,
          exactMatch: exactMatch,
        ));
        break;
      }

      if (startRedaction > currentIndex) {
        spans.add(_highlightSearch(
          segment.substring(currentIndex, startRedaction),
          query,
          style,
          exactMatch: exactMatch,
        ));
      }

      final int end = segment.indexOf(')))', startRedaction + 3);
      if (end == -1) {
        spans.add(_highlightSearch(
          segment.substring(startRedaction),
          query,
          style,
          exactMatch: exactMatch,
        ));
        break;
      }

      final String inside = segment.substring(startRedaction + 3, end);
      spans.add(_highlightSearch(
        inside,
        query,
        style.copyWith(color: Colors.red),
        exactMatch: exactMatch,
      ));

      currentIndex = end + 3;
    }
    return TextSpan(children: spans);
  }

  Widget _buildArticleRichText(String fullText, String searchInput) {
    final TextStyle baseStyle = TextStyle(
      color: _isDark ? Colors.white : Colors.black,
      fontSize: _fontSize,
      height: 1.9,
      fontWeight: FontWeight.bold,
    );

    if (fullText.trim().isEmpty) {
      return SelectableText.rich(const TextSpan(text: ''));
    }

    // --- التعبير النمطي النهائي الشامل لكافة استثناءاتك ---
    // الحالات المغطاة: (المبالغ، النقاط المتكررة، الاختصارات، الترقيم أ.1.، النقطتين والشرطة، كلمة مكرر)
    final RegExp sentenceSplitter = RegExp(
        r'(?<![0-9أ-ي])' // منع الفصل إذا سبقه حرف/رقم وحيد (حماية أ. و 1.)
        r'(?<![0-9])' // منع الفصل إذا سبقه رقم (حماية المبالغ 50.000)
        r'(\.{2,}\s*|[.؟!]+|:(?:\s*-)?)' // التقاط (.. أو ...) أو علامات الترقيم أو (:-)
        r'(?![0-9])' // منع الفصل إذا تبعه رقم (حماية المبالغ)
        r'(?![أ-ي]\b)' // منع الفصل إذا تبعه حرف وحيد (حماية الاختصارات ج.ي)
        r'(?!\s*مكرر)' // منع الفصل إذا كانت الكلمة التالية هي "مكرر"
        r'\s+' // اشتراط وجود مسافة للانتقال لسطر جديد
        );

    final String formattedText =
        fullText.replaceAllMapped(sentenceSplitter, (match) {
      // نعيد العلامة كاملة بدون مسافات زائدة ثم ننزل سطر
      return '${match.group(1)?.trim()}\n';
    });

    final List<String> lines = formattedText.split('\n');
    List<InlineSpan> finalSpans = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isNotEmpty) {
        finalSpans.add(_processTextSegment(line, searchInput, baseStyle,
            exactMatch: _exactMatch));

        if (i < lines.length - 1) {
          finalSpans.add(const TextSpan(text: '\n'));
        }
      }
    }

    // ✅ الكود الجديد بعد التعديل
    return Text.rich(
      TextSpan(children: finalSpans, style: baseStyle),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
    );
  }

  // --- دالة تصميم بطاقة المقدمة والخاتمة الجديدة ---
  Widget _buildIntroOutroCard(Map<String, dynamic> item, int index) {
    final bool isPreamble = item['type'] == 'preamble';

    // تنظيف النص من علامات +++ وما بينهما إذا وجدت (خاص باللوائح)
    final String rawContent = item['text'] ?? '';
    final String content =
        rawContent.replaceAll(RegExp(r'\+\+\+.*?\+\+\+'), '').trim();

    final Color accentColor =
        _isDark ? Colors.amber.shade300 : const Color(0xFF8E6E58);

    return AutoScrollTag(
      key: ValueKey(item['type'] + index.toString()),
      controller: _scrollController,
      index: index,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.3 : 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // زخرفة علوية بسيطة
              Positioned(
                top: -20,
                left: -20,
                child: Icon(Icons.gavel_rounded,
                    size: 100, color: accentColor.withOpacity(0.05)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: accentColor.withOpacity(0.4),
                                thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            isPreamble
                                ? Icons.account_balance_rounded
                                : Icons.verified_rounded,
                            color: accentColor,
                            size: 32,
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: accentColor.withOpacity(0.4),
                                thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Text(
                      content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _fontSize + 1,
                        height: 2.0,
                        fontWeight: FontWeight.w600,
                        fontFamily:
                            'Traditional Arabic', // إذا كان متوفراً في مشروعك
                        color: _isDark
                            ? Colors.grey.shade200
                            : const Color(0xFF2C2C2C),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} // نهاية الكلاس State
