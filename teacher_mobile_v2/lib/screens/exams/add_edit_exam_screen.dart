import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
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
                TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'السؤال *')),
                const SizedBox(height: 8),
                TextField(controller: opt1Ctrl, decoration: const InputDecoration(labelText: 'الخيار 1 *')),
                const SizedBox(height: 8),
                TextField(controller: opt2Ctrl, decoration: const InputDecoration(labelText: 'الخيار 2 *')),
                const SizedBox(height: 8),
                TextField(controller: opt3Ctrl, decoration: const InputDecoration(labelText: 'الخيار 3')),
                const SizedBox(height: 8),
                TextField(controller: opt4Ctrl, decoration: const InputDecoration(labelText: 'الخيار 4')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: correctAnswer,
                  decoration: const InputDecoration(labelText: 'الإجابة الصحيحة'),
                  items: [1, 2, 3, 4].map((i) => DropdownMenuItem(value: i, child: Text('الخيار $i'))).toList(),
                  onChanged: (v) => setDialogState(() => correctAnswer = v ?? 1),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsCtrl,
                  decoration: const InputDecoration(labelText: 'النقاط'),
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
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الاختبار' : 'اختبار جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'العنوان *', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.description)),
                maxLines: 3,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      decoration: const InputDecoration(labelText: 'المدة (دقيقة)', prefixIcon: Icon(Icons.timer)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _totalPointsCtrl,
                      decoration: const InputDecoration(labelText: 'مجموع النقاط', prefixIcon: Icon(Icons.stars)),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_saving ? 'جاري الحفظ...' : (_isEdit ? 'تحديث' : 'إضافة'), style: const TextStyle(fontSize: 16)),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الأسئلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _showAddQuestionDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة سؤال'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('سيتم تحميل الأسئلة عند حفظ الاختبار', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
