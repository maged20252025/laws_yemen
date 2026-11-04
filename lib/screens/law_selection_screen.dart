import 'package:flutter/material.dart';
import '../utils/law_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'law_articles_screen.dart';
import 'global_search_screen.dart';
import 'favorites_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/favorites_sync_service.dart';
import 'package:laws_yemen/services/free_trial_manager.dart';
// استدعاء متغيرات الإصدار
import '../version/version.dart';
import 'activation_screen.dart'; // تأكد أن المسار صحيح

class LawSelectionScreen extends StatefulWidget {
  // إضافة متغير لاستقبال خدمة المفضلة من شاشة تسجيل الدخول
  final FavoritesSyncService? favoritesService;

  const LawSelectionScreen({super.key, this.favoritesService});

  @override
  State<LawSelectionScreen> createState() => _LawSelectionScreenState();
}

class _LawSelectionScreenState extends State<LawSelectionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, String>> laws = [];
  List<Map<String, String>> filteredLaws = [];
  List<Map<String, String>> importantLaws = [];
  Set<String> favoriteLawFiles = {};
  int _selectedIndex = 0;

  final List<String> importantFilesOrder = [
    "المرافعات والتنفيذ المدني وتعديلاته 40-2002.json",
    "المدني 14-2002.json",
    "الإثبات 21-1992.json",
    "الأحوال الشخصية 20-1992.json",
    "الإجراءات الجزائية 13-1994.json",
    "الجرائم والعقوبات 12-1994.json",
    "التجاري 32-1991.json",
    "تنظيم العلاقة بين المؤجر والمستأجر 22-2006.json",
    "التحكيم 22-1992.json",
    "الشركات التجارية 22-1997.json",
    "الأسماء التجارية 20-2003.json",
  ];

  String userEmail = "";
  FavoritesSyncService? favoritesSyncService;
  bool favoritesLoaded = false;
  bool isLimitedMode = false; // 🆕
  bool isPaid = false; // 🆕

  @override
  void initState() {
    super.initState();
    _checkStatusAndAccess(); // دالة محدثة
    _loadUserEmail();
    _loadLaws();
    _searchController.addListener(() {
      _filterLaws(_searchController.text);
    });
    _initFavoritesSystem(); // **نبدأ تهيئة نظام المفضلة بالترتيب الجديد**
    _checkForUpdates(); // تم افتراض وجود هذه الدالة في كودك الأصلي
  }

  // ==========================================================
  // 🔹 الدالة الموحدة لتهيئة المفضلة بالترتيب الصحيح
  // ==========================================================
  Future<void> _initFavoritesSystem() async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('userEmail');
    userEmail = email ?? ""; // تحديث إيميل المستخدم

    // 1. استخدام الخدمة الممررة أولاً (إذا جاء من شاشة تسجيل الدخول)
    favoritesSyncService = widget.favoritesService;

    // 2. إذا لم يتم تمرير الخدمة ولكن المستخدم مسجل الدخول، قم بإنشاء خدمة جديدة
    if (favoritesSyncService == null && userEmail.isNotEmpty) {
      favoritesSyncService = FavoritesSyncService(
        userEmail: userEmail,
        firestore: FirebaseFirestore.instance,
        prefs: prefs, // 🔑 التعديل المطلوب
      );
    }

    // 3. تنفيذ الترتيب الحاسم وتفعيل المستمعين
    if (favoritesSyncService != null) {
      // 🥇 الاستعادة من فايربيس أولاً (مفتاح حل مشكلة حذف البيانات)
      await favoritesSyncService!.restoreFavoritesFromFirebase();

      // 🥈 إضافة المستمع لتحديث واجهة المستخدم
      favoritesSyncService!.addListener(_onFavoritesChangedListener);

      // ملاحظة: نعتمد على أن الدالة البانية لـ FavoritesSyncService
      // تقوم بتشغيل مستمعي السحابة والإنترنت بعد الاستعادة مباشرة.
    }

    // 4. تحميل المفضلة المحلية بعد الاستعادة (لتحديث واجهة المستخدم)
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

  bool isSubscribed =
      false; // أضف هذا المتغير في بداية الكلاس (_LawSelectionScreenState)

  Future<void> _checkStatusAndAccess() async {
    final prefs = await SharedPreferences.getInstance();

    // فحص حالة التجربة المجانية الأصلية باستخدام الدالة الصحيحة
    final bool isValidTrial = await FreeTrialManager.isTrialActive();

    // جلب الحالات من التفضيلات
    isPaid = prefs.getBool('isActivated') ?? false;
    isLimitedMode = prefs.getBool('isLimitedModeActive') ?? false;

    // تحديث متغير isSubscribed: نعتبره مشتركاً إذا دفع أو إذا كانت تجربته سارية
    setState(() {
      isSubscribed = isPaid || isValidTrial;
    });

    // يسمح بالدخول إذا كان مشتركاً، أو في تجربة سارية، أو اختار الوضع المحدود
    if (!isPaid && !isValidTrial && !isLimitedMode) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ActivationScreen()),
        );
      }
    }
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    // تم تحديث userEmail بالفعل في _initFavoritesSystem
    // لكن يمكن أن تبقى هذه الدالة لجلب الإيميل إن لزم الأمر في مكان آخر
    setState(() {
      userEmail = prefs.getString('userEmail') ?? "";
    });
  }

  // تم افتراض وجود هذه الدالة في كودك الأصلي
  void _checkForUpdates() {
    // منطق التحقق من التحديثات
  }

  @override
  void dispose() {
    favoritesSyncService?.removeListener(_onFavoritesChangedListener);
    favoritesSyncService?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // التحقق من حالة الاشتراك قبل السماح بالدخول لميزات البحث والمفضلة
    if (!isSubscribed) {
      _showRestrictionDialog();
      setState(() {
        _selectedIndex = -1;
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      // شاشة البحث الشامل
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
      ).then((_) => setState(() => _selectedIndex = -1));
    } else if (index == 1) {
      // شاشة المفضلة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FavoritesScreen(
            onFavoritesChanged: () {},
            favoritesService: favoritesSyncService,
          ),
        ),
      ).then((_) {
        _searchFocusNode.unfocus();
        setState(() {
          _selectedIndex = -1;
        });
      });
    }
  }

  // 🆕 الدالة الموحدة لإظهار تنبيه القيود لمستخدمي الوضع المحدود
  void _showRestrictionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'عــــذراً',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              backgroundColor: const Color(0xFF37474F),
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

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "ℹ️ معلومة",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF37474F)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "يتضمن هذا القسم كافة القوانين اليمنية مع آخر التعديلات الرسمية التي طرأت عليها حتى اليوم، لضمان وصولك إلى نص قانوني دقيق وموثوق.",
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 15),
                  const Text("📊 هل تعلم؟",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 16)),
                  const Text(
                      "منذ عام 1990م وحتى اليوم:\n• تم إلغاء أكثر من 10 قوانين بالكامل وحل محلها قوانين جديدة.\n• طرأت تعديلات على  أكثر من 50 قانوناً آخر.\n• تغيرت أكثر من الف مادة قانونية سواء بالحذف أو التعديل أو الإضافة.",
                      style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 15),
                  const Text("🎁 جرّبه بنفسك",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 16)),
                  const Text(
                      "القرار لا يُبنى على الكلام، بل على التجربة. أمامك الوقت الكافي لتجربة التطبيق مجاناً ومقارنته بمصادرك الحالية.",
                      style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 15),
                  const Text("⭐ مميزات التطبيق",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 16)),
                  const Text(
                      "• المفضلة لسهولة الرجوع.\n• البحث الشامل والسريع.\n• فهرس تفاعلي للأبواب والفصول.\n• البحث برقم المادة مباشرة.\n• نسخ المواد بنقرة واحدة.\n• التحكم بحجم الخط والوضع الليلي.\n• تمييز المواد المعدّلة.\n• خالي من الإعلانات ويعمل بدون إنترنت.",
                      style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 15),
                  const Text(
                    "✨ اختيارك لهذا التطبيق هو استثمار في الدقة، والسرعة، والاحترافية. مرجع قانوني واحد… يغنيك عن عشرات المصادر المتناقضة.",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF37474F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child:
                    const Text("فهمت", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadLaws() async {
    // استدعاء الدالة وتحميل الملفات من المجلد المحدد
    final loadedLaws = await LawLoader.loadFromFolder('assets/laws/');

    // استخراج القوانين الهامة بناءً على الترتيب المحدد
    List<Map<String, String>> tempImportant = [];
    for (String fileName in importantFilesOrder) {
      final law = loadedLaws.firstWhere(
        (l) => l['file'] == fileName,
        orElse: () => {},
      );
      if (law.isNotEmpty) {
        tempImportant.add(law);
      }
    }

    setState(() {
      laws = loadedLaws;
      filteredLaws = loadedLaws;
      importantLaws = tempImportant;
    });
  }

  String removeTatweel(String text) {
    return text.replaceAll('\u0640', '');
  }

  void _filterLaws(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredLaws = laws;
      } else {
        filteredLaws = laws.where((law) {
          String lawNameNoTatweel = removeTatweel(law['name']!.toLowerCase());
          String queryNoTatweel = removeTatweel(query.toLowerCase());
          return lawNameNoTatweel.contains(queryNoTatweel);
        }).toList();
      }
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(FavoritesSyncService.lawsKey) ?? [];
    setState(() {
      favoriteLawFiles = favs.toSet();
    });
  }

  Future<void> _toggleFavorite(String lawFile, String lawName) async {
    if (favoritesSyncService != null) {
      if (favoriteLawFiles.contains(lawFile)) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("تأكيد الإزالة", textAlign: TextAlign.center),
            content: Text("هل تريد إزالة \"$lawName\" من المفضلة؟",
                textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("إزالة", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await favoritesSyncService!.removeFavoriteLaw(context, lawFile);
      } else {
        await favoritesSyncService!.addFavoriteLaw(context, lawFile);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (favoriteLawFiles.contains(lawFile)) {
          favoriteLawFiles.remove(lawFile);
        } else {
          favoriteLawFiles.add(lawFile);
        }
      });
      await prefs.setStringList(
          FavoritesSyncService.lawsKey, favoriteLawFiles.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!favoritesLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (favoritesSyncService == null && userEmail.isNotEmpty) {
      return const Scaffold(
          body: Center(child: Text("خطأ في تهيئة خدمة المفضلة!")));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: favoritesSyncService ?? ValueNotifier<bool>(true),
        builder: (context, child) {
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              elevation: 0,
              backgroundColor: const Color.fromARGB(255, 28, 38, 43),
              title: const Text(
                "القـــوانيــــن اليمنــــية",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: false,
                    readOnly: !isSubscribed,
                    onTap: () {
                      if (!isSubscribed) {
                        _showRestrictionDialog();
                      } else {
                        _searchFocusNode.requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث عن القانون...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _filterLaws('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: laws.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: (_searchController.text.isEmpty &&
                                  importantLaws.isNotEmpty)
                              ? filteredLaws.length + 2
                              : filteredLaws.length,
                          itemBuilder: (context, index) {
                            if (_searchController.text.isEmpty &&
                                importantLaws.isNotEmpty) {
                              if (index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.star,
                                          color: Colors.orange, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "أهم القوانين المستخدمة",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF37474F),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (index <= importantLaws.length) {
                                final law = importantLaws[index - 1];
                                final isFavorite =
                                    favoriteLawFiles.contains(law["file"]!);
                                return _buildLawCard(law, isFavorite, index - 1,
                                    isImportant: true);
                              } else if (index == importantLaws.length + 1) {
                                return const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                                  child: Text(
                                    "كافة القوانين",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF37474F),
                                    ),
                                  ),
                                );
                              }
                              final normalIndex =
                                  index - (importantLaws.length + 2);
                              final law = filteredLaws[normalIndex];
                              final isFavorite =
                                  favoriteLawFiles.contains(law["file"]!);
                              return _buildLawCard(
                                  law, isFavorite, normalIndex);
                            }

                            final law = filteredLaws[index];
                            final isFavorite =
                                favoriteLawFiles.contains(law["file"]!);
                            return _buildLawCard(law, isFavorite, index);
                          },
                        ),
                ),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex == -1
                  ? 0
                  : (_selectedIndex == 1 ? 2 : _selectedIndex),
              onTap: (index) {
                if (index == 1) {
                  _showInfoDialog();
                } else {
                  _onItemTapped(index == 2 ? 1 : index);
                }
              },
              selectedItemColor: const Color(0xFF37474F),
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              elevation: 15,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'بحث شامل',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.info_outline),
                  label: 'حول',
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

  Widget _buildLawCard(Map<String, String> law, bool isFavorite, int index,
      {bool isImportant = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: isImportant ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isImportant
            ? BorderSide(color: Colors.orange.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.orange : Colors.grey,
          ),
          onPressed: () => _toggleFavorite(law["file"]!, law["name"]!),
        ),
        leading: CircleAvatar(
          radius: 15,
          backgroundColor:
              isImportant ? const Color(0xFFFFA000) : const Color(0xFF546E7A),
          child: Text(
            "${index + 1}",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          law["name"]!,
          style: TextStyle(
            fontSize: 17,
            fontWeight: isImportant ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LawArticlesScreen(
                lawFileName: law["file"]!,
                lawName: law["name"]!,
                basePath: 'assets/laws/',
              ),
            ),
          );
        },
      ),
    );
  }
}
