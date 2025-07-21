import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Process? backendProcess;

Future<bool> runBackendServer() async {
  try {
    // جرب مسارات مختلفة للـ backend.exe
    final possiblePaths = [
      'backend.exe',
      './backend.exe',
      '../backend.exe',
      'assets/backend.exe',
      'data/flutter_assets/assets/backend.exe',
      'windows/runner/Release/backend.exe',
      'build/windows/x64/runner/Release/backend.exe',
      'build/windows/x64/runner/Debug/backend.exe', // إضافة هذا المسار
      '../../backend.exe', // إضافة هذا المسار
      '../../../backend.exe', // إضافة هذا المسار
    ];

    String? foundPath;
    for (String path in possiblePaths) {
      final file = File(path);
      if (await file.exists()) {
        foundPath = path;
        print('✅ تم العثور على backend.exe في: $foundPath');
        break;
      }
    }

    if (foundPath == null) {
      print('❌ لم يتم العثور على backend.exe في المسارات المتوقعة');
      print('المسارات التي تم البحث فيها:');
      for (String path in possiblePaths) {
        print('  - $path');
      }
      return false;
    }

    // تحقق من أن الخادم ليس يشتغل مسبقاً
    if (await checkServerStatus()) {
      print('✅ الخادم يشتغل مسبقاً');
      return true;
    }

    print('🔄 تشغيل backend.exe...');

    // تشغيل الـ backend
    backendProcess = await Process.start(
      foundPath,
      [],
      mode: ProcessStartMode.normal, // تغيير من detached إلى normal
    );

    // استمع لمخرجات الخادم
    backendProcess?.stdout.transform(utf8.decoder).listen((data) {
      print('Backend stdout: $data');
    });

    backendProcess?.stderr.transform(utf8.decoder).listen((data) {
      print('Backend stderr: $data');
    });

    print('✅ backend.exe تم تشغيله');

    // انتظار للخادم يبدأ (وقت أطول)
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (await checkServerStatus()) {
        print('✅ الخادم جاهز بعد ${i + 1} ثواني');
        return true;
      }
    }

    print('❌ انتهت مهلة انتظار تشغيل الخادم');
    return false;
  } catch (e) {
    print('❌ فشل تشغيل backend.exe: $e');
    return false;
  }
}

Future<bool> checkServerStatus() async {
  try {
    final response = await http
        .get(Uri.parse('http://localhost:8080/get?id=test'))
        .timeout(const Duration(seconds: 2));

    return response.statusCode == 200 || response.statusCode == 404;
  } catch (e) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool serverStarted = false;

  if (!kIsWeb && Platform.isWindows) {
    print('🔄 محاولة تشغيل الخادم...');
    serverStarted = await runBackendServer();

    try {
      await Window.initialize();
      await Window.setEffect(effect: WindowEffect.acrylic);
      await Window.showWindowControls();
    } catch (e) {
      print('تحذير: فشل في تطبيق تأثيرات النافذة: $e');
    }
  }

  runApp(MyApp(serverStarted: serverStarted));
}

class MyApp extends StatelessWidget {
  final bool serverStarted;
  const MyApp({super.key, required this.serverStarted});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Arial'),
      home: GlassForm(serverStarted: serverStarted),
    );
  }
}

class GlassForm extends StatefulWidget {
  final bool serverStarted;
  const GlassForm({super.key, required this.serverStarted});

  @override
  State<GlassForm> createState() => _GlassFormState();
}

class _GlassFormState extends State<GlassForm> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final couponController = TextEditingController();
  final monayController = TextEditingController();

  String resultText = 'جاهز للعمل';
  bool isServerOnline = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isServerOnline = widget.serverStarted;
    if (widget.serverStarted) {
      resultText = '✅ الخادم يعمل بنجاح';
    } else {
      resultText = '❌ فشل تشغيل الخادم - ضع backend.exe في نفس مجلد التطبيق';
    }

    // فحص دوري للخادم كل 30 ثانية
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) checkServerPeriodically();
    });
  }

  void checkServerPeriodically() async {
    if (!mounted) return;

    final wasOnline = isServerOnline;
    final isOnline = await checkServerStatus();

    if (mounted && wasOnline != isOnline) {
      setState(() {
        isServerOnline = isOnline;
        if (isOnline && !wasOnline) {
          resultText = '✅ الخادم متصل الآن';
        } else if (!isOnline && wasOnline) {
          resultText = '❌ انقطع الاتصال بالخادم';
        }
      });
    }

    // فحص كل 30 ثانية
    Future.delayed(const Duration(seconds: 30), checkServerPeriodically);
  }

  Future<void> testConnection() async {
    setState(() {
      resultText = '🔄 فحص الاتصال...';
      isLoading = true;
    });

    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/get?id=test'))
          .timeout(const Duration(seconds: 5));

      setState(() {
        isServerOnline = true;
        resultText =
            '✅ الخادم متصل ويعمل بنجاح (الكود: ${response.statusCode})';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isServerOnline = false;
        resultText = '❌ الخادم غير متاح - تأكد من تشغيل backend.exe';
        isLoading = false;
      });
    }
  }

  Future<void> sendAddRequest() async {
    if (!isServerOnline) {
      setState(() => resultText = '❌ الخادم غير متصل');
      return;
    }

    if (couponController.text.trim().isEmpty) {
      setState(() => resultText = '❌ يجب إدخال كود الكوبون');
      return;
    }

    setState(() {
      resultText = '🔄 إرسال البيانات...';
      isLoading = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/add');
      final body = jsonEncode({
        "idcoupon": couponController.text.trim(),
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "monay": int.tryParse(monayController.text.trim()) ?? 0,
      });

      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      setState(() {
        if (response.statusCode == 201) {
          resultText = '✅ تمت إضافة العميل بنجاح';
          // مسح الحقول بعد الإضافة الناجحة
          nameController.clear();
          phoneController.clear();
          couponController.clear();
          monayController.clear();
        } else {
          resultText = '❌ خطأ (${response.statusCode}): ${response.body}';
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        resultText = '❌ فشل الإرسال: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> sendUpdateRequest() async {
    if (!isServerOnline) {
      setState(() => resultText = '❌ الخادم غير متصل');
      return;
    }

    if (couponController.text.trim().isEmpty) {
      setState(() => resultText = '❌ يجب إدخال كود الكوبون');
      return;
    }

    final monayValue = int.tryParse(monayController.text.trim()) ?? 0;
    if (monayValue <= 0) {
      setState(() => resultText = '❌ يجب إدخال مبلغ صحيح أكبر من صفر');
      return;
    }

    setState(() {
      resultText = '🔄 تحديث البيانات...';
      isLoading = true;
    });

    try {
      final url = Uri.parse('http://localhost:8080/update');
      final body = jsonEncode({
        "idcoupon": couponController.text.trim(),
        "monay": monayValue,
      });

      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      setState(() {
        if (response.statusCode == 200) {
          resultText = '✅ تم تحديث المبلغ بنجاح';
          monayController.clear();
        } else {
          resultText = '❌ خطأ (${response.statusCode}): ${response.body}';
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        resultText = '❌ فشل التحديث: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> fetchData() async {
    if (!isServerOnline) {
      setState(() => resultText = '❌ الخادم غير متصل');
      return;
    }

    if (couponController.text.trim().isEmpty) {
      setState(() => resultText = '❌ يجب إدخال كود الكوبون');
      return;
    }

    setState(() {
      resultText = '🔄 جلب البيانات...';
      isLoading = true;
    });

    try {
      final id = couponController.text.trim();
      final url = Uri.parse('http://localhost:8080/get?id=$id');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          nameController.text = data['name']?.toString() ?? '';
          phoneController.text = data['phone']?.toString() ?? '';
          monayController.text = data['monay']?.toString() ?? '0';
          resultText =
              '✅ تم جلب البيانات - العداد: ${data['counter'] ?? 0}\n ${data['monay']} ريال ';
          isLoading = false;
        });
      } else {
        setState(() {
          resultText = '❌ (${response.statusCode}): ${response.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        resultText = '❌ فشل جلب البيانات: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void clearInputs() {
    nameController.clear();
    phoneController.clear();
    couponController.clear();
    monayController.clear();
    setState(() => resultText = 'تم تفريغ الحقول');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('إدارة العملاء ${isServerOnline ? '🟢' : '🔴'}'),
        backgroundColor: Colors.black.withOpacity(0.3),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : testConnection,
            tooltip: 'فحص الاتصال',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  textTitle('معلومات العميل'),
                  const SizedBox(height: 20),
                  customInput(nameController, 'اسم العميل'),
                  const SizedBox(height: 15),
                  customInput(
                    phoneController,
                    'رقم الهاتف',
                    TextInputType.phone,
                  ),
                  const SizedBox(height: 15),
                  customInput(couponController, 'كود الكوبون (مطلوب)'),
                  const SizedBox(height: 15),
                  customInput(monayController, 'المبلغ', TextInputType.number),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: customButton(
                          text: 'إضافة عميل',
                          color: Colors.green,
                          onPressed: (isServerOnline && !isLoading)
                              ? sendAddRequest
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: customButton(
                          text: 'تحديث المبلغ',
                          color: Colors.orange,
                          onPressed: (isServerOnline && !isLoading)
                              ? sendUpdateRequest
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: customButton(
                          text: 'جلب البيانات',
                          color: Colors.blue,
                          onPressed: (isServerOnline && !isLoading)
                              ? fetchData
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: customButton(
                          text: 'تفريغ الحقول',
                          color: Colors.red,
                          onPressed: isLoading ? null : clearInputs,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: customButton(
                      text: '🔄 فحص الاتصال',
                      color: Colors.purple,
                      onPressed: isLoading ? null : testConnection,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      resultText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget textTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 24,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget customInput(
    TextEditingController controller,
    String label, [
    TextInputType type = TextInputType.text,
  ]) {
    return TextField(
      controller: controller,
      keyboardType: type,
      textDirection: TextDirection.rtl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget customButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  void dispose() {
    // إيقاف الخادم عند إغلاق التطبيق
    backendProcess?.kill();
    nameController.dispose();
    phoneController.dispose();
    couponController.dispose();
    monayController.dispose();
    super.dispose();
  }
}
