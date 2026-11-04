import 'package:flutter/material.dart';
import '../utils/law_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'law_articles_screen.dart';
import 'global_search_screen.dart';
import 'favorites_screen.dart';
import 'activation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/favorites_sync_service.dart';
import 'package:laws_yemen/services/free_trial_manager.dart';

class RegulationsSelectionScreen extends StatefulWidget {
  final FavoritesSyncService? favoritesService;
  final String? storageKey;

  const RegulationsSelectionScreen({
    super.key,
    this.favoritesService,
    this.storageKey,
  });

  @override
  State<RegulationsSelectionScreen> createState() =>
      _RegulationsSelectionScreenState();
}

class _RegulationsSelectionScreenState
    extends State<RegulationsSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // المتغيرات الموحدة للتحكم بالصلاحيات
  bool isSubscribed = false;
  bool isLimitedMode = false;
  bool isPaid = false;

  List<Map<String, String>> regulations = [];
  List<Map<String, String>> filteredRegulations = [];
  Set<String> favoriteFiles = {};
  int _selectedIndex = 0;

  String userEmail = "";
  FavoritesSyncService? favoritesSyncService;
  bool dataLoaded = false;

  // الدالة الموحدة لفحص الصلاحيات (تم التعديل لدعم التجربة المجانية)
  Future<void> _checkStatusAndAccess() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. فحص حالة التجربة المجانية الأصلية عبر الدالة الصحيحة
    final bool isValidTrial = await FreeTrialManager.isTrialActive();

    // 2. جلب الحالات الأخرى
    isPaid = prefs.getBool('isActivated') ?? false;
    isLimitedMode = prefs.getBool('isLimitedModeActive') ?? false;

    setState(() {
      // 3. نعتبر المستخدم "مشتركاً" (صلاحية كاملة) إذا دفع أو إذا كانت تجربته سارية
      isSubscribed = isPaid || isValidTrial;
    });

    // 4. التوجيه لشاشة التفعيل فقط إذا لم يكن: مشتركاً، ولا في تجربة سارية، ولم يوافق على الوضع المحدود
    if (!isPaid && !isValidTrial && !isLimitedMode) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ActivationScreen()),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkStatusAndAccess(); // استدعاء الدالة المحدثة
    _loadUserEmail();
    _loadData();
    _searchController.addListener(() {
      _filterData(_searchController.text);
    });
    _initFavoritesSystem();
  }

  Future<void> _checkAccess() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ فحص هل المستخدم في "الوضع المحدود"
    bool isLimitedMode = prefs.getBool('isLimitedModeActive') ?? false;

    final trialEnd = prefs.getInt('trialEnd');
    final now = DateTime.now().millisecondsSinceEpoch;
    final trialExpired = trialEnd != null && now > trialEnd;
    final hasPaid = prefs.getBool('isActivated') ?? false;
    final paidEnd = prefs.getInt('paidEndMs');
    final paidExpired = paidEnd != null && now > paidEnd;

    setState(() {
      // ✅ إذا لم يكن محدوداً فهو (مشترك أو تجربة أصلية)
      isSubscribed = !isLimitedMode;
    });

    if ((trialEnd == null || trialExpired) && (!hasPaid || paidExpired)) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
      }
    }
  }

  Future<void> _initFavoritesSystem() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail') ?? "";
    favoritesSyncService = widget.favoritesService;

    if (favoritesSyncService == null && userEmail.isNotEmpty) {
      favoritesSyncService = FavoritesSyncService(
        userEmail: userEmail,
        firestore: FirebaseFirestore.instance,
        prefs: prefs,
        storageKey: widget.storageKey ?? 'favorite_regulations',
      );
    }

    if (favoritesSyncService != null) {
      await favoritesSyncService!.restoreFavoritesFromFirebase();
      favoritesSyncService!.addListener(_onFavoritesChangedListener);
    }

    await _loadFavorites();
    setState(() {
      dataLoaded = true;
    });
  }

  void _onFavoritesChangedListener() {
    _loadFavorites();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? "";
    });
  }

  Future<void> _loadData() async {
    final rawData = await LawLoader.loadFromFolder('assets/regulations/');
    List<Map<String, String>> updatedData = [];

    for (var item in rawData) {
      String displayName = item['name'] ?? "";
      try {
        final content =
            await DefaultAssetBundle.of(context).loadString(item['file']!);
        final regex = RegExp(r'\+\+\+(.*?)\+\+\+');
        final match = regex.firstMatch(content);
        if (match != null && match.group(1) != null) {
          displayName = match.group(1)!.trim();
        }
      } catch (e) {
        // فشل القراءة، نستخدم الاسم الأصلي
      }

      updatedData.add({
        'name': displayName,
        'file': item['file']!,
      });
    }

    setState(() {
      regulations = updatedData;
      filteredRegulations = updatedData;
    });
  }

  String removeTatweel(String text) {
    return text.replaceAll('\u0640', '');
  }

  void _filterData(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredRegulations = regulations;
      } else {
        filteredRegulations = regulations.where((item) {
          String nameNoTatweel = removeTatweel(item['name']!.toLowerCase());
          String queryNoTatweel = removeTatweel(query.toLowerCase());
          return nameNoTatweel.contains(queryNoTatweel);
        }).toList();
      }
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs =
        prefs.getStringList(widget.storageKey ?? 'favorite_regulations') ?? [];
    setState(() {
      favoriteFiles = favs.toSet();
    });
  }

  Future<void> _toggleFavorite(String file, String name) async {
    if (favoritesSyncService != null) {
      if (favoriteFiles.contains(file)) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => _buildCenteredDialog(
            title: "تأكيد الإزالة",
            content: "هل تريد إزالة \"$name\" من المفضلة؟",
            confirmText: "إزالة",
            cancelText: "إلغاء",
            confirmColor: Colors.red,
          ),
        );
        if (confirm != true) return;

        await favoritesSyncService!.removeFavoriteLaw(context, file);
        setState(() {
          favoriteFiles.remove(file);
        });
      } else {
        await favoritesSyncService!.addFavoriteLaw(context, file);
        setState(() {
          favoriteFiles.add(file);
        });
      }
    }
  }

  Widget _buildCenteredDialog({
    required String title,
    required String content,
    required String confirmText,
    required String cancelText,
    required Color confirmColor,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(
          child:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
      content: Text(content, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText)),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmText),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    if (!isSubscribed) {
      _showRestrictionDialog();
      // حذفنا تعيين القيمة -1 لمنع الخطأ البرمجي
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GlobalSearchScreen(
            searchPath: 'assets/regulations/',
            title: 'بحث شامل في اللوائح',
            searchHint: 'أكتب كلمة للبحث في اللوائح',
            themeColor: const Color.fromARGB(255, 51, 1, 1),
          ),
        ),
      ).then((_) => setState(() => _selectedIndex = 0));
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FavoritesScreen(
            onFavoritesChanged: () {},
            favoritesService: favoritesSyncService,
            storageKey: widget.storageKey ?? 'favorite_regulations',
            title: "مفضلة اللوائح",
          ),
        ),
      ).then((_) {
        _loadFavorites();
        setState(() => _selectedIndex = 0);
      });
    }
  }

  // دالة التنبيه الموحدة (أضفها داخل الكلاس)
  void _showRestrictionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('عــــذراً',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'هذه الميزة متاحة لمشتركي النسخة المدفوعة فقط قم بترقيه حسابك الآن للوصول إلى جميع المزايا المتقدمة',
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
              backgroundColor: const Color(0xFF6D4C41),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ActivationScreen()),
              );
            },
            child: const Text('تفعيل الاشتراك',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    favoritesSyncService?.removeListener(_onFavoritesChangedListener);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!dataLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          centerTitle: true,
          elevation: 2,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8D6E63),
                  Color(0xFF3E2723),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          title: const Text(
            "اللوائــــــح ",
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                readOnly: !isSubscribed,
                onTap: () {
                  if (!isSubscribed) {
                    _showRestrictionDialog(); // استخدام الدالة الموحدة
                  } else {
                    _searchFocusNode.requestFocus();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'ابحث في اللوائح...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _filterData('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredRegulations.length,
                itemBuilder: (context, index) {
                  final item = filteredRegulations[index];
                  final isFavorite = favoriteFiles.contains(item["file"]!);

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      // ✅ التعديل: تصغير الدائرة وتغيير اللون للذهبي البارز
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF5D4037),
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        item["name"]!,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A4A4A)),
                      ),
                      trailing: IconButton(
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite
                                ? const Color(0xFFD4AF37)
                                : Colors.grey),
                        onPressed: () =>
                            _toggleFavorite(item["file"]!, item["name"]!),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LawArticlesScreen(
                              lawFileName: item["file"]!,
                              lawName: item["name"]!,
                              basePath: 'assets/regulations/',
                              themeColor: const Color.fromARGB(255, 0, 128, 68),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // ✅ التعديل: اللون الذهبي العميق للعنصر المحدد وتنسيق الشريط
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFF4E342E),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'بحث شامل',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_rounded),
              label: 'المفضلة',
            ),
          ],
        ),
      ),
    );
  }
}
