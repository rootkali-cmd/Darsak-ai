import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';

class AddEditInvoiceScreen extends StatefulWidget {
  final dynamic invoice;

  const AddEditInvoiceScreen({super.key, this.invoice});

  @override
  State<AddEditInvoiceScreen> createState() => _AddEditInvoiceScreenState();
}

class _AddEditInvoiceScreenState extends State<AddEditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.invoice != null;

  final List<String> _statuses = ['paid', 'unpaid', 'overdue', 'cancelled'];
  String _selectedStatus = 'unpaid';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final inv = widget.invoice!;
      _studentIdCtrl.text = inv['student_id']?.toString() ?? '';
      _amountCtrl.text = inv['amount']?.toString() ?? '';
      _descCtrl.text = inv['description'] ?? '';
      _dueDateCtrl.text = inv['due_date'] ?? '';
      _selectedStatus = _statuses.contains(inv['status']) ? inv['status'] : 'unpaid';
    }
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'student_id': int.tryParse(_studentIdCtrl.text.trim()),
        'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'due_date': _dueDateCtrl.text.trim().isEmpty ? null : _dueDateCtrl.text.trim(),
        'status': _selectedStatus,
      };

      if (_isEdit) {
        await ApiService().dio.put('/invoices/${widget.invoice!['id']}', data: body);
      } else {
        await ApiService().dio.post('/invoices/', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الفاتورة' : 'تم إضافة الفاتورة'),
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

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDateCtrl.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل الفاتورة' : 'فاتورة جديدة'),
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
                  controller: _amountCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('المبلغ *', Icons.money),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'المبلغ مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('الوصف', Icons.description),
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dueDateCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: GlassTheme.glassFormInput('تاريخ الاستحقاق', Icons.calendar_today),
                  readOnly: true,
                  onTap: _pickDueDate,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: GlassTheme.glassFormInput('الحالة', Icons.flag),
                  dropdownColor: const Color(0xFF111111),
                  style: const TextStyle(color: Colors.white),
                  items: _statuses.map((s) {
                    String label;
                    switch (s) {
                      case 'paid':
                        label = 'مدفوع';
                        break;
                      case 'unpaid':
                        label = 'غير مدفوع';
                        break;
                      case 'overdue':
                        label = 'متأخر';
                        break;
                      case 'cancelled':
                        label = 'ملغي';
                        break;
                      default:
                        label = s;
                    }
                    return DropdownMenuItem(value: s, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v ?? 'unpaid'),
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
