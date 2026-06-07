import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';

class AddEditExamScreen extends StatefulWidget {
  final dynamic exam;

  const AddEditExamScreen({super.key, this.exam});

  @override
  State<AddEditExamScreen> createState() => _AddEditExamScreenState();
}

class _AddEditExamScreenState extends State<AddEditExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _totalPointsCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.exam != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.exam!;
      _titleCtrl.text = e['title'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      _durationCtrl.text = e['duration_minutes']?.toString() ?? '';
      _totalPointsCtrl.text = e['total_points']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _totalPointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()),
        'total_points': double.tryParse(_totalPointsCtrl.text.trim()),
      };

      if (_isEdit) {
        await ApiService().dio.put('/exams/${widget.exam!['id']}', data: body);
      } else {
        await ApiService().dio.post('/exams', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الاختبار' : 'تم إضافة الاختبار'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: ${getDioErrorMessage(e)}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAddQuestionDialog() {
    final questionCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final opt4Ctrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '1');
    int correctAnswer = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة سؤال'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: questionCtrl, decoration: GlassTheme.glassFormInput('السؤال *', Icons.help_outline)),
                const SizedBox(height: 8),
                TextField(controller: opt1Ctrl, decoration: GlassTheme.glassFormInput('الخيار 1 *', Icons.looks_one)),
                const SizedBox(height: 8),
                TextField(controller: opt2Ctrl, decoration: GlassTheme.glassFormInput('الخيار 2 *', Icons.looks_two)),
                const SizedBox(height: 8),
                TextField(controller: opt3Ctrl, decoration: GlassTheme.glassFormInput('الخيار 3', Icons.looks_3)),
                const SizedBox(height: 8),
                TextField(controller: opt4Ctrl, decoration: GlassTheme.glassFormInput('الخيار 4', Icons.looks_4)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: correctAnswer,
                  decoration: GlassTheme.glassFormInput('الإجابة الصحيحة', Icons.check),
                  dropdownColor: const Color(0xFF1E293B),
                  items: [1, 2, 3, 4].map((i) => DropdownMenuItem(value: i, child: Text('الخيار $i'))).toList(),
                  onChanged: (v) => setDialogState(() => correctAnswer = v ?? 1),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsCtrl,
                  decoration: GlassTheme.glassFormInput('النقاط', Icons.star),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (questionCtrl.text.trim().isEmpty || opt1Ctrl.text.trim().isEmpty || opt2Ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'question': questionCtrl.text.trim(),
                  'options': [
                    opt1Ctrl.text.trim(),
                    opt2Ctrl.text.trim(),
                    opt3Ctrl.text.trim().isEmpty ? null : opt3Ctrl.text.trim(),
                    opt4Ctrl.text.trim().isEmpty ? null : opt4Ctrl.text.trim(),
                  ].whereType<String>().toList(),
                  'correct_answer': correctAnswer,
                  'points': int.tryParse(pointsCtrl.text.trim()) ?? 1,
                });
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل الاختبار' : 'اختبار جديد'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('العنوان *', Icons.title),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('الوصف', Icons.description),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: GlassTheme.glassFormInput('المدة (دقيقة)', Icons.timer),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _totalPointsCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: GlassTheme.glassFormInput('مجموع النقاط', Icons.stars),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _saving ? 'جاري الحفظ...' : (_isEdit ? 'تحديث' : 'إضافة'),
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الأسئلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      TextButton.icon(
                        onPressed: _showAddQuestionDialog,
                        icon: const Icon(Icons.add, color: GlassTheme.indigo),
                        label: const Text('إضافة سؤال', style: TextStyle(color: GlassTheme.indigo)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: GlassTheme.glassCard,
                    child: const Center(
                      child: Text('سيتم تحميل الأسئلة عند حفظ الاختبار', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
