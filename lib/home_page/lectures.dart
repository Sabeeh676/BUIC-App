import 'package:buic_app/services/download_service.dart';
import 'package:buic_app/services/student_data_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

class LecturesPage extends StatefulWidget {
  const LecturesPage({super.key});

  @override
  State<LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends State<LecturesPage> {
  final _studentDataService = StudentDataService();
  Map<String, List<Map<String, dynamic>>> courseLectures = {};
  Map<String, String> courseNames = {};
  List registeredCourses = [];
  bool isLoading = true;
  String classId = '';
  String studentId = '';

  final DownloadService _downloadService = DownloadService();
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloaded = {};

  @override
  void initState() {
    super.initState();
    fetchLectures();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No due date';
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy h:mm a').format(date);
  }

  Future<void> fetchLectures({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final studentData = await _studentDataService.getStudentData(
        forceRefresh: forceRefresh,
      );
      if (studentData == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      studentId = studentData['id'];
      classId = studentData['class'];
      List<String> registeredCourses = List<String>.from(
        studentData['registeredCourses'] ?? [],
      );

      if (classId.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      if (registeredCourses.isEmpty) {
        setState(() {
          courseLectures = {};
          isLoading = false;
        });
        return;
      }

      final newCourseNames =
          await _studentDataService.getCourseNames(
            forceRefresh: forceRefresh,
          ) ??
          {};

      final lecturesSnapshots = await Future.wait(
        registeredCourses.map((courseId) {
          return FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .collection('classes')
              .doc(classId)
              .collection('lectures')
              .orderBy('uploadTime', descending: true)
              .get();
        }),
      );

      final newCourseLectures = <String, List<Map<String, dynamic>>>{};
      for (var course in registeredCourses) {
        newCourseLectures[course] = [];
      }

      for (var snapshot in lecturesSnapshots) {
        for (var doc in snapshot.docs) {
          final courseId = doc.reference.parent.parent!.parent.parent!.id;
          newCourseLectures[courseId]!.add({
            'id': doc.id,
            'title': doc['title'],
            'externalLinks': doc['externalLinks'],
            'fileUrl': doc['fileUrl'],
          });
        }
      }

      var sortedEntries = newCourseLectures.entries.toList()
        ..sort((a, b) {
          bool aHasLectures = a.value.isNotEmpty;
          bool bHasLectures = b.value.isNotEmpty;
          if (aHasLectures && !bHasLectures) return -1;
          if (!aHasLectures && bHasLectures) return 1;
          return 0;
        });

      setState(() {
        courseNames = newCourseNames;
        courseLectures = Map.fromEntries(sortedEntries);
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching lectures: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching lectures: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkIfDownloaded(
    String courseName,
    String fileName,
    String lectureId,
  ) async {
    final path = await _downloadService.getDownloadPath(
      courseName,
      'Lectures',
      fileName,
    );
    final exists = await _downloadService.fileExists(path);
    if (mounted) {
      setState(() {
        _isDownloaded[lectureId] = exists;
      });
    }
  }

  Future<void> _downloadLecture(
    String url,
    String courseName,
    String lectureId,
  ) async {
    final fileName = '${lectureId}_${url.split('/').last.split('?').first}';
    final path = await _downloadService.getDownloadPath(
      courseName,
      'Lectures',
      fileName,
    );

    if (await _downloadService.fileExists(path)) {
      OpenFile.open(path);
      return;
    }

    setState(() {
      _downloadProgress[lectureId] = 0.0;
    });

    try {
      await _downloadService.downloadFile(
        url: url,
        courseName: courseName,
        category: 'Lectures',
        fileName: fileName,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[lectureId] = progress;
          });
        },
      );
      setState(() {
        _downloadProgress.remove(lectureId);
        _isDownloaded[lectureId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Lecture downloaded successfully!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      OpenFile.open(path);
    } catch (e) {
      setState(() {
        _downloadProgress.remove(lectureId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Download failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          children: [
            Text(
              'Course Lectures',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Bahria University Islamabad',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D7E75),
        centerTitle: true,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF0D7E75),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your lectures...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF0D7E75),
              onRefresh: () => fetchLectures(forceRefresh: true),
              child: courseLectures.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      itemCount: courseLectures.entries.length,
                      itemBuilder: (context, index) {
                        final entry = courseLectures.entries.elementAt(index);
                        final courseId = entry.key;
                        final courseName =
                            courseNames[courseId] ?? "Unnamed Course";
                        final lectures = entry.value;

                        return _buildCourseCard(
                          courseName,
                          courseId,
                          lectures,
                          index,
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D7E75).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_library_outlined,
                  size: 80,
                  color: const Color(0xFF0D7E75).withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Lectures Available',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You don\'t have any registered courses yet.\nCheck back later for updates.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    String courseName,
    String courseId,
    List<Map<String, dynamic>> lectures,
    int index,
  ) {
    final colors = [
      [const Color(0xFF0D7E75), const Color(0xFF0A6660)],
      [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
      [const Color(0xFF43A047), const Color(0xFF2E7D32)],
      [const Color(0xFFE53935), const Color(0xFFC62828)],
      [const Color(0xFFFB8C00), const Color(0xFFE65100)],
      [const Color(0xFF8E24AA), const Color(0xFF6A1B9A)],
    ];

    final colorPair = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Enhanced Course Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colorPair,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${lectures.length} ${lectures.length == 1 ? 'Lecture' : 'Lectures'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Lectures List
            if (lectures.isEmpty)
              _buildEmptyLecturesState()
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: lectures.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, lectureIndex) {
                  final lecture = lectures[lectureIndex];
                  return _buildLectureItem(lecture, lectureIndex, courseName);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLecturesState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.video_library_outlined, size: 48, color: Colors.grey[350]),
          const SizedBox(height: 12),
          Text(
            'No lectures uploaded yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check back later for updates',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureItem(
    Map<String, dynamic> lecture,
    int index,
    String courseName,
  ) {
    final lectureId = lecture['id'] as String;
    final isDownloading = _downloadProgress.containsKey(lectureId);
    final isDownloaded = _isDownloaded[lectureId] ?? false;

    _checkIfDownloaded(
      courseName,
      '${lectureId}_${lecture['fileUrl'].split('/').last.split('?').first}',
      lectureId,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8EB), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: const Color(0xFF0D7E75).withOpacity(0.05),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D7E75),
                  const Color(0xFF0D7E75).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7E75).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            lecture['title'],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3142),
              height: 1.3,
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF0D7E75),
            size: 28,
          ),
          children: [
            const SizedBox(height: 8),
            if (lecture['externalLinks'] != null &&
                lecture['externalLinks'].isNotEmpty) ...[
              _buildExternalLinks(lecture['externalLinks']),
              const SizedBox(height: 16),
            ],
            _buildDownloadButton(
              lecture,
              courseName,
              isDownloading,
              isDownloaded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLinks(List externalLinks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF0D7E75), size: 18),
            SizedBox(width: 8),
            Text(
              'External Resources',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E8EB)),
          ),
          child: Column(
            children: List.generate(externalLinks.length, (linkIndex) {
              final link = externalLinks[linkIndex];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse(link);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Could not open $link')),
                            ],
                          ),
                          backgroundColor: Colors.red.shade600,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D7E75).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.open_in_new,
                            color: Color(0xFF0D7E75),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resource ${linkIndex + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                link,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(
    Map<String, dynamic> lecture,
    String courseName,
    bool isDownloading,
    bool isDownloaded,
  ) {
    final lectureId = lecture['id'] as String;

    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D7E75).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0D7E75).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Downloading...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D7E75),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${(_downloadProgress[lectureId]! * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D7E75),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress[lectureId],
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF0D7E75),
                ),
                minHeight: 8,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDownloaded
              ? [Colors.green.shade600, Colors.green.shade700]
              : [const Color(0xFF0D7E75), const Color(0xFF0A6660)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isDownloaded ? Colors.green : const Color(0xFF0D7E75))
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _downloadLecture(lecture['fileUrl'], courseName, lectureId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDownloaded
                      ? Icons.open_in_new_rounded
                      : Icons.download_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  isDownloaded ? 'Open Lecture' : 'Download Lecture',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
