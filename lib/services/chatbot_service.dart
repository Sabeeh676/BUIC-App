import 'package:dio/dio.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> sources;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatbotService {
  // Change this to your server IP if running on a physical device
  // Use 10.0.2.2 for Android emulator, or your PC's local IP for real device
  static const String _baseUrl = 'http://10.0.2.2:8000';

  final Dio _dio;

  ChatbotService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  Future<ChatMessage> sendMessage(String question, [List<ChatMessage> history = const []]) async {
    try {
      final formattedHistory = history.map((msg) => {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      }).toList();

      final response = await _dio.post(
        '/chat',
        data: {
          'question': question,
          'history': formattedHistory,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final answer = data['answer'] as String;
      final rawSources = data['sources'] as List<dynamic>? ?? [];

      final sources = rawSources
          .map((s) => 'Page ${s['page']}: ${s['page_content']}')
          .toList()
          .cast<String>();

      return ChatMessage(text: answer, isUser: false, sources: sources);
    } on DioException catch (e) {
      String errorMsg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMsg =
            'The chatbot is taking too long to respond. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg =
            'Could not connect to the BU Chatbot server. Make sure it is running.';
      } else {
        errorMsg = 'Something went wrong. Please try again later.';
      }
      return ChatMessage(text: errorMsg, isUser: false);
    } catch (e) {
      return ChatMessage(
        text: 'An unexpected error occurred. Please try again.',
        isUser: false,
      );
    }
  }

  Future<bool> isServerReachable() async {
    try {
      final response = await _dio.get(
        '/',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
