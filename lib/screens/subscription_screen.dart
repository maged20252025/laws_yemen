import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activation_screen.dart'; // تأكد أن المسار صحيح

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool hasPaidSubscription = false;
  String paidType = '';
  String paidStart = '';
  String paidEnd = '';

  String trialStart = '';
  String trialEnd = '';
  bool trialExpired = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    final prefs = await SharedPreferences.getInstance();

    // بيانات التجربة المجانية (تم التعديل ليستخدم String بدلاً من int)
    final trialStartStr = prefs.getString('trialStart');
    final trialEndStr = prefs.getString('trialEnd');
    if (trialStartStr != null && trialEndStr != null) {
      trialStart = _formatDateString(trialStartStr);
      trialEnd = _formatDateString(trialEndStr);
      final endDate = DateTime.tryParse(trialEndStr);
      trialExpired = endDate != null ? DateTime.now().isAfter(endDate) : true;
    } else {
      trialStart = '';
      trialEnd = '';
      trialExpired = true;
    }

    // بيانات الاشتراك المدفوع (كما هي)
    hasPaidSubscription = prefs.getBool('isActivated') ?? false;
    if (hasPaidSubscription) {
      paidType = prefs.getString('paidType') ?? '';
      final paidStartMs = prefs.getInt('paidStartMs');
      final paidEndMs = prefs.getInt('paidEndMs');
      paidStart = paidStartMs != null ? _formatDate(paidStartMs) : '';
      paidEnd = paidEndMs != null ? _formatDate(paidEndMs) : '';
    } else {
      paidType = '';
      paidStart = '';
      paidEnd = '';
    }

    setState(() {});
  }

  // تحويل String بصيغة ISO8601 إلى التاريخ المطلوب
  String _formatDateString(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  // تحويل int milliseconds إلى التاريخ المطلوب - للاشتراك المدفوع فقط
  String _formatDate(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  /// تعديل دالة تحويل نوع الاشتراك ليظهر بالعربي
  String getPaidTypeArabic(String type) {
    switch (type) {
      case 'daily':
      case 'daily_codes':
        return 'يـــومـــي';
      case 'monthly':
      case 'monthly_codes':
        return 'شهـــــري';
      case 'yearly':
      case 'yearly_codes':
        return 'سنـــــوي';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F3F8),
      body: Column(
        children: [
          // شريط علوي متدرج مع زر الرجوع
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 244, 245, 247),
                      Color(0xFF1A237E)
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "تفاصيل الاشتراك",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 60, 78, 121),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  _buildTrialSection(),
                  const SizedBox(height: 18),
                  hasPaidSubscription
                      ? _buildPaidSection()
                      : Column(
                          children: [
                            _buildNoPaidSection(),
                            const SizedBox(height: 18),
                            _buildActivateButton(context),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialSection() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "التجربة المجانية",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.right,
              ),
              const Divider(),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    trialExpired
                        ? Icons.close_rounded
                        : Icons.check_circle_rounded,
                    color: trialExpired ? Colors.red : Colors.green,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "الحالة:",
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    trialExpired ? "منتهية" : "نشطة",
                    style: TextStyle(
                      color: trialExpired ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text("تاريخ البـــدء: $trialStart",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                  textAlign: TextAlign.right),
              Text("تاريخ الانتهاء: $trialEnd",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                  textAlign: TextAlign.right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaidSection() {
    bool paidExpired = false;
    if (paidEnd.isNotEmpty) {
      try {
        final parts = paidEnd.split('/');
        if (parts.length == 3) {
          final paidEndDate = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          paidExpired = DateTime.now().isAfter(paidEndDate);
        }
      } catch (_) {
        paidExpired = false;
      }
    }
    String paidTypeArabic = getPaidTypeArabic(paidType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "الاشتراك المدفوع",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.right,
              ),
              const Divider(),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    paidExpired
                        ? Icons.close_rounded
                        : Icons.check_circle_rounded,
                    color: paidExpired ? Colors.red : Colors.green,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "الحالة:",
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    paidExpired ? "منتهي" : "نشط",
                    style: TextStyle(
                      color: paidExpired ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text("نوع الاشتراك: $paidTypeArabic",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                  textAlign: TextAlign.right),
              Text("تاريخ البـــدء: $paidStart",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                  textAlign: TextAlign.right),
              Text("تاريخ الانتهاء: $paidEnd",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                  textAlign: TextAlign.right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoPaidSection() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              "لا يوجد اشتراك مدفوع حتى الآن",
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivateButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.vpn_key, color: Colors.white),
        label: const Text("تفعيل الاشتراك المدفوع"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivationScreen()),
          ).then((_) {
            _loadSubscriptionDetails(); // تحديث البيانات بعد العودة
          });
        },
      ),
    );
  }
}
