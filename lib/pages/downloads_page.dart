import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<Directory> _courseFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedCourses();
  }

  Future<void> _loadDownloadedCourses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final directory = await getApplicationDocumentsDirectory();
      final buicDir = Directory('${directory.path}/BUIC');
      if (await buicDir.exists()) {
        final folders = buicDir.listSync().whereType<Directory>().toList();
        setState(() {
          _courseFolders = folders;
        });
      }
    } catch (e) {
      print("Error loading downloaded courses: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Files'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, const Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courseFolders.isEmpty
              ? _buildEmptyState()
              : _buildCoursesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No downloaded files',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your downloaded materials will appear here.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _courseFolders.length,
      itemBuilder: (context, index) {
        final courseFolder = _courseFolders[index];
        final courseName = courseFolder.path.split('/').last;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.folder, color: Theme.of(context).primaryColor),
            title: Text(courseName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CourseDownloadsPage(courseFolder: courseFolder),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class CourseDownloadsPage extends StatelessWidget {
  final Directory courseFolder;
  const CourseDownloadsPage({super.key, required this.courseFolder});

  @override
  Widget build(BuildContext context) {
    final courseName = courseFolder.path.split('/').last;
    final categoryFolders =
        courseFolder.listSync().whereType<Directory>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(courseName),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, const Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: categoryFolders.length,
        itemBuilder: (context, index) {
          final categoryFolder = categoryFolders[index];
          final categoryName = categoryFolder.path.split('/').last;
          final files = categoryFolder.listSync().whereType<File>().toList();

          return ExpansionTile(
            leading:
                Icon(Icons.folder_special, color: Colors.amber.shade700),
            title: Text('$categoryName (${files.length})',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            children: files.map((file) {
              final fileName = file.path.split('/').last;
              return ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(fileName),
                onTap: () => OpenFile.open(file.path),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
