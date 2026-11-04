import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroScreen extends StatefulWidget {
  final Future<void> Function()? onIntroComplete; // 🔹 استدعاء عند الانتهاء

  const IntroScreen({super.key, this.onIntroComplete});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  bool _loading = false;

  Future<void> _onStartPressed() async {
    if (_loading) return;
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntro', true);

    if (widget.onIntroComplete != null) {
      await widget.onIntroComplete!();
    }

    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // الهيدر
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF5D4037),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  "التشريعات اليمنية",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // أيقونة جمالية
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: const Icon(
                  Icons.gavel,
                  color: Color(0xFF5D4037),
                  size: 70,
                ),
              ),
              const SizedBox(height: 20),
              // النص التعريفي والمميزات
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 2),
                  child: Text(
                    "مرحباً بك في تطبيق القوانين اليمنية، مرجعك الشامل لكل القوانين والتشريعات اليمنية بأحدث تعديلاتها، صُمّم التطبيق ليمنحك تجربة استخدام سهلة وسريعة، ويضع القوانين بين يديك في أي وقت حتى بدون اتصال بالإنترنت.\n\n"
                    "⭐ أهم المميزات:\n\n"
                    "• الوصول بدون إنترنت: جميع القوانين والمواد متاحة بالكامل على هاتفك حتى بدون اتصال بالإنترنت لتضمن وصولاً دائماً وسريعاً.\n\n"
                    "• تجربة مجانية شاملة لفترة محدودة: تصفح القوانين واطّلع على المحتوى بحرية قبل الاشتراك.\n\n"
                    "• أحدث التعديلات: جميع القوانين محدثة وفق آخر التغييرات الرسمية.\n\n"
                    "• بحث متقدم: أبحث بسهولة عن أي قانون أو نص مادة باستخدام كلمات مفتاحية، أو بالبحث برقم المادة مباشرة.\n\n"
                    "• تخصيص القراءة: تحكم في حجم النص، وفعّل وضع القراءة الليلي لراحة العينين.\n\n"
                    "• مفضلة المواد والقوانين: احفظ أي مادة أو قانون في المفضلة للرجوع إليها لاحقاً بسرعة.\n\n"
                    "• فهرس ذكي: تصفح القوانين عبر فهرس منظم للمواضيع مع سهولة الانتقال لأي موضوع أو فصل.\n\n"
                    "• تطويرات مستمرة: تحديثات ومزايا جديدة أسبوعياً لتحسين تجربتك باستمرار.",
                    style: TextStyle(
                      color: Color(0xFF5D4037),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.65,
                      wordSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              // زر البدء
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    onPressed: _loading ? null : _onStartPressed,
                    child: _loading
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "ابدأ الآن",
                            style: TextStyle(
                              fontSize: 21,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
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
}
