import 'package:buic_app/services/database_helper.dart';
import 'package:buic_app/services/download_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

class MyCoursesPage extends StatefulWidget {
  const MyCoursesPage({super.key});

  @override
  State<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends State<MyCoursesPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? studentId;
  final dbHelper = DatabaseHelper();

  bool isLoading = true;
  List<Map<String, dynamic>> courses = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeStudent();
  }

  Future<void> _initializeStudent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        studentId = user.email!.split('@')[0];
      });
      _loadCoursesData();
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCoursesData() async {
    await _fetchCoursesFromCache();
    await _fetchCoursesFromFirestore();
  }

  Future<void> _fetchCoursesFromCache() async {
    final cachedData = await dbHelper.getCachedData('courses');
    if (cachedData.isNotEmpty && mounted) {
      setState(() {
        courses = cachedData;
        isLoading = false;
      });
    }
  }

  Future<void> _fetchCoursesFromFirestore() async {
    if (studentId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      final studentDoc = await _firestore
          .collection('students')
          .doc(studentId!)
          .get();
      final studentData = studentDoc.data();
      if (studentData == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final String studentClass = studentData['class'];
      final List<String> courseIds = List<String>.from(
        studentData['registeredCourses'] ?? [],
      );

      if (courseIds.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final coursesSnapshot = await _firestore
          .collection('courses')
          .where(FieldPath.documentId, whereIn: courseIds)
          .get();

      final classFutures = courseIds.map(
        (courseId) => _firestore
            .collection('courses')
            .doc(courseId)
            .collection('classes')
            .doc(studentClass)
            .get(),
      );
      final classDocs = await Future.wait(classFutures);

      Map<String, dynamic> coursesMap = {
        for (var doc in coursesSnapshot.docs) doc.id: doc.data(),
      };
      Map<String, dynamic> classMap = {
        for (var doc in classDocs)
          if (doc.exists) doc.reference.parent.parent!.id: doc.data(),
      };

      Set<String> teacherIds = classMap.values
          .where((data) => data != null && data['teacher_id'] != null)
          .map((data) => data['teacher_id'] as String)
          .toSet();

      Map<String, String> teacherNames = {};
      if (teacherIds.isNotEmpty) {
        final teacherSnapshot = await _firestore
            .collection('teachers')
            .where(FieldPath.documentId, whereIn: teacherIds.toList())
            .get();
        teacherNames = {
          for (var doc in teacherSnapshot.docs)
            doc.id: doc['name'] ?? 'Unknown',
        };
      }

      List<Map<String, dynamic>> fetchedCourses = [];
      for (String courseId in courseIds) {
        var courseData = coursesMap[courseId];
        if (courseData == null) continue;

        var classData = classMap[courseId];
        String teacherName = "Unknown";
        if (classData != null && classData['teacher_id'] != null) {
          teacherName = teacherNames[classData['teacher_id']] ?? "Unknown";
        }

        fetchedCourses.add({
          'course_id': courseId,
          'course_name': courseData['course_name'],
          'credit_hours': courseData['credit_hours'],
          'teacher_name': teacherName,
          'student_class': studentClass,
        });
      }

      if (mounted) {
        setState(() {
          courses = fetchedCourses;
          isLoading = false;
        });
      }

      await dbHelper.cacheData('courses', fetchedCourses);
    } catch (e) {
      print("Error fetching courses: $e");
      if (mounted && courses.isEmpty) {
        setState(() => isLoading = false);
      }
    }
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showCourseDetails(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CourseDetailsModal(course: course, onLaunchURL: _launchURL),
    );
  }

  Color _getCourseColor(int index) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFF84CC16), // Lime
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'My Courses',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${courses.length} Courses',
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : courses.isEmpty
          ? _buildEmptyState()
          : _buildCoursesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No courses enrolled',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your academic advisor to enroll in courses',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildModernCourseCard(courses[index], index),
              );
            }, childCount: courses.length),
          ),
        ),
      ],
    );
  }

  Widget _buildModernCourseCard(Map<String, dynamic> course, int index) {
    final courseColor = _getCourseColor(index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: courseColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCourseDetails(course),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: courseColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          course['course_name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course['course_name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course['course_id'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200], thickness: 1),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12.0,
                  runSpacing: 8.0,
                  children: <Widget>[
                    _buildInfoChip(
                      Icons.person_outline,
                      course['teacher_name'],
                      courseColor,
                    ),
                    _buildInfoChip(
                      Icons.class_outlined,
                      'Class ${course['student_class']}',
                      Colors.grey[600]!,
                    ),
                    _buildInfoChip(
                      Icons.schedule_outlined,
                      '${course['credit_hours']} Credit Hours',
                      Colors.grey[600]!,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CourseDetailsModal extends StatefulWidget {
  final Map<String, dynamic> course;
  final Function(String) onLaunchURL;

  const CourseDetailsModal({
    super.key,
    required this.course,
    required this.onLaunchURL,
  });

  @override
  State<CourseDetailsModal> createState() => _CourseDetailsModalState();
}

class _CourseDetailsModalState extends State<CourseDetailsModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Map<String, dynamic>? _files;
  bool _isLoadingFiles = true;

  // New state variables for downloads
  final DownloadService _downloadService = DownloadService();
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloaded = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
    _fetchMiscFiles();
  }

  Future<void> _fetchMiscFiles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingFiles = false);
        return;
      }
      final courseId = widget.course['course_id'];
      final studentClass = widget.course['student_class'];

      if (studentClass == null) {
        if (mounted) setState(() => _isLoadingFiles = false);
        return;
      }

      final miscSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('classes')
          .doc(studentClass)
          .collection('misc')
          .get();

      List<dynamic> miscFiles =
          miscSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      Map<String, dynamic> files = {
        'Book': null,
        'Course Outline': null,
        'Other': [],
      };

      for (var data in miscFiles) {
        final title = data['title']?.toString() ?? 'Other';
        final fileUrl = data['file_url']?.toString();
        final fileId = data['id'];

        final fileData = {'id': fileId, 'title': title, 'file_url': fileUrl};

        if (title == 'Book' || title == 'Course Outline') {
          files[title] = fileData;
        } else {
          files['Other'].add(fileData);
        }
      }

      if (mounted) {
        setState(() {
          _files = files;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      print("Error fetching misc files: $e");
      if (mounted) {
        setState(() {
          _isLoadingFiles = false;
        });
      }
    }
  }

  Future<void> _checkIfDownloaded(
      String courseName, String fileName, String fileId) async {
    final path = await _downloadService.getDownloadPath(
        courseName, 'Miscellaneous', fileName);
    final exists = await _downloadService.fileExists(path);
    if (mounted) {
      setState(() {
        _isDownloaded[fileId] = exists;
      });
    }
  }

  Future<void> _downloadMiscFile(
      String url, String courseName, String fileId, String title) async {
    final fileName = '${fileId}_${title.replaceAll(' ', '_')}.pdf';
    final path = await _downloadService.getDownloadPath(
        courseName, 'Miscellaneous', fileName);

    if (await _downloadService.fileExists(path)) {
      OpenFile.open(path);
      return;
    }

    setState(() {
      _downloadProgress[fileId] = 0.0;
    });

    try {
      await _downloadService.downloadFile(
        url: url,
        courseName: courseName,
        category: 'Miscellaneous',
        fileName: fileName,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[fileId] = progress;
          });
        },
      );
      setState(() {
        _downloadProgress.remove(fileId);
        _isDownloaded[fileId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      OpenFile.open(path);
    } catch (e) {
      setState(() {
        _downloadProgress.remove(fileId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _animation.value) * 300),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                _buildModalHeader(),
                Expanded(child: _buildModalContent()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    widget.course['course_name'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course['course_name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.course['course_id'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
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

  Widget _buildModalContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildFilesSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          Icons.person_outline,
          'Instructor',
          widget.course['teacher_name'],
        ),
        _buildInfoRow(
          Icons.class_outlined,
          'Class',
          widget.course['student_class'] ?? 'N/A',
        ),
        _buildInfoRow(
          Icons.schedule_outlined,
          'Credit Hours',
          '${widget.course['credit_hours']}',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Materials',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingFiles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else if (_files != null)
          ..._buildFileList(_files!)
        else
          _buildEmptyFilesState(),
      ],
    );
  }

  List<Widget> _buildFileList(Map<String, dynamic> files) {
    List<Widget> fileWidgets = [];

    // Handle Book and Course Outline
    ['Book', 'Course Outline'].forEach((key) {
      if (files[key] != null) {
        fileWidgets.add(_buildFileCard(files[key]));
      }
    });

    // Handle Other files
    if (files['Other'] is List) {
      for (var fileData in files['Other']) {
        fileWidgets.add(_buildFileCard(fileData));
      }
    }

    if (fileWidgets.isEmpty) {
      return [_buildEmptyFilesState()];
    }

    return fileWidgets;
  }

  Widget _buildFileCard(Map<String, dynamic> fileData) {
    final fileId = fileData['id'] as String;
    final title = fileData['title'] as String;
    final fileUrl = fileData['file_url'] as String?;
    final courseName = widget.course['course_name'] as String;

    final isDownloading = _downloadProgress.containsKey(fileId);
    final isDownloaded = _isDownloaded[fileId] ?? false;

    _checkIfDownloaded(
        courseName, '${fileId}_${title.replaceAll(' ', '_')}.pdf', fileId);

    IconData iconData;
    Color iconColor;

    if (title.toLowerCase().contains('book')) {
      iconData = Icons.menu_book_rounded;
      iconColor = const Color(0xFF059669);
    } else if (title.toLowerCase().contains('outline')) {
      iconData = Icons.description_rounded;
      iconColor = const Color(0xFF7C3AED);
    } else {
      iconData = Icons.insert_drive_file_rounded;
      iconColor = const Color(0xFF0EA5E9);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: fileUrl != null ? Colors.white : Colors.grey[50],
        border: Border.all(
          color: fileUrl != null
              ? iconColor.withOpacity(0.2)
              : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: fileUrl != null
                ? iconColor.withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            iconData,
            color: fileUrl != null ? iconColor : Colors.grey[500],
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: fileUrl != null ? const Color(0xFF1E293B) : Colors.grey[600],
          ),
        ),
        subtitle: isDownloading
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _downloadProgress[fileId],
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'Downloading... ${(_downloadProgress[fileId]! * 100).toStringAsFixed(0)}%'),
                ],
              )
            : Text(
                isDownloaded
                    ? 'Downloaded'
                    : (fileUrl != null ? 'Tap to download' : 'Not available'),
                style: TextStyle(
                  fontSize: 14,
                  color:
                      fileUrl != null ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
        trailing: fileUrl != null && !isDownloading
            ? Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDownloaded ? Colors.green : iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDownloaded ? Icons.open_in_new : Icons.download_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              )
            : null,
        onTap: fileUrl != null && !isDownloading
            ? () => _downloadMiscFile(fileUrl, courseName, fileId, title)
            : null,
      ),
    );
  }

  Widget _buildEmptyFilesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No materials available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Course materials will appear here when uploaded',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
