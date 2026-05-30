import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/grades_provider.dart';
import '../../providers/students_provider.dart';

class AddEditGradeScreen extends StatefulWidget {
  final dynamic grade;

  const AddEditGradeScreen({super.key, this.grade});

  @override
  State<AddEditGradeScreen> createState() => _AddEditGradeScreenState();
}

class _AddEditGradeScreenState extends State<AddEditGradeScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedStudentId;
  late final TextEditingController _examController;
  late final TextEditingController _subjectController;
  late final TextEditingController _scoreController;
  late final TextEditingController _maxScoreController;
  bool _isLoading = false;

  bool get isEditing => widget.grade != null;

  @override
  void initState() {
    super.initState();
    final g = widget.grade;
    _selectedStudentId = g?['student_id'] ?? g?['student']?['id'];
    _examController = TextEditingController(text: g?['exam_name']?.toString() ?? g?['exam']?.toString() ?? '');
    _subjectController = TextEditingController(text: g?['subject']?.toString() ?? '');
    _scoreController = TextEditingController(text: g?['score']?.toString() ?? '');
    _maxScoreController = TextEditingController(text: g?['max_score']?.toString() ?? '');
    Provider.of<StudentsProvider>(context, listen: false).loadStudents();
  }

  @override
  void dispose() {
    _examController.dispose();
    _subjectController.dispose();
    _scoreController.dispose();
    _maxScoreController.dispose();
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
      'exam_name': _examController.text.trim(),
      'subject': _subjectController.text.trim(),
      'score': double.tryParse(_scoreController.text) ?? 0,
      'max_score': double.tryParse(_maxScoreController.text) ?? 0,
    };

    final provider = Provider.of<GradesProvider>(context, listen: false);
    bool success;
    if (isEditing) {
      success = await provider.updateGrade(widget.grade['id'] as int, data);
    } else {
      success = await provider.createGrade(data);
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
        title: Text(isEditing ? 'تعديل درجة' : 'إضافة درجة'),
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
                controller: _examController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'اسم الاختبار',
                  prefixIcon: Icon(Icons.assignment),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال اسم الاختبار';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'المادة',
                  prefixIcon: Icon(Icons.book),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _scoreController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الدرجة',
                  prefixIcon: Icon(Icons.score),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال الدرجة';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxScoreController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الدرجة العظمى',
                  prefixIcon: Icon(Icons.assessment),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال الدرجة العظمى';
                  return null;
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
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الدرجة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
