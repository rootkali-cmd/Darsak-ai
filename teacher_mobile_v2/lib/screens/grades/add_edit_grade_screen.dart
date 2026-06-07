import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';

class AddEditGradeScreen extends StatefulWidget {
  final dynamic grade;

  const AddEditGradeScreen({super.key, this.grade});

  @override
  State<AddEditGradeScreen> createState() => _AddEditGradeScreenState();
}

class _AddEditGradeScreenState extends State<AddEditGradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController(text: '100');
  final _typeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.grade != null;

  final List<String> _types = ['امتحان', 'واجب', 'اختبار', 'مشروع', 'شفوي'];
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final g = widget.grade!;
      _studentIdCtrl.text = g['student_id']?.toString() ?? '';
      _subjectCtrl.text = g['subject'] ?? '';
      _scoreCtrl.text = g['score']?.toString() ?? '';
      _maxScoreCtrl.text = g['max_score']?.toString() ?? '100';
      _selectedType = _types.contains(g['type']) ? g['type'] : null;
      _typeCtrl.text = g['type'] ?? '';
      _notesCtrl.text = g['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _subjectCtrl.dispose();
    _scoreCtrl.dispose();
    _maxScoreCtrl.dispose();
    _typeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'student_id': int.tryParse(_studentIdCtrl.text.trim()),
        'subject': _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
        'score': int.tryParse(_scoreCtrl.text.trim()) ?? 0,
        'max_score': int.tryParse(_maxScoreCtrl.text.trim()) ?? 100,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      if (_isEdit) {
        await ApiService().dio.put('/grades/${widget.grade!['id']}', data: body);
      } else {
        await ApiService().dio.post('/grades/', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الدرجة' : 'تم إضافة الدرجة'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل الدرجة' : 'درجة جديدة'),
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
                  controller: _studentIdCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('رقم الطالب', Icons.person),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _subjectCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('المادة', Icons.book),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _scoreCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: GlassTheme.glassFormInput('الدرجة', Icons.star),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxScoreCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: GlassTheme.glassFormInput('الدرجة الكلية', Icons.star_border),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _types.contains(_selectedType) ? _selectedType : null,
                  decoration: GlassTheme.glassFormInput('النوع', Icons.category),
                  dropdownColor: const Color(0xFF111111),
                  style: const TextStyle(color: Colors.white),
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('ملاحظات', Icons.notes),
                  maxLines: 2,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
