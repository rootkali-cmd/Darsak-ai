import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'lesson_viewer_screen.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _availableCourses = [];
  List<dynamic> _enrolledCourses = [];
  bool _isLoading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getAvailableCourses(),
        _api.getEnrolledCourses(),
      ]);
      if (!mounted) return;
      setState(() {
        _availableCourses = results[0];
        _enrolledCourses = results[1];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الكورسات'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                _buildTabs(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _currentTab == 0
                        ? _buildCourseList(_availableCourses, isEnrolled: false)
                        : _buildCourseList(_enrolledCourses, isEnrolled: true),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _currentTab == 0 ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'الكورسات المتاحة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentTab == 0 ? Colors.white : AppColors.textSecondary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _currentTab == 1 ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'كورساتي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentTab == 1 ? Colors.white : AppColors.textSecondary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList(List<dynamic> courses, {required bool isEnrolled}) {
    if (courses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Icon(
            isEnrolled ? Icons.school_outlined : Icons.store_outlined,
            size: 64,
            color: AppColors.textSecondary(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              isEnrolled ? 'لم تنضم لأي كورس بعد' : 'لا توجد كورسات متاحة',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: courses.length,
      itemBuilder: (_, i) => _buildCourseCard(courses[i], isEnrolled: isEnrolled),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, {required bool isEnrolled}) {
    final title = course['title'] ?? '';
    final subject = course['subject'] ?? '';
    final level = course['level'] ?? '';
    final description = course['description'] ?? '';
    final pricing = course['pricing'];
    final isFreeForStudent = course['is_free_for_student'] ?? true;
    final centerPrice = pricing != null ? (pricing['center_price'] ?? 0).toDouble() : 0.0;
    final platformPrice = pricing != null ? (pricing['platform_price'] ?? 0).toDouble() : 0.0;
    final chaptersCount = course['chapters_count'] ?? course['chapters']?.length ?? 0;

    return GestureDetector(
      onTap: () => _openCourseDetail(course['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      if (subject.isNotEmpty || level.isNotEmpty)
                        Text(
                          [subject, level].where((e) => e.isNotEmpty).join(' - '),
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (isEnrolled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('مسجل', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isFreeForStudent ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isFreeForStudent ? 'مجاني' : '${_getPrice(course).toStringAsFixed(0)} ج.م',
                      style: TextStyle(
                        color: isFreeForStudent ? AppTheme.success : AppTheme.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _getPrice(Map<String, dynamic> course) {
    final pricing = course['pricing'];
    if (pricing == null) return 0;
    final isFreeForStudent = course['is_free_for_student'] ?? true;
    if (isFreeForStudent) return 0;
    return (pricing['platform_price'] ?? pricing['center_price'] ?? 0).toDouble();
  }

  void _openCourseDetail(String? courseId) {
    if (courseId == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CourseDetailScreen(courseId: courseId),
    ));
  }
}

class _CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const _CourseDetailScreen({required this.courseId});

  @override
  State<_CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<_CourseDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _course;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getCourseDetail(widget.courseId);
      if (!mounted) return;
      final inner = data['data'] ?? data;
      setState(() {
        _course = inner is Map<String, dynamic> ? inner : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_course?['title'] ?? 'الكورس')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _course == null
              ? const Center(child: Text('لم يتم العثور على الكورس'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final course = _course!;
    final isEnrolled = course['is_enrolled'] ?? false;
    final isFree = course['is_free'] ?? true;
    final centerPrice = (course['center_price'] ?? 0).toDouble();
    final platformPrice = (course['platform_price'] ?? 0).toDouble();
    final chapters = course['chapters'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isEnrolled && !isFree) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text('السعر', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${platformPrice > 0 ? platformPrice.toStringAsFixed(0) : centerPrice.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPurchasing ? null : _purchaseCourse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isPurchasing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('شراء الكورس', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (chapters.isNotEmpty) ...[
            Text('الفصول', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...chapters.map((ch) => _buildChapter(ch, isEnrolled)),
          ],
          if (chapters.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('لا توجد فصول بعد', style: TextStyle(color: AppColors.textSecondary(context))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapter(Map<String, dynamic> chapter, bool isEnrolled) {
    final title = chapter['title'] ?? '';
    final lessons = chapter['lessons'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text('${lessons.length} درس', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
          children: lessons.map((l) => _buildLesson(l, isEnrolled)).toList(),
        ),
      ),
    );
  }

  Widget _buildLesson(Map<String, dynamic> lesson, bool isEnrolled) {
    final title = lesson['title'] ?? '';
    final lessonId = lesson['id'] ?? '';
    final isLocked = lesson['is_locked'] ?? false;
    final hasExam = lesson['has_exam'] ?? false;
    final hasVideo = lesson['video_url'] != null || lesson['r2_video_key'] != null;

    return ListTile(
      leading: Icon(
        isLocked ? Icons.lock : (hasExam ? Icons.quiz : (hasVideo ? Icons.play_circle_outline : Icons.article_outlined)),
        color: isLocked ? AppColors.textSecondary(context).withValues(alpha: 0.4) : AppTheme.accent,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLocked ? AppColors.textSecondary(context).withValues(alpha: 0.5) : AppColors.textPrimary(context),
          fontSize: 14,
          decoration: isLocked ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: isLocked
          ? null
          : Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary(context), size: 14),
      onTap: isLocked || !isEnrolled ? null : () {
        if (lessonId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonViewerScreen(
              courseId: widget.courseId,
              lessonId: lessonId.toString(),
              lessonTitle: title,
            ),
          ),
        );
      },
    );
  }

  void _purchaseCourse() async {
    setState(() => _isPurchasing = true);
    try {
      final result = await _api.purchaseCourse(widget.courseId);
      if (!mounted) return;
      final msg = result['message'] ?? 'تم بنجاح';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: AppTheme.success),
      );
      _loadCourse();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }
}
