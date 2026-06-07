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
  final _pinCtrl = TextEditingController();
  bool _saving = false;
  bool _deleting = false;

  List<dynamic> _groups = [];
  String? _selectedGroupId;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    if (_isEdit) {
      final s = widget.student!;
      _nameCtrl.text = s['full_name'] ?? '';
      _codeCtrl.text = s['code'] ?? '';
      _phoneCtrl.text = s['parent_phone'] ?? '';
      _selectedGroupId = s['group_id']?.toString();
      _pinCtrl.text = s['pin']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final resp = await ApiService().dio.get('/groups/');
      final data = resp.data;
      if (data is Map && data.containsKey('data')) {
        _groups = data['data'] as List<dynamic>;
      } else if (data is List) {
        _groups = data;
      } else {
        _groups = [];
      }
      if (mounted) setState(() {});
    } catch (_) {
      _groups = [];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        'parent_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'group_id': _selectedGroupId,
        'pin': _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
      };

      if (_isEdit) {
        await ApiService().dio.put('/students/${widget.student!['id']}', data: body);
      } else {
        final resp = await ApiService().dio.post('/students/', data: body);
        final created = resp.data;
        final studentCode = created['code'] ?? '';

        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('تم إضافة الطالب'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('كود الطالب:', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      studentCode,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('أرسل هذا الكود للطالب لتسجيل الدخول', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  if (_pinCtrl.text.trim().isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('⚠️ لم يتم تعيين رمز سري. الطالب لن يتمكن من الدخول حتى يتم تعيين رمز.', style: TextStyle(fontSize: 11, color: AppTheme.warning)),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
              ],
            ),
          );
          Navigator.pop(context);
        }
        return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
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
            decoration: GlassTheme.glassCard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'الاسم الكامل *', Icons.person),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _codeCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'الكود (اختياري)', Icons.qr_code),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'هاتف ولي الأمر', Icons.phone),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  decoration: GlassTheme.glassFormInput(context, 'المجموعة', Icons.group),
                  dropdownColor: isDark ? const Color(0xFF111111) : Colors.white,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('بدون مجموعة', style: TextStyle(color: GlassTheme.textSecondary(context))),
                    ),
                    ..._groups.map<DropdownMenuItem<String>>((g) {
                      return DropdownMenuItem<String>(
                        value: g['id']?.toString(),
                        child: Text(g['name'] ?? 'مجموعة'),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pinCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'الرمز السري', Icons.lock),
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
