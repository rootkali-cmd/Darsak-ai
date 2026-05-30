import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/students_provider.dart';

class AddEditStudentScreen extends StatefulWidget {
  final dynamic student;

  const AddEditStudentScreen({super.key, this.student});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;
  late final TextEditingController _gradeController;
  late final TextEditingController _pinController;
  bool _isLoading = false;

  bool get isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?['full_name'] ?? s?['name'] ?? '');
    _phoneController = TextEditingController(text: s?['phone']?.toString() ?? '');
    _parentPhoneController = TextEditingController(text: s?['parent_phone']?.toString() ?? '');
    _gradeController = TextEditingController(text: s?['grade_level']?.toString() ?? '');
    _pinController = TextEditingController(text: s?['pin']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _gradeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'parent_phone': _parentPhoneController.text.trim(),
      'grade_level': _gradeController.text.trim(),
      'pin': _pinController.text.trim(),
    };

    final provider = Provider.of<StudentsProvider>(context, listen: false);
    bool success;
    if (isEditing) {
      success = await provider.updateStudent(widget.student['id'] as int, data);
    } else {
      success = await provider.createStudent(data);
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
        title: Text(isEditing ? 'تعديل طالب' : 'إضافة طالب'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال الاسم';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _parentPhoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'رقم ولي الأمر',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gradeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الصف الدراسي',
                  prefixIcon: Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الرقم السري (PIN)',
                  prefixIcon: Icon(Icons.lock),
                ),
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
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الطالب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
