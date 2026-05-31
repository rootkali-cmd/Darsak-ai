import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exams_provider.dart';

class AddEditExamScreen extends StatefulWidget {
  final dynamic exam;

  const AddEditExamScreen({super.key, this.exam});

  @override
  State<AddEditExamScreen> createState() => _AddEditExamScreenState();
}

class _AddEditExamScreenState extends State<AddEditExamScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  String _status = 'draft';
  bool _isLoading = false;

  bool get isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _titleController = TextEditingController(text: e?['title']?.toString() ?? '');
    _durationController = TextEditingController(text: e?['duration']?.toString() ?? '');
    _status = e?['status']?.toString() ?? 'draft';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final duration = int.tryParse(_durationController.text) ?? 0;
    if (duration < 1) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المدة يجب أن تكون 1 دقيقة على الأقل')),
        );
      }
      return;
    }

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'duration_minutes': duration,
      'status': _status,
    };

    final provider = Provider.of<ExamsProvider>(context, listen: false);
    bool success;
    if (isEditing) {
      success = await provider.updateExam(widget.exam['id'] as int, data);
    } else {
      success = await provider.createExam(data);
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
        title: Text(isEditing ? 'تعديل اختبار' : 'إضافة اختبار'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'عنوان الاختبار',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال العنوان';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'المدة (بالدقائق)',
                  prefixIcon: Icon(Icons.timer),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال المدة';
                  final n = int.tryParse(value);
                  if (n == null || n < 1) return 'المدة يجب أن تكون رقماً أكبر من 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('مسودة (draft)')),
                  DropdownMenuItem(value: 'published', child: Text('منشور (published)')),
                  DropdownMenuItem(value: 'closed', child: Text('مغلق (closed)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
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
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الاختبار'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
