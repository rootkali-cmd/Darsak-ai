import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class AiExamScreen extends StatefulWidget {
  const AiExamScreen({super.key});

  @override
  State<AiExamScreen> createState() => _AiExamScreenState();
}

class _AiExamScreenState extends State<AiExamScreen> {
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  bool _isLoading = false;
  final ApiService _api = ApiService();

  @override
  void dispose() {
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _generateExam() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال وصف الامتحان')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text) ?? 30;

    setState(() => _isLoading = true);

    try {
      final formData = FormData.fromMap({
        'title': _descriptionController.text.trim(),
        'duration_minutes': duration,
      });

      await _api.dio.post('/exams/ai-generate', data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم توليد الامتحان بنجاح')),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        String message = 'حدث خطأ أثناء توليد الامتحان';
        final respData = e.response?.data;
        if (respData is Map && respData['detail'] != null) {
          message = respData['detail'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ غير متوقع')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('امتحان بالذكاء الاصطناعي')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.accent, AppTheme.accentLight],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'توليد امتحان بالذكاء الاصطناعي',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'صف الامتحان المطلوب وسيتم توليده تلقائياً',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'صف الامتحان',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'مثال: امتحان في رياضيات للصف الثالث الثاني، 10 أسئلة اختيار من متعدد',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'المدة (بالدقائق)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      decoration: const InputDecoration(
                        hintText: '30',
                        prefixIcon: Icon(Icons.timer),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generateExam,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'توليد الامتحان',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
