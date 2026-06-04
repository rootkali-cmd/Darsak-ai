import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
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
        'day_of_week': _selectedDay ?? _dayCtrl.text.trim().isEmpty ? null : _dayCtrl.text.trim(),
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
      appBar: AppBar(title: Text(_isEdit ? 'تعديل المجموعة' : 'مجموعة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم *', prefixIcon: Icon(Icons.group)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(labelText: 'المادة', prefixIcon: Icon(Icons.book)),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _levelCtrl,
                decoration: const InputDecoration(labelText: 'المستوى', prefixIcon: Icon(Icons.school)),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _days.contains(_selectedDay) ? _selectedDay : null,
                decoration: const InputDecoration(labelText: 'اليوم', prefixIcon: Icon(Icons.calendar_today)),
                items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _selectedDay = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeCtrl,
                decoration: const InputDecoration(labelText: 'الوقت', hintText: 'مثال: 10:00 صباحاً', prefixIcon: Icon(Icons.access_time)),
                textInputAction: TextInputAction.done,
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
            ],
          ),
        ),
      ),
    );
  }
}
