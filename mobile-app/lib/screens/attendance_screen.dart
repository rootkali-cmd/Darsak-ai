import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/empty_state.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _currentMonth = DateTime.now();

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _firstWeekday(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    final monthRecords = data.attendance.where((a) {
      final d = DateTime.tryParse(a.date);
      return d != null && d.month == _currentMonth.month && d.year == _currentMonth.year;
    }).toList();

    final presentCount = monthRecords.where((a) => a.status == 'present').length;
    final absentCount = monthRecords.where((a) => a.status == 'absent').length;
    final rate = monthRecords.isEmpty ? 0.0 : (presentCount / monthRecords.length) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور والغياب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => data.fetchAttendance(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF141414)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                      child: const Icon(Icons.chevron_right, color: Color(0xFF2563EB)),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'ar').format(_currentMonth),
                      style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                      child: const Icon(Icons.chevron_left, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: const Color(0xFF2A2A2A),
                    color: rate >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'نسبة الحضور: ${rate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: rate >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(color: const Color(0xFF10B981), label: 'حاضر $presentCount'),
                    const SizedBox(width: 16),
                    _LegendItem(color: const Color(0xFFEF4444), label: 'غائب $absentCount'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: data.isLoading && data.attendance.isEmpty
                ? const ShimmerList()
                : data.attendance.isEmpty
                    ? const EmptyState(
                        icon: Icons.calendar_month,
                        title: 'لا توجد سجلات حضور',
                        subtitle: 'سيتم عرض سجلات الحضور بعد أول محاضرة',
                      )
                    : _buildCalendar(monthRecords),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List records) {
    final days = _daysInMonth(_currentMonth);
    final firstWeekday = _firstWeekday(_currentMonth);
    final recordMap = <String, String>{};
    for (final r in records) {
      recordMap[r.date.split('-').last] = r.status;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['سبت', 'أحد', 'اثن', 'ثلث', 'أرب', 'خمس', 'جمع']
                .map((d) => SizedBox(
                      width: 40,
                      child: Text(d, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: firstWeekday - 1 + days,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) return const SizedBox();
                final day = index - firstWeekday + 2;
                final dayStr = day.toString().padLeft(2, '0');
                final status = recordMap[dayStr];
                return _DayCell(day: day, status: status);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final String? status;

  const _DayCell({required this.day, this.status});

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color textColor = const Color(0xFFF5F5F5);

    if (status == 'present') {
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
      textColor = const Color(0xFF10B981);
    } else if (status == 'absent') {
      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
      textColor = const Color(0xFFEF4444);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: status != null ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}
