import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../core/subscription_guard.dart';

class AddEditGroupScreen extends StatefulWidget {
  final dynamic group;

  const AddEditGroupScreen({super.key, this.group});

  @override
  State<AddEditGroupScreen> createState() => _AddEditGroupScreenState();
}

class _AddEditGroupScreenState extends State<AddEditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.group != null;

  final List<String> _days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
  String? _selectedDay;

  final List<String> _defaultLevels = [
    'الصف الأول الإعدادي', 'الصف الثاني الإعدادي', 'الصف الثالث الإعدادي',
    'الصف الأول الثانوي', 'الصف الثاني الثانوي', 'الصف الثالث الثانوي',
  ];
  final List<String> _defaultSubjects = [
    'رياضيات', 'فيزياء', 'كيمياء', 'أحياء', 'عربي', 'إنجليزي',
    'فرنساوي', 'ألماني', 'تاريخ', 'جغرافيا', 'فلسفة', 'علوم',
    'دراسات', 'حاسب آلي',
  ];

  String? _selectedSubject;
  String? _selectedLevel;
  final List<String> _timeSlots = ['صباحاً', 'ظهراً', 'مساءً'];
  String? _selectedTimeSlot;

  // Get teacher's subjects and levels from profile
  List<String> get _subjects {
    final user = context.read<AuthProvider>().user;
    final list = user?['subjects'];
    if (list is List && list.isNotEmpty) return list.cast<String>();
    return _defaultSubjects;
  }

  List<String> get _levels {
    final user = context.read<AuthProvider>().user;
    final list = user?['levels'];
    if (list is List && list.isNotEmpty) return list.cast<String>();
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
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!checkSubscription(context)) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'subject': _selectedSubject,
        'level': _selectedLevel,
        'day_of_week': _selectedDay,
        'time_slot': _selectedTimeSlot,
      };

      if (_isEdit) {
        await ApiService().dio.put('/groups/${widget.group!['id']}', data: body);
      } else {
        await ApiService().dio.post('/groups/', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث المجموعة' : 'تم إضافة المجموعة'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjects = _subjects;
    final levels = _levels;

    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
        appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل المجموعة' : 'مجموعة جديدة'),
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
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'اسم المجموعة *', Icons.group),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                // Subject dropdown
                DropdownButtonFormField<String>(
                  value: subjects.contains(_selectedSubject) ? _selectedSubject : null,
                  decoration: GlassTheme.glassFormInput(context, 'المادة', Icons.book),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  isExpanded: true,
                  items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v),
                ),
                const SizedBox(height: 14),
                // Level dropdown
                DropdownButtonFormField<String>(
                  value: levels.contains(_selectedLevel) ? _selectedLevel : null,
                  decoration: GlassTheme.glassFormInput(context, 'الصف', Icons.school),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  isExpanded: true,
                  items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setState(() => _selectedLevel = v),
                ),
                const SizedBox(height: 14),
                // Day dropdown
                DropdownButtonFormField<String>(
                  value: _days.contains(_selectedDay) ? _selectedDay : null,
                  decoration: GlassTheme.glassFormInput(context, 'اليوم', Icons.calendar_today),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  isExpanded: true,
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _selectedDay = v),
                ),
                const SizedBox(height: 14),
                // Time slot dropdown
                DropdownButtonFormField<String>(
                  value: _timeSlots.contains(_selectedTimeSlot) ? _selectedTimeSlot : null,
                  decoration: GlassTheme.glassFormInput(context, 'الوقت', Icons.access_time),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  isExpanded: true,
                  items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedTimeSlot = v),
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
