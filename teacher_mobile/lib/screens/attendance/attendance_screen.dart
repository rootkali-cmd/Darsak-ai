import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'barcode_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'present';
  final List<Map<String, dynamic>> _attendanceList = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _StatusChip(
                    label: 'حاضر',
                    value: 'present',
                    color: AppTheme.success,
                    selected: _selectedStatus == 'present',
                    onTap: () => setState(() => _selectedStatus = 'present'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusChip(
                    label: 'غائب',
                    value: 'absent',
                    color: AppTheme.danger,
                    selected: _selectedStatus == 'absent',
                    onTap: () => setState(() => _selectedStatus = 'absent'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusChip(
                    label: 'ملغي',
                    value: 'cancelled',
                    color: AppTheme.warning,
                    selected: _selectedStatus == 'cancelled',
                    onTap: () => setState(() => _selectedStatus = 'cancelled'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    Text(
                      'تغيير',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _attendanceList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 64, color: AppTheme.darkTextMuted),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد سجلات حضور لهذا اليوم',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'استخدم مسح الباركود لتسجيل الحضور',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _attendanceList.length,
                    itemBuilder: (context, index) {
                      final item = _attendanceList[index];
                      return _AttendanceItem(
                        name: item['name'] ?? 'طالب',
                        code: item['code'] ?? '',
                        status: item['status'] ?? 'present',
                        time: item['time'] ?? '',
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
          );
          if (result != null && result is Map<String, dynamic>) {
            setState(() {
              _attendanceList.insert(0, {
                'name': result['name'] ?? 'طالب',
                'code': result['code'] ?? '',
                'status': 'present',
                'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              });
            });
          }
        },
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.barcode_reader),
        label: const Text('مسح الباركود'),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: AppTheme.accent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppTheme.darkBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppTheme.darkTextSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceItem extends StatelessWidget {
  final String name;
  final String code;
  final String status;
  final String time;

  const _AttendanceItem({
    required this.name,
    required this.code,
    required this.status,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'present':
        statusColor = AppTheme.success;
        break;
      case 'absent':
        statusColor = AppTheme.danger;
        break;
      case 'cancelled':
        statusColor = AppTheme.warning;
        break;
      default:
        statusColor = AppTheme.darkTextMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'كود: $code',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
