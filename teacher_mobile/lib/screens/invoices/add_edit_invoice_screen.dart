import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/students_provider.dart';

class AddEditInvoiceScreen extends StatefulWidget {
  final dynamic invoice;

  const AddEditInvoiceScreen({super.key, this.invoice});

  @override
  State<AddEditInvoiceScreen> createState() => _AddEditInvoiceScreenState();
}

class _AddEditInvoiceScreenState extends State<AddEditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedStudentId;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  bool _paid = false;
  bool _isLoading = false;

  bool get isEditing => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    _selectedStudentId = inv?['student_id'] ?? inv?['student']?['id'];
    _amountController = TextEditingController(text: inv?['amount']?.toString() ?? '');
    _descriptionController = TextEditingController(text: inv?['description']?.toString() ?? '');
    _paid = inv?['paid'] == true;
    Provider.of<StudentsProvider>(context, listen: false).loadStudents();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار طالب')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'student_id': _selectedStudentId,
      'amount': double.tryParse(_amountController.text) ?? 0,
      'description': _descriptionController.text.trim(),
      'paid': _paid,
    };

    final provider = Provider.of<InvoicesProvider>(context, listen: false);
    bool success;
    if (isEditing) {
      success = await provider.updateInvoice(widget.invoice['id'] as int, data);
    } else {
      success = await provider.createInvoice(data);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'تم التحديث بنجاح' : 'تم الإضافة بنجاح')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'حدث خطأ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل فاتورة' : 'إضافة فاتورة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Consumer<StudentsProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const LinearProgressIndicator();
                  }
                  final students = provider.students;
                  return DropdownButtonFormField<int?>(
                    initialValue: _selectedStudentId,
                    dropdownColor: const Color(0xFF1a1a2e),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'اختيار الطالب',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: students.map<DropdownMenuItem<int?>>((s) {
                      final id = s['id'] as int?;
                      final name = s['full_name'] ?? s['name'] ?? '';
                      return DropdownMenuItem(
                        value: id,
                        child: Text(name, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedStudentId = value),
                    validator: (value) => value == null ? 'الرجاء اختيار طالب' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال المبلغ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('مدفوع', style: TextStyle(color: Colors.white)),
                value: _paid,
                activeThumbColor: const Color(0xFFdc2626),
                onChanged: (value) => setState(() => _paid = value),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الفاتورة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
