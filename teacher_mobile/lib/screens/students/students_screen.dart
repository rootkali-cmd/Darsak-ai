import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/students_provider.dart';
import '../../core/app_theme.dart';
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
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف الطالب "${student['full_name'] ?? student['name'] ?? ''}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
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
                  leading: const Icon(Icons.edit),
                  title: const Text('تعديل'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditStudent(student);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppTheme.danger),
                  title: const Text('حذف', style: TextStyle(color: AppTheme.danger)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو الهاتف...',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  Provider.of<StudentsProvider>(context, listen: false).search(value);
                },
              )
            : const Text('الطلاب'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
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
              icon: const Icon(Icons.person_add),
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
            color: AppTheme.accent,
            backgroundColor: colorScheme.surface,
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
                  margin: const EdgeInsets.only(bottom: 10),
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
                      backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: AppTheme.accent),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$phone ${gradeLevel.isNotEmpty ? ' • $gradeLevel' : ''}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
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
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
