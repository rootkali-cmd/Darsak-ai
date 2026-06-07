import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';

class AddEditGroupScreen extends StatefulWidget {
  final dynamic group;

  const AddEditGroupScreen({super.key, this.group});

  @override
  State<AddEditGroupScreen> createState() => _AddEditGroupScreenState();
}

class _AddEditGroupScreenState extends State<AddEditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.group != null;

  final List<String> _days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final g = widget.group!;
      _nameCtrl.text = g['name'] ?? '';
      _subjectCtrl.text = g['subject'] ?? '';
      _levelCtrl.text = g['level']?.toString() ?? '';
      _dayCtrl.text = g['day_of_week'] ?? '';
      _selectedDay = g['day_of_week'];
      _timeCtrl.text = g['time_slot'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _levelCtrl.dispose();
    _dayCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
        'level': _levelCtrl.text.trim().isEmpty ? null : _levelCtrl.text.trim(),
        'day_of_week': _selectedDay ?? (_dayCtrl.text.trim().isEmpty ? null : _dayCtrl.text.trim()),
        'time_slot': _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل المجموعة' : 'مجموعة جديدة'),
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
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('الاسم *', Icons.group),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
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
                TextFormField(
                  controller: _levelCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('المستوى', Icons.school),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _days.contains(_selectedDay) ? _selectedDay : null,
                  decoration: GlassTheme.glassFormInput('اليوم', Icons.calendar_today),
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _selectedDay = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _timeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('الوقت', Icons.access_time),
                  textInputAction: TextInputAction.done,
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
