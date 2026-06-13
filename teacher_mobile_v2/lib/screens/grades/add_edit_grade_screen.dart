import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../core/subscription_guard.dart';

class AddEditGradeScreen extends StatefulWidget {
  final dynamic grade;

  const AddEditGradeScreen({super.key, this.grade});

  @override
  State<AddEditGradeScreen> createState() => _AddEditGradeScreenState();
}

class _AddEditGradeScreenState extends State<AddEditGradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _maxScoreCtrl = TextEditingController(text: '100');
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.grade != null;

  final List<String> _types = ['امتحان', 'واجب', 'اختبار', 'مشروع', 'شفوي'];
  String? _selectedType;

  List<String> _subjects = [];
  String? _selectedSubject;

  List<dynamic> _students = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadStudents();
    if (_isEdit) {
      final g = widget.grade!;
      _studentIdCtrl.text = g['student_id']?.toString() ?? '';
      _selectedSubject = g['subject'];
      _scoreCtrl.text = g['score']?.toString() ?? '';
      _maxScoreCtrl.text = g['max_score']?.toString() ?? '100';
      _selectedType = _types.contains(g['type']) ? g['type'] : null;
      _notesCtrl.text = g['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _scoreCtrl.dispose();
    _maxScoreCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subjects = prefs.getStringList('onboarding_subjects');
      if (subjects != null && subjects.isNotEmpty) {
        _subjects = subjects;
      } else {
        _subjects = ['رياضيات', 'فيزياء', 'كيمياء', 'أحياء', 'عربي', 'إنجليزي', 'فرنساوي', 'ألماني', 'تاريخ', 'جغرافيا', 'فلسفة', 'علوم', 'دراسات', 'حاسب آلي'];
      }
      if (_isEdit && _selectedSubject != null && !_subjects.contains(_selectedSubject)) {
        _subjects.insert(0, _selectedSubject!);
      }
      if (mounted) setState(() {});
    } catch (_) {
      _subjects = ['رياضيات', 'فيزياء', 'كيمياء', 'أحياء', 'عربي', 'إنجليزي'];
    }
  }

  Future<void> _loadStudents() async {
    try {
      final resp = await ApiService().dio.get('/students/');
      final data = resp.data;
      if (data is Map && data.containsKey('data')) {
        _students = data['data'] as List<dynamic>;
      } else if (data is List) {
        _students = data;
      } else {
        _students = [];
      }
      if (mounted) setState(() {});
    } catch (_) {
      _students = [];
    }
  }

  Future<void> _save() async {
    if (!checkSubscription(context)) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'student_id': int.tryParse(_studentIdCtrl.text.trim()),
        'subject': _selectedSubject,
        'score': int.tryParse(_scoreCtrl.text.trim()) ?? 0,
        'max_score': int.tryParse(_maxScoreCtrl.text.trim()) ?? 100,
        'type': _selectedType,
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
        String msg = 'فشل الحفظ';
        final detail = e.response?.data;
        if (detail is Map && detail['detail'] != null) {
          msg = detail['detail'].toString();
        } else {
          msg = 'فشل الحفظ: ${getDioErrorMessage(e)}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ غير متوقع. حاول مرة أخرى'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
        appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل الدرجة' : 'درجة جديدة'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassCard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _students.any((s) => s['id']?.toString() == _studentIdCtrl.text) ? _studentIdCtrl.text : null,
                  decoration: GlassTheme.glassFormInput(context, 'الطالب', Icons.person),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  items: _students.map<DropdownMenuItem<String>>((s) {
                    return DropdownMenuItem<String>(
                      value: s['id']?.toString(),
                      child: Text(s['full_name'] ?? 'طالب'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _studentIdCtrl.text = v ?? ''),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: GlassTheme.glassFormInput(context, 'المادة', Icons.book),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  items: _subjects.map<DropdownMenuItem<String>>((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: Text(s),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _scoreCtrl,
                        style: TextStyle(color: GlassTheme.textPrimary(context)),
                        decoration: GlassTheme.glassFormInput(context, 'الدرجة', Icons.star),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxScoreCtrl,
                        style: TextStyle(color: GlassTheme.textPrimary(context)),
                        decoration: GlassTheme.glassFormInput(context, 'الدرجة الكلية', Icons.star_border),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _types.contains(_selectedType) ? _selectedType : null,
                  decoration: GlassTheme.glassFormInput(context, 'النوع', Icons.category),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'ملاحظات', Icons.notes),
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
