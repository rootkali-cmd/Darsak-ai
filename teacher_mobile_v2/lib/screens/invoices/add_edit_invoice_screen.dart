import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
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
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الفاتورة' : 'فاتورة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _studentIdCtrl,
                decoration: const InputDecoration(labelText: 'رقم الطالب', prefixIcon: Icon(Icons.person)),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'المبلغ *', prefixIcon: Icon(Icons.money)),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'المبلغ مطلوب' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.description)),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueDateCtrl,
                decoration: const InputDecoration(
                  labelText: 'تاريخ الاستحقاق',
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: Icon(Icons.date_range),
                ),
                readOnly: true,
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'الحالة', prefixIcon: Icon(Icons.flag)),
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
