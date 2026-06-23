import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/subscription_guard.dart';
import '../subscription/subscription_screen.dart';

class AiGenerateExamScreen extends StatefulWidget {
  const AiGenerateExamScreen({super.key});

  @override
  State<AiGenerateExamScreen> createState() => _AiGenerateExamScreenState();
}

class _AiGenerateExamScreenState extends State<AiGenerateExamScreen> {
  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');
  final _countCtrl = TextEditingController(text: '10');
  bool _generating = false;
  String? _error;
  String? _selectedFilePath;
  String? _selectedFileName;
  String _selectedSubject = '';

  final _subjects = [
    '',
    'رياضيات',
    'فيزياء',
    'كيمياء',
    'أحياء',
    'لغة عربية',
    'لغة إنجليزية',
    'تاريخ',
    'جغرافيا',
    'تربية دينية',
    'علوم',
    'геولوجيا',
    'فلسفة',
    'علم نفس',
  ];

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  void _checkSubscription() {
    WidgetsBinding.instance.addPostFrameCallback((_) => checkSubscription(context));
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.path == null) return;

    final file = File(picked.path!);
    final size = await file.length();
    if (size > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الملف كبير جداً (الحد الأقصى 20MB)'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    setState(() {
      _selectedFilePath = picked.path;
      _selectedFileName = picked.name;
    });
  }

  Future<void> _generate() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل عنوان الاختبار');
      return;
    }
    if (_selectedFilePath == null) {
      setState(() => _error = 'ارفع ملف PDF أو صورة أولاً');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final fileName = _selectedFilePath!.split(Platform.pathSeparator).last;
      final ext = fileName.split('.').last.toLowerCase();
      final isPdf = ext == 'pdf';
      final mimeType = isPdf ? 'application/pdf' : 'image/$ext';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFilePath!,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        'title': _titleCtrl.text.trim(),
        'subject': _selectedSubject.isEmpty ? null : _selectedSubject,
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()) ?? 60,
        'question_count': int.tryParse(_countCtrl.text.trim()) ?? 10,
      });

      final client = ApiClient();
      await client.uploadFile('/exams/ai-generate', formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الاختبار كمسودة - يمكنك مراجعته ونشره'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text(
          'اختبار بالذكاء الاصطناعي',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward, color: textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _generating ? null : _pickFile,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: _selectedFilePath != null
                            ? AppTheme.accent.withValues(alpha: 0.05)
                            : surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFilePath != null
                              ? AppTheme.accent
                              : borderColor,
                          width: _selectedFilePath != null ? 2 : 1,
                        ),
                      ),
                      child: _selectedFilePath != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedFileName?.endsWith('.pdf') == true
                                      ? Icons.picture_as_pdf
                                      : Icons.image,
                                  size: 48,
                                  color: AppTheme.accent,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFileName ?? 'ملف محدد',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'اضغط لتغيير الملف',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  size: 48,
                                  color: textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'ارفع ملف PDF أو صورة',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PDF أو JPG أو PNG — حد أقصى 20MB',
                                  style: TextStyle(
                                    color: textSecondary.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _titleCtrl,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'عنوان الاختبار *',
                    prefixIcon: const Icon(Icons.title, size: 20),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubject,
                      isExpanded: true,
                      dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      icon: Icon(Icons.keyboard_arrow_down, color: textSecondary),
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      items: _subjects
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.isEmpty ? 'المادة (اختياري)' : s),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSubject = v ?? ''),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _durationCtrl,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'المدة (دقيقة)',
                          prefixIcon: Icon(Icons.timer_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _countCtrl,
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'عدد الأسئلة',
                          prefixIcon: Icon(Icons.format_list_numbered, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppTheme.accent.withValues(alpha: 0.7), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيقوم الذكاء الاصطناعي بقراءة المحتوى وتوليد أسئلة اختبار متعددة ومقالية',
                          style: TextStyle(color: textSecondary, fontSize: 12),
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
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _generating ? null : _generate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _generating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'جاري التوليد بالذكاء الاصطناعي...',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'إنشاء اختبار بالذكاء الاصطناعي',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
