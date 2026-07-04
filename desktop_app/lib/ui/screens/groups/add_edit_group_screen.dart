import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';

class AddEditGroupScreen extends StatefulWidget {
  final Map<String, dynamic>? group;

  const AddEditGroupScreen({super.key, this.group});

  @override
  State<AddEditGroupScreen> createState() => _AddEditGroupScreenState();
}

class _AddEditGroupScreenState extends State<AddEditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.group != null;

  final List<String> _days = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];
  String? _selectedDay;

  final List<String> _defaultLevels = [
    'الصف الأول الإعدادي',
    'الصف الثاني الإعدادي',
    'الصف الثالث الإعدادي',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];
  final List<String> _defaultSubjects = [
    'رياضيات',
    'فيزياء',
    'كيمياء',
    'أحياء',
    'عربي',
    'إنجليزي',
    'فرنساوي',
    'ألماني',
    'تاريخ',
    'جغرافيا',
    'فلسفة',
    'علوم',
    'دراسات',
    'حاسب آلي',
  ];

  String? _selectedSubject;
  String? _selectedLevel;
  final List<String> _timeSlots = ['صباحاً', 'ظهراً', 'مساءً'];
  String? _selectedTimeSlot;

  List<String> get _subjects {
    final auth = context.read<AuthProvider>();
    final list = auth.subjects;
    if (list.isNotEmpty) return list;
    return _defaultSubjects;
  }

  List<String> get _levels {
    final auth = context.read<AuthProvider>();
    final list = auth.levels;
    if (list.isNotEmpty) return list;
    return _defaultLevels;
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final g = widget.group!;
      _nameCtrl.text = g['name'] ?? '';
      _selectedSubject = g['subject'];
      _selectedLevel = g['level']?.toString();
      _selectedDay = g['day_of_week'];
      _selectedTimeSlot = g['time_slot'];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final data = context.read<DataProvider>();
      final body = {
        'name': _nameCtrl.text.trim(),
        'subject': _selectedSubject,
        'level': _selectedLevel,
        'day_of_week': _selectedDay,
        'time_slot': _selectedTimeSlot,
      };

      if (_isEdit) {
        await data.api.updateGroup(widget.group!['id'], body);
      } else {
        await data.api.createGroup(body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث المجموعة' : 'تم إضافة المجموعة'),
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
          final match =
              RegExp(r'detail["\s:]+([^\]]+)').firstMatch(e.toString());
          if (match != null) msg = match.group(1) ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
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
    final textPrimary =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final subjects = _subjects;
    final levels = _levels;

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isEdit ? Icons.edit : Icons.group_add,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isEdit ? 'تعديل المجموعة' : 'مجموعة جديدة',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                        TextFormField(
                          controller: _nameCtrl,
                          style: TextStyle(color: textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'اسم المجموعة *',
                            prefixIcon: Icon(Icons.group, size: 20),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'الاسم مطلوب'
                              : null,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: subjects.contains(_selectedSubject)
                              ? _selectedSubject
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'المادة',
                            prefixIcon: Icon(Icons.book, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          isExpanded: true,
                          items: subjects
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedSubject = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: levels.contains(_selectedLevel)
                              ? _selectedLevel
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'الصف',
                            prefixIcon: Icon(Icons.school, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          isExpanded: true,
                          items: levels
                              .map((l) =>
                                  DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedLevel = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _days.contains(_selectedDay)
                              ? _selectedDay
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'اليوم',
                            prefixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          isExpanded: true,
                          items: _days
                              .map((d) =>
                                  DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedDay = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _timeSlots.contains(_selectedTimeSlot)
                              ? _selectedTimeSlot
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'الوقت',
                            prefixIcon: Icon(Icons.access_time, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          isExpanded: true,
                          items: _timeSlots
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedTimeSlot = v),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              _saving
                                  ? 'جاري الحفظ...'
                                  : (_isEdit ? 'تحديث' : 'إضافة'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
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
