import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/grade.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final List<GradeModel> _grades = [];

  void _showAddGradeDialog() {
    final examController = TextEditingController();
    final subjectController = TextEditingController();
    final scoreController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إضافة درجة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: examController,
                decoration: const InputDecoration(labelText: 'اسم الامتحان'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'المادة'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: scoreController,
                      decoration: const InputDecoration(labelText: 'الدرجة'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxScoreController,
                      decoration: const InputDecoration(labelText: 'من'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final score = double.tryParse(scoreController.text) ?? 0;
                  final maxScore = double.tryParse(maxScoreController.text) ?? 100;
                  final grade = GradeModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    studentId: '',
                    examName: examController.text.trim(),
                    subject: subjectController.text.trim(),
                    score: score,
                    maxScore: maxScore,
                    createdAt: DateTime.now(),
                  );
                  setState(() => _grades.insert(0, grade));
                  Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('الدرجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddGradeDialog,
          ),
        ],
      ),
      body: _grades.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grade_outlined, size: 64, color: AppTheme.darkTextMuted),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد درجات مسجلة',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _grades.length,
              itemBuilder: (context, index) {
                final grade = _grades[index];
                return _GradeCard(grade: grade);
              },
            ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final GradeModel grade;
  const _GradeCard({required this.grade});

  @override
  Widget build(BuildContext context) {
    final percentage = grade.percentage;
    Color color;
    if (percentage >= 90) {
      color = AppTheme.success;
    } else if (percentage >= 70) {
      color = AppTheme.accentLight;
    } else if (percentage >= 50) {
      color = AppTheme.warning;
    } else {
      color = AppTheme.danger;
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${percentage.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.examName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${grade.subject} • ${grade.score}/${grade.maxScore}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: AppTheme.darkTextMuted, size: 14),
        ],
      ),
    );
  }
}
