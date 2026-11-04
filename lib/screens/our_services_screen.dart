import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ألوان متناسقة مع الشاشة الرئيسية
const Color primaryDark = Color(0xFF101D3D);
const Color accentGold = Color(0xFFC5A358);
const Color bgSilver = Color(0xFFF4F7FA);

class OurServicesScreen extends StatefulWidget {
  const OurServicesScreen({Key? key}) : super(key: key);

  @override
  State<OurServicesScreen> createState() => _OurServicesScreenState();
}

class _OurServicesScreenState extends State<OurServicesScreen> {
  // null = الشاشة الرئيسية للخدمات
  // 1 = تفاصيل أحكام المحكمة العليا
  // 2 = تفاصيل المراجع القانونية
  int? _selectedService;

  Future<void> _openWhatsApp(String serviceName) async {
    const phone = "+967777533034";
    final message = "مرحباً، أود الاستفسار عن خدمة: $serviceName";
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر فتح الواتساب")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedService != null) {
          setState(() => _selectedService = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: bgSilver,
        appBar: AppBar(
          title: Text(
              _selectedService == null ? 'خدماتنا الأخرى' : 'تفاصيل الخدمة',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: primaryDark,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: _selectedService != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedService = null))
              : null,
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildCurrentContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentContent() {
    if (_selectedService == 1) {
      return Column(
        children: [
          _buildServiceCard(
            context,
            title: "توفير أحكام المحكمة العليا حسب الموضوع",
            content:
                "عزيزي المستخدم،\nتتوفر لدينا أحكام المحكمة العليا مصنّفة حسب الموضوع الذي تبحث عنه.\nإذا كنت مهتماً بهذه الخدمة، يرجى التواصل معنا عبر الواتساب وتزويدنا بالموضوع الذي تبحث عنه وسنقوم بتوفير أحكام المحكمة العليا ذات الصلة في أقرب وقت ممكن.",
            icon: Icons.gavel_rounded,
            serviceName: "أحكام المحكمة العليا",
          ),
          const SizedBox(height: 25),
          const Text("يمكنك الإطلاع على بعض المواضيع من هنا",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryDark)),
          const SizedBox(height: 15),
          _buildActionSearchButton(),
        ],
      );
    } else if (_selectedService == 2) {
      return _buildServiceCard(
        context,
        title: "توفير مراجع قانونية حسب الطلب",
        content:
            "عزيزي المستخدم\nإذا كنت تبحث عن مراجع قانونية معينه وليس لديك الوقت للبحث عنها في الانترنت ماعليك سوى مراسلتنا على الواتساب واعطاءنا اسماء المراجع التي تبحث عنها وسنقوم نيابة عنك بالبحث عنها وموافاتك بها.",
        icon: Icons.menu_book_rounded,
        serviceName: "المراجع القانونية",
      );
    } else {
      return Column(
        children: [
          _buildMainOption(
              title: "أحكام المحكمة العليا",
              icon: Icons.gavel_rounded,
              index: 1),
          const SizedBox(height: 20),
          _buildMainOption(
              title: "توفير مراجع قانونية حسب الطلب",
              icon: Icons.menu_book_rounded,
              index: 2),
        ],
      );
    }
  }

  Widget _buildMainOption(
      {required String title, required IconData icon, required int index}) {
    return InkWell(
      onTap: () => setState(() => _selectedService = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
          border: Border.all(color: accentGold.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 60, color: accentGold),
            const SizedBox(height: 15),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const JudgmentsIndicesScreen())),
        icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
        label: const Text("استعراض مواضيع الأحكام",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: accentGold,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15))),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context,
      {required String title,
      required String content,
      required IconData icon,
      required String serviceName}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 50, color: accentGold),
          const SizedBox(height: 15),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryDark)),
          const Divider(height: 30),
          Text(content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: Colors.black87)),
          const SizedBox(height: 20),
          IconButton(
            icon:
                const Icon(Icons.chat_outlined, color: Colors.green, size: 45),
            onPressed: () => _openWhatsApp(serviceName),
          ),
          const Text("تواصل معنا الآن عبر الواتساب",
              style:
                  TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// شاشة التبويبات السبعة
class JudgmentsIndicesScreen extends StatefulWidget {
  const JudgmentsIndicesScreen({Key? key}) : super(key: key);

  @override
  State<JudgmentsIndicesScreen> createState() => _JudgmentsIndicesScreenState();
}

class _JudgmentsIndicesScreenState extends State<JudgmentsIndicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _faharasData = {};
  bool _isLoading = true;

  final List<String> _tabs = [
    'الدائرة الادارية',
    'الدائرة الشخصية',
    'الدائرة التجارية',
    'الدائرة المدنية',
    'الدائرة الجزائية',
    'الدائرة العسكرية',
    'دائرة فحص الطعون',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadJsonData();
  }

  Future<void> _loadJsonData() async {
    try {
      final String response =
          await rootBundle.loadString('assets/alahkam/faharas alahkam.json');
      final data = json.decode(response);
      setState(() {
        _faharasData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSilver,
      appBar: AppBar(
        title:
            const Text('فهارس الأحكام', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryDark,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tabs[_tabController.index],
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_circle_outlined,
                      color: accentGold),
                  items: _tabs.map((String tab) {
                    return DropdownMenuItem<String>(
                      value: tab,
                      child: Text(
                        tab,
                        style: const TextStyle(
                            color: primaryDark, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _tabController.index = _tabs.indexOf(newValue);
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryDark))
            : _buildTabContent(_tabs[_tabController.index]),
      ),
    );
  }

  Widget _buildTabContent(String tabName) {
    final List titles = _faharasData[tabName] ?? [];
    if (titles.isEmpty) {
      return const Center(child: Text("لا توجد عناوين متاحة حالياً"));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(15),
      itemCount: titles.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return ListTile(
          onTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Container(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "إذا أردت الحصول على أحكام عليا حول هذا الموضوع، يرجى التواصل بنا عبر الواتساب",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryDark),
                      ),
                      const SizedBox(height: 20),
                      IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: accentGold, size: 40),
                        onPressed: () {
                          Navigator.pop(context);
                          _openWhatsAppInIndices(titles[index].toString());
                        },
                      ),
                      const Text("إرسال طلب",
                          style: TextStyle(
                              color: accentGold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            );
          },
          leading: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: accentGold),
          title: Text(titles[index].toString(),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        );
      },
    );
  }

  Future<void> _openWhatsAppInIndices(String subject) async {
    const phone = "+967777533034";
    final message = "مرحباً، أود الحصول على أحكام عليا بخصوص موضوع: $subject";
    final url = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
