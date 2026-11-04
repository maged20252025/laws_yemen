import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/law_loader.dart';
import 'law_articles_screen.dart';
import '../services/favorites_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesScreen extends StatefulWidget {
  final VoidCallback onFavoritesChanged;
  final FavoritesSyncService? favoritesService;
  final String title;
  final String? filterPath;
  final String storageKey; // 🆕 إضافة استقبال مفتاح التخزين

  const FavoritesScreen({
    super.key,
    required this.onFavoritesChanged,
    this.favoritesService,
    this.title = "المفضلة",
    this.filterPath,
    this.storageKey = 'favorite_laws', // الافتراضي هو القوانين
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, String>> allLaws = [];
  Set<String> favoriteLawFiles = {};

  FavoritesSyncService? favoritesSyncService;
  String userEmail = "";
  bool favoritesLoaded = false;

  @override
  void initState() {
    super.initState();
    // 1. استخدام الخدمة المُمررة أولاً
    favoritesSyncService = widget.favoritesService;
    _loadAllLaws(); // تحميل قائمة القوانين بالكامل
    _initFavoritesSystem(); // بدء تهيئة نظام المفضلة
  }

  Future<void> _initFavoritesSystem() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('userEmail') ?? "";

    if (favoritesSyncService == null && userEmail.isNotEmpty) {
      favoritesSyncService = FavoritesSyncService(
        userEmail: userEmail,
        firestore: FirebaseFirestore.instance,
        prefs: prefs,
        storageKey: widget.storageKey, // ✅ استخدام المفتاح الممرر
      );
    }

    if (favoritesSyncService != null) {
      await favoritesSyncService!.restoreFavoritesFromFirebase();
      favoritesSyncService!.addListener(_onFavoritesChangedListener);
    }

    await _loadFavorites();

    setState(() {
      favoritesLoaded = true;
    });
  }

  // تحديث قائمة القوانين المفضلة عند أي تغيير من الخدمة (مزامنة لحظية)
  void _onFavoritesChangedListener() async {
    await _loadFavorites();
    setState(() {});
  }

  Future<void> _loadAllLaws() async {
    // جلب البيانات من المجلدات الثلاثة وتجميعها في قائمة واحدة مع إضافة المسار
    final lawsFolder = (await LawLoader.loadFromFolder('assets/laws/'))
        .map((e) => {...e, 'path': 'assets/laws/'})
        .toList();
    final regsFolder = (await LawLoader.loadFromFolder('assets/regulations/'))
        .map((e) => {...e, 'path': 'assets/regulations/'})
        .toList();
    final prosFolder = (await LawLoader.loadFromFolder('assets/prosecutions/'))
        .map((e) => {...e, 'path': 'assets/prosecutions/'})
        .toList();

    setState(() {
      // دمج الجميع في قائمة allLaws لكي يتمكن التطبيق من إيجاد أي ملف مفضل
      allLaws = [...lawsFolder, ...regsFolder, ...prosFolder];
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ نستخدم المفتاح الممرر من الشاشة السابقة لضمان عرض مفضلة القسم الصحيح
    final favs = prefs.getStringList(widget.storageKey) ?? [];
    setState(() {
      favoriteLawFiles = favs.toSet();
    });
  }

  Future<bool> _confirmDelete(String lawName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Center(
              child: Text(
                "تأكيد الإزالة",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            content: Text(
              'هل تريد إزالة "$lawName" من المفضلة؟',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                child:
                    const Text("إلغاء", style: TextStyle(color: Colors.purple)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("إزالة"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _removeFromFavorites(String lawFile, String lawName) async {
    final confirmed = await _confirmDelete(lawName);
    if (!confirmed) return;

    if (favoritesSyncService != null) {
      await favoritesSyncService!.removeFavoriteLaw(context, lawFile);
      // التحديث سيتم تلقائيًا عبر المستمع
    } else {
      final prefs = await SharedPreferences.getInstance();
      favoriteLawFiles.remove(lawFile);
      // ✅ التعديل: استخدام المفتاح الممرر للقسم (قوانين، لوائح، أو نيابة)
      await prefs.setStringList(widget.storageKey, favoriteLawFiles.toList());
      setState(() {});
    }
    // بما أن التحديث يتم عبر المستمع، لا نحتاج لاستدعاء setState() هنا داخل الـ if(service != null)
    // لكنه ضروري في الـ else (لعدم وجود خدمة)
  }

  @override
  void dispose() {
    // **تصحيح:** إزالة المستمع الصحيح عند الخروج من الشاشة
    favoritesSyncService?.removeListener(_onFavoritesChangedListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!favoritesLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // نستخدم ListenableBuilder مع التحقق من وجود الخدمة لضمان تحديث UI
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: favoritesSyncService ?? ValueNotifier<bool>(true),
        builder: (context, child) {
          final favoriteLaws = allLaws.where((law) {
            final isFav = favoriteLawFiles.contains(law['file']);
            // إذا تم تمرير مسار معين، نتحقق أن الملف يبدأ بهذا المسار
            if (widget.filterPath != null) {
              return isFav && law['file']!.startsWith(widget.filterPath!);
            }
            return isFav;
          }).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.title, // استخدام العنوان الممرر من الشاشة السابقة
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: const Color.fromARGB(181, 179, 182, 26),
            ),
            body: favoriteLaws.isEmpty
                ? Center(
                    child: Text(
                      "لا توجد عناصر في ${widget.title} حالياً",
                      style: const TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: favoriteLaws.length,
                    itemBuilder: (context, index) {
                      final law = favoriteLaws[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.gavel,
                              color: Colors.blue, size: 28),
                          title: Text(
                            law['name']!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _removeFromFavorites(law['file']!, law['name']!);
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LawArticlesScreen(
                                  lawFileName: law['file']!,
                                  lawName: law['name']!,
                                  basePath: law['path']!,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
