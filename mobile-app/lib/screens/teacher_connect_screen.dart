import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class TeacherConnectScreen extends StatefulWidget {
  const TeacherConnectScreen({super.key});

  @override
  State<TeacherConnectScreen> createState() => _TeacherConnectScreenState();
}

class _TeacherConnectScreenState extends State<TeacherConnectScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _parsingBarcode = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();

    // Listen for hardware barcode scanner input (types the full URI)
    _codeController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_parsingBarcode) return;
    final text = _codeController.text;
    if (text.endsWith('\n')) {
      _parsingBarcode = true;
      final clean = text.trim();
      String? code;
      if (clean.startsWith('darsak://teacher/')) {
        code = _extractTeacherCode(clean);
      } else if (clean.startsWith('TCH-') && clean.length <= 20) {
        code = clean;
      } else {
        code = clean;
      }
      if (code != null && code.isNotEmpty) {
        _codeController.text = code;
        _codeController.selection = TextSelection.fromPosition(
          TextPosition(offset: code.length),
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _connect(code: code);
        });
      }
      _parsingBarcode = false;
    }
  }

  String? _extractTeacherCode(String raw) {
    try {
      final clean = raw.trim().split('\n').first.trim();
      if (clean.startsWith('darsak://teacher/')) {
        final parts = clean.split('/');
        if (parts.length >= 4) {
          final code = parts[3];
          if (code.isNotEmpty) return code;
        }
      }
      if (clean.length <= 20 && RegExp(r'^TCH[-:][A-Z0-9]+$').hasMatch(clean)) {
        return clean.replaceAll(':', '-');
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _codeController.removeListener(_onInputChanged);
    _codeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _connect({String? code}) async {
    final teacherCode = (code ?? _codeController.text).trim();
    if (teacherCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('أدخل كود المعلم'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _api.verifyTeacher(teacherCode);
      if (!mounted) return;
      await _storage.write(
          key: AppConstants.storageKeyTeacherCode,
          value: result['teacher_code'] as String);
      await _storage.write(
          key: AppConstants.storageKeyTeacherName,
          value: result['teacher_name'] as String);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LoginScreen(teacherCode: result['teacher_code'] as String),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('كود المعلم غير صحيح'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    ).then((teacherCode) {
      if (teacherCode != null && teacherCode is String) {
        _codeController.text = teacherCode;
        _connect(code: teacherCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.qr_code_scanner,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'الاتصال بالمعلم',
                      style: TextStyle(
                        color: Color(0xFFF5F5F5),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'امسح باركود المعلم أو أدخل الكود يدوياً',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _codeController,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF5F5F5),
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        labelText: 'كود المعلم',
                        hintText: 'TCH-XXXXXX',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(Icons.person,
                            color: Color(0xFF2563EB)),
                        filled: true,
                        fillColor: const Color(0xFF141414),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _connect(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text(
                          'مسح QR Code',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF2A2A2A)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _connect(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          disabledBackgroundColor:
                              const Color(0xFF2563EB).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'اتصال',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('تسجيل دخول الطالب مباشرة'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _controller;
  bool _found = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    _found = true;
    final teacherCode = _extractCodeFromRaw(raw);

    if (teacherCode != null) {
      Navigator.pop(context, teacherCode);
    } else {
      _found = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('باركود غير صالح'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  String? _extractCodeFromRaw(String raw) {
    final clean = raw.trim();
    if (clean.startsWith('darsak://teacher/')) {
      final parts = clean.split('/');
      if (parts.length >= 4) {
        final code = parts[3];
        if (code.isNotEmpty) return code;
      }
    }
    // TCH-XXXXXX or TCH:XXXXXX
    if (clean.length <= 20 && RegExp(r'^TCH[-:][A-Z0-9]+$').hasMatch(clean)) {
      return clean.replaceAll(':', '-');
    }
    // Plain teacher code
    if (clean.length <= 20 && RegExp(r'^[A-Z0-9\-]+$').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح QR Code'),
        centerTitle: true,
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        overlayBuilder: (context, constraints) => Container(
          alignment: Alignment.center,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
