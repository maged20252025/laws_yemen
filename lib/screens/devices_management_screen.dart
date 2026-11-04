import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevicesManagementScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final int maxPhones;
  final bool isFromLogin;

  const DevicesManagementScreen({
    Key? key,
    required this.userId,
    required this.userEmail,
    this.maxPhones = 10,
    this.isFromLogin = false,
  }) : super(key: key);

  @override
  State<DevicesManagementScreen> createState() =>
      _DevicesManagementScreenState();
}

class _DevicesManagementScreenState extends State<DevicesManagementScreen> {
  late CollectionReference devicesRef;

  @override
  void initState() {
    super.initState();
    devicesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('devices');
  }

  Future<void> _deleteDevice(String deviceId) async {
    await devicesRef.doc(deviceId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم حذف الجهاز بنجاح")),
    );

    // لا نحتاج لإعادة توجيه المستخدم لشاشة الدخول لأن الدخول لم يعد مقيداً بعدد الأجهزة
    // سنكتفي بإظهار رسالة الحذف فقط
  }

  // إزالة البصمة من وثيقة المستخدم (حقل deviceFingerprints)
  Future<void> _removeFingerprintFromUserDoc(String fingerprint) async {
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);
    await userDocRef.set({
      'deviceFingerprints': FieldValue.arrayRemove([fingerprint])
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأجهزة المرتبطة'),
        backgroundColor: Colors.blueAccent,
        // ⭐️ التعديل الأول: توسيط العنوان
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'قائمة الأجهزة المسجلة للدخول بهذا الحساب',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: devicesRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("لا توجد أجهزة مسجلة."));
                }

                final devices = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = devices[index].data() as Map<String, dynamic>;
                    final deviceId =
                        devices[index].id; // fingerprint (مفتاح المستند)
                    final deviceModel = data['deviceName'] ?? 'جهاز غير معروف';
                    final deviceType = data['deviceType'] ?? 'غير محدد';
                    final deviceStatus = data['status'] ?? '';
                    final addedAt = data['addedAt'] ?? '';

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: Icon(
                          deviceType == 'phone'
                              ? Icons.smartphone
                              : Icons.laptop,
                          color: Colors.teal,
                          size: 34,
                        ),
                        title: Text(
                          deviceModel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        // ⭐️ التعديل الثاني: إخفاء سطر الـ ID
                        subtitle: Text(
                          'نوع: $deviceType\nالحالة: $deviceStatus\nتاريخ الإضافة: $addedAt',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            // الـ ID ما زال يُستخدم هنا في المنطق
                            await _deleteDevice(deviceId);
                            await _removeFingerprintFromUserDoc(deviceId);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
