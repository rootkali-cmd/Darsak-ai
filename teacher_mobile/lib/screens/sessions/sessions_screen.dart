import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_theme.dart';
import '../../models/lecture_session.dart';
import '../../providers/sessions_provider.dart';
import '../../providers/groups_provider.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionsProvider>().loadSessions();
      context.read<GroupsProvider>().loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحاضرات المتكررة'),
      ),
      body: Consumer<SessionsProvider>(
        builder: (context, provider, _) {
          if (provider.sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_repeat, size: 64, color: Color(0xFF6b7280)),
                  SizedBox(height: 16),
                  Text('لا توجد محاضرات', style: TextStyle(color: Colors.white, fontSize: 18)),
                  SizedBox(height: 8),
                  Text(
                    'أنشئ محاضرة متكررة لتشمل عدة مجموعات وأيام',
                    style: TextStyle(color: Color(0xFF6b7280), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.sessions.length,
            itemBuilder: (context, index) {
              final session = provider.sessions[index];
              return Card(
                color: const Color(0xFF1a1a2e),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(session.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${session.schedules.length} مجموعة • ${session.schedules.map((s) => s.dayName).toSet().join(", ")}',
                    style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                        onPressed: () => _showEditSession(session),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppTheme.danger, size: 20),
                        onPressed: () => _deleteSession(session.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSession,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddSession() {
    // Show bottom sheet or dialog to create session
    _showSessionDialog();
  }

  void _showEditSession(LectureSession session) {
    _showSessionDialog(session: session);
  }

  void _showSessionDialog({LectureSession? session}) {
    final nameController = TextEditingController(text: session?.name ?? '');
    final descController = TextEditingController(text: session?.description ?? '');
    final List<SessionSchedule> schedules = session?.schedules.toList() ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            title: Text(
              session == null ? 'محاضرة جديدة' : 'تعديل المحاضرة',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'اسم المحاضرة',
                      labelStyle: TextStyle(color: Color(0xFF6b7280)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'وصف (اختياري)',
                      labelStyle: TextStyle(color: Color(0xFF6b7280)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('المجموعات والأيام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...schedules.asMap().entries.map((entry) {
                    final i = entry.key;
                    final sch = entry.value;
                    return ListTile(
                      title: Text('${sch.groupName} - ${sch.dayName} ${sch.timeSlot}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppTheme.danger, size: 18),
                        onPressed: () {
                          setDialogState(() => schedules.removeAt(i));
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showAddSchedule(schedules, setDialogState),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('إضافة مجموعة + يوم'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  final newSession = LectureSession(
                    id: session?.id ?? const Uuid().v4(),
                    name: nameController.text.trim(),
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    schedules: schedules,
                  );

                  final provider = context.read<SessionsProvider>();
                  if (session == null) {
                    await provider.createSession(newSession);
                  } else {
                    await provider.updateSession(newSession);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFdc2626)),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSchedule(List<SessionSchedule> schedules, StateSetter setDialogState) {
    final groupsProvider = context.read<GroupsProvider>();
    final groups = groupsProvider.groups;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مجموعات. أضف مجموعات أولاً.')),
      );
      return;
    }

    String? selectedGroupId;
    int selectedDay = DateTime.now().weekday;
    final timeController = TextEditingController(text: '10:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('إضافة موعد', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'المجموعة', labelStyle: TextStyle(color: Color(0xFF6b7280))),
              items: groups.map<DropdownMenuItem<String>>((g) {
                return DropdownMenuItem<String>(
                  value: g['id'].toString(),
                  child: Text(g['name'] ?? 'مجموعة', style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (v) => selectedGroupId = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'اليوم', labelStyle: TextStyle(color: Color(0xFF6b7280))),
              items: const [
                DropdownMenuItem(value: 1, child: Text('الإثنين', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 2, child: Text('الثلاثاء', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 3, child: Text('الأربعاء', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 4, child: Text('الخميس', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 5, child: Text('الجمعة', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 6, child: Text('السبت', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 7, child: Text('الأحد', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => selectedDay = v ?? 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'وقت المحاضرة (مثال: 10:00)',
                labelStyle: TextStyle(color: Color(0xFF6b7280)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedGroupId == null) return;
              final group = groups.firstWhere((g) => g['id'].toString() == selectedGroupId);
              setDialogState(() {
                schedules.add(SessionSchedule(
                  groupId: selectedGroupId!,
                  groupName: group['name'] ?? 'مجموعة',
                  dayOfWeek: selectedDay,
                  timeSlot: timeController.text,
                ));
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFdc2626)),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذه المحاضرة؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<SessionsProvider>().deleteSession(id);
    }
  }
}
