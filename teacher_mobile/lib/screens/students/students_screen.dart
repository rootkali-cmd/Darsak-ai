import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/students_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/empty_state.dart';
import 'student_detail_screen.dart';
import 'add_edit_student_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentsProvider>(context, listen: false).loadStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
    );
  }

  void _showEditStudent(dynamic student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditStudentScreen(student: student),
      ),
    );
  }

  Future<void> _deleteStudent(dynamic student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف الطالب "${student['full_name'] ?? student['name'] ?? ''}"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<StudentsProvider>(context, listen: false);
      final success = await provider.deleteStudent(student['id'] as int);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الطالب بنجاح')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? 'فشل الحذف')),
          );
        }
      }
    }
  }

  void _showOptions(dynamic student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text('تعديل', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditStudent(student);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('حذف', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteStudent(student);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'بحث بالاسم أو الهاتف...',
                  hintStyle: TextStyle(color: Color(0xFF6b7280)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  Provider.of<StudentsProvider>(context, listen: false).search(value);
                },
              )
            : const Text('الطلاب'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  Provider.of<StudentsProvider>(context, listen: false).search('');
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: _showAddStudent,
            ),
        ],
      ),
      body: Consumer<StudentsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AppLoadingIndicator();
          }
          if (provider.error != null && provider.students.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadStudents(),
            );
          }
          if (provider.students.isEmpty) {
            return const EmptyState(
              message: 'لا يوجد طلاب',
              icon: Icons.people,
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadStudents(),
            color: const Color(0xFFdc2626),
            backgroundColor: const Color(0xFF1a1a2e),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.students.length,
              itemBuilder: (context, index) {
                final student = provider.students[index];
                final name = student['full_name'] ?? student['name'] ?? 'بدون اسم';
                final phone = student['phone']?.toString() ?? '';
                final gradeLevel = student['grade_level']?.toString() ?? '';
                return Card(
                  color: const Color(0xFF1a1a2e),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDetailScreen(student: student),
                        ),
                      );
                    },
                    onLongPress: () => _showOptions(student),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFdc2626).withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Color(0xFFdc2626)),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$phone ${gradeLevel.isNotEmpty ? ' • $gradeLevel' : ''}',
                      style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF6b7280)),
                      onPressed: () => _showOptions(student),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudent,
        backgroundColor: const Color(0xFFdc2626),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
