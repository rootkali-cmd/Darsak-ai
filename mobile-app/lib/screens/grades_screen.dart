import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/data_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _selectedSubject;
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرجات'),
        actions: [
          IconButton(
            icon: Icon(_showChart ? Icons.list : Icons.bar_chart),
            onPressed: () => setState(() => _showChart = !_showChart),
            tooltip: _showChart ? 'قائمة' : 'رسم بياني',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => data.fetchGrades(subject: _selectedSubject),
          ),
        ],
      ),
      body: Column(
        children: [
          if (data.subjects.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: _selectedSubject == null,
                      onTap: () {
                        setState(() => _selectedSubject = null);
                        data.fetchGrades();
                      },
                    ),
                    const SizedBox(width: 6),
                    ...data.subjects.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _FilterChip(
                        label: s,
                        selected: _selectedSubject == s,
                        onTap: () {
                          setState(() => _selectedSubject = s);
                          data.fetchGrades(subject: s);
                        },
                      ),
                    )),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _buildContent(data),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DataProvider data) {
    if (data.isLoading && data.grades.isEmpty) {
      return const ShimmerList();
    }

    if (data.grades.isEmpty) {
      if (data.isOffline) {
        return ErrorState(
          message: 'لا يمكن الاتصال بالخادم',
          onRetry: () => data.fetchGrades(subject: _selectedSubject),
        );
      }
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'لا توجد درجات حالياً',
        subtitle: 'سيتم عرض درجاتك هنا بعد أول اختبار',
      );
    }

    final grades = _selectedSubject != null
        ? data.gradesBySubject(_selectedSubject!)
        : data.grades;

    if (_showChart && grades.isNotEmpty) {
      return _buildChart(grades);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grades.length,
      itemBuilder: (context, index) {
        final g = grades[index];
        final pct = g.percentage;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(g.examName, style: const TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(g.subject, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: const Color(0xFF2A2A2A),
                        color: pct >= 75
                            ? const Color(0xFF10B981)
                            : pct >= 50
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: pct >= 75
                          ? const Color(0xFF10B981)
                          : pct >= 50
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${g.score.toStringAsFixed(0)} / ${g.maxScore.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChart(List grades) {
    final spots = <FlSpot>[];
    for (int i = 0; i < grades.length; i++) {
      spots.add(FlSpot(i.toDouble(), grades[i].percentage));
    }
    final maxY = grades.fold<double>(0, (m, g) => g.percentage > m ? g.percentage : m) + 10;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFF2A2A2A),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (grades.length - 1).toDouble(),
                minY: 0,
                maxY: maxY.clamp(50, 100),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF2563EB),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF2563EB),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: grades.asMap().entries.map((e) {
              final g = e.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: g.percentage >= 75
                          ? const Color(0xFF10B981)
                          : g.percentage >= 50
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.createdAt.month.toString(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 9),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF2A2A2A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2563EB) : Colors.grey[400],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
