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

class ProsecutionSelectionScreen extends StatefulWidget {
  final FavoritesSyncService? favoritesService;
  final String storageKey;

  const ProsecutionSelectionScreen({
    super.key,
    this.favoritesService,
    this.storageKey = 'favorite_instructions',
  });

  @override
  State<ProsecutionSelectionScreen> createState() =>
      _ProsecutionSelectionScreenState();
}

class _ProsecutionSelectionScreenState
    extends State<ProsecutionSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // المتغيرات الموحدة للتحكم بالصلاحيات
  bool isSubscribed = false;
  bool isLimitedMode = false;
  bool isPaid = false;

  List<Map<String, String>> prosecutions = [];
  List<Map<String, String>> filteredProsecutions = [];
  Set<String> favoriteFiles = {};
  int _selectedIndex = 0;

  String userEmail = "";
  FavoritesSyncService? favoritesSyncService;
  bool dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkStatusAndAccess(); // استدعاء الدالة الموحدة
    _loadUserEmail();
    _loadData();
    _searchController.addListener(() {
      _filterData(_searchController.text);
    });
    _initFavoritesSystem();
  }

  // الدالة الموحدة لفحص الصلاحيات (تم التعديل لدعم التجربة المجانية الأصلية)
  Future<void> _checkStatusAndAccess() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. التحقق من حالة التجربة المجانية عبر الدالة الصحيحة
    final bool isValidTrial = await FreeTrialManager.isTrialActive();

    // 2. جلب الحالات الأخرى من التفضيلات
    isPaid = prefs.getBool('isActivated') ?? false;
    isLimitedMode = prefs.getBool('isLimitedModeActive') ?? false;

    setState(() {
      // 3. فتح الصلاحيات الكاملة إذا كان مشتركاً أو في فترة التجربة السارية
      isSubscribed = isPaid || isValidTrial;
    });

    // 4. التوجيه لشاشة التفعيل فقط إذا فقد جميع الصلاحيات ولم يختر الوضع المحدود
    if (!isPaid && !isValidTrial && !isLimitedMode) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ActivationScreen()),
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
        storageKey: widget.storageKey,
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

  void _onFavoritesChangedListener() async {
    await _loadFavorites();
    setState(() {});
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? "";
    });
  }

  Future<void> _loadData() async {
    final loadedData = await LawLoader.loadFromFolder('assets/prosecutions/');
    setState(() {
      prosecutions = loadedData;
      filteredProsecutions = loadedData;
    });
  }

  String removeTatweel(String text) {
    return text.replaceAll('\u0640', '');
  }

  void _filterData(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProsecutions = prosecutions;
      } else {
        filteredProsecutions = prosecutions.where((item) {
          String nameNoTatweel = removeTatweel(item['name']!.toLowerCase());
          String queryNoTatweel = removeTatweel(query.toLowerCase());
          return nameNoTatweel.contains(queryNoTatweel);
        }).toList();
      }
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(widget.storageKey) ?? [];
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
      // تمت إزالة -1 لمنع الانهيار
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GlobalSearchScreen(
            searchPath: 'assets/prosecutions/',
            title: 'بحث شامل في تعليمات النيابة',
            searchHint: 'أكتب كلمة للبحث ',
            themeColor: Color(0xFF1A237E),
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
            storageKey: widget.storageKey,
            title: 'مفضلة النيابة العامة',
          ),
        ),
      ).then((_) {
        _loadFavorites();
        setState(() => _selectedIndex = 0);
      });
    }
  }

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
              backgroundColor: const Color(0xFF1A237E),
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
      child: ListenableBuilder(
        listenable: favoritesSyncService ?? ValueNotifier<bool>(true),
        builder: (context, child) {
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              elevation: 4,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              title: const Text(
                "تعليمات النيابة العامة",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 22,
                  shadows: [
                    Shadow(
                      blurRadius: 3,
                      color: Colors.black45,
                      offset: Offset(1, 1),
                    )
                  ],
                ),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
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
                        _showRestrictionDialog();
                      } else {
                        _searchFocusNode.requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث في التعليمات...',
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
                    itemCount: filteredProsecutions.length,
                    itemBuilder: (context, index) {
                      final item = filteredProsecutions[index];
                      final isFavorite =
                          favoriteFiles.contains(item["file"]!.split('/').last);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFF1A237E),
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          title: Text(
                            item["name"]!,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color:
                                    isFavorite ? Colors.orange : Colors.grey),
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
                                  basePath: 'assets/prosecutions/',
                                  themeColor: const Color(0xFF1A237E),
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
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex == -1 ? 0 : _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: const Color(0xFF1A237E),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'بحث شامل',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.star),
                  label: 'المفضلة',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
