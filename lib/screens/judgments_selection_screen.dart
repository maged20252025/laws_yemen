import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laws_yemen/screens/global_search_screen.dart';
import 'package:laws_yemen/screens/favorites_screen.dart'; // تأكد من استيراد شاشة المفضلة الخاصة بك
import 'package:laws_yemen/services/favorites_sync_service.dart'; // تأكد من استيراد الخدمة الخاصة بك
import 'package:laws_yemen/services/free_trial_manager.dart';
import 'activation_screen.dart';

// --- الشاشة الرئيسية لأقسام القواعد القضائية ---
class JudgmentsSelectionScreen extends StatefulWidget {
  const JudgmentsSelectionScreen({super.key});

  @override
  State<JudgmentsSelectionScreen> createState() =>
      _JudgmentsSelectionScreenState();
}

class _JudgmentsSelectionScreenState extends State<JudgmentsSelectionScreen> {
  final List<Map<String, String>> categories = [
    {'title': 'القواعد القضائية الدستورية', 'keyword': 'الدستورية'},
    {'title': 'القواعد القضائية الإدارية', 'keyword': 'الإدارية'},
    {'title': 'القواعد القضائية الشخصية', 'keyword': 'الشخصية'},
    {'title': 'القواعد القضائية التجارية', 'keyword': 'التجارية'},
    {'title': 'القواعد القضائية المدنية', 'keyword': 'المدنية'},
    {'title': 'القواعد القضائية الجزائية', 'keyword': 'الجزائية'},
  ];

  final Color appleGreen = const Color(0xFFDCEDC8);
  final String _storageKey = 'favorite_judgments';
  bool isSubscribed = false; // ✅ متغير حالة الاشتراك

  @override
  void initState() {
    super.initState();
    _checkAccess(); // ✅ فحص الصلاحيات عند الدخول
  }

  // ✅ دالة فحص الصلاحيات الموحدة
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

  // ✅ دالة التنبيه الموحدة
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
              backgroundColor: const Color(0xFF388E3C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'القواعد القضائية',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: appleGreen,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.95,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final List<List<Color>> cardGradients = [
              [const Color(0xFF66BB6A), const Color(0xFF388E3C)],
              [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
              [const Color(0xFFFFA726), const Color(0xFFF57C00)],
              [const Color(0xFF26A69A), const Color(0xFF00796B)],
              [const Color(0xFF78909C), const Color(0xFF455A64)],
              [const Color(0xFFEC407A), const Color(0xFFC2185B)],
            ];

            return _buildModernCategoryCard(cat['title']!, cat['keyword']!,
                cardGradients[index % cardGradients.length]);
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF388E3C),
        onPressed: () {
          if (!isSubscribed) {
            _showLimitedAccessDialog();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GlobalSearchScreen(
                  searchPath: 'assets/judgments/',
                  title: 'بحث شامل في القواعد القضائية',
                  searchHint: 'أكتب كلمة للبحث في القواعد القضائية...',
                  themeColor: const Color(0xFF388E3C),
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.manage_search_rounded, color: Colors.white),
        label: const Text("البحث الشامل",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildModernCategoryCard(
      String title, String keyword, List<Color> colors) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                JudgmentsListView(categoryTitle: title, keyword: keyword),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.library_books_rounded, size: 40, color: colors[0]),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.brown.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة عرض نصوص القواعد لكل قسم ---
class JudgmentsListView extends StatefulWidget {
  final String categoryTitle;
  final String keyword;
  const JudgmentsListView(
      {super.key, required this.categoryTitle, required this.keyword});

  @override
  State<JudgmentsListView> createState() => _JudgmentsListViewState();
}

class _JudgmentsListViewState extends State<JudgmentsListView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  List<dynamic> _allJudgments = [];
  bool isSubscribed = false;

  // ✅ النسخة الواحدة الصحيحة (توضع هنا مرة واحدة فقط)
  @override
  void initState() {
    super.initState();
    _checkAccess(); // فحص حالة الاشتراك والقيد
    _initFavoritesAndData(); // تحميل البيانات والمفضلة
  } // ✅ إضافة متغير حالة الاشتراك

  // ✅ دالة فحص الصلاحيات الموحدة
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

  // ✅ دالة التنبيه الموحدة
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
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
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

  double _fontSize = 16.0;
  bool _isDark = false;
  bool _isExactMatch = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Set<String> _favorites = {};
  FavoritesSyncService? _favoritesSyncService;
  final String _storageKey = 'favorite_judgments';
  final Color appleGreen = const Color(0xFFDCEDC8);

  Future<void> _initFavoritesAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? "";

    if (userEmail.isNotEmpty) {
      _favoritesSyncService = FavoritesSyncService(
        userEmail: userEmail,
        firestore: FirebaseFirestore.instance,
        prefs: prefs,
        storageKey: _storageKey,
      );
      _favoritesSyncService!.addListener(_onFavoritesChanged);
      await _favoritesSyncService!.restoreFavoritesFromFirebase();
    }
    await _loadLocalFavorites();
    await _loadAllRelatedFiles();
  }

  void _onFavoritesChanged() async {
    await _loadLocalFavorites();
    if (mounted) setState(() {});
  }

  Future<void> _loadLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getStringList(FavoritesSyncService.articlesKey(_storageKey)) ??
            [];
    setState(() => _favorites = saved.toSet());
  }

  @override
  void dispose() {
    _favoritesSyncService?.removeListener(_onFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRelatedFiles() async {
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = assetManifest.listAssets();
      final relevantFiles = allAssets.where((path) {
        final fileName = path.split('/').last;
        return fileName.contains(widget.keyword) && fileName.endsWith('.json');
      }).toList();

      List<dynamic> combinedData = [];
      for (String filePath in relevantFiles) {
        final String response = await rootBundle.loadString(filePath);
        final List<dynamic> decodedData = json.decode(response);

        final cleanedData = decodedData.where((item) {
          final content = item['content']?.toString().trim() ?? "";
          final ruleNumber = item['rule_number']?.toString().trim() ?? "";
          return content.isNotEmpty && ruleNumber.isNotEmpty;
        }).toList();

        combinedData.addAll(cleanedData);
      }
      setState(() {
        _allJudgments = combinedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(dynamic item) async {
    // إنشاء معرف فريد يجمع (رقم القاعدة، رقم الطعن، العدد، الصفحة)
    String uniqueId =
        "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";

    if (_favoritesSyncService != null) {
      if (_favorites.contains(uniqueId)) {
        await _favoritesSyncService!
            .removeFavoriteArticle(context, _storageKey, uniqueId);
      } else {
        await _favoritesSyncService!
            .addFavoriteArticle(context, _storageKey, uniqueId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cleanQuery = _searchQuery.trim();
    final filteredJudgments = _allJudgments.where((item) {
      if (cleanQuery.isEmpty) return true;
      String content = (item['content'] ?? "").toString();
      String caseNumber = (item['case_number'] ?? "").toString();
      String ruleNumber = (item['rule_number'] ?? "").toString();

      if (_isExactMatch) {
        // ننشئ المعرف المركب للعنصر الحالي لمقارنته بالمعرف المطلوب
        String uniqueId =
            "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";
        return uniqueId == cleanQuery;
      } else {
        return content.contains(cleanQuery) || caseNumber.contains(cleanQuery);
      }
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: appleGreen,
        elevation: 2,
        centerTitle: true,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.text_fields_rounded, color: Colors.black),
              onPressed: () => _showFontSizeDialog(),
            ),
            IconButton(
              icon: Icon(
                  _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Colors.black),
              onPressed: () => setState(() => _isDark = !_isDark),
            ),
          ],
        ),
        leadingWidth: 100,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.categoryTitle,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Text("",
                style: TextStyle(color: Colors.black54, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black),
            onPressed: () {
              // ✅ حماية الوصول للمفضلة الجانبية
              if (!isSubscribed) {
                _showLimitedAccessDialog();
              } else {
                _scaffoldKey.currentState?.openEndDrawer();
              }
            },
          ),
        ],
      ),
      endDrawer: _buildFavoritesDrawer(),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.lightGreen))
            : Column(
                children: [
                  _buildTopToolBar(),
                  Expanded(
                    child: filteredJudgments.isEmpty
                        ? const Center(
                            child: Text("لا توجد نتائج مطابقة لبحثك"))
                        : ListView.builder(
                            itemCount: filteredJudgments.length,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemBuilder: (context, index) => _buildJudgmentCard(
                                filteredJudgments[index], index),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 240,
              child: Column(
                children: [
                  Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("تغيير حجم الخط",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _fontActionButton(Icons.remove, () {
                        if (_fontSize > 12) {
                          setModalState(() => _fontSize--);
                          setState(() {});
                        }
                      }),
                      const SizedBox(width: 40),
                      Text("${_fontSize.toInt()}",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _isDark ? Colors.white : Colors.black)),
                      const SizedBox(width: 40),
                      _fontActionButton(Icons.add, () {
                        setModalState(() => _fontSize++);
                        setState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("يتم الحفظ تلقائياً",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _fontActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: _isDark ? Colors.white24 : Colors.black12)),
        child: Icon(icon,
            size: 28, color: _isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildTopToolBar() {
    int totalWordOccurrences = 0;
    int rulesCount = 0;
    final String cleanQuery = _searchQuery.trim();

    if (cleanQuery.isNotEmpty) {
      final filteredList = _allJudgments.where((item) {
        if (_isExactMatch) {
          String uId =
              "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";
          return uId == cleanQuery;
        }
        String content = (item['content'] ?? "").toString();
        String caseNumber = (item['case_number'] ?? "").toString();
        return content.contains(cleanQuery) || caseNumber.contains(cleanQuery);
      }).toList();

      rulesCount = filteredList.length;
      for (var item in filteredList) {
        String content = (item['content'] ?? "").toString();
        int count = 0;
        int index = content.indexOf(cleanQuery);
        while (index != -1) {
          count++;
          index = content.indexOf(cleanQuery, index + cleanQuery.length);
        }
        totalWordOccurrences += count;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _isDark ? Colors.white10 : Colors.black12),
            ),
            child: TextField(
              controller: _searchController,
              // ✅ منع الكتابة وإظهار الرسالة إذا لم يشترك
              onTap: !isSubscribed ? () => _showLimitedAccessDialog() : null,
              readOnly: !isSubscribed,
              onChanged: (val) => setState(() => _searchQuery = val),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: "بحث في النص أو رقم الطعن...",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, size: 22, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel,
                            size: 20, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              ),
            ),
          ),
          if (cleanQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                  "تم العثور على $totalWordOccurrences كلمة في $rulesCount قاعدة",
                  style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildJudgmentCard(dynamic item, int index) {
    // إنشاء المعرف المركب الفريد
    String uniqueId =
        "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";
    bool isFav = _favorites.contains(uniqueId);

    // فحص ما إذا كان يجب فتح البطاقة تلقائياً (عند الانتقال من المفضلة)
    bool expandByDefault = _searchQuery == uniqueId && _isExactMatch;

    return Card(
      key: ValueKey(uniqueId),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      color: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        key: PageStorageKey(uniqueId),
        initiallyExpanded: expandByDefault,
        iconColor: Colors.lightGreen.shade700,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.lightGreen.shade600,
          child: Text("${index + 1}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        title: RichText(
          textAlign: TextAlign.justify,
          text: TextSpan(
            children: [
              TextSpan(
                  text: "الموجز: ",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isDark
                          ? Colors.white
                          : const Color.fromARGB(255, 196, 21, 21),
                      fontSize: _fontSize + 1)),
              _highlightSearchResult(
                  item['subject'] ?? 'بدون عنوان', _searchQuery.trim(),
                  isBold: true),
            ],
          ),
        ),
        subtitle: _buildInfoRow(item),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: _isDark ? const Color(0xFF252525) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("نص القاعدة القضائية:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isDark
                                ? Colors.white
                                : const Color.fromARGB(255, 206, 23, 23),
                            fontSize: _fontSize + 1)),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(isFav ? Icons.star : Icons.star_border,
                              color: Colors.amber),
                          onPressed: () {
                            if (!isSubscribed) {
                              _showLimitedAccessDialog();
                            } else {
                              _toggleFavorite(item); // نرسل العنصر كاملاً هنا
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy,
                              size: 20, color: Colors.blueGrey),
                          onPressed: () {
                            if (!isSubscribed) {
                              _showLimitedAccessDialog();
                            } else {
                              String fullText =
                                  "العنوان: ${item['subject'] ?? '-'}\nنص القاعدة: ${item['content'] ?? '-'}\nرقم القاعدة: ${item['rule_number'] ?? '-'}\nرقم الطعن: ${item['case_number'] ?? '-'}\nالعدد: ${item['issue_number'] ?? '-'}\nالصفحة: ${item['page'] ?? '-'}";
                              Clipboard.setData(ClipboardData(text: fullText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("تم نسخ كامل بيانات القاعدة")));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                RichText(
                  textAlign: TextAlign.justify,
                  text: _highlightSearchResult(
                      item['content'] ?? 'لا يوجد محتوى', _searchQuery.trim()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _infoTag("القاعدة", item['rule_number']),
          _divider(),
          _infoTag("الطعن", item['case_number']),
          _divider(),
          _infoTag("العدد", item['issue_number']),
          _divider(),
          _infoTag("الصفحة", item['page']),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      height: 18, width: 1, color: _isDark ? Colors.white24 : Colors.black12);

  Widget _infoTag(String label, dynamic val) {
    return Column(children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      // استخدام Theme لعزل حجم الخط داخل هذا الجزء فقط
      Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                bodyMedium: const TextStyle(fontSize: 14),
              ),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, // تثبيت الحجم هنا
                color: _isDark ? Colors.white70 : Colors.black),
            children: [
              _highlightFixedSize(val?.toString() ?? "-", _searchQuery.trim())
            ],
          ),
        ),
      ),
    ]);
  }

  // دالة مساعدة جديدة للتمييز بحجم ثابت حصراً للمربعات
  TextSpan _highlightFixedSize(String text, String query) {
    if (query.isEmpty || !text.contains(query)) {
      return TextSpan(text: text);
    }
    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;
    while ((indexOfMatch = text.indexOf(query, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: TextStyle(
              backgroundColor: Colors.yellow.withOpacity(0.7),
              color: Colors.black,
              fontSize: 14, // ضمان ثبات الحجم حتى عند التظليل
              fontWeight: FontWeight.bold)));
      start = indexOfMatch + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(children: spans);
  }

  Widget _buildFavoritesDrawer() {
    // تصفية العناصر بناءً على المعرف المركب لضمان الدقة وعدم التكرار
    final List<dynamic> favoriteItems = _allJudgments
        .where((item) {
          String uniqueId =
              "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";
          return _favorites.contains(uniqueId);
        })
        .fold<Map<String, dynamic>>({}, (map, item) {
          String uniqueId =
              "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";
          map[uniqueId] = item;
          return map;
        })
        .values
        .toList();

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: appleGreen),
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.star_rounded,
                        size: 40, color: Colors.orange),
                    const SizedBox(height: 10),
                    Text("مفضلة ${widget.categoryTitle}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ])),
            ),
            Expanded(
              child: favoriteItems.isEmpty
                  ? const Center(child: Text("قائمة المفضلة فارغة"))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: favoriteItems.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = favoriteItems[index];
                        final String caseNum =
                            item['case_number']?.toString() ?? "-";
                        final String ruleNum =
                            item['rule_number']?.toString() ?? "-";

                        return ListTile(
                          title: Text(
                            item['subject'] ?? 'بدون عنوان',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          leading: const Icon(Icons.bookmark,
                              color: Colors.green, size: 20),
                          subtitle: Text(
                              "رقم الطعن: $caseNum | قاعدة: $ruleNum",
                              style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.pop(context);
                            String uniqueId =
                                "${item['rule_number']}_${item['case_number']}_${item['issue_number']}_${item['page']}";
                            setState(() {
                              _searchQuery = uniqueId;
                              _searchController.clear();
                              _isExactMatch = true;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _highlightSearchResult(String text, String query,
      {bool isBold = false}) {
    String formattedText = text.replaceAll('. ', '.\n');
    if (query.isEmpty || !formattedText.contains(query)) {
      return TextSpan(
          text: formattedText,
          style: TextStyle(
              fontSize: _fontSize,
              height: 1.8,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: _isDark ? Colors.white : Colors.black87));
    }
    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;
    while ((indexOfMatch = formattedText.indexOf(query, start)) != -1) {
      if (indexOfMatch > start)
        spans.add(TextSpan(
            text: formattedText.substring(start, indexOfMatch),
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
      spans.add(TextSpan(
          text: formattedText.substring(
              indexOfMatch, indexOfMatch + query.length),
          style: TextStyle(
              backgroundColor: Colors.yellow.withOpacity(0.7),
              color: Colors.black,
              fontWeight: FontWeight.bold)));
      start = indexOfMatch + query.length;
    }
    if (start < formattedText.length)
      spans.add(TextSpan(
          text: formattedText.substring(start),
          style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal)));
    return TextSpan(
        style: TextStyle(
            fontSize: _fontSize,
            height: 1.8,
            color: _isDark ? Colors.white : Colors.black87),
        children: spans);
  }
}
