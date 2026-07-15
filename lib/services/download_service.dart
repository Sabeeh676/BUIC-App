import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<String> getDownloadPath(
      String courseName, String category, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final sanitizedCourseName = courseName.replaceAll(RegExp(r'[^\w\s]+'), '');
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s\.]+'), '');

    final path =
        '${directory.path}/BUIC/$sanitizedCourseName/$category/$sanitizedFileName';
    return path;
  }

  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  Future<void> downloadFile({
    required String url,
    required String courseName,
    required String category,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    // 1. Request storage permission
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission not granted');
    }

    // 2. Get the local path
    final path = await getDownloadPath(courseName, category, fileName);
    final file = File(path);

    // 3. Create directory if it doesn't exist
    await file.parent.create(recursive: true);

    // 4. Download the file
    await _dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );
  }
}
