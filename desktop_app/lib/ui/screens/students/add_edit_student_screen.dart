import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_provider.dart';

class AddEditStudentScreen extends StatefulWidget {
  final Map<String, dynamic>? student;

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
      final data = context.read<DataProvider>();
      final groups = await data.api.getGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _groups = []);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final data = context.read<DataProvider>();
      final body = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        'parent_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'group_id': _selectedGroupId,
        'pin': _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
      };

      if (_isEdit) {
        await data.api.updateStudent(widget.student!['id'], body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الطالب'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final created = await data.api.createStudent(body);
      final studentCode = created['code'] ?? '';

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogSurface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
            final dialogBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
            final dialogTextPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
            final dialogTextSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

            return AlertDialog(
              backgroundColor: dialogSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: dialogBorder),
              ),
              title: Text('تم إضافة الطالب', style: TextStyle(color: dialogTextPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('كود الطالب:', style: TextStyle(fontSize: 14, color: dialogTextSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      studentCode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontArabic,
                        color: dialogTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أرسل هذا الكود للطالب لتسجيل الدخول',
                    style: TextStyle(fontSize: 12, color: dialogTextSecondary),
                  ),
                  if (_pinCtrl.text.trim().isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'لم يتم تعيين رمز سري. الطالب لن يتمكن من الدخول حتى يتم تعيين رمز.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                    ),
                  ],
                ],
              ),
              actions: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('حسناً'),
                  ),
                ),
              ],
            );
          },
        );
        if (mounted) Navigator.pop(context);
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

  Future<void> _delete() async {
    final data = context.read<DataProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogSurface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final dialogBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final dialogTextPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final dialogTextSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dialogBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            const SizedBox(width: 12),
            Text('حذف الطالب', style: TextStyle(color: dialogTextPrimary, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل أنت متأكد من حذف الطالب؟', style: TextStyle(color: dialogTextSecondary, fontSize: 15)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          (_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim()[0] : '?'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nameCtrl.text.trim(), style: TextStyle(color: dialogTextPrimary, fontWeight: FontWeight.w600)),
                        Text(_codeCtrl.text.trim(), style: TextStyle(color: dialogTextSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('سيتم حذف جميع بيانات الطالب.', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await data.api.deleteStudent(widget.student!['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

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
                          _isEdit ? Icons.edit : Icons.person_add,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isEdit ? 'تعديل الطالب' : 'طالب جديد',
                          style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isEdit)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              onPressed: _deleting ? null : _delete,
                              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                              tooltip: 'حذف الطالب',
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
                          decoration: InputDecoration(
                            labelText: 'الاسم الكامل *',
                            prefixIcon: const Icon(Icons.person, size: 20),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeCtrl,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'الكود (اختياري)',
                            prefixIcon: const Icon(Icons.qr_code, size: 20),
                          ),
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'هاتف ولي الأمر',
                            prefixIcon: const Icon(Icons.phone, size: 20),
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGroupId,
                          decoration: const InputDecoration(
                            labelText: 'المجموعة',
                            prefixIcon: Icon(Icons.group, size: 20),
                          ),
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textPrimary),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('بدون مجموعة', style: TextStyle(color: textSecondary)),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinCtrl,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'الرمز السري',
                            prefixIcon: const Icon(Icons.lock, size: 20),
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
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
