import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';

class AddEditStudentScreen extends StatefulWidget {
  final dynamic student;

  const AddEditStudentScreen({super.key, this.student});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _groupIdCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _saving = false;
  bool _deleting = false;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.student!;
      _nameCtrl.text = s['full_name'] ?? '';
      _codeCtrl.text = s['code'] ?? '';
      _phoneCtrl.text = s['parent_phone'] ?? '';
      _groupIdCtrl.text = s['group_id']?.toString() ?? '';
      _pinCtrl.text = s['pin']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _groupIdCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'full_name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        'parent_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'group_id': _groupIdCtrl.text.trim().isEmpty ? null : _groupIdCtrl.text.trim(),
        'pin': _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
      };

      if (_isEdit) {
        await ApiService().dio.put('/students/${widget.student!['id']}', data: body);
      } else {
        await ApiService().dio.post('/students/', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الطالب' : 'تم إضافة الطالب'),
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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطالب'),
        content: const Text('سيتم حذف الطالب نهائياً'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await ApiService().dio.delete('/students/${widget.student!['id']}');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: GlassTheme.glassAppBar(
        _isEdit ? 'تعديل الطالب' : 'طالب جديد',
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: GlassTheme.red),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
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
                  decoration: GlassTheme.glassFormInput('الاسم الكامل *', Icons.person),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _codeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('الكود', Icons.qr_code),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('هاتف ولي الأمر', Icons.phone),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _groupIdCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('المجموعة', Icons.group),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pinCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('الرمز السري', Icons.lock),
                  keyboardType: TextInputType.number,
                  obscureText: true,
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
