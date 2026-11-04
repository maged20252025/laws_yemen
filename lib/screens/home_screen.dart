import 'package:flutter/material.dart';
import 'all_indices_screen.dart';
import 'law_selection_screen.dart';
import 'regulations_selection_screen.dart';
import 'prosecution_selection_screen.dart';
import 'global_search_screen.dart';
import 'judgments_selection_screen.dart'; // إضافة ملف القواعد القضائية
import 'our_services_screen.dart';
// إضافة الاستيرادات اللازمة للقائمة الجانبية
import 'Subscription_screen.dart';
import 'activation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../version/version.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // تعريف المفتاح والمتغيرات اللازمة للقائمة الجانبية
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String userEmail = "";
  String _subscriptionStatus = ""; // ✅ المتغير الجديد لحالة الاشتراك
  bool isLimitedMode = false; // 🆕 لمتابعة حالة الوضع المحدود
  bool isPaid = false; // 🆕 لمتابعة حالة الاشتراك الفعلي

  @override
  void initState() {
    super.initState();
    _loadUserStatus(); // ✅ تم تغيير الدالة لدالة شاملة
  }

  // ✅ دالة جلب البيانات وفحص حالة الاشتراك بدقة
  Future<void> _loadUserStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final bool paidStatus = prefs.getBool('isActivated') ?? false;
    final bool limitedStatus = prefs.getBool('isLimitedModeActive') ?? false;

    String status = "";
    if (paidStatus) {
      status = "مشترك";
    } else if (limitedStatus) {
      status = "تجربة مجانية محدودة";
    } else {
      status = "التجربة المجانية";
    }

    setState(() {
      userEmail = prefs.getString('userEmail') ?? "";
      _subscriptionStatus = status;
      isPaid = paidStatus; // 🆕 تحديث الحالة
      isLimitedMode = limitedStatus; // 🆕 تحديث الحالة
    });
  }

  // دالة التواصل عبر واتساب
  Future<void> _openWhatsApp() async {
    const phone = "+967777533034";
    const message = "مرحباً، أود الاستفسار عن التطبيق.";
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر فتح الرابط")),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final confirmExit = await showDialog<bool>(
      context: context,
      builder: (context) => _buildCenteredDialog(
        title: "تأكيد الخروج",
        content: "هل تريد الخروج من التطبيق؟",
        confirmText: "نعم",
        cancelText: "لا",
        confirmColor: Colors.red,
      ),
    );
    return confirmExit ?? false;
  }

  Widget _buildCenteredDialog({
    required String title,
    required String content,
    required String confirmText,
    required String cancelText,
    required Color confirmColor,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // تعريف الألوان الجديدة
    const Color primaryDark = Color(0xFF101D3D); // كحلي عميق جداً
    const Color accentGold = Color(0xFFC5A358); // ذهبي ملكي
    const Color bgSilver = Color(0xFFF4F7FA); // خلفية فضية فاتحة

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: bgSilver,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white, size: 28),
          title: const Text(
            'الرئيســـية',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
          centerTitle: true,
          elevation: 8,
          shadowColor: primaryDark.withOpacity(0.5),
          toolbarHeight: 70,
          backgroundColor: primaryDark,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
        ),
        endDrawer: Drawer(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: primaryDark),
                  currentAccountPicture: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentGold, width: 2),
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: AssetImage("assets/images/logo.png"),
                    ),
                  ),
                  accountName: Transform.translate(
                    offset: const Offset(0, 12),
                    child: const Text(
                      "القوانين اليمنية",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  accountEmail: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userEmail.isNotEmpty ? userEmail : "غير مسجل"),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _subscriptionStatus == "مشترك"
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _subscriptionStatus == "مشترك"
                                ? Colors.green
                                : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _subscriptionStatus,
                          style: TextStyle(
                            color: _subscriptionStatus == "مشترك"
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.credit_card, color: primaryDark),
                        title: const Text("اشتراكي",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.chat, color: Colors.green),
                        title: const Text("تواصل بنا",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          _openWhatsApp();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.grid_view_rounded,
                            color: primaryDark),
                        title: const Text("خدماتنا الأخرى",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const OurServicesScreen()));
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Text("الإصدار: $appVersion",
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildMenuCard(
                  title: 'القوانين اليمنية',
                  subtitle: ' بآخر التعديلات',
                  icon: Icons.gavel_rounded,
                  primaryColor: primaryDark,
                  accentColor: accentGold,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LawSelectionScreen())),
                  isFullWidth: true,
                ),
                const SizedBox(height: 15),
                _buildMenuCard(
                  title: 'القواعد القضائية',
                  subtitle: 'مبادئ المحكمة العليا',
                  icon: Icons.account_balance_rounded,
                  primaryColor: primaryDark,
                  accentColor: accentGold,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const JudgmentsSelectionScreen())),
                  isFullWidth: true,
                ),
                const SizedBox(height: 15),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildMenuCard(
                          title: 'اللوائح',
                          subtitle: '',
                          icon: Icons.description_outlined,
                          primaryColor: primaryDark,
                          accentColor: accentGold,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const RegulationsSelectionScreen(
                                          storageKey: 'favorite_regulations'))),
                          isFullWidth: false,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildMenuCard(
                          title: 'تعليمات النيابة',
                          subtitle: '',
                          icon: Icons.account_balance_rounded,
                          primaryColor: primaryDark,
                          accentColor: accentGold,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ProsecutionSelectionScreen(
                                          storageKey: 'favorite_prosecution'))),
                          isFullWidth: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (const bool.fromEnvironment('dart.vm.product') == false)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                width: double.infinity,
                height: 50,
                child: FloatingActionButton.extended(
                  heroTag: 'indices_btn',
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AllIndicesScreen()));
                  },
                  backgroundColor: Colors.orange.shade800,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  icon: const Icon(Icons.format_list_bulleted_rounded,
                      color: Colors.white, size: 24),
                  label: const Text(
                    "فهارس جميع الأقسام",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              height: 60,
              child: FloatingActionButton.extended(
                heroTag: 'search_btn',
                onPressed: () {
                  if (isLimitedMode && !isPaid) {
                    _showRestrictionDialog();
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GlobalSearchScreen(
                                searchPath: 'all', title: 'البحث الشامل')));
                  }
                },
                backgroundColor: primaryDark,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: accentGold, width: 1),
                ),
                icon: const Icon(Icons.search_rounded,
                    color: accentGold, size: 28),
                label: const Text(
                  "البحث الشامل في جميع الأقسام",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 دالة لإظهار رسالة تنبيه لمستخدمي الوضع المحدود (تم نقلها لداخل الكلاس)
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
                backgroundColor: const Color(0xFF101D3D)),
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
}

Widget _buildMenuCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color primaryColor,
  required Color accentColor,
  required VoidCallback onTap,
  required bool isFullWidth,
}) {
  return Container(
    width: double.infinity,
    height: isFullWidth ? 160 : null,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.15),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isFullWidth ? 10 : 20,
            ),
            decoration: BoxDecoration(
              border:
                  Border.all(color: primaryColor.withOpacity(0.05), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, primaryColor.withOpacity(0.02)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isFullWidth ? 45 : 38, color: accentColor),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isFullWidth ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    height: 1.2,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
