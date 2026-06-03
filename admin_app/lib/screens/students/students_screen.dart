import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://darsak-backend.fly.dev/api/admin',
    connectTimeout: const Duration(seconds: 30),
  ));

  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/students');
      final list = List<Map<String, dynamic>>.from(res.data);
      if (mounted) {
        setState(() {
          _students = list;
          _filtered = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _students = [];
          _filtered = [];
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _filter(String query) {
    setState(() {
      _filtered = _students
          .where((s) =>
              (s['name'] as String).contains(query) ||
              (s['code'] as String).contains(query))
          .toList();
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> student) async {
    final id = student['id'];
    final currentlyActive = student['is_active'] as bool;
    final action = currentlyActive ? 'deactivate' : 'activate';
    try {
      await _dio.post('/students/$id/$action');
      _fetchStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(currentlyActive ? 'تم التعطيل' : 'تم التفعيل')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل التحديث'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('تأكيد الحذف',
            style: TextStyle(color: Color(0xFFD4AF37))),
        content: Text(
          'هل تريد حذف ${student['name']}؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dio.delete('/students/${student['id']}');
      _fetchStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل الحذف'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: _filter,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'بحث...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : RefreshIndicator(
                  onRefresh: _fetchStudents,
                  color: const Color(0xFFD4AF37),
                  child: _filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'لا يوجد طلاب',
                                style: TextStyle(color: Colors.white30),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final student = _filtered[index];
                            final isActive = student['is_active'] as bool;
                            return Dismissible(
                              key: Key(student['id'] as String),
                              background: _swipeBackground(
                                isActive ? Colors.redAccent : const Color(0xFFD4AF37),
                                isActive ? Icons.power_settings_new : Icons.check,
                                Alignment.centerLeft,
                              ),
                              secondaryBackground: _swipeBackground(
                                Colors.redAccent,
                                Icons.delete,
                                Alignment.centerRight,
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  await _deleteStudent(student);
                                } else {
                                  await _toggleActive(student);
                                }
                                return false;
                              },
                              child: _studentCard(student, isActive),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _swipeBackground(Color color, IconData icon, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: color),
    );
  }

  Widget _studentCard(Map<String, dynamic> student, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFFD4AF37) : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  student['code'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            isActive ? 'نشط' : 'غير نشط',
            style: TextStyle(
              color: isActive ? const Color(0xFFD4AF37) : Colors.redAccent,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
