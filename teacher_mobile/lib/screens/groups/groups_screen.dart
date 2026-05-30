import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/groups_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupsProvider>(context, listen: false).loadGroups();
    });
  }

  void _showAddGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditGroupScreen()),
    );
  }

  void _showEditGroup(dynamic group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditGroupScreen(group: group)),
    );
  }

  Future<void> _deleteGroup(dynamic group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف المجموعة "${group['name'] ?? ''}"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<GroupsProvider>(context, listen: false);
      final success = await provider.deleteGroup(group['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'تم الحذف بنجاح' : (provider.error ?? 'فشل الحذف'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المجموعات'),
      ),
      body: Consumer<GroupsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AppLoadingIndicator();
          }
          if (provider.error != null && provider.groups.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadGroups(),
            );
          }
          if (provider.groups.isEmpty) {
            return const EmptyState(message: 'لا توجد مجموعات', icon: Icons.groups);
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadGroups(),
            color: const Color(0xFFdc2626),
            backgroundColor: const Color(0xFF1a1a2e),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.groups.length,
              itemBuilder: (context, index) {
                final group = provider.groups[index];
                return Card(
                  color: const Color(0xFF1a1a2e),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _showEditGroup(group),
                    onLongPress: () => _deleteGroup(group),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF3b82f6).withValues(alpha: 0.2),
                      child: const Icon(Icons.groups, color: Color(0xFF3b82f6)),
                    ),
                    title: Text(
                      group['name']?.toString() ?? '—',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${group['subject']?.toString() ?? ''} ${group['level']?.toString() ?? ''}\n'
                      '${group['day_of_week']?.toString() ?? ''} ${group['time_slot']?.toString() ?? ''}',
                      style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteGroup(group),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGroup,
        backgroundColor: const Color(0xFFdc2626),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
