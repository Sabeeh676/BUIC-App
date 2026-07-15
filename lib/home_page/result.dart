import 'package:buic_app/services/student_data_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';

// Data Models for structured results
class CourseResult {
  final String courseId;
  final String courseName;
  final CategoryResult assignments;
  final CategoryResult quizzes;
  final CategoryResult midterm;
  final CategoryResult project;

  CourseResult({
    required this.courseId,
    required this.courseName,
    required this.assignments,
    required this.quizzes,
    required this.midterm,
    required this.project,
  });

  factory CourseResult.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CourseResult(
      courseId: doc.id,
      courseName: data['courseName'] ?? 'Unknown Course',
      assignments: CategoryResult.fromMap(data['assignments'], 'Assignments'),
      quizzes: CategoryResult.fromMap(data['quizzes'], 'Quizzes'),
      midterm: CategoryResult.fromMap(data['midterm'], 'Midterm'),
      project: CategoryResult.fromMap(data['project'], 'Project'),
    );
  }

  factory CourseResult.placeholder({
    required String courseId,
    required String courseName,
  }) {
    return CourseResult(
      courseId: courseId,
      courseName: courseName,
      assignments: CategoryResult(title: 'Assignments'),
      quizzes: CategoryResult(title: 'Quizzes'),
      midterm: CategoryResult(title: 'Midterm'),
      project: CategoryResult(title: 'Project'),
    );
  }
}

class CategoryResult {
  final String title;
  final double totalMarks;
  final double obtainedMarks;

  CategoryResult({
    required this.title,
    this.totalMarks = 0,
    this.obtainedMarks = 0,
  });

  factory CategoryResult.fromMap(Map<String, dynamic>? data, String title) {
    if (data == null) {
      return CategoryResult(title: title);
    }
    return CategoryResult(
      title: title,
      totalMarks: (data['totalMarks'] ?? 0).toDouble(),
      obtainedMarks: (data['obtainedMarks'] ?? 0).toDouble(),
    );
  }
}

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final _studentDataService = StudentDataService();
  bool _isLoading = true;
  List<CourseResult> _allCourseResults = [];

  @override
  void initState() {
    super.initState();
    _fetchAllResults();
  }

  Future<void> _fetchAllResults({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final studentData = await _studentDataService.getStudentData(
        forceRefresh: forceRefresh,
      );
      if (studentData == null || studentData.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final studentId = studentData['id'];
      final registeredCourses = List<String>.from(
        studentData['registeredCourses'] ?? [],
      );
      final courseNames =
          await _studentDataService.getCourseNames(
            forceRefresh: forceRefresh,
          ) ??
          {};

      if (studentId == null || registeredCourses.isEmpty) {
        if (mounted) {
          setState(() {
            _allCourseResults = [];
            _isLoading = false;
          });
        }
        return;
      }

      final resultsSnapshot = await FirebaseFirestore.instance
          .collection('results')
          .doc(studentId)
          .collection('courses')
          .get();

      final Map<String, CourseResult> existingResults = {
        for (var doc in resultsSnapshot.docs)
          doc.id: CourseResult.fromFirestore(doc),
      };

      final List<CourseResult> finalResults = [];
      for (String courseId in registeredCourses) {
        if (existingResults.containsKey(courseId)) {
          finalResults.add(existingResults[courseId]!);
        } else {
          finalResults.add(
            CourseResult.placeholder(
              courseId: courseId,
              courseName: courseNames[courseId] ?? 'Unknown Course',
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _allCourseResults = finalResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching all results: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching results: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Academic Results',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: const Color(0xFF0D7E75),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0D7E75),
        onRefresh: () => _fetchAllResults(forceRefresh: true),
        child: _isLoading
            ? _buildShimmerLoading()
            : _allCourseResults.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                itemCount: _allCourseResults.length,
                itemBuilder: (context, index) {
                  return CourseResultCard(
                    result: _allCourseResults[index],
                    index: index,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 10,
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.assessment_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Results Available',
            style: TextStyle(
              fontSize: 22,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Results will appear here once uploaded',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 150,
                                    height: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CourseResultCard extends StatelessWidget {
  final CourseResult result;
  final int index;

  const CourseResultCard({
    super.key,
    required this.result,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAnyResults =
        result.assignments.totalMarks > 0 ||
        result.quizzes.totalMarks > 0 ||
        result.midterm.totalMarks > 0 ||
        result.project.totalMarks > 0;

    // Calculate overall progress
    double totalObtained =
        result.assignments.obtainedMarks +
        result.quizzes.obtainedMarks +
        result.midterm.obtainedMarks +
        result.project.obtainedMarks;
    double totalMarks =
        result.assignments.totalMarks +
        result.quizzes.totalMarks +
        result.midterm.totalMarks +
        result.project.totalMarks;
    double overallPercentage = totalMarks > 0
        ? (totalObtained / totalMarks) * 100
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D7E75),
                  const Color(0xFF0D7E75).withOpacity(0.85),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.courseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (hasAnyResults) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${overallPercentage.toStringAsFixed(1)}% Overall',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: hasAnyResults
                ? Column(
                    children: [
                      ResultCategoryView(
                        category: result.assignments,
                        icon: Icons.assignment_rounded,
                        color: const Color(0xFFFF6B6B),
                      ),
                      ResultCategoryView(
                        category: result.quizzes,
                        icon: Icons.quiz_rounded,
                        color: const Color(0xFF4ECDC4),
                      ),
                      ResultCategoryView(
                        category: result.midterm,
                        icon: Icons.assessment_rounded,
                        color: const Color(0xFF95E1D3),
                      ),
                      ResultCategoryView(
                        category: result.project,
                        icon: Icons.group_work_rounded,
                        color: const Color(0xFFFFA07A),
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hourglass_empty_rounded,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Results Pending',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No results have been uploaded yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ResultCategoryView extends StatelessWidget {
  final CategoryResult category;
  final IconData icon;
  final Color color;

  const ResultCategoryView({
    super.key,
    required this.category,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (category.totalMarks == 0) {
      return const SizedBox.shrink();
    }

    final double percentage = category.totalMarks > 0
        ? category.obtainedMarks / category.totalMarks
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Obtained',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: category.obtainedMarks.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${category.totalMarks.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
