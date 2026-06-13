import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/native_file_picker.dart';
import '../../core/glass_theme.dart';
import '../../core/subscription_guard.dart';
import '../../providers/auth_provider.dart';
import '../../screens/subscriptions/subscription_screen.dart';

class AiGenerateExamScreen extends StatefulWidget {
  final String? initialFilePath;
  const AiGenerateExamScreen({super.key, this.initialFilePath});

  @override
  State<AiGenerateExamScreen> createState() => _AiGenerateExamScreenState();
}

class _AiGenerateExamScreenState extends State<AiGenerateExamScreen> {
  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');
  final _countCtrl = TextEditingController(text: '10');
  bool _generating = false;
  String? _error;
  File? _selectedFile;
  String? _selectedFileName;
  String _selectedSubject = '';

  final _subjects = [
    '', 'رياضيات', 'فيزياء', 'كيمياء', 'أحياء', 'لغة عربية',
    'لغة إنجليزية', 'تاريخ', 'جغرافيا', 'تربية دينية',
    'علوم', 'геولوجيا', 'فلسفة', 'علم نفس',
  ];

  @override
  void initState() {
    super.initState();
    _checkSubscriptionAndInit();
  }

  Future<void> _checkSubscriptionAndInit() async {
    final auth = context.read<AuthProvider>();
    final hasSubscription = auth.hasSubscription;

    if (!hasSubscription) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSubscriptionRequiredDialog();
      });
      return;
    }

    if (widget.initialFilePath != null) {
      _selectedFile = File(widget.initialFilePath!);
      _selectedFileName = widget.initialFilePath!.split('/').last;
    }
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // منع الرجوع - توجيه لصفحة الاشتراك
          Navigator.of(ctx).pop();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          );
        },
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('اشتراك مطلوب', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('يجب الاشتراك في باقة أولاً لإنشاء اختبارات بالذكاء الاصطناعي'),
          actions: [
            // إزالة زر "إلغاء" - لا يمكن تجاوز الاشتراك
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: const Text('الذهاب للاشتراكات'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final uri = await NativeFilePicker.pickAny();
    if (uri == null) return;

    try {
      final filePath = uri.replaceFirst('file://', '');
      final file = File(filePath);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الملف كبير جداً (الحد الأقصى 20MB)'), backgroundColor: GlassTheme.red),
          );
        }
        return;
      }
      setState(() {
        _selectedFile = file;
        _selectedFileName = filePath.split('/').last;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في قراءة الملف: $e'), backgroundColor: GlassTheme.red),
        );
      }
    }
  }

  Future<void> _generate() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل عنوان الاختبار');
      return;
    }
    if (_selectedFile == null) {
      setState(() => _error = 'ارفع ملف PDF أو صورة أولاً');
      return;
    }

    setState(() { _generating = true; _error = null; });

    try {
      final fileName = _selectedFile!.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      final isPdf = ext == 'pdf';
      final mimeType = isPdf ? 'application/pdf' : 'image/$ext';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFile!.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        'title': _titleCtrl.text.trim(),
        'subject': _selectedSubject.isEmpty ? null : _selectedSubject,
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()) ?? 60,
        'question_count': int.tryParse(_countCtrl.text.trim()) ?? 10,
      });

      final resp = await ApiService().aiDio.post('/exams/ai-generate', data: formData);

      if (mounted && resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الاختبار كمسودة - يمكنك مراجعته ونشره'), backgroundColor: GlassTheme.green),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      String msg = 'فشل إنشاء الاختبار';
      if (e.response?.data is Map) msg = e.response?.data['detail'] ?? msg;
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = 'حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubscriptionRequiredWidget(
      child: Scaffold(
        backgroundColor: GlassTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('اختبار بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _generating ? null : _pickFile,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: _selectedFile != null ? GlassTheme.indigo.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedFile != null ? GlassTheme.indigo : Colors.white.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: _selectedFile != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_selectedFileName?.endsWith('.pdf') == true ? Icons.picture_as_pdf : Icons.image,
                              size: 48, color: GlassTheme.indigo),
                          const SizedBox(height: 12),
                          Text(_selectedFileName ?? 'ملف محدد', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('اضغط لتغيير الملف', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('ارفع ملف PDF أو صورة', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('PDF أو JPG أو PNG — حد أقصى 20MB', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _buildField(_titleCtrl, 'عنوان الاختبار *', Icons.title),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubject,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.5)),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  items: _subjects.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.isEmpty ? 'المادة (اختياري)' : s),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildField(_durationCtrl, 'المدة (دقيقة)', Icons.timer, isNumber: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_countCtrl, 'عدد الأسئلة', Icons.format_list_numbered, isNumber: true)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlassTheme.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: GlassTheme.indigo.withValues(alpha: 0.7), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيقوم الذكاء الاصطناعي بقراءة المحتوى وتوليد أسئلة اختبار متعددة ومقالية',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: GlassTheme.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: const TextStyle(color: GlassTheme.red, fontSize: 13)),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _generating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _generating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Text('جاري التوليد بالذكاء الاصطناعي...', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('إنشاء اختبار بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GlassTheme.indigo)),
      ),
    );
  }
}
