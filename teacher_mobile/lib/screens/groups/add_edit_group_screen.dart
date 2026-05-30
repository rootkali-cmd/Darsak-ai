import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/groups_provider.dart';

class AddEditGroupScreen extends StatefulWidget {
  final dynamic group;

  const AddEditGroupScreen({super.key, this.group});

  @override
  State<AddEditGroupScreen> createState() => _AddEditGroupScreenState();
}

class _AddEditGroupScreenState extends State<AddEditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _levelController;
  late final TextEditingController _dayController;
  late final TextEditingController _timeController;
  bool _isLoading = false;

  bool get isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameController = TextEditingController(text: g?['name']?.toString() ?? '');
    _subjectController = TextEditingController(text: g?['subject']?.toString() ?? '');
    _levelController = TextEditingController(text: g?['level']?.toString() ?? '');
    _dayController = TextEditingController(text: g?['day_of_week']?.toString() ?? '');
    _timeController = TextEditingController(text: g?['time_slot']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _levelController.dispose();
    _dayController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'name': _nameController.text.trim(),
      'subject': _subjectController.text.trim(),
      'level': _levelController.text.trim(),
      'day_of_week': _dayController.text.trim(),
      'time_slot': _timeController.text.trim(),
    };

    final provider = Provider.of<GroupsProvider>(context, listen: false);
    bool success;
    if (isEditing) {
      success = await provider.updateGroup(widget.group['id'] as int, data);
    } else {
      success = await provider.createGroup(data);
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
        title: Text(isEditing ? 'تعديل مجموعة' : 'إضافة مجموعة'),
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
                  labelText: 'اسم المجموعة',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال الاسم';
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
                controller: _levelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'المستوى',
                  prefixIcon: Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dayController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'يوم الأسبوع',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'وقت المجموعة',
                  prefixIcon: Icon(Icons.access_time),
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
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة المجموعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
