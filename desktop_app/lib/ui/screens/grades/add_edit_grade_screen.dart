import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_provider.dart';

class AddEditGradeScreen extends StatefulWidget {
  final Map<String, dynamic>? grade;

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
        _subjects = [
          'رياضيات', 'فيزياء', 'كيمياء', 'أحياء', 'عربي',
          'إنجليزي', 'فرنساوي', 'ألماني', 'تاريخ', 'جغرافيا',
          'فلسفة', 'علوم', 'دراسات', 'حاسب آلي',
        ];
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
      final data = context.read<DataProvider>();
      final resp = await data.api.getStudents();
      _students = resp;
      if (mounted) setState(() {});
    } catch (_) {
      _students = [];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final data = context.read<DataProvider>();
      final body = <String, dynamic>{
        'student_id': _studentIdCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_studentIdCtrl.text.trim()),
        'subject': _selectedSubject,
        'score': int.tryParse(_scoreCtrl.text.trim()) ?? 0,
        'max_score': int.tryParse(_maxScoreCtrl.text.trim()) ?? 100,
        'type': _selectedType,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      if (_isEdit) {
        await data.api.updateGrade(widget.grade!['id'], body);
      } else {
        await data.api.createGrade(body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الدرجة' : 'تم إضافة الدرجة'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'فشل الحفظ';
        if (e.toString().contains('detail')) {
          final match = RegExp(r'detail["\s:]+([^\]]+)').firstMatch(e.toString());
          if (match != null) msg = match.group(1) ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isEdit ? Icons.edit : Icons.star,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isEdit ? 'تعديل الدرجة' : 'درجة جديدة',
                          style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _students.any((s) => s['id']?.toString() == _studentIdCtrl.text)
                              ? _studentIdCtrl.text
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'الطالب *',
                            prefixIcon: Icon(Icons.person, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          items: _students.map<DropdownMenuItem<String>>((s) {
                            return DropdownMenuItem<String>(
                              value: s['id']?.toString(),
                              child: Text(s['full_name'] ?? 'طالب'),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _studentIdCtrl.text = v ?? ''),
                          validator: (v) => (v == null || v.isEmpty) ? 'يرجى اختيار طالب' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSubject,
                          decoration: const InputDecoration(
                            labelText: 'المادة *',
                            prefixIcon: Icon(Icons.book, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          items: _subjects.map<DropdownMenuItem<String>>((s) {
                            return DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedSubject = v),
                          validator: (v) => (v == null || v.isEmpty) ? 'يرجى اختيار المادة' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _scoreCtrl,
                                style: TextStyle(color: textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'الدرجة *',
                                  prefixIcon: Icon(Icons.star, size: 20),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _maxScoreCtrl,
                                style: TextStyle(color: textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'الدرجة الكلية',
                                  prefixIcon: Icon(Icons.star_border, size: 20),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _types.contains(_selectedType) ? _selectedType : null,
                          decoration: const InputDecoration(
                            labelText: 'النوع',
                            prefixIcon: Icon(Icons.category, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _selectedType = v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesCtrl,
                          style: TextStyle(color: textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                            prefixIcon: Icon(Icons.notes, size: 20),
                          ),
                          maxLines: 2,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              _saving ? 'جاري الحفظ...' : (_isEdit ? 'تحديث' : 'إضافة'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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
}
